@file:OptIn(androidx.compose.material3.ExperimentalMaterial3ExpressiveApi::class)

package com.github.avbox.osc.ui.page

import com.github.avbox.osc.api.AppBootstrap
import android.widget.Toast
import androidx.activity.compose.BackHandler
import androidx.annotation.DrawableRes
import androidx.annotation.StringRes
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.scrollBy
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.calculateStartPadding
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.systemBars
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationRail
import androidx.compose.material3.NavigationRailItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.ShortNavigationBar
import androidx.compose.material3.ShortNavigationBarItem
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.withFrameNanos
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.ContentDrawScope
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.compose.rememberLifecycleOwner
import androidx.lifecycle.viewmodel.compose.viewModel
import com.github.avbox.osc.R
import com.github.avbox.osc.ui.components.AVBoxAlertDialog
import com.github.avbox.osc.ui.components.LocalTopBarGlassPauseRecording
import com.github.avbox.osc.ui.components.LocalSheetDismissThen
import com.github.avbox.osc.ui.components.LocalSheetHost
import com.github.avbox.osc.ui.components.LocalTopBarSystemInsetConsumed
import com.github.avbox.osc.ui.components.SheetHost
import com.github.avbox.osc.ui.components.SheetHostState
import com.github.avbox.osc.ui.currentWindowWidthClass
import com.github.avbox.osc.ui.navbar.NavAxis
import com.github.avbox.osc.ui.navbar.NavMetrics
import com.github.avbox.osc.ui.settings.UiSettingsState
import com.github.avbox.osc.ui.theme.LiquidGlassState
import com.github.avbox.osc.boot.BootGuard
import com.github.avbox.osc.util.HomeSettings
import com.kyant.backdrop.backdrops.layerBackdrop
import com.kyant.backdrop.backdrops.rememberLayerBackdrop
import kotlinx.coroutines.launch

private enum class AppTab(@StringRes val labelRes: Int, @DrawableRes val icon: Int) {
    HOME(R.string.tab_home, R.drawable.ic_tab_home),
}

@Composable
fun MainScreen(
    onExit: () -> Unit,
    embedded: Boolean = false,
    onHostNavigationOcclusionChanged: (Boolean) -> Unit = {},
) {
    LaunchedEffect(Unit) { AppBootstrap.start() }
    DisposableEffect(embedded, onHostNavigationOcclusionChanged) {
        onDispose {
            if (embedded) onHostNavigationOcclusionChanged(false)
        }
    }
    val boot by AppBootstrap.state.collectAsState()
    Box(modifier = Modifier.fillMaxSize()) {
        MainContent(onExit, embedded, onHostNavigationOcclusionChanged)
        if (boot is AppBootstrap.Boot.Error) {
            BootErrorDialog((boot as AppBootstrap.Boot.Error).msg)
        }
    }
}

@Composable
private fun BootErrorDialog(msg: String) {
    AVBoxAlertDialog(
        onDismissRequest = {},
        dismissible = false,
        title = { Text(stringResource(R.string.config_load_failed)) },
        text = { Text(msg) },
        confirmButton = {
            val dismissThen = LocalSheetDismissThen.current
            TextButton(onClick = { dismissThen { AppBootstrap.retry() } }) {
                Text(stringResource(R.string.common_retry))
            }
        },
        dismissButton = {
            val dismissThen = LocalSheetDismissThen.current
            TextButton(onClick = { dismissThen { AppBootstrap.continueOffline() } }) {
                Text(stringResource(R.string.common_cancel))
            }
        },
    )
}

