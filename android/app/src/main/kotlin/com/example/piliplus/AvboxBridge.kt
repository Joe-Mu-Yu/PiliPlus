package com.aritxonly.hyperpiliplus

import android.content.Context
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import androidx.activity.OnBackPressedDispatcher
import androidx.activity.OnBackPressedDispatcherOwner
import androidx.activity.setViewTreeOnBackPressedDispatcherOwner
import androidx.compose.ui.platform.ComposeView
import androidx.compose.ui.platform.ViewCompositionStrategy
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.LifecycleRegistry
import androidx.lifecycle.ViewModelStore
import androidx.lifecycle.ViewModelStoreOwner
import androidx.lifecycle.findViewTreeLifecycleOwner
import androidx.lifecycle.findViewTreeViewModelStoreOwner
import androidx.lifecycle.setViewTreeLifecycleOwner
import androidx.lifecycle.setViewTreeViewModelStoreOwner
import androidx.savedstate.SavedStateRegistry
import androidx.savedstate.SavedStateRegistryController
import androidx.savedstate.SavedStateRegistryOwner
import androidx.savedstate.findViewTreeSavedStateRegistryOwner
import androidx.savedstate.setViewTreeSavedStateRegistryOwner
import com.github.avbox.osc.base.App
import com.github.avbox.osc.ui.page.MainScreen
import com.github.avbox.osc.ui.theme.AVBoxTheme
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

/** Hosts AVBox directly inside Flutter's Movies tab. */
internal class AvboxBridge(
    private val activity: MainActivity,
    flutterEngine: FlutterEngine,
) {
    private val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)

    init {
        App.initialize(activity.applicationContext)
        // A recreated Activity can reuse the cached FlutterEngine, so this bridge
        // may run twice in one process. PlatformViewRegistry has no unregister
        // API on this Flutter version, so the factory registers once per process
        // and resolves the current host/exit callback dynamically; re-registering
        // must never throw at startup.
        if (AvboxSharedState.exitCallback == null) {
            check(
                flutterEngine.platformViewsController.registry.registerViewFactory(
                    VIEW_TYPE,
                    AvboxPlatformViewFactory(activity, ::exitEmbedded),
                ),
            ) { "AVBox platform view could not be registered" }
        }
        AvboxSharedState.exitOwner = this
        AvboxSharedState.exitCallback = ::exitEmbedded
        AvboxSharedState.host = activity
    }

    private fun exitEmbedded() {
        channel.invokeMethod("exitEmbedded", null)
    }

    fun dispose() {
        // Only the most recently attached bridge owns the shared callback; a
        // recreated Activity installs a new bridge before the old one is disposed.
        if (AvboxSharedState.exitOwner === this) {
            AvboxSharedState.exitOwner = null
            AvboxSharedState.exitCallback = null
            AvboxSharedState.host = null
        }
        channel.setMethodCallHandler(null)
    }

    companion object {
        const val CHANNEL = "com.aritxonly.hyperpiliplus/avbox"
        const val VIEW_TYPE = "com.aritxonly.hyperpiliplus/avbox_view"
    }
}

/**
 * Process-wide bridge state. A recreated Activity reuses the cached
 * FlutterEngine, so the platform-view factory registered by the first bridge
 * must resolve the current host lazily instead of capturing one Activity.
 */
private object AvboxSharedState {
    @Volatile
    var exitOwner: AvboxBridge? = null

    @Volatile
    var exitCallback: (() -> Unit)? = null

    @Volatile
    var host: MainActivity? = null
}

/**
 * Registered once per process. The platform view is created lazily whenever the
 * Flutter Movies tab mounts, which can happen long after the registering
 * Activity was destroyed, so the host is resolved dynamically from the shared
 * bridge state instead of being captured at registration time.
 */
private class AvboxPlatformViewFactory(
    private val activity: MainActivity,
    private val onExit: () -> Unit,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val host = AvboxSharedState.host ?: activity
        return AvboxPlatformView(host, context, AvboxSharedState.exitCallback ?: onExit)
    }
}

