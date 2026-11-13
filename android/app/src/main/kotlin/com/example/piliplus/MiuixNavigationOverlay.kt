package com.aritxonly.hyperpiliplus

import android.app.Activity
import android.net.Uri
import android.graphics.Color as AndroidColor
import android.view.Gravity
import android.view.MotionEvent
import android.view.ViewGroup
import android.view.View
import android.widget.FrameLayout
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.platform.ComposeView
import androidx.compose.ui.platform.ViewCompositionStrategy
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.LifecycleRegistry
import androidx.lifecycle.ViewModelStore
import androidx.lifecycle.ViewModelStoreOwner
import androidx.lifecycle.setViewTreeLifecycleOwner
import androidx.lifecycle.setViewTreeViewModelStoreOwner
import androidx.savedstate.SavedStateRegistry
import androidx.savedstate.SavedStateRegistryController
import androidx.savedstate.SavedStateRegistryOwner
import androidx.savedstate.setViewTreeSavedStateRegistryOwner
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.renderer.FlutterUiDisplayListener
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

private const val MIUIX_NAVIGATION_CHANNEL = "com.aritxonly.hyperpiliplus/miuix_navigation"
private val MY_HYPER_MODIFIER_SETTINGS_URI =
    Uri.parse("content://com.aritxonly.myhypermodifier.settings")

/**
 * A thin native shell around Flutter's main destinations.  Flutter remains
 * the source of truth for pages; this overlay only owns the Android chrome.
 */
