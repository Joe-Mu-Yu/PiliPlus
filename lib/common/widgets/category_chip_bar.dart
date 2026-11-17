import 'package:PiliPlus/common/widgets/immersive/immersive_pill.dart';
import 'package:PiliPlus/common/widgets/immersive/immersive_tokens.dart';
import 'package:PiliPlus/utils/extension/theme_ext.dart';
import 'package:material_ui/material_ui.dart';

/// Horizontal chip row wrapped in the same continuous capsule track as
/// [categoryTabBar], used for secondary category rows (live areas, tags).
///
/// [builder] returns the label for each chip; selection styling follows the
/// active [ColorScheme].
Widget categoryChipBar(
  BuildContext context, {
  required int itemCount,
  required String Function(int index) labelOf,
  required int selectedIndex,
  required ValueChanged<int> onSelected,
  EdgeInsetsGeometry padding = const EdgeInsets.fromLTRB(12, 4, 12, 4),
  double height = 40,
  double chipHeight = 32,
}) {
  final scheme = ColorScheme.of(context);
  final trackColor = scheme.surfaceContainerHigh.withValues(
    alpha: scheme.isLight ? .72 : .56,
  );
  return Padding(
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
        height: height,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          itemCount: itemCount,
          separatorBuilder: (_, _) => const SizedBox(width: 4),
          itemBuilder: (context, index) {
            final selected = index == selectedIndex;
            return Center(
              child: ImmersivePill(
                selected: selected,
                height: chipHeight,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                onTap: () => onSelected(index),
                child: Text(labelOf(index)),
              ),
            );
          },
        ),
      ),
    ),
  );
}
