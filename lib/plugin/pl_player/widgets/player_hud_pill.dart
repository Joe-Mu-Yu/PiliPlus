import 'package:PiliPlus/common/widgets/immersive/immersive_tokens.dart';
import 'package:material_ui/material_ui.dart';

/// Shared player HUD capsule for volume, brightness, seek and speed feedback.
///
/// Purely decorative: it ignores pointers, paints a single capsule and animates
/// opacity plus a small scale. No blur, screenshot or shader is involved, and the
/// animation collapses to zero duration when the platform disables animations.
class PlayerHudPill extends StatelessWidget {
  const PlayerHudPill({
    super.key,
    required this.visible,
    required this.icon,
    required this.label,
    this.trailing,
    this.alignment = Alignment.center,
    this.semanticLabel,
  });

  /// Drives both opacity and scale; pass the controller's observable flag.
  final bool visible;
  final Widget icon;
  final String label;
  final Widget? trailing;
  final Alignment alignment;

  /// Screen-reader text; defaults to [label].
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final duration = ImmersiveTokens.hudDuration(context);
    return IgnorePointer(
      child: Align(
        alignment: alignment,
        child: Semantics(
          label: semanticLabel ?? label,
          child: AnimatedOpacity(
            opacity: visible ? 1 : 0,
            duration: duration,
            curve: Curves.easeOutCubic,
            child: AnimatedScale(
              scale: visible ? 1 : .94,
              duration: duration,
              curve: Curves.easeOutCubic,
              child: DecoratedBox(
                decoration: ImmersiveTokens.pillSurface(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      icon,
                      const SizedBox(width: 8),
                      Text(
                        label,
                        style: const TextStyle(
                          color: ImmersiveTokens.playerChromeText,
                          fontSize: 13,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                      if (trailing case final trailing?) ...[
                        const SizedBox(width: 8),
                        trailing,
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
