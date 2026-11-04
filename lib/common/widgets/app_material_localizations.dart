import 'package:material_ui/material_ui.dart';

/// Material routes opened outside the page subtree must provide their own
/// localization scope because GetX may build them in the root navigator.
class AppMaterialLocalizations extends StatelessWidget {
  const AppMaterialLocalizations({
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
