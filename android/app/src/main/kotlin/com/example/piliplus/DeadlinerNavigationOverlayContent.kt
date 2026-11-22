package com.aritxonly.hyperpiliplus

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.only
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.Image
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicText
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.TransformOrigin
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.layout.positionInWindow
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import top.yukonga.miuix.kmp.basic.Badge
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.NavigationItem
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.blur.isRuntimeShaderSupported
import top.yukonga.miuix.kmp.blur.layerBackdrop
import top.yukonga.miuix.kmp.blur.rememberLayerBackdrop
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.ContactsCircle
import top.yukonga.miuix.kmp.icon.extended.Home
import top.yukonga.miuix.kmp.icon.extended.Messages
import top.yukonga.miuix.kmp.icon.extended.Play
import top.yukonga.miuix.kmp.icon.extended.Recording
import top.yukonga.miuix.kmp.icon.extended.ScreenMirroring
import top.yukonga.miuix.kmp.icon.extended.Search
import top.yukonga.miuix.kmp.blur.LayerBackdrop
import top.yukonga.miuix.kmp.blur.blur
import top.yukonga.miuix.kmp.blur.drawBackdrop
import top.yukonga.miuix.kmp.theme.LocalContentColor
import top.yukonga.miuix.kmp.theme.MiuixTheme
import top.yukonga.miuix.kmp.theme.darkColorScheme as miuixDarkColorScheme
import top.yukonga.miuix.kmp.theme.lightColorScheme as miuixLightColorScheme

/**
 * Flutter owns routes and state; Miuix's official liquid-glass example renders
 * the native navigation bar over a PixelCopy layer of the Flutter surface.
 */
