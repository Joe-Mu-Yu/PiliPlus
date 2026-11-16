import 'package:PiliPlus/common/widgets/immersive/immersive_tokens.dart';
import 'package:material_ui/material_ui.dart';

/// Center the label within the entire menu button's touch target.
class PlayerControlLabel extends StatelessWidget {
  const PlayerControlLabel({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Center(
    widthFactor: 1,
    heightFactor: 1,
    child: child,
  );
}

/// Single-row player controls: a flexible seek rail plus grouped actions,
/// painted on one rounded chrome surface.
///
/// The row is a flat decoration (no blur/shader), so it costs the same as the
/// old transparent bar. Every interactive slot keeps a >=40dp touch target even
/// when the text scale grows, and the seek rail stays flexible instead of
/// shrinking the buttons.
class CompactPlayerControls extends StatelessWidget {
  const CompactPlayerControls({
    super.key,
    required this.playButton,
    required this.progress,
    required this.time,
    required this.speed,
    required this.options,
    this.fullscreenButton,
    this.chromeSurface = true,
  });

  final Widget playButton;
  final Widget progress;
  final Widget time;
  final Widget speed;
  final Widget? fullscreenButton;

  /// Whether to paint the rounded chrome surface behind the row.
  final bool chromeSurface;

  /// Runs a page-level action only after the options dialog is dismissed.
  ///
  /// A chapter or episode sheet belongs to the video page's navigator. Opening
  /// it while this dialog is still the active modal route leaves the sheet
  /// underneath the dialog, so its list appears but cannot receive taps.
  final List<({String label, Widget control})> Function(
    void Function(VoidCallback action) runOutsideOptionsDialog,
  )
  options;

  Future<void> _showOptions(BuildContext context) async {
    VoidCallback? pendingPageAction;
    await showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xff242428),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      '播放选项',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '关闭',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 16,
                children:
                    options((action) {
                          pendingPageAction = action;
                          Navigator.of(context).pop();
                        })
                        .map(
                          (option) => SizedBox(
                            width: 76,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  height: 44,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: .07),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: DefaultTextStyle.merge(
                                    textAlign: TextAlign.center,
                                    child: SizedBox(
                                      width: 76,
                                      height: 44,
                                      child: option.control,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  option.label,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
              ),
            ],
          ),
        ),
      ),
      // The options dialog is an opaque sheet; keep it instant when the platform
      // disables animations instead of playing a route transition.
      barrierDismissible: true,
    );
    pendingPageAction?.call();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 440;
        final row = SizedBox(
          height: ImmersiveTokens.controlRowHeight,
          child: Row(
            textDirection: TextDirection.ltr,
            children: [
              SizedBox(
                width: 44,
                height: ImmersiveTokens.controlRowHeight,
                child: playButton,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: progress,
                ),
              ),
              // The time label is the first thing to go so the seek rail never
              // collapses; it only appears once there is room for both.
              if (constraints.maxWidth >= 360)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 120),
                  child: time,
                ),
              if (wide)
                SizedBox(
                  width: 48,
                  child: Center(child: SizedBox(height: 40, child: speed)),
                ),
              IconButton(
                constraints: const BoxConstraints.tightFor(
                  width: 44,
                  height: ImmersiveTokens.controlRowHeight,
                ),
                padding: EdgeInsets.zero,
                tooltip: '播放选项',
                onPressed: () => _showOptions(context),
                icon: const Icon(
                  Icons.more_horiz_rounded,
                  size: 22,
                  color: ImmersiveTokens.playerChromeText,
                ),
              ),
              if (fullscreenButton case final button?)
                SizedBox(
                  width: 44,
                  height: ImmersiveTokens.controlRowHeight,
                  child: button,
                ),
            ],
          ),
        );
        if (!chromeSurface) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: row,
          );
        }
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: DecoratedBox(
            key: const ValueKey('player-control-chrome'),
            decoration: ImmersiveTokens.pillSurface(radius: 24),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: row,
            ),
          ),
        );
      },
    );
  }
}