internal class MiuixNavigationOverlay(
    private val activity: Activity,
    flutterEngine: FlutterEngine,
) {
    private val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, MIUIX_NAVIGATION_CHANNEL)
    private var uiState by mutableStateOf(NavigationUiState())
    private var backdropSnapshot by mutableStateOf<FlutterBackdropSnapshot?>(null)
    private var backdropDebugState by mutableStateOf(FlutterBackdropDebugState())
    private var backdropSamplingPaused = false
    private var overlayOccluded = false
    private var hostActivityCovered = false
    private var sharedNavigationLiftDp by mutableStateOf(0f)
    private var globalLiftLoadInFlight = false
    private var composeView: ComposeView? = null
    private var viewTreeOwner: OverlayViewTreeOwner? = null
    private val flutterRenderer = flutterEngine.renderer
    private val backdropSampler = FlutterSurfaceBackdropSampler(
        activity = activity,
        onSnapshotChanged = { snapshot -> backdropSnapshot = snapshot },
        onDebugStateChanged = { debugState -> backdropDebugState = debugState },
    )
    private val flutterUiDisplayListener = object : FlutterUiDisplayListener {
        override fun onFlutterUiDisplayed() {
            backdropSampler.onFlutterUiDisplayed()
        }

        override fun onFlutterUiNoLongerDisplayed() {
            backdropSampler.onFlutterUiNoLongerDisplayed()
        }
    }

    init {
        // Unlike a polling delay, this callback fires exactly when Flutter has
        // committed its first usable frame to the rendering surface. FlutterRenderer
        // also invokes it immediately when the UI was already being displayed.
        flutterRenderer.addIsDisplayingFlutterUiListener(flutterUiDisplayListener)
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "update" -> {
                    uiState = NavigationUiState.from(call.arguments as? Map<*, *>)
                    if (uiState.followMyHyperModifierNavigationLift) {
                        refreshSharedNavigationLift()
                    }
                    backdropSampler.setDebugEnabled(uiState.backdropDebug)
                    updateBackdropSampling()
                    result.success(null)
                }
                "flutterFrameRendered" -> {
                    backdropSampler.onFlutterFrameRendered()
                    result.success(null)
                }
                "setBackdropSamplingPaused" -> {
                    backdropSamplingPaused = call.arguments as? Boolean ?: false
                    updateBackdropSampling()
                    result.success(null)
                }
                "setOverlayOccluded" -> {
                    setOverlayOccluded(call.arguments as? Boolean ?: false)
                    result.success(null)
                }
                "hide" -> {
                    uiState = uiState.copy(visible = false)
                    backdropSampler.setEnabled(false)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    fun attach() {
        if (composeView != null) return
        val lifecycleOwner = activity as? LifecycleOwner ?: return
        val owner = OverlayViewTreeOwner(lifecycleOwner)
        val view = ComposeView(activity).apply {
            // This view is attached beside Flutter's root view, so it cannot
            // inherit FlutterActivity's lifecycle through the usual parent
            // hierarchy. FlutterActivity does not implement the ViewModel or
            // saved-state owner interfaces, so the overlay owns those trees.
            setViewTreeLifecycleOwner(owner)
            setViewTreeViewModelStoreOwner(owner)
            setViewTreeSavedStateRegistryOwner(owner)
            setViewCompositionStrategy(ViewCompositionStrategy.DisposeOnDetachedFromWindow)
            setContent {
                DeadlinerNavigationOverlayContent(
                    state = uiState.copy(
                        bottomLiftDp = if (uiState.followMyHyperModifierNavigationLift) {
                            sharedNavigationLiftDp
                        } else {
                            uiState.bottomLiftDp
                        },
                    ),
                    backdropSnapshot = backdropSnapshot,
                    backdropDebugState = backdropDebugState,
                    onBackdropBoundsChanged = backdropSampler::setNavigationBounds,
                    onDestinationSelected = ::selectDestination,
                )
            }
        }
        val content = activity.findViewById<ViewGroup>(android.R.id.content)
        content.addView(
            view,
            FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
                Gravity.BOTTOM,
            ),
        )
        composeView = view
        view.visibility = if (overlayOccluded) View.INVISIBLE else View.VISIBLE
        viewTreeOwner = owner
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
        flutterRenderer.removeIsDisplayingFlutterUiListener(flutterUiDisplayListener)
        composeView?.let { view ->
            (view.parent as? ViewGroup)?.removeView(view)
        }
        composeView = null
        backdropSampler.dispose()
        viewTreeOwner?.dispose()
        viewTreeOwner = null
    }

    fun onTouchEvent(event: MotionEvent) {
        backdropSampler.onTouchEvent(event)
    }

    private fun updateBackdropSampling() {
        backdropSampler.setEnabled(
            uiState.visible && uiState.backdropSampling && !backdropSamplingPaused &&
                !overlayOccluded && !hostActivityCovered,
        )
    }

    fun setHostActivityCovered(covered: Boolean) {
        hostActivityCovered = covered
        composeView?.visibility = if (covered || overlayOccluded) View.INVISIBLE else View.VISIBLE
        updateBackdropSampling()
    }

    fun setOverlayOccluded(occluded: Boolean) {
        overlayOccluded = occluded
        composeView?.visibility =
            if (occluded || hostActivityCovered) View.INVISIBLE else View.VISIBLE
        updateBackdropSampling()
    }

    private fun selectDestination(index: Int) {
        if (index !in uiState.destinations.indices) return
        // Update the native source immediately so the selected icon and the
        // moving indicator stay in sync with the tap. Flutter remains the
        // routing source of truth and will confirm the same index in `update`.
        uiState = uiState.copy(selectedIndex = index)
        channel.invokeMethod("selectDestination", index)
    }

    private fun refreshSharedNavigationLift() {
        if (globalLiftLoadInFlight) return
        globalLiftLoadInFlight = true
        settingsExecutor.execute {
            val lift = runCatching {
                activity.contentResolver.call(
                    MY_HYPER_MODIFIER_SETTINGS_URI,
                    "get_settings",
                    null,
                    null,
                )?.getFloat("hyper_glassify_hidden_navigation_lift", 0f) ?: 0f
            }.getOrDefault(0f).coerceIn(0f, 48f)
            activity.runOnUiThread {
                sharedNavigationLiftDp = lift
                globalLiftLoadInFlight = false
            }
        }
    }

    private companion object {
        val settingsExecutor = Executors.newSingleThreadExecutor { runnable ->
            Thread(runnable, "HyperPiliPlus-settings").apply { isDaemon = true }
        }
    }
}

