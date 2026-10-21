import 'package:pure_live/host/recording_i18n.dart';

String i18n(String key, {Map<String, String>? args}) => RecordingI18n.translate(key, args: args);

String i18nOr(String key, String fallback, {Map<String, String>? args}) =>
    RecordingI18n.translateOr(key, fallback, args: args);

bool i18nExists(String key) => RecordingI18n.containsKey(key);
