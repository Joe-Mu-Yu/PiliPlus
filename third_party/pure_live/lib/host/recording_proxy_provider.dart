import 'package:PiliPlus/services/pure_live_recording_preferences.dart';

/// Reads the existing PiliPlus system-proxy preferences without registering
/// Pure Live's application-wide proxy settings controller.
class RecordingProxyProvider {
  static bool enabled() => PureLiveRecordingPreferences.getBool('enableSystemProxy') ?? false;
  static String host() => PureLiveRecordingPreferences.getString('systemProxyHost') ?? '';
  static int port() => int.tryParse(PureLiveRecordingPreferences.getString('systemProxyPort') ?? '') ?? 7897;
}
