import 'package:PiliPlus/utils/extension/theme_ext.dart';
import 'package:material_ui/material_ui.dart';

/// Low-cost "cloud" immersive surfaces shared by the home page, video cards and
/// the shared player chrome.
///
/// Every token here is static: no backdrop blur, no per-frame sampling and no
/// always-on shader. Colours always come from the active [ColorScheme] so light,
/// dark and pure-black themes stay readable.
abstract final class ImmersiveTokens {
  /// Corner radius for compact media cards (video cards, related rows).
  static const double cardRadius = 16;

  /// Corner radius for grouped information surfaces (intro, replies, lists).
  static const double groupRadius = 22;

  /// Corner radius for bars, chips and pills.
  static const double pillRadius = 999;

  /// Minimum touch target used by every interactive immersive control.
  static const double minTouchTarget = 44;

  /// Compact pill height used by segmented controls and metadata chips.
  static const double pillHeight = 32;

  /// Control row height used by the player chrome.
  static const double controlRowHeight = 48;

  /// Hairline border width for low-contrast card outlines.
  static const double hairline = 1;

  /// Press feedback scale for tappable cards. Kept well above the reference
  /// project's 0.9 so text stays legible during the press.
  static const double pressedScale = .985;

  /// Press feedback duration; zero when the platform disables animations.
  static Duration pressDuration(BuildContext context) => reduceMotionOf(context)
      ? Duration.zero
      : const Duration(milliseconds: 120);

  /// Chrome fade/slide duration kept inside the 120-300ms budget.
  static Duration chromeDuration(BuildContext context) =>
      reduceMotionOf(context)
      ? Duration.zero
      : const Duration(milliseconds: 220);

  /// Fast indicator duration (volume/brightness/seek HUDs).
  static Duration hudDuration(BuildContext context) => reduceMotionOf(context)
      ? Duration.zero
      : const Duration(milliseconds: 160);

  static bool reduceMotionOf(BuildContext context) =>
      MediaQuery.maybeOf(context)?.disableAnimations ?? false;

  /// Low-contrast card outline derived from the current scheme.
  static Color cardOutline(ColorScheme scheme) =>
      scheme.outlineVariant.withValues(alpha: scheme.isLight ? .5 : .32);

  /// Grouped surface colour; slightly deeper than the page canvas so grouped
  /// content reads without extra compositing layers.
  static Color groupSurface(ColorScheme scheme) => scheme.surfaceContainerLow;

  /// Media card surface: stays close to the canvas to avoid a "floating tile"
  /// look while still separating the cover from the background.
  static Color mediaSurface(ColorScheme scheme) => scheme.surfaceContainer;

  /// Static ambient wash used behind immersive headers. A two-stop linear
  /// gradient painted once; no blur and no screenshot sampling.
  static LinearGradient ambientWash(ColorScheme scheme) => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      scheme.primary.withValues(alpha: scheme.isLight ? .07 : .16),
      scheme.surface.withValues(alpha: 0),
    ],
  );

  /// Player chrome surface: semi-transparent black capsule that stays legible
  /// over any video frame.
  static const Color playerChrome = Color(0x8C000000);
  static const Color playerChromeBorder = Color(0x1FFFFFFF);
  static const Color playerChromeText = Colors.white;
  static const Color playerChromeSubText = Color(0xB3FFFFFF);

  static BoxDecoration pillSurface({
    Color color = playerChrome,
    Color? borderColor,
    double radius = pillRadius,
  }) => BoxDecoration(
    color: color,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(
      color: borderColor ?? playerChromeBorder,
      width: hairline,
    ),
  );

  static BoxDecoration cardSurface(ColorScheme scheme, {double? radius}) =>
      BoxDecoration(
        color: mediaSurface(scheme),
        borderRadius: BorderRadius.circular(radius ?? cardRadius),
        border: Border.all(color: cardOutline(scheme), width: hairline),
      );

  static BoxDecoration groupBox(ColorScheme scheme, {double? radius}) =>
      BoxDecoration(
        color: groupSurface(scheme),
        borderRadius: BorderRadius.circular(radius ?? groupRadius),
      );
}
