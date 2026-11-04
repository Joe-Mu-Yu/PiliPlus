import 'package:PiliPlus/common/widgets/app_material_localizations.dart';
import 'package:flutter/widgets.dart';

/// Keeps Material routes opened from the Movies WebView localized without
/// adding any visible browser controls over the third-party page.
class MovieWebViewShell extends StatelessWidget {
  const MovieWebViewShell({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => AppMaterialLocalizations(child: child);
}
