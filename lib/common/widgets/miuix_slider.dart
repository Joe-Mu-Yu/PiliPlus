import 'package:flutter/services.dart' show HapticFeedback, LogicalKeyboardKey;
import 'package:flutter_miuix/miuix.dart' as miuix;
import 'package:material_ui/material_ui.dart';

/// Material-compatible entry point backed by the MIUIX slider where its
/// behavior can be preserved exactly.
///
/// Material-only features, including the value indicator, secondary track,
/// restricted interaction modes and reduced-motion behavior, deliberately use
/// the globally themed Material slider rather than silently dropping
/// information or leaving a spring animation paused.
class PiliMiuixSlider extends StatefulWidget {
  const PiliMiuixSlider({
    super.key,
    required this.value,
    required this.onChanged,
    this.onChangeStart,
    this.onChangeEnd,
    this.min = 0,
    this.max = 1,
    this.divisions,
    this.label,
    this.secondaryTrackValue,
    this.activeColor,
    this.inactiveColor,
    this.secondaryActiveColor,
    this.thumbColor,
    this.padding,
    this.semanticFormatterCallback,
    this.focusNode,
    this.autofocus = false,
    this.allowedInteraction,
    this.forceMaterialFallback = false,
    // Kept for source compatibility with existing call sites. The project
    // theme already opts Material fallbacks into the current appearance.
    this.year2023,
  }) : assert(min < max),
       assert(value >= min && value <= max),
       assert(divisions == null || divisions > 0);

  final double value;
  final ValueChanged<double>? onChanged;
  final ValueChanged<double>? onChangeStart;
  final ValueChanged<double>? onChangeEnd;
  final double min;
  final double max;
  final int? divisions;
  final String? label;
  final double? secondaryTrackValue;
  final Color? activeColor;
  final Color? inactiveColor;
  final Color? secondaryActiveColor;
  final Color? thumbColor;
  final EdgeInsetsGeometry? padding;
  final SemanticFormatterCallback? semanticFormatterCallback;
  final FocusNode? focusNode;
  final bool autofocus;
  final SliderInteraction? allowedInteraction;
  final bool forceMaterialFallback;
  final bool? year2023;

  @override
  State<PiliMiuixSlider> createState() => _PiliMiuixSliderState();
}

class _PiliMiuixSliderState extends State<PiliMiuixSlider> {
  bool _interactionActive = false;
  late double _lastValue = widget.value;

  bool get _enabled => widget.onChanged != null;

  double get _step => widget.divisions == null
      ? (widget.max - widget.min) / 20
      : (widget.max - widget.min) / widget.divisions!;

  @override
  void didUpdateWidget(PiliMiuixSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_interactionActive) _lastValue = widget.value;
  }

  void _beginInteraction() {
    if (!_enabled || _interactionActive) return;
    _interactionActive = true;
    _lastValue = widget.value;
    widget.onChangeStart?.call(widget.value);
  }

  void _handleChanged(double value) {
    _beginInteraction();
    _lastValue = value;
    widget.onChanged?.call(value);
  }

  void _finishInteraction() {
    if (!_interactionActive) return;
    _interactionActive = false;
    widget.onChangeEnd?.call(_lastValue);
  }

  void _scheduleFinish() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _finishInteraction());
  }

  void _adjust(double direction) {
    if (!_enabled) return;
    final value = (widget.value + _step * direction).clamp(
      widget.min,
      widget.max,
    );
    if (value == widget.value) return;
    _beginInteraction();
    HapticFeedback.selectionClick();
    _handleChanged(value);
    _finishInteraction();
  }

  String _semanticValue(double value) {
    return widget.semanticFormatterCallback?.call(value) ??
        widget.label ??
        value.toStringAsFixed(widget.divisions == null ? 2 : 0);
  }

  Widget _buildMaterialFallback() {
    return Slider(
      value: widget.value,
      onChanged: widget.onChanged,
      onChangeStart: widget.onChangeStart,
      onChangeEnd: widget.onChangeEnd,
      min: widget.min,
      max: widget.max,
      divisions: widget.divisions,
      label: widget.label,
      secondaryTrackValue: widget.secondaryTrackValue,
      activeColor: widget.activeColor,
      inactiveColor: widget.inactiveColor,
      secondaryActiveColor: widget.secondaryActiveColor,
      thumbColor: widget.thumbColor,
      padding: widget.padding,
      semanticFormatterCallback: widget.semanticFormatterCallback,
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      allowedInteraction: widget.allowedInteraction,
      // ignore: deprecated_member_use
      year2023: widget.year2023,
    );
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (widget.forceMaterialFallback ||
        widget.label != null ||
        widget.secondaryTrackValue != null ||
        widget.allowedInteraction != null ||
        reduceMotion) {
      return _buildMaterialFallback();
    }

    final theme = miuix.MiuixTheme.of(context);
    final colors = theme.colors;
    final slider = miuix.MiuixSlider(
      value: widget.value,
      min: widget.min,
      max: widget.max,
      // Compose/MIUIX `steps` counts points between the two endpoints while
      // Material `divisions` counts the intervals.
      steps: widget.divisions == null ? 0 : widget.divisions! - 1,
      onValueChanged: widget.onChanged == null ? null : _handleChanged,
      onValueChangeFinished: _finishInteraction,
      hapticEffect: widget.divisions == null
          ? miuix.MiuixSliderHapticEffect.edge
          : miuix.MiuixSliderHapticEffect.step,
      colors: miuix.MiuixSliderColors(
        foregroundColor: widget.activeColor ?? colors.primary,
        disabledForegroundColor: colors.disabledPrimarySlider,
        backgroundColor: widget.inactiveColor ?? colors.sliderBackground,
        disabledBackgroundColor: colors.disabledSecondary,
        thumbColor: widget.thumbColor ?? colors.onPrimary,
        disabledThumbColor: colors.disabledOnPrimary,
        keyPointColor: colors.sliderKeyPoint,
        keyPointForegroundColor: colors.sliderKeyPointForeground,
      ),
    );

    final padded = widget.padding == null
        ? slider
        : Padding(padding: widget.padding!, child: slider);
    final increased = (widget.value + _step).clamp(widget.min, widget.max);
    final decreased = (widget.value - _step).clamp(widget.min, widget.max);

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.arrowRight): () => _adjust(1),
        const SingleActivator(LogicalKeyboardKey.arrowUp): () => _adjust(1),
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () => _adjust(-1),
        const SingleActivator(LogicalKeyboardKey.arrowDown): () => _adjust(-1),
      },
      child: Focus(
        focusNode: widget.focusNode,
        autofocus: widget.autofocus,
        child: Semantics(
          container: true,
          slider: true,
          enabled: _enabled,
          value: _semanticValue(widget.value),
          increasedValue: _semanticValue(increased),
          decreasedValue: _semanticValue(decreased),
          onIncrease: _enabled ? () => _adjust(1) : null,
          onDecrease: _enabled ? () => _adjust(-1) : null,
          child: Listener(
            onPointerDown: _enabled ? (_) => _beginInteraction() : null,
            onPointerUp: _enabled ? (_) => _scheduleFinish() : null,
            onPointerCancel: _enabled ? (_) => _scheduleFinish() : null,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: SizedBox(width: double.infinity, child: padded),
            ),
          ),
        ),
      ),
    );
  }
}
