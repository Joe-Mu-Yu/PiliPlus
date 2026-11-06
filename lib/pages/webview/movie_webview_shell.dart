import 'package:PiliPlus/common/widgets/app_material_localizations.dart';
import 'package:flutter/material.dart';

bool isMovieSiteUrl(String url) {
  final host = Uri.tryParse(url)?.host.toLowerCase() ?? '';
  return host == 'gimytv.biz' || host.endsWith('.gimytv.biz');
}

class MovieWebViewAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const MovieWebViewAppBar({
    required this.title,
    required this.progress,
    required this.onBack,
    super.key,
  });

  final String title;
  final double progress;
  final VoidCallback onBack;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppMaterialLocalizations(
      child: Builder(
        builder: (context) => _LocalizedMovieAppBar(
          title: title,
          progress: progress,
          onBack: onBack,
        ),
      ),
    );
  }
}

class _LocalizedMovieAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const _LocalizedMovieAppBar({
    required this.title,
    required this.progress,
    required this.onBack,
  });

  final String title;
  final double progress;
  final VoidCallback onBack;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) => AppBar(
    backgroundColor: Theme.of(context).colorScheme.surface,
    foregroundColor: Theme.of(context).colorScheme.onSurface,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    leading: IconButton(
      tooltip: '返回',
      onPressed: onBack,
      icon: const Icon(Icons.arrow_back_rounded),
    ),
    title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
    bottom: PreferredSize(
      preferredSize: Size.zero,
      child: progress < 1
          ? LinearProgressIndicator(value: progress.clamp(0, 1))
          : const SizedBox.shrink(),
    ),
  );
}

/// Keeps Material routes opened from the Movies WebView localized without
/// adding browser-tool controls over the third-party page.
class MovieWebViewShell extends StatelessWidget {
  const MovieWebViewShell({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => AppMaterialLocalizations(child: child);
}
