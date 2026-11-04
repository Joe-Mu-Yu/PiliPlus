package com.aritxonly.hyperpiliplus

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.Row
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
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.layout.positionInWindow
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import top.yukonga.miuix.kmp.basic.Badge
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
    val density = LocalDensity.current
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
                                .onGloballyPositioned { coordinates ->
                                    rootPositionInWindow = coordinates.positionInWindow()
                                },
                        ) {
                            backdropSnapshot?.let { snapshot ->
                                Image(
                                    bitmap = snapshot.bitmap.asImageBitmap(),
                                    contentDescription = null,
                                    contentScale = ContentScale.FillBounds,
                                    modifier = Modifier
                                        .offset {
                                            IntOffset(
                                                x = snapshot.sourceLeftInWindowPx -
                                                    rootPositionInWindow.x.toInt(),
                                                y = snapshot.sourceTopInWindowPx -
                                                    rootPositionInWindow.y.toInt(),
                                            )
                                        }
                                        .size(
                                            width = with(density) {
                                                snapshot.sourceWidthPx.toDp()
                                            },
                                            height = with(density) {
                                                snapshot.sourceHeightPx.toDp()
                                            },
                                        )
                                        .alpha(0f)
                                        .layerBackdrop(backdrop),
                                )
                            }
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
                                onBarBoundsChanged = onBackdropBoundsChanged,
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(top = FLUTTER_BACKDROP_BLEED_DP.dp)
                                    .offset(y = -state.bottomLiftDp.dp),
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
                    }
                }
            }
        }
    }
}

private const val FLUTTER_BACKDROP_BLEED_DP = 48
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
