import 'package:pure_live/core/common/http_header_policy.dart';
import 'package:pure_live/core/site/douyin/douyin_site.dart';
import 'package:pure_live/core/utils/douyin/douyin_request_params.dart';
import 'package:pure_live/host/recording_cookie_provider.dart';

/// Builds recording-only transport headers without importing the playback
/// resolver's complete platform registry and its app-wide settings graph.
class FFmpegHeaderFactory {
  static const String _douyinOrigin = 'https://live.douyin.com';

  static Future<Map<String, String>> build({
    required String platform,
    String roomId = '',
    Map<String, String> roomHeaders = const <String, String>{},
  }) async {
    final normalizedPlatform = platform.trim().toLowerCase();
    final normalizedRoomId = Uri.encodeComponent(roomId.trim());
    if (normalizedPlatform != 'douyin') return HttpHeaderPolicy.normalize(roomHeaders);

    final configuredCookie = RecordingCookieProvider.read().trim();
    final cookie = configuredCookie.isNotEmpty ? configuredCookie : DouyinSite.cookie.trim();
    return HttpHeaderPolicy.normalize(<String, String>{
      'user-agent': DouyinRequestParams.kDefaultUserAgent,
      'origin': _douyinOrigin,
      'referer': normalizedRoomId.isEmpty ? '$_douyinOrigin/' : '$_douyinOrigin/$normalizedRoomId',
      if (cookie.isNotEmpty) 'cookie': cookie,
      ...roomHeaders,
    });
  }
}
