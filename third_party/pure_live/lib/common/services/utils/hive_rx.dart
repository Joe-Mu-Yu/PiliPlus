import 'dart:async';
import 'dart:convert';

import 'package:get/get.dart';
import 'package:pure_live/common/utils/hive_pref_util.dart' show HivePrefUtil;
import 'package:PiliPlus/services/pure_live_recording_preferences.dart';

final _persistCurrentValue = Expando<void Function()>('hive-persist-current');

RxBool hiveBool(String key, bool defaultValue) {
  final initialValue = PureLiveRecordingPreferences.getBool(key) ?? defaultValue;

  return RxBool(initialValue)..hive(key);
}

RxString hiveString(String key, String defaultValue) {
  final initialValue = PureLiveRecordingPreferences.getString(key) ?? defaultValue;

  return RxString(initialValue)..hive(key);
}

RxInt hiveInt(String key, int defaultValue) {
  final initialValue = PureLiveRecordingPreferences.getInt(key) ?? defaultValue;

  return RxInt(initialValue)..hive(key);
}

RxDouble hiveDouble(String key, double defaultValue) {
  final initialValue = PureLiveRecordingPreferences.getDouble(key) ?? defaultValue;

  return RxDouble(initialValue)..hive(key);
}

RxList<String> hiveStringList(String key, List<String> defaultValue) {
  final initialValue = PureLiveRecordingPreferences.getStringList(key);

  if (initialValue != null) {
    return RxList<String>(List<String>.from(initialValue))..hiveList(key);
  }

  return RxList<String>(List<String>.from(defaultValue))..hiveList(key);
}

Rx<T> hiveObject<T>(
  String key,
  T defaultValue, {
  required T Function(Map<String, dynamic>) fromJson,
  required Map<String, dynamic> Function(T value) toJson,
}) {
  final jsonStr = PureLiveRecordingPreferences.getString(key);

  T initialValue = defaultValue;

  if (jsonStr != null && jsonStr.isNotEmpty) {
    try {
      initialValue = fromJson(jsonDecode(jsonStr));
    } catch (_) {}
  }

  return Rx<T>(initialValue)..hiveObject(key, toJson: toJson);
}

extension HiveRxExtension<T> on Rx<T> {
  T get v => value;

  set v(T newValue) {
    value = newValue;
    // A failed disk write may leave this Rx value already equal to a retry's
    // input. Persist it without manufacturing a UI notification in that case.
    if (HivePrefUtil.isCollectingWrites) _persistCurrentValue[this]?.call();
  }

  void hive(String key) {
  _persistCurrentValue[this] = () => unawaited(PureLiveRecordingPreferences.setAnyPref(key, value));
    ever<T>(this, (value) {
      if (value is bool) {
        unawaited(PureLiveRecordingPreferences.setBool(key, value));
      } else if (value is String) {
        unawaited(PureLiveRecordingPreferences.setString(key, value));
      } else if (value is int) {
        unawaited(PureLiveRecordingPreferences.setInt(key, value));
      } else if (value is double) {
        unawaited(PureLiveRecordingPreferences.setDouble(key, value));
      } else {
        unawaited(PureLiveRecordingPreferences.setAnyPref(key, value));
      }
    });
  }

  void hiveObject(String key, {required Map<String, dynamic> Function(T value) toJson}) {
      _persistCurrentValue[this] = () => unawaited(PureLiveRecordingPreferences.setString(key, jsonEncode(toJson(value))));
    ever<T>(this, (value) {
      try {
        unawaited(PureLiveRecordingPreferences.setString(key, jsonEncode(toJson(value))));
      } catch (_) {}
    }, condition: () => true);
  }
}

extension HiveRxListExtension on RxList<String> {
  List<String> get v => this;

  set v(List<String> newValue) {
    try {
      assignAll(List<String>.from(newValue));
    } catch (_) {
      value = List<String>.from(newValue);
    }
  }

  void hiveList(String key) {
    ever<List<String>>(this, (value) {
      unawaited(PureLiveRecordingPreferences.setStringList(key, value));
    });
  }
}
