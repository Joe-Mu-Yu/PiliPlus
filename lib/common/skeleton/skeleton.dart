import 'dart:ui' as ui;

import 'package:flutter_miuix/miuix.dart' as miuix;
import 'package:material_ui/material_ui.dart';

class Skeleton extends StatefulWidget {
  final Widget child;

  const Skeleton({super.key, required this.child});

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Color color;
  final matrix = Matrix4.identity();
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController.unbounded(vsync: this, value: 0.5);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    color = miuix.MiuixTheme.of(
      context,
    ).colors.onSurface.withValues(alpha: 0.04);
    _reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (_reduceMotion) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat(
        min: -0.5,
        max: 1.5,
        period: const Duration(milliseconds: 1000),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_reduceMotion) return widget.child;
    final colors = [Colors.transparent, color, color, Colors.transparent];
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        child: widget.child,
        builder: (context, child) => ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (Rect bounds) {
            final width = bounds.width;
            final height = bounds.height;
            matrix[12] = width * _controller.value;
            return ui.Gradient.linear(
              Offset(0, 0.35 * height),
              Offset(width, 0.95 * height),
              colors,
              const [0.1, 0.3, 0.5, 0.7],
              TileMode.clamp,
              matrix.storage,
            );
          },
          child: child,
        ),
      ),
    );
  }
}
