package com.aritxonly.hyperpiliplus

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
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
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.layout.positionInWindow
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import top.yukonga.miuix.kmp.basic.Badge
import top.yukonga.miuix.kmp.basic.FloatingNavigationBar
import top.yukonga.miuix.kmp.basic.FloatingNavigationBarDefaults
import top.yukonga.miuix.kmp.basic.FloatingNavigationBarItem
import top.yukonga.miuix.kmp.basic.Text
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
import kotlin.math.abs

/**
 * Flutter owns routes and state; the Miuix library provides the floating bar
 * and item visuals. The app keeps its existing swipe-to-select gesture around
 * the official items without drawing a separate selection indicator.
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
    val materialColors = if (state.dark) {
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
    }
    val items = state.destinations.map { destination ->
        val icon = when (destination.key) {
            "home" -> MiuixIcons.Home
            "dynamics" -> MiuixIcons.Messages
            "mine" -> MiuixIcons.ContactsCircle
            "follow" -> MiuixIcons.ScreenMirroring
            "recorderCenter" -> MiuixIcons.Recording
            "movies" -> MiuixIcons.Play
            else -> MiuixIcons.ContactsCircle
        }
        destination to icon
    }
    var draggedIndex by remember { mutableIntStateOf(state.selectedIndex) }
    val density = LocalDensity.current
    val horizontalPaddingPx = with(density) {
        FloatingNavigationBarDefaults.HorizontalPadding.toPx()
    }
    val itemStridePx = with(density) {
        (FloatingNavigationBarDefaults.IconSize +
            FloatingNavigationBarDefaults.IconPadding * 2 +
            FloatingNavigationBarDefaults.ItemSpacing).toPx()
    }
    val selectDestination by rememberUpdatedState(onDestinationSelected)

    LaunchedEffect(state.selectedIndex) {
        draggedIndex = state.selectedIndex
    }

    MaterialTheme(colorScheme = materialColors) {
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
                    FloatingNavigationBar(
                        modifier = Modifier
                            .offset(y = -state.bottomLiftDp.dp)
                            .pointerInput(items.size, horizontalPaddingPx, itemStridePx) {
                                awaitEachGesture {
                                    val down = awaitFirstDown(requireUnconsumed = false)
                                    var dragging = false
                                    var targetIndex = draggedIndex
                                    while (true) {
                                        val event = awaitPointerEvent()
                                        val change = event.changes.firstOrNull { it.id == down.id }
                                            ?: break
                                        if (!change.pressed) break
                                        val deltaX = change.position.x - down.position.x
                                        if (!dragging && abs(deltaX) > viewConfiguration.touchSlop) {
                                            dragging = true
                                        }
                                        if (dragging) {
                                            change.consume()
                                            targetIndex = (
                                                (change.position.x - horizontalPaddingPx) /
                                                    itemStridePx
                                                ).toInt().coerceIn(items.indices)
                                            draggedIndex = targetIndex
                                        }
                                    }
                                    if (dragging) selectDestination(targetIndex)
                                }
                            }
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
                            },
                    ) {
                        items.forEachIndexed { index, (destination, icon) ->
                            val badge = destination.badge?.let { badgeText ->
                                @Composable {
                                    if (badgeText.isEmpty()) {
                                        Badge()
                                    } else {
                                        Badge { Text(badgeText) }
                                    }
                                }
                            }
                            FloatingNavigationBarItem(
                                selected = draggedIndex == index,
                                onClick = {
                                    draggedIndex = index
                                    selectDestination(index)
                                },
                                icon = icon,
                                label = destination.label,
                                badge = badge,
                            )
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
                        "Miuix 浮栏：默认主题纯色"
                    } else {
                        "Miuix 浮栏：surfaceContainer；采样仅用于调试"
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