@Composable
internal fun DeadlinerNavigationOverlayContent(
    state: NavigationUiState,
    backdropSnapshot: FlutterBackdropSnapshot?,
    backdropDebugState: FlutterBackdropDebugState,
    onBackdropBoundsChanged: (FlutterBackdropBounds) -> Unit,
    onDestinationSelected: (Int) -> Unit,
    onSearchActionSelected: () -> Unit,
) {
    val miuixColors = if (state.dark) {
        miuixDarkColorScheme(
            primary = Color(state.primary),
            background = Color(state.background),
            surface = Color(state.surface),
            surfaceContainer = Color(state.surfaceContainer),
            onSurface = Color(state.onSurface),
            outline = Color(state.outline),
        )
    } else {
        miuixLightColorScheme(
            primary = Color(state.primary),
            background = Color(state.background),
            surface = Color(state.surface),
            surfaceContainer = Color(state.surfaceContainer),
            onSurface = Color(state.onSurface),
            outline = Color(state.outline),
        )
    }
    val destinations = state.destinations.map { destination ->
        val icon = when (destination.key) {
            "home" -> MiuixIcons.Home
            "dynamics" -> MiuixIcons.Messages
            "mine" -> MiuixIcons.ContactsCircle
            "follow" -> MiuixIcons.ScreenMirroring
            "recorderCenter" -> MiuixIcons.Recording
            "movies" -> MiuixIcons.Play
            else -> MiuixIcons.ContactsCircle
        }
        NavigationItem(label = destination.label, icon = icon)
    }
    val backdrop = rememberLayerBackdrop()
    var rootPositionInWindow by remember { mutableStateOf(Offset.Zero) }
    val blurActive = backdropSnapshot != null && isRuntimeShaderSupported()

    MaterialTheme(
        colorScheme = if (state.dark) {
            darkColorScheme(
                primary = Color(state.primary),
                background = Color(state.background),
                surface = Color(state.surface),
                surfaceVariant = Color(state.surfaceContainer),
                onSurface = Color(state.onSurface),
                outline = Color(state.outline),
            )
        } else {
            lightColorScheme(
                primary = Color(state.primary),
                background = Color(state.background),
                surface = Color(state.surface),
                surfaceVariant = Color(state.surfaceContainer),
                onSurface = Color(state.onSurface),
                outline = Color(state.outline),
            )
        },
    ) {
        MiuixTheme(colors = miuixColors) {
            AnimatedVisibility(
                visible = state.visible,
                enter = fadeIn(tween(180)) + slideInVertically(tween(260)) { it / 2 },
                exit = fadeOut(tween(140)) + slideOutVertically(tween(220)) { it / 2 },
            ) {
                Column(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalAlignment = Alignment.CenterHorizontally,
                ) {
                    if (state.backdropDebug) {
                        BackdropDebugPanel(
                            snapshot = backdropSnapshot,
                            debugState = backdropDebugState,
                        )
                        Spacer(Modifier.height(8.dp))
                    }
                    if (destinations.isNotEmpty()) {
                        Box(
                            modifier = Modifier
                                .fillMaxWidth()
                                // The sampled crop extends past this box on
                                // every side; let it paint outside so the
                                // pill's edges keep real backdrop pixels.
                                .graphicsLayer { clip = false }
                                .onGloballyPositioned { coordinates ->
                                    rootPositionInWindow = coordinates.positionInWindow()
                                },
                        ) {
                            // Row is declared first so it alone defines the
                            // Box height. The transparent sample Image below
                            // uses matchParentSize() and never inflates the
                            // Box, which keeps the reserved bottom gap honest.
                            Row(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    // Sample the whole chrome (pill + search
                                    // circle), not just the pill. Sampling the
                                    // pill alone left the outer half of the
                                    // circle outside the crop, so its glass had
                                    // no backdrop and read as a black wedge.
                                    .onGloballyPositioned { coordinates ->
                                        val position = coordinates.positionInWindow()
                                        onBackdropBoundsChanged(
                                            FlutterBackdropBounds(
                                                left = position.x.toInt(),
                                                top = position.y.toInt(),
                                                width = coordinates.size.width,
                                                height = coordinates.size.height,
                                            ),
                                        )
                                    }
                                    .padding(horizontal = 14.dp)
                                    // Breathing gap above the screen edge.
                                    .padding(bottom = 10.dp)
                                    .offset(y = -state.bottomLiftDp.dp),
                                // Bottom-aligned: the pill owns the height, the
                                // smaller circle rests on the same baseline.
                                verticalAlignment = Alignment.Bottom,
                                horizontalArrangement = Arrangement.spacedBy(10.dp),
                            ) {
                                if (state.searchAction && state.searchActionOnLeft) {
                                    SearchGlassCircleButton(
                                        backdrop = backdrop,
                                        isBlurActive = blurActive,
                                        dark = state.dark,
                                        onClick = onSearchActionSelected,
                                    )
                                }
                                Box(modifier = Modifier.weight(1f)) {
                                    IosLiquidGlassNavigationBar(
                                        items = destinations,
                                        selectedIndex = state.selectedIndex.coerceIn(
                                            0,
                                            destinations.lastIndex,
                                        ),
                                        onItemClick = onDestinationSelected,
                                        backdrop = backdrop,
                                        isBlurActive = blurActive,
                                        dark = state.dark,
                                        modifier = Modifier.fillMaxWidth(),
                                        // Zero insets: the overlay row owns the
                                        // spacing so the pill and the search
                                        // circle share one baseline and height.
                                        bottomInset = 0.dp,
                                        horizontalInset = 0.dp,
                                        // Baseline is owned by the row's bottom inset.
                                        badge = { index ->
                                            state.destinations.getOrNull(index)?.badge?.let { badgeText ->
                                                @Composable {
                                                    if (badgeText.isEmpty()) {
                                                        Badge()
                                                    } else {
                                                        Badge { Text(badgeText) }
                                                    }
                                                }
                                            }
                                        },
                                    )
                                }
                                if (state.searchAction && !state.searchActionOnLeft) {
                                    SearchGlassCircleButton(
                                        backdrop = backdrop,
                                        isBlurActive = blurActive,
                                        dark = state.dark,
                                        onClick = onSearchActionSelected,
                                    )
                                }
                            }

                            // Overlay the sample behind the chrome. matchParentSize()
                            // makes it exactly the Row's bounds: it can never grow
                            // the Box or reserve bottom space. graphicsLayer then
                            // translates and scales the downsampled crop back to
                            // its real window position and size, so the glass
                            // (including the search circle on either side) reads
                            // the correct pixels instead of an offset/gap.
                            backdropSnapshot?.takeIf { blurActive }?.let { snapshot ->
                                Image(
                                    bitmap = snapshot.bitmap.asImageBitmap(),
                                    contentDescription = null,
                                    contentScale = ContentScale.FillBounds,
                                    modifier = Modifier
                                        .matchParentSize()
                                        .graphicsLayer {
                                            // The crop is wider and taller than
                                            // this box (it includes sampler
                                            // bleed), so it must be allowed to
                                            // paint outside the bounds; clipping
                                            // would leave the pill's lower edge
                                            // with an un-sampled grey band.
                                            clip = false
                                            // Scale from the top-left so the
                                            // translation is a pure window-space
                                            // offset, not a center-pivot shift.
                                            transformOrigin = TransformOrigin(0f, 0f)
                                            val parentWidthPx = size.width.coerceAtLeast(1f)
                                            val parentHeightPx = size.height.coerceAtLeast(1f)
                                            scaleX = snapshot.sourceWidthPx / parentWidthPx
                                            scaleY = snapshot.sourceHeightPx / parentHeightPx
                                            translationX = snapshot.sourceLeftInWindowPx -
                                                rootPositionInWindow.x
                                            translationY = snapshot.sourceTopInWindowPx -
                                                rootPositionInWindow.y
                                        }
                                        // A tiny non-zero alpha keeps the
                                        // layer alive: alpha(0f) is culled by
                                        // some HyperOS renderers, which leaves
                                        // the glass with no backdrop pixels and
                                        // renders its lower edge as grey.
                                        .alpha(0.001f)
                                        .layerBackdrop(backdrop),
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}

/**
 * Shows the PixelCopy diagnostic sample and sampler metrics. The standard
 * navigation bar itself uses Miuix's solid surface and does not consume it.
 */
@Composable
private fun BackdropDebugPanel(
    snapshot: FlutterBackdropSnapshot?,
    debugState: FlutterBackdropDebugState,
) {
    val colors = MaterialTheme.colorScheme
    val shape = RoundedCornerShape(18.dp)
    val bounds = debugState.barBounds
    val result = debugState.pixelCopyResult?.toString() ?: "-"
    val sourceText =
        "${debugState.sourceViewClass.substringAfterLast('.')} " +
            "${debugState.surfaceWidthPx}×${debugState.surfaceHeightPx}  " +
            "bar ${bounds?.left ?: 0},${bounds?.top ?: 0} " +
            "${bounds?.width ?: 0}×${bounds?.height ?: 0}"
    val cropText =
        "crop ${debugState.cropLeftPx},${debugState.cropTopPx} " +
            "${debugState.cropWidthPx}×${debugState.cropHeightPx} → " +
            "${debugState.bitmapWidthPx}×${debugState.bitmapHeightPx}"
    val metricsText =
        "frame ${debugState.captureCount}  ${debugState.captureFps}fps  " +
            "result $result  ${debugState.latencyMs}ms " +
            "first ${debugState.firstSampleLatencyMs}ms  sig ${debugState.contentSignature}"
    Column(
        modifier = Modifier
            .widthIn(max = 380.dp)
            .fillMaxWidth()
            .clip(shape)
            .background(colors.surfaceContainer.copy(alpha = 0.97f))
            .border(1.dp, colors.outline.copy(alpha = 0.35f), shape)
            .padding(10.dp),
    ) {
        BasicText(
            text = "Backdrop 调试 · ${debugState.status}",
            style = TextStyle(
                color = colors.onSurface,
                fontSize = 13.sp,
                fontWeight = FontWeight.SemiBold,
            ),
        )
        Spacer(Modifier.height(7.dp))
        Row(verticalAlignment = Alignment.CenterVertically) {
            Box(
                modifier = Modifier
                    .width(116.dp)
                    .height(70.dp)
                    .clip(RoundedCornerShape(10.dp))
                    .background(colors.onSurface.copy(alpha = 0.08f)),
                contentAlignment = Alignment.Center,
            ) {
                if (snapshot == null) {
                    BasicText(
                        text = "无原始采样",
                        style = TextStyle(
                            color = colors.onSurface.copy(alpha = 0.58f),
                            fontSize = 11.sp,
                        ),
                    )
                } else {
                    Image(
                        bitmap = snapshot.bitmap.asImageBitmap(),
                        contentDescription = "PixelCopy 原始采样",
                        contentScale = ContentScale.Crop,
                        modifier = Modifier.fillMaxSize(),
                    )
                }
            }
            Spacer(Modifier.width(9.dp))
            Column(modifier = Modifier.weight(1f)) {
                DebugLine(sourceText, colors.onSurface)
                DebugLine(cropText, colors.onSurface)
                DebugLine(metricsText, colors.onSurface)
                DebugLine(
                    if (snapshot == null) {
                        "液态玻璃底栏：等待背板采样"
                    } else {
                        "液态玻璃底栏：已接入 Flutter 背景采样"
                    },
                    colors.onSurface,
                )
            }
        }
    }
}

@Composable
private fun DebugLine(text: String, color: Color) {
    BasicText(
        text = text,
        style = TextStyle(
            color = color.copy(alpha = 0.72f),
            fontSize = 10.sp,
            lineHeight = 13.sp,
        ),
    )
}

/**
 * Detached circular glass search entry shown beside the navigation pill,
 * mirroring the reference design. Shares the same backdrop layer so the
 * refraction stays continuous with the bar.
 */
@Composable
internal fun SearchGlassCircleButton(
    backdrop: LayerBackdrop?,
    isBlurActive: Boolean,
    dark: Boolean,
    onClick: () -> Unit,
) {
    val surfaceContainer = MiuixTheme.colorScheme.surfaceContainer
    val containerColor =
        if (isBlurActive) surfaceContainer.copy(alpha = 0.4f) else surfaceContainer
    val pillShape = CircleShape
    val contentColor = MiuixTheme.colorScheme.onSurface

    Box(
        modifier = Modifier
            .size(64.dp)
            // No drop shadow: a black halo bleeds through the translucent
            // glass on dark pages and reads as a dirty ring around the button.
            // The pill itself relies on its backdrop refraction, not a shadow.
            .clip(pillShape)
            .then(
                if (isBlurActive && backdrop != null) {
                    Modifier.drawBackdrop(
                        backdrop = backdrop,
                        shape = { pillShape },
                        effects = {
                            vibrancy()
                            blur(4.dp.toPx(), 4.dp.toPx())
                            lens(
                                refractionHeight = 24.dp.toPx(),
                                refractionAmount = 24.dp.toPx(),
                            )
                        },
                        // Same reason as the pill: the BloomStroke rim's
                        // inner blur darkens the circle's lower edge.
                        highlight = { null },
                        onDrawSurface = { drawRect(containerColor) },
                    )
                } else {
                    Modifier.background(containerColor, pillShape)
                },
            )
            .clickable(onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        CompositionLocalProvider(LocalContentColor provides contentColor) {
            Icon(
                modifier = Modifier.size(24.dp),
                imageVector = MiuixIcons.Search,
                contentDescription = "搜索",
            )
        }
    }
}
