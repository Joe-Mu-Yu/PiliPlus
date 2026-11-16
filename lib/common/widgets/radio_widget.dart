import 'package:PiliPlus/utils/platform_utils.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_miuix/miuix.dart' as miuix;
import 'package:material_ui/material_ui.dart';

class RadioWidget<T> extends StatefulWidget {
  final T value;
  final String title;
  final bool tristate;
  final EdgeInsetsGeometry? padding;
  final MainAxisSize mainAxisSize;

  const RadioWidget({
    super.key,
    required this.value,
    required this.title,
    this.tristate = false,
    this.padding,
    this.mainAxisSize = MainAxisSize.min,
  });

  @override
  State<RadioWidget<T>> createState() => RadioWidgetState<T>();
}

class RadioWidgetState<T> extends State<RadioWidget<T>> with RadioClient<T> {
  @override
  final focusNode = FocusNode();

  @override
  T get radioValue => widget.value;

  bool get checked => radioValue == registry!.groupValue;

  @override
  bool get tristate => widget.tristate;

  @override
  bool get enabled => registry != null;

  @override
  void dispose() {
    registry = null;
    focusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    registry = RadioGroup.maybeOf(context);
    assert(registry != null);
  }

  void _handleTap() {
    if (checked) {
      if (tristate) {
        HapticFeedback.selectionClick();
        registry!.onChanged(null);
      }
      return;
    }
    HapticFeedback.selectionClick();
    registry!.onChanged(radioValue);
  }

  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisSize: widget.mainAxisSize,
      children: [
        SizedBox.square(
          dimension: PlatformUtils.isDesktop ? 40 : 48,
          child: Center(
            child: ExcludeSemantics(
              child: IgnorePointer(
                child: miuix.MiuixRadioButton(
                  selected: checked,
                  enabled: enabled,
                  onChanged: enabled ? (_) {} : null,
                ),
              ),
            ),
          ),
        ),
        Text(widget.title),
      ],
    );
    return Semantics(
      container: true,
      checked: checked,
      enabled: enabled,
      inMutuallyExclusiveGroup: true,
      onTap: enabled ? _handleTap : null,
      child: InkWell(
        onTap: enabled ? _handleTap : null,
        focusNode: focusNode,
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        child: widget.padding == null
            ? child
            : Padding(padding: widget.padding!, child: child),
      ),
    );
  }
}

class WrapRadioOptionsGroup<T> extends StatelessWidget {
  final String groupTitle;
  final Map<T, String> options;
  final EdgeInsetsGeometry? itemPadding;

  const WrapRadioOptionsGroup({
    super.key,
    required this.groupTitle,
    required this.options,
    this.itemPadding,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (groupTitle.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 22),
            child: Text(
              groupTitle,
              style: TextStyle(color: Theme.of(context).colorScheme.outline),
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Wrap(
            children: options.entries.map((entry) {
              return RadioWidget<T>(
                value: entry.key,
                title: entry.value,
                padding: itemPadding ?? const EdgeInsets.only(right: 10),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
