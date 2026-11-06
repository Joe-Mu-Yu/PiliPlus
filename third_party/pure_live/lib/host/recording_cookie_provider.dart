import 'package:PiliPlus/services/pure_live_recording_preferences.dart';

/// Reads explicitly stored platform cookies from PiliPlus settings.
/// Anonymous access remains available when the user has not configured one.
class RecordingCookieProvider {
  static String read() =>
      PureLiveRecordingPreferences.getString('douyinCookie') ?? '';

  static String readHuya() =>
      PureLiveRecordingPreferences.getString('huyaCookie') ?? '';
}
