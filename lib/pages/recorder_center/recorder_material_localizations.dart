import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

/// The recorder can be hosted in a retained page subtree whose route builder
/// does not inherit the app-level Localizations scope. Keep its Material
/// widgets safe in either the main navigator or an embedded host.
class RecorderMaterialLocalizations extends StatelessWidget {
  const RecorderMaterialLocalizations({
    super.key,
    required this.child,
    this.locale = const Locale('zh', 'CN'),
  });

  final Widget child;
  final Locale locale;

  @override
  Widget build(BuildContext context) => Localizations(
    locale: locale,
    delegates: GlobalMaterialLocalizations.delegates,
    child: child,
  );
}