/**
 * FlutterActivity supplies a LifecycleOwner but not ComponentActivity's
 * ViewModelStore/SavedState owners. Compose's current Android runtime requires
 * all three ViewTree owners even for a standalone overlay, so provide a small,
 * lifecycle-synchronised owner rather than casting FlutterActivity.
 */
private class OverlayViewTreeOwner(
    host: LifecycleOwner,
) : LifecycleOwner, ViewModelStoreOwner, SavedStateRegistryOwner, DefaultLifecycleObserver {
    private val hostLifecycle = host.lifecycle
    private val lifecycleRegistry = LifecycleRegistry(this)
    private val savedStateController = SavedStateRegistryController.create(this)

    override val lifecycle: Lifecycle
        get() = lifecycleRegistry
    override val viewModelStore = ViewModelStore()
    override val savedStateRegistry: SavedStateRegistry
        get() = savedStateController.savedStateRegistry

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
        if (lifecycleRegistry.currentState != Lifecycle.State.DESTROYED)
            lifecycleRegistry.currentState = state
    }
}

internal data class NavigationDestination(
    val key: String,
    val label: String,
    /** Null means no badge; an empty string is a dot-only badge. */
    val badge: String? = null,
)

internal data class NavigationUiState(
    val destinations: List<NavigationDestination> = emptyList(),
    val selectedIndex: Int = 0,
    val visible: Boolean = false,
    val backdropSampling: Boolean = false,
    val backdropDebug: Boolean = false,
    val bottomLiftDp: Float = 0f,
    val followMyHyperModifierNavigationLift: Boolean = false,
    val dark: Boolean = false,
    val primary: Int = AndroidColor.rgb(52, 130, 255),
    val background: Int = AndroidColor.rgb(243, 243, 243),
    val surface: Int = AndroidColor.rgb(243, 243, 243),
    val surfaceContainer: Int = AndroidColor.WHITE,
    val onSurface: Int = AndroidColor.BLACK,
    val outline: Int = AndroidColor.rgb(217, 217, 217),
) {
    companion object {
        fun from(args: Map<*, *>?): NavigationUiState {
            if (args == null) return NavigationUiState()
            val destinations = (args["destinations"] as? List<*>)
                ?.mapNotNull { raw ->
                    val item = raw as? Map<*, *> ?: return@mapNotNull null
                    val key = item["key"] as? String ?: return@mapNotNull null
                    val label = item["label"] as? String ?: return@mapNotNull null
                    NavigationDestination(key, label, item["badge"] as? String)
                }
                .orEmpty()
            fun color(name: String, fallback: Int) = (args[name] as? Number)?.toInt() ?: fallback
            return NavigationUiState(
                destinations = destinations,
                selectedIndex = ((args["selectedIndex"] as? Number)?.toInt() ?: 0)
                    .coerceIn(0, (destinations.size - 1).coerceAtLeast(0)),
                visible = (args["visible"] as? Boolean == true) && destinations.size > 1,
                backdropSampling = args["backdropSampling"] as? Boolean ?: false,
                backdropDebug = args["backdropDebug"] as? Boolean ?: false,
                bottomLiftDp = ((args["bottomLiftDp"] as? Number)?.toFloat() ?: 0f)
                    .coerceIn(0f, 48f),
                followMyHyperModifierNavigationLift =
                    args["followMyHyperModifierNavigationLift"] as? Boolean ?: false,
                dark = args["dark"] as? Boolean ?: false,
                primary = color("primary", AndroidColor.rgb(52, 130, 255)),
                background = color("background", AndroidColor.rgb(243, 243, 243)),
                surface = color("surface", AndroidColor.rgb(243, 243, 243)),
                surfaceContainer = color("surfaceContainer", AndroidColor.WHITE),
                onSurface = color("onSurface", AndroidColor.BLACK),
                outline = color("outline", AndroidColor.rgb(217, 217, 217)),
            )
        }
    }
}