private class AvboxPlatformView(
    private val activity: MainActivity,
    context: Context,
    onExit: () -> Unit,
) : PlatformView {
    private val owner = AvboxViewTreeOwner(activity, onExit)
    private val composeView = ComposeView(context)
    private val rootView = FrameLayout(context).apply {
        installViewTreeOwners(this)
        addView(
            composeView.apply {
                installViewTreeOwners(this)
                setViewCompositionStrategy(
                    ViewCompositionStrategy.DisposeOnViewTreeLifecycleDestroyed,
                )
                setContent {
                    AVBoxTheme {
                        MainScreen(
                            onExit = onExit,
                            embedded = true,
                            onHostNavigationOcclusionChanged =
                                activity::setMiuixNavigationOccluded,
                        )
                    }
                }
            },
            FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT,
            ),
        )
    }
    private var flutterView: View? = null
    private var previousLifecycleOwner: LifecycleOwner? = null
    private var previousViewModelStoreOwner: ViewModelStoreOwner? = null
    private var previousSavedStateRegistryOwner: SavedStateRegistryOwner? = null

    /**
     * Compose 1.12 resolves a shared ComposeViewContext from the outermost
     * Compose root. For a Flutter PlatformView that root is FlutterView, not
     * this ComposeView, so the owners must also be present there before the
     * first PlatformView measure. Restore the previous tree when Flutter
     * detaches so the bridge never leaves host-wide state behind.
     */
    override fun onFlutterViewAttached(flutterView: View) {
        restoreFlutterViewOwners()
        this.flutterView = flutterView
        previousLifecycleOwner = flutterView.findViewTreeLifecycleOwner()
        previousViewModelStoreOwner = flutterView.findViewTreeViewModelStoreOwner()
        previousSavedStateRegistryOwner = flutterView.findViewTreeSavedStateRegistryOwner()
        installViewTreeOwners(flutterView, includeBackDispatcher = false)
    }

    override fun onFlutterViewDetached() {
        restoreFlutterViewOwners()
    }

    private fun installViewTreeOwners(
        view: View,
        includeBackDispatcher: Boolean = true,
    ) {
        view.setViewTreeLifecycleOwner(owner)
        view.setViewTreeViewModelStoreOwner(owner)
        view.setViewTreeSavedStateRegistryOwner(owner)
        if (includeBackDispatcher) {
            view.setViewTreeOnBackPressedDispatcherOwner(owner)
        }
    }

    private fun restoreFlutterViewOwners() {
        flutterView?.let { view ->
            view.setViewTreeLifecycleOwner(previousLifecycleOwner)
            view.setViewTreeViewModelStoreOwner(previousViewModelStoreOwner)
            view.setViewTreeSavedStateRegistryOwner(previousSavedStateRegistryOwner)
        }
        flutterView = null
        previousLifecycleOwner = null
        previousViewModelStoreOwner = null
        previousSavedStateRegistryOwner = null
    }

    override fun getView(): View = rootView

    override fun dispose() {
        activity.setMiuixNavigationOccluded(false)
        composeView.disposeComposition()
        restoreFlutterViewOwners()
        rootView.removeAllViews()
        owner.dispose()
    }
}

/** FlutterActivity has LifecycleOwner only; Compose viewModel/BackHandler need the other owners. */
private class AvboxViewTreeOwner(
    host: LifecycleOwner,
    onBack: () -> Unit,
) : LifecycleOwner,
    ViewModelStoreOwner,
    SavedStateRegistryOwner,
    OnBackPressedDispatcherOwner,
    DefaultLifecycleObserver {
    private val hostLifecycle = host.lifecycle
    private val lifecycleRegistry = LifecycleRegistry(this)
    private val savedStateController = SavedStateRegistryController.create(this)

    override val lifecycle: Lifecycle
        get() = lifecycleRegistry
    override val viewModelStore = ViewModelStore()
    override val savedStateRegistry: SavedStateRegistry
        get() = savedStateController.savedStateRegistry
    override val onBackPressedDispatcher = OnBackPressedDispatcher(onBack)

    init {
        savedStateController.performAttach()
        savedStateController.performRestore(null)
        hostLifecycle.addObserver(this)
        lifecycleRegistry.currentState = hostLifecycle.currentState
    }

    override fun onCreate(owner: LifecycleOwner) = moveTo(Lifecycle.State.CREATED)

    override fun onStart(owner: LifecycleOwner) = moveTo(Lifecycle.State.STARTED)

    override fun onResume(owner: LifecycleOwner) = moveTo(Lifecycle.State.RESUMED)

    override fun onPause(owner: LifecycleOwner) = moveTo(Lifecycle.State.STARTED)

    override fun onStop(owner: LifecycleOwner) = moveTo(Lifecycle.State.CREATED)

    override fun onDestroy(owner: LifecycleOwner) = dispose()

    fun dispose() {
        hostLifecycle.removeObserver(this)
        if (lifecycleRegistry.currentState != Lifecycle.State.DESTROYED) {
            lifecycleRegistry.currentState = Lifecycle.State.DESTROYED
            viewModelStore.clear()
        }
    }

    private fun moveTo(state: Lifecycle.State) {
        if (lifecycleRegistry.currentState != Lifecycle.State.DESTROYED) {
            lifecycleRegistry.currentState = state
        }
    }
}
