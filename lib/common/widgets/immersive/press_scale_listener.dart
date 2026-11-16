import 'package:PiliPlus/common/widgets/immersive/immersive_tokens.dart';
import 'package:material_ui/material_ui.dart';

/// Adds press-scale feedback without owning the gesture.
///
/// Wrapping widgets that already have their own tap/long-press handling (such as
/// [InkWell]) must not install another gesture recognizer, otherwise the tap
/// would fire twice. This widget only observes raw pointer down/up/cancel and
/// animates the scale, leaving all hit testing and gesture handling to [child].
class PressScaleListener extends StatefulWidget {
  const PressScaleListener({
    super.key,
    required this.child,
    this.scale = ImmersiveTokens.pressedScale,
    this.curve = Curves.easeOutCubic,
    this.enabled = true,
  });

  final Widget child;
  final double scale;
  final Curve curve;
  final bool enabled;

  @override
  State<PressScaleListener> createState() => _PressScaleListenerState();
}

class _PressScaleListenerState extends State<PressScaleListener> {
  bool _pressed = false;

  void _set(bool value) {
    if (_pressed == value || !mounted) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    final reduced = ImmersiveTokens.reduceMotionOf(context);
    return Listener(
      behavior: HitTestBehavior.deferToChild,
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: reduced || !_pressed ? 1.0 : widget.scale,
        duration: ImmersiveTokens.pressDuration(context),
        curve: widget.curve,
        child: widget.child,
      ),
    );
  }
}
