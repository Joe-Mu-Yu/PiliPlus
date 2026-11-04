import 'package:hive_ce/hive.dart';

/// Narrow bridge from Pure Live's recorder settings API to PiliPlus's
/// already-initialized Hive `setting` box. No parallel Hive box is created.
abstract final class PureLiveRecordingPreferences {
  static Box<dynamic>? _settings;

  static Box<dynamic> get _box =>
      _settings ??
      (throw StateError('Pure Live recording preferences are not initialized'));

  static void configure(Box<dynamic> settings) {
    _settings = settings;
  }

  static dynamic _get(String key) => _box.get(key);

  static dynamic getAnyPref(String key) => _get(key);
  static bool? getBool(String key) =>
      _get(key) is bool ? _get(key) as bool : null;
  static int? getInt(String key) => _get(key) is int ? _get(key) as int : null;
  static String? getString(String key) =>
      _get(key) is String ? _get(key) as String : null;
  static double? getDouble(String key) =>
      _get(key) is num ? (_get(key) as num).toDouble() : null;
  static List<String>? getStringList(String key) =>
      _get(key) is List ? List<String>.from(_get(key) as List) : null;

  static Future<bool> setAnyPref(String key, dynamic value) async {
    await _box.put(key, value);
    return true;
  }

  static Future<bool> setBool(String key, bool value) => setAnyPref(key, value);
  static Future<bool> setInt(String key, int value) => setAnyPref(key, value);
  static Future<bool> setString(String key, String value) =>
      setAnyPref(key, value);
  static Future<bool> setDouble(String key, double value) =>
      setAnyPref(key, value);
  static Future<bool> setStringList(String key, List<String> value) =>
      setAnyPref(key, value);
  static Future<bool> remove(String key) async {
    await _box.delete(key);
    return true;
  }

  static bool containsKey(String key) => _box.containsKey(key);
  static Future<void> flush() => _box.flush();
}
