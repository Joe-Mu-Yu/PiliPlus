import 'dart:convert';
import 'dart:io';

import 'package:PiliPlus/services/pure_live_recording_preferences.dart';

/// Compatibility bridge for LiveRoom's optional per-room volume accessors.
/// It preserves Pure Live's existing Hive keys without loading its volume
/// settings/GetX service graph into PiliPlus.
abstract final class RecordingRoomVolume {
  static const _volumesKey = 'roomVolumes';

  static double read(String platform, String roomId) {
    if (PureLiveRecordingPreferences.getBool('globalVolumeMute') ?? false)
      return 0;
    final key = 'room_vol_${platform.toLowerCase().trim()}_${roomId.trim()}';
    final raw = PureLiveRecordingPreferences.getAnyPref(_volumesKey) ?? '{}';
    try {
      final values = raw is String ? jsonDecode(raw) as Map : raw as Map;
      final value = values[key];
      if (value is num && value.isFinite)
        return value.clamp(0.0, 1.0).toDouble();
    } catch (_) {
      // Invalid optional volume config falls back to the documented default.
    }
    final setting = Platform.isAndroid || Platform.isIOS
        ? 'defaultMobileVolume'
        : 'defaultDesktopVolume';
    final fallback = Platform.isAndroid || Platform.isIOS ? 0.5 : 1.0;
    final value = PureLiveRecordingPreferences.getDouble(setting) ?? fallback;
    return value.isFinite ? value.clamp(0.0, 1.0).toDouble() : fallback;
  }

  static Future<void> write(String platform, String roomId, double volume) {
    if (!volume.isFinite) return Future<void>.value();
    final write = _writeQueue.then((_) => _write(platform, roomId, volume));
    _writeQueue = write.catchError((Object _) {});
    return write;
  }

  static Future<void> _writeQueue = Future<void>.value();

  static Future<void> _write(
    String platform,
    String roomId,
    double volume,
  ) async {
    final raw = PureLiveRecordingPreferences.getAnyPref(_volumesKey) ?? '{}';
    final values = <String, double>{};
    try {
      final decoded = raw is String ? jsonDecode(raw) as Map : raw as Map;
      for (final entry in decoded.entries) {
        if (entry.key is String &&
            entry.value is num &&
            (entry.value as num).isFinite) {
          values[entry.key as String] = (entry.value as num)
              .clamp(0.0, 1.0)
              .toDouble();
        }
      }
    } catch (_) {}
    final key = 'room_vol_${platform.toLowerCase().trim()}_${roomId.trim()}';
    values[key] = volume.clamp(0.0, 1.0).toDouble();
    await PureLiveRecordingPreferences.setString(
      _volumesKey,
      jsonEncode(values),
    );
  }
}
