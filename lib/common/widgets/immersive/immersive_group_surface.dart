import 'package:PiliPlus/common/widgets/immersive/immersive_tokens.dart';
import 'package:material_ui/material_ui.dart';

/// Higher-level grouped surface for intro panels, reply containers and side
/// columns. Rounded once and painted with a flat fill, so it adds no composited
/// layers beyond the single clip.
class ImmersiveGroupSurface extends StatelessWidget {
  const ImmersiveGroupSurface({
    super.key,
    required this.child,
    this.radius = ImmersiveTokens.groupRadius,
    this.padding,
    this.colorScheme,
    this.color,
    this.border = false,
    this.clip = true,
    this.margin,
  });

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry? padding;
  final ColorScheme? colorScheme;
  final Color? color;
  final bool border;
  final bool clip;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final scheme = colorScheme ?? ColorScheme.of(context);
    final decoration = BoxDecoration(
      color: color ?? ImmersiveTokens.groupSurface(scheme),
      borderRadius: BorderRadius.circular(radius),
      border: border
          ? Border.all(
              color: ImmersiveTokens.cardOutline(scheme),
              width: ImmersiveTokens.hairline,
            )
          : null,
    );
    Widget content = child;
    if (padding != null) content = Padding(padding: padding!, child: content);
    final body = DecoratedBox(
      decoration: decoration,
      child: clip
          ? ClipRRect(
              borderRadius: BorderRadius.circular(radius),
              child: content,
            )
          : content,
    );
    if (margin == null) return body;
    return Padding(padding: margin!, child: body);
  }
}
