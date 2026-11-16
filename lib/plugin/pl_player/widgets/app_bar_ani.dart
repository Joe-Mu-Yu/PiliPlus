import 'package:PiliPlus/common/widgets/immersive/immersive_tokens.dart';
import 'package:PiliPlus/common/widgets/view_safe_area.dart';
import 'package:material_ui/material_ui.dart';

/// Top/bottom player chrome transition.
///
/// Uses a short fade plus a small vertical offset instead of sliding the whole
/// bar off-screen. The offset stays inside the bar so nothing pops in from the
/// edge, and both animations collapse to zero duration when the platform
/// disables animations.
class AppBarAni extends StatelessWidget {
  const AppBarAni({
    super.key,
    required this.child,
    required this.controller,
    required this.isTop,
    required this.isFullScreen,
    required this.removeSafeArea,
  });

  final Widget child;
  final AnimationController controller;
  final bool isTop;
  final bool isFullScreen;
  final bool removeSafeArea;

  static final _topPos = Tween<Offset>(
    begin: const Offset(0.0, -.18),
    end: Offset.zero,
  );

  static const _topDecoration = LinearGradient(
    begin: Alignment.bottomCenter,
    end: Alignment.topCenter,
    colors: <Color>[
      Colors.transparent,
      Color(0xBF000000),
    ],
    tileMode: TileMode.mirror,
  );

  static final _bottomPos = Tween<Offset>(
    begin: const Offset(0, .22),
    end: Offset.zero,
  );

  static const _bottomDecoration = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[
      Colors.transparent,
      Color(0xBF000000),
    ],
    tileMode: TileMode.mirror,
  );

  @override
  Widget build(BuildContext context) {
    final reduceMotion = ImmersiveTokens.reduceMotionOf(context);
    final content = DecoratedBox(
      decoration: BoxDecoration(
        gradient: isTop ? _topDecoration : _bottomDecoration,
      ),
      child: removeSafeArea
          ? child
          : ViewSafeArea(
              left: isFullScreen,
              right: isFullScreen,
              child: child,
            ),
    );
    if (reduceMotion) return content;
    return SlideTransition(
      position: controller.drive(isTop ? _topPos : _bottomPos),
      child: FadeTransition(
        opacity: controller,
        child: content,
      ),
    );
  }
}
