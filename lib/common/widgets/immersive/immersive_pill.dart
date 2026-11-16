import 'package:PiliPlus/common/widgets/immersive/immersive_tokens.dart';
import 'package:PiliPlus/utils/extension/theme_ext.dart';
import 'package:material_ui/material_ui.dart';

/// Compact capsule used by segmented switches, metadata chips and the player
/// chrome. Every instance is a single painted box with a hairline border; no
/// blur, shader or backdrop filter is involved.
class ImmersivePill extends StatelessWidget {
  const ImmersivePill({
    super.key,
    required this.child,
    this.selected = false,
    this.onTap,
    this.colorScheme,
    this.padding = const EdgeInsets.symmetric(horizontal: 14),
    this.height = ImmersiveTokens.pillHeight,
    this.tint,
    this.borderColor,
    this.semanticLabel,
  });

  final Widget child;

  /// Selected pills use the primary container role instead of a hard-coded
  /// accent so light, dark and pure-black themes all stay in contrast.
  final bool selected;
  final VoidCallback? onTap;

  /// Explicit scheme for surfaces rendered outside the page theme (player).
  final ColorScheme? colorScheme;
  final EdgeInsetsGeometry padding;
  final double height;
  final Color? tint;
  final Color? borderColor;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = colorScheme ?? ColorScheme.of(context);
    final background =
        tint ??
        (selected
            ? scheme.primaryContainer
            : scheme.surfaceContainerHigh.withValues(
                alpha: scheme.isLight ? .72 : .56,
              ));
    final foreground = selected
        ? scheme.onPrimaryContainer
        : scheme.onSurfaceVariant;
    final body = DefaultTextStyle.merge(
      style: TextStyle(
        color: foreground,
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
      child: IconTheme.merge(
        data: IconThemeData(color: foreground, size: 18),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: height,
            minWidth: ImmersiveTokens.minTouchTarget,
          ),
          child: Padding(
            padding: padding,
            child: Center(widthFactor: 1, heightFactor: 1, child: child),
          ),
        ),
      ),
    );
    final decorated = DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(ImmersiveTokens.pillRadius),
        border: Border.all(
          color:
              borderColor ??
              (selected
                  ? Colors.transparent
                  : ImmersiveTokens.cardOutline(scheme)),
          width: ImmersiveTokens.hairline,
        ),
      ),
      child: body,
    );
    if (onTap == null) {
      return Semantics(
        label: semanticLabel,
        button: false,
        child: decorated,
      );
    }
    return Semantics(
      label: semanticLabel,
      button: true,
      selected: selected,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: decorated,
        ),
      ),
    );
  }
}
