import 'package:PiliPlus/common/widgets/immersive/immersive_tokens.dart';
import 'package:PiliPlus/utils/extension/theme_ext.dart';
import 'package:PiliPlus/utils/feed_back.dart';
import 'package:material_ui/material_ui.dart';

/// Floating capsule category tab bar shared by top-level browsing pages.
///
/// The selected tab reads as a pill inside a continuous capsule track instead
/// of a bare underline, matching the reference design's floating segmented
/// switcher. Colours always come from the active [ColorScheme]; no hard-coded
/// "close enough" values.
///
/// [trailing] renders an action inside the same track (for example the
/// dynamics "new post" button) so the bar stays one continuous surface.
Widget categoryTabBar(
  BuildContext context, {
  Key? key,
  required TabController? controller,
  required List<Widget> tabs,
  void Function(int)? onTap,
  bool isScrollable = true,
  TabAlignment tabAlignment = TabAlignment.start,
  EdgeInsetsGeometry padding = const EdgeInsets.fromLTRB(12, 4, 12, 0),
  double height = 56,
  bool onTapFeedback = true,
  Widget? trailing,
}) {
  final scheme = ColorScheme.of(context);
  // Continuous capsule track behind the tabs, matching the reference
  // floating tab bar: one rounded plate holding every segment.
  final trackColor = scheme.surfaceContainerHigh.withValues(
    alpha: scheme.isLight ? .72 : .56,
  );
  final tabBar = TabBar(
    controller: controller,
    tabs: tabs,
    isScrollable: isScrollable,
    labelColor: scheme.onSecondaryContainer,
    unselectedLabelColor: scheme.onSurfaceVariant,
    labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
    unselectedLabelStyle: const TextStyle(fontSize: 13),
    indicator: BoxDecoration(
      color: scheme.secondaryContainer,
      borderRadius: BorderRadius.circular(ImmersiveTokens.pillRadius),
    ),
    indicatorSize: TabBarIndicatorSize.tab,
    indicatorPadding: const EdgeInsets.symmetric(vertical: 4),
    dividerColor: Colors.transparent,
    dividerHeight: 0,
    labelPadding: const EdgeInsets.symmetric(horizontal: 14),
    splashBorderRadius: const BorderRadius.all(
      Radius.circular(ImmersiveTokens.pillRadius),
    ),
    overlayColor: WidgetStatePropertyAll(
      scheme.primary.withValues(alpha: .08),
    ),
    tabAlignment: tabAlignment,
    onTap: (index) {
      if (onTapFeedback) {
        // Widget tests run without the platform channel; haptics are
        // best-effort feedback and must not break the tap.
        try {
          feedBack();
        } catch (_) {}
      }
      onTap?.call(index);
    },
  );

  return Padding(
    key: key,
    padding: padding,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: trackColor,
        borderRadius: BorderRadius.circular(height / 2),
        border: Border.all(
          color: ImmersiveTokens.cardOutline(scheme),
          width: ImmersiveTokens.hairline,
        ),
      ),
      child: SizedBox(
        // Leave room for the TabBar's intrinsic tab height inside the track
        // so labels are never clipped.
        height: height - 6,
        width: double.infinity,
        child: trailing == null
            ? tabBar
            : Row(
                children: [
                  Expanded(child: tabBar),
                  trailing,
                  const SizedBox(width: 4),
                ],
              ),
      ),
    ),
  );
}
