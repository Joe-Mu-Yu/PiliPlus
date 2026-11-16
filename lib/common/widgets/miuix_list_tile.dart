import 'package:PiliPlus/common/widgets/miuix_checkbox.dart';
import 'package:PiliPlus/common/widgets/miuix_switch.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_miuix/miuix.dart' as miuix;
import 'package:material_ui/material_ui.dart';

/// List-tile controls that preserve Flutter's rich title/subtitle slots while
/// using MIUIX controls and MIUIX's trailing-control interaction model.
///
/// The complete row is the primary target. The visual control is excluded from
/// hit testing and semantics so a tap cannot fire the callback twice.
class PiliMiuixSwitchListTile extends StatelessWidget {
  const PiliMiuixSwitchListTile({
    super.key,
    required this.value,
    required this.onChanged,
    this.title,
    this.subtitle,
    this.secondary,
    this.contentPadding,
    this.dense,
    this.enabled = true,
    this.autofocus = false,
    this.focusNode,
    this.shape,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final Widget? title;
  final Widget? subtitle;
  final Widget? secondary;
  final EdgeInsetsGeometry? contentPadding;
  final bool? dense;
  final bool enabled;
  final bool autofocus;
  final FocusNode? focusNode;
  final ShapeBorder? shape;

  bool get _interactive => enabled && onChanged != null;

  void _handleTap() {
    if (!_interactive) return;
    HapticFeedback.lightImpact();
    onChanged!.call(!value);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      toggled: value,
      enabled: _interactive,
      onTap: _interactive ? _handleTap : null,
      child: ListTile(
        leading: secondary,
        title: title,
        subtitle: subtitle,
        trailing: ExcludeSemantics(
          child: IgnorePointer(
            child: PiliMiuixSwitch(
              value: value,
              onChanged: _interactive ? (_) {} : null,
              enabled: _interactive,
            ),
          ),
        ),
        contentPadding: contentPadding,
        dense: dense,
        enabled: _interactive,
        autofocus: autofocus,
        focusNode: focusNode,
        shape: shape,
        onTap: _interactive ? _handleTap : null,
      ),
    );
  }
}

class PiliMiuixCheckboxListTile extends StatelessWidget {
  const PiliMiuixCheckboxListTile({
    super.key,
    required this.value,
    required this.onChanged,
    this.title,
    this.subtitle,
    this.secondary,
    this.contentPadding,
    this.dense,
    this.enabled = true,
    this.tristate = false,
    this.autofocus = false,
    this.focusNode,
    this.shape,
    this.activeColor,
  }) : assert(tristate || value != null);

  final bool? value;
  final ValueChanged<bool?>? onChanged;
  final Widget? title;
  final Widget? subtitle;
  final Widget? secondary;
  final EdgeInsetsGeometry? contentPadding;
  final bool? dense;
  final bool enabled;
  final bool tristate;
  final bool autofocus;
  final FocusNode? focusNode;
  final ShapeBorder? shape;
  final Color? activeColor;

  bool get _interactive => enabled && onChanged != null;

  void _handleTap() {
    if (!_interactive) return;
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
    onChanged!.call(nextValue);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      checked: value,
      mixed: value == null,
      enabled: _interactive,
      onTap: _interactive ? _handleTap : null,
      child: ListTile(
        leading: secondary,
        title: title,
        subtitle: subtitle,
        trailing: ExcludeSemantics(
          child: IgnorePointer(
            child: PiliMiuixCheckbox(
              value: value,
              onChanged: _interactive ? (_) {} : null,
              enabled: _interactive,
              activeColor: activeColor,
            ),
          ),
        ),
        contentPadding: contentPadding,
        dense: dense,
        enabled: _interactive,
        autofocus: autofocus,
        focusNode: focusNode,
        shape: shape,
        onTap: _interactive ? _handleTap : null,
      ),
    );
  }
}

class PiliMiuixRadioListTile<T> extends StatefulWidget {
  const PiliMiuixRadioListTile({
    super.key,
    required this.value,
    this.title,
    this.subtitle,
    this.secondary,
    this.contentPadding,
    this.dense,
    this.enabled,
    this.toggleable = false,
    this.autofocus = false,
    this.focusNode,
    this.shape,
  });

  final T value;
  final Widget? title;
  final Widget? subtitle;
  final Widget? secondary;
  final EdgeInsetsGeometry? contentPadding;
  final bool? dense;
  final bool? enabled;
  final bool toggleable;
  final bool autofocus;
  final FocusNode? focusNode;
  final ShapeBorder? shape;

  @override
  State<PiliMiuixRadioListTile<T>> createState() =>
      _PiliMiuixRadioListTileState<T>();
}

class _PiliMiuixRadioListTileState<T> extends State<PiliMiuixRadioListTile<T>>
    with RadioClient<T> {
  FocusNode? _internalFocusNode;

  @override
  FocusNode get focusNode =>
      widget.focusNode ?? (_internalFocusNode ??= FocusNode());

  @override
  T get radioValue => widget.value;

  @override
  bool get tristate => widget.toggleable;

  @override
  bool get enabled => widget.enabled ?? registry != null;

  bool get _checked => radioValue == registry?.groupValue;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    registry = RadioGroup.maybeOf<T>(context);
  }

  @override
  void dispose() {
    registry = null;
    _internalFocusNode?.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (!enabled || registry == null || (!tristate && _checked)) return;
    HapticFeedback.selectionClick();
    registry!.onChanged(_checked ? null : radioValue);
  }

  @override
  Widget build(BuildContext context) {
    assert(
      registry != null,
      'PiliMiuixRadioListTile requires a RadioGroup<$T> ancestor.',
    );
    return Semantics(
      container: true,
      checked: _checked,
      enabled: enabled,
      inMutuallyExclusiveGroup: true,
      onTap: enabled ? _handleTap : null,
      child: ListTile(
        leading: widget.secondary,
        title: widget.title,
        subtitle: widget.subtitle,
        trailing: ExcludeSemantics(
          child: IgnorePointer(
            child: SizedBox.square(
              dimension: 48,
              child: Center(
                child: miuix.MiuixRadioButton(
                  selected: _checked,
                  enabled: enabled,
                  onChanged: enabled ? (_) {} : null,
                ),
              ),
            ),
          ),
        ),
        contentPadding: widget.contentPadding,
        dense: widget.dense,
        enabled: enabled,
        autofocus: widget.autofocus,
        focusNode: focusNode,
        shape: widget.shape,
        onTap: enabled ? _handleTap : null,
      ),
    );
  }
}