@Composable
private fun MainContent(
    onExit: () -> Unit,
    embedded: Boolean,
    onHostNavigationOcclusionChanged: (Boolean) -> Unit,
) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val pagerState = rememberPagerState(pageCount = { AppTab.entries.size })
    val homeViewModel: HomeViewModel = viewModel()

    LaunchedEffect(Unit) {
        if (homeViewModel.defaultLiveLaunched) return@LaunchedEffect
        AppBootstrap.state.collect { boot ->
            if (boot is AppBootstrap.Boot.Ready && !homeViewModel.defaultLiveLaunched) {
                homeViewModel.markDefaultLiveLaunched()
                val disabled = BootGuard.takeSafeDisabledNotice()
                if (disabled.isNotEmpty()) {
                    Toast.makeText(context, context.getString(R.string.toast_source_auto_disabled), Toast.LENGTH_LONG).show()
                }
            }
        }
    }

    LaunchedEffect(pagerState) {
        withFrameNanos { }
        withFrameNanos { }
        pagerState.scrollBy(1f)
        pagerState.scrollBy(-1f)
    }

    val sheetHost = remember { SheetHostState() }
    val sheetVisible = sheetHost.request != null
    BackHandler(enabled = !sheetVisible, onBack = onExit)
    LaunchedEffect(embedded, sheetVisible, onHostNavigationOcclusionChanged) {
        if (embedded) onHostNavigationOcclusionChanged(sheetVisible)
    }
    val navConfig = UiSettingsState.config
    val navAnimationEnabled = !navConfig.navAnimationDisabled

    val selectTab: (Int) -> Unit = { index ->
        scope.launch {
            if (navAnimationEnabled) {
                pagerState.animateScrollToPage(index)
            } else {
                pagerState.scrollToPage(index)
            }
        }
    }
    val liquidGlassConfig = LiquidGlassState.config
    // Embedded AVBox always keeps the IosLiquidGlassNavigationBar layout.
    // The AVBox preference still controls whether the capsule uses live blur
    // or the official solid-surface fallback, never a different nav component.
    val liquidGlassEnabled = true
    val liquidBackdropBgColor = MaterialTheme.colorScheme.surfaceContainer
    val liquidBackdropOnDraw: ContentDrawScope.() -> Unit =
        remember(liquidBackdropBgColor) {
            { drawRect(liquidBackdropBgColor); drawContent() }
        }
    val liquidBackdrop = rememberLayerBackdrop(onDraw = liquidBackdropOnDraw)
    val pauseGlassRecording: () -> Boolean = remember(pagerState, sheetHost) {
        { pagerState.isScrollInProgress || sheetHost.request != null }
    }
    val pauseTopBarRecording: () -> Boolean = remember(pagerState) {
        { pagerState.isScrollInProgress }
    }
    val density = LocalDensity.current
    val layoutDirection = LocalLayoutDirection.current

    val navAxis = NavMetrics.axisFor(currentWindowWidthClass())
    val railMode = navAxis == NavAxis.Vertical
    val surfaceNavVisible = !liquidGlassEnabled
    val emptyInsets = WindowInsets(0, 0, 0, 0)
    val navBarsPadding = (if (embedded) emptyInsets else WindowInsets.navigationBars).asPaddingValues()
    val navBandExtent = NavMetrics.BAND_EXTENT_DP.dp
    val liquidBackdropBounds: (Size) -> Rect? = remember(density, navBandExtent, navAxis) {
        { size ->
            val extentPx = with(density) { navBandExtent.toPx() }
            if (navAxis == NavAxis.Horizontal) {
                Rect(0f, 0f, size.width, extentPx)
            } else {
                Rect(0f, 0f, extentPx, size.height)
            }
        }
    }
    // The embedded build exposes only Home, so a one-item navigation capsule
    // is redundant. Keep the real status-bar inset after removing it; the
    // former capsule reserve happened to provide this clearance on phones.
    val pageViewportTopPadding = WindowInsets.statusBars
        .asPaddingValues()
        .calculateTopPadding()
    val embeddedHostBottomPadding =
        NavMetrics.embeddedHostBottomReserveDp(embedded, navAxis).dp
    val pageContentPadding = PaddingValues(
        start = if (railMode) navBarsPadding.calculateStartPadding(layoutDirection) else 0.dp,
        bottom = navBarsPadding.calculateBottomPadding() + embeddedHostBottomPadding,
    )
    CompositionLocalProvider(
        LocalSheetHost provides sheetHost,
        LocalTopBarGlassPauseRecording provides pauseTopBarRecording,
        // The pager below places every page after the host/status and floating
        // navigation bands, so page TopAppBars must not consume status bars a
        // second time. This mirrors the host app's top-safe-area structure.
        LocalTopBarSystemInsetConsumed provides true,
    ) {
        Box(modifier = Modifier.fillMaxSize()) {
            Scaffold(
                containerColor = MaterialTheme.colorScheme.surfaceContainer,
                contentWindowInsets = WindowInsets(0, 0, 0, 0),
                topBar = {
                    if (surfaceNavVisible && !railMode) {
                        ShortNavigationBar(
                            modifier = Modifier.windowInsetsPadding(
                                if (embedded) emptyInsets else WindowInsets.statusBars,
                            ),
                            containerColor = MaterialTheme.colorScheme.surfaceContainerHigh,
                        ) {
                            AppTab.entries.forEachIndexed { index, tab ->
                                val selected = pagerState.targetPage == index
                                ShortNavigationBarItem(
                                    selected = selected,
                                    onClick = { selectTab(index) },
                                    icon = {
                                        Icon(
                                            painterResource(tab.icon),
                                            contentDescription = stringResource(tab.labelRes),
                                        )
                                    },
                                    label = if (selected) {
                                        { Text(stringResource(tab.labelRes)) }
                                    } else {
                                        null
                                    },
                                )
                            }
                        }
                    }
                },
            ) { innerPadding ->
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .then(
                            if (liquidGlassEnabled) {
                                Modifier.layerBackdrop(liquidBackdrop, liquidBackdropBounds, pauseGlassRecording)
                            } else {
                                Modifier
                            }
                        ),
                ) {
                    HorizontalPager(
                        state = pagerState,
                        userScrollEnabled = navAnimationEnabled,
                        beyondViewportPageCount = 3,
                        modifier = Modifier
                            .fillMaxSize()
                            .padding(top = pageViewportTopPadding)
                            .then(if (liquidGlassEnabled) Modifier else Modifier.padding(innerPadding)),
                    ) { page ->
                        val pageLifecycleOwner = rememberLifecycleOwner(
                            maxLifecycle = if (page == pagerState.targetPage) {
                                Lifecycle.State.RESUMED
                            } else {
                                Lifecycle.State.STARTED
                            }
                        )
                        CompositionLocalProvider(LocalLifecycleOwner provides pageLifecycleOwner) {
                            when (AppTab.entries[page]) {
                                AppTab.HOME -> HomePage(homeViewModel, pageContentPadding)
                            }
                        }
                    }
                }
            }
            if (surfaceNavVisible && railMode) {
                NavigationRail(
                    modifier = Modifier
                        .align(Alignment.CenterStart)
                        .fillMaxHeight()
                    .windowInsetsPadding(if (embedded) emptyInsets else WindowInsets.systemBars),
                    containerColor = MaterialTheme.colorScheme.surfaceContainerHigh,
                ) {
                    AppTab.entries.forEachIndexed { index, tab ->
                        NavigationRailItem(
                            selected = pagerState.currentPage == index,
                            onClick = { selectTab(index) },
                            icon = {
                                Icon(
                                    painterResource(tab.icon),
                                    contentDescription = stringResource(tab.labelRes),
                                )
                            },
                            label = { Text(stringResource(tab.labelRes)) },
                        )
                    }
                }
            }
            SheetHost(sheetHost)
        }
    }
}
