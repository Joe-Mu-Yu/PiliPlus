import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart' show WidgetsFlutterBinding;

/// Narrow localization bridge backed by the original Pure Live translations.
/// Keeping this independent of EasyLocalization avoids bootstrapping its
/// application-wide localization and routing layer in PiliPlus.
class RecordingI18n {
  static final Map<String, Map<String, String>> _translations = {};
  static const String _language = 'zh';

  static Future<void> initialize() async {
    WidgetsFlutterBinding.ensureInitialized();
    final data = await rootBundle.loadString(
      'packages/pure_live/assets/translations/$_language.json',
    );
    _translations[_language] = (jsonDecode(data) as Map<String, dynamic>).map(
      (key, value) => MapEntry(key, value.toString()),
    );
  }

  static String translate(String key, {Map<String, String>? args}) {
    final translations = _translations[_language];
    var value = translations?[key] ?? key;
    for (final entry in args?.entries ?? const <MapEntry<String, String>>[]) {
      value = value.replaceAll('{${entry.key}}', entry.value);
    }
    return value;
  }

  static bool containsKey(String key) {
    return _translations[_language]?.containsKey(key) ?? false;
  }

  static String translateOr(
    String key,
    String fallback, {
    Map<String, String>? args,
  }) => containsKey(key) ? translate(key, args: args) : fallback;
}

String i18n(String key, {Map<String, String>? args}) {
  return RecordingI18n.translate(key, args: args);
}

String i18nOr(String key, String fallback, {Map<String, String>? args}) {
  final translated = i18n(key, args: args);
  return translated == key ? fallback : translated;
}
