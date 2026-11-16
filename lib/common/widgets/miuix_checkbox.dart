import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_miuix/miuix.dart' as miuix;
import 'package:material_ui/material_ui.dart';

/// MIUIX checkbox with an accessibility-sized hit target.
///
/// The upstream visual is 26dp. Keeping the paint size while expanding the
/// target to 48dp avoids making compact selection rows hard to operate.
class PiliMiuixCheckbox extends StatelessWidget {
  const PiliMiuixCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    this.tristate = false,
    this.enabled = true,
    this.touchTargetSize = 48,
    this.activeColor,
  });

  static const double visualSize = miuix.MiuixCheckboxDefaults.size;

  final bool? value;
  final ValueChanged<bool?>? onChanged;
  final bool tristate;
  final bool enabled;
  final double touchTargetSize;
  final Color? activeColor;

  bool get _effectiveEnabled => enabled && onChanged != null;

  void _handleTap() {
    if (!_effectiveEnabled) return;
    final bool? nextValue;
    if (!tristate) {
      nextValue = value != true;
    } else {
      nextValue = switch (value) {
        false => true,
        true => null,
        null => false,
      };
    }
    HapticFeedback.lightImpact();
    onChanged?.call(nextValue);
  }

  @override
  Widget build(BuildContext context) {
    final defaultColors = miuix.MiuixCheckboxDefaults.checkboxColors(context);
    final colors = activeColor == null
        ? defaultColors
        : miuix.MiuixCheckboxColors(
            checkedForegroundColor: defaultColors.checkedForegroundColor,
            uncheckedForegroundColor: defaultColors.uncheckedForegroundColor,
            disabledCheckedForegroundColor:
                defaultColors.disabledCheckedForegroundColor,
            disabledUncheckedForegroundColor:
                defaultColors.disabledUncheckedForegroundColor,
            checkedBackgroundColor: activeColor!,
            uncheckedBackgroundColor: defaultColors.uncheckedBackgroundColor,
            disabledCheckedBackgroundColor:
                defaultColors.disabledCheckedBackgroundColor,
            disabledUncheckedBackgroundColor:
                defaultColors.disabledUncheckedBackgroundColor,
          );
    final targetSize = touchTargetSize < visualSize
        ? visualSize
        : touchTargetSize;
    return Semantics(
      container: true,
      checked: value,
      mixed: value == null,
      enabled: _effectiveEnabled,
      onTap: _effectiveEnabled ? _handleTap : null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _effectiveEnabled ? _handleTap : null,
        child: SizedBox.square(
          dimension: targetSize,
          child: Center(
            child: ExcludeSemantics(
              child: IgnorePointer(
                child: miuix.MiuixCheckbox(
                  value: value,
                  enabled: _effectiveEnabled,
                  // A non-null callback keeps the upstream visual in its
                  // enabled state. Input is owned by the 48dp parent target.
                  onChanged: _effectiveEnabled ? (_) {} : null,
                  colors: colors,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
