import 'dart:convert';

import 'package:PiliPlus/http/live.dart';
import 'package:PiliPlus/http/init.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/models/common/live_favorite.dart';
import 'package:PiliPlus/models_new/live/live_room_info_h5/data.dart';
import 'package:PiliPlus/models_new/live/live_room_play_info/data.dart';
import 'package:PiliPlus/services/live_favorite_repository.dart';
import 'package:dio/dio.dart';
import 'package:pure_live/common/models/live_room.dart'
    show LiveRoom, LiveStatus;
import 'package:pure_live/core/site/douyin/douyin_site.dart';
import 'package:pure_live/core/interface/live_site.dart'
    show LiveSite, normalizeResolvedPlayUrls;
import 'package:pure_live/core/interface/live_danmaku.dart' show LiveDanmaku;
import 'package:pure_live/core/danmaku/empty_danmaku.dart' show EmptyDanmaku;
import 'package:pure_live/model/live_play_quality.dart' show LivePlayQuality;

class LiveRoomResolutionException extends FormatException {
  const LiveRoomResolutionException(super.message);
}

abstract interface class LivePlatformAdapter {
  String get platformId;
  bool canResolve(String rawLink);
  Future<LiveFavorite> resolveFavorite(String rawLink);
  Future<LiveFavorite> refreshFavorite(LiveFavorite favorite);
}

typedef BilibiliRoomInfoLookup = Future<LoadingState<RoomInfoH5Data>> Function(
  int roomId,
);
typedef BilibiliPlayInfoLookup =
    Future<LoadingState<RoomPlayInfoData>> Function(int roomId);

class BilibiliLivePlatformAdapter implements LivePlatformAdapter {
  BilibiliLivePlatformAdapter({
    BilibiliRoomInfoLookup? getRoomInfo,
    BilibiliPlayInfoLookup? getPlayInfo,
  }) : _getRoomInfo = getRoomInfo ?? _fetchRoomInfo,
       _getPlayInfo = getPlayInfo ?? _fetchPlayInfo;

  final BilibiliRoomInfoLookup _getRoomInfo;
  final BilibiliPlayInfoLookup _getPlayInfo;

  @override
  String get platformId => 'bilibili';

  static String? roomIdFromUrl(String rawLink) {
    final uri = Uri.tryParse(rawLink.trim());
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.toLowerCase() != 'live.bilibili.com' ||
        uri.userInfo.isNotEmpty ||
        (uri.hasPort && uri.port != 443) ||
        uri.hasFragment) {
      return null;
    }
    final match = RegExp(r'^/([1-9][0-9]{0,12})/?$').firstMatch(uri.path);
    return match?.group(1);
  }

  @override
  bool canResolve(String rawLink) => roomIdFromUrl(rawLink) != null;

  @override
  Future<LiveFavorite> resolveFavorite(String rawLink) async {
    final roomIdString = roomIdFromUrl(rawLink);
    final roomId = roomIdString == null ? null : int.tryParse(roomIdString);
    if (roomId == null) {
      throw const LiveRoomResolutionException('不是受支持的 Bilibili 直播间链接');
    }

    final results = await Future.wait([
      _getRoomInfo(roomId),
      _getPlayInfo(roomId),
    ]);
    final roomResult = results[0] as LoadingState<RoomInfoH5Data>;
    final playResult = results[1] as LoadingState<RoomPlayInfoData>;
    if (!roomResult.isSuccess || roomResult.data.roomInfo == null) {
      throw const LiveRoomResolutionException('无法验证该 Bilibili 直播间');
    }

    final roomInfo = roomResult.data;
    final playInfo = playResult.dataOrNull;
    final resolvedRoomId = playInfo?.roomId ?? roomId;
    final status = switch (playInfo?.liveStatus) {
      1 => LiveFavoriteStatus.live,
      2 => LiveFavoriteStatus.replay,
      0 => LiveFavoriteStatus.offline,
      _ => LiveFavoriteStatus.unknown,
    };

    return LiveFavorite(
      platformId: platformId,
      roomId: resolvedRoomId.toString(),
      roomUrl: 'https://live.bilibili.com/$resolvedRoomId',
      title: roomInfo.roomInfo?.title,
      anchorName: roomInfo.anchorInfo?.baseInfo?.uname,
      coverUrl: roomInfo.roomInfo?.cover,
      status: status,
    );
  }

  @override
  Future<LiveFavorite> refreshFavorite(LiveFavorite favorite) =>
      resolveFavorite(favorite.roomUrl);

  static Future<LoadingState<RoomInfoH5Data>> _fetchRoomInfo(int roomId) =>
      LiveHttp.liveRoomInfoH5(roomId: roomId);

  static Future<LoadingState<RoomPlayInfoData>> _fetchPlayInfo(int roomId) =>
      LiveHttp.liveRoomInfo(roomId: roomId);
}

typedef DouyuRoomInfoLookup = Future<Map<String, Object?>> Function(
  String roomId,
);

class DouyuLivePlatformAdapter implements LivePlatformAdapter {
  DouyuLivePlatformAdapter({DouyuRoomInfoLookup? getRoomInfo})
    : _getRoomInfo = getRoomInfo ?? _fetchRoomInfo;

  final DouyuRoomInfoLookup _getRoomInfo;

  @override
  String get platformId => 'douyu';

  static String? roomIdFromUrl(String rawLink) {
    final uri = Uri.tryParse(rawLink.trim());
    if (uri == null ||
        uri.scheme != 'https' ||
        !{'douyu.com', 'www.douyu.com'}.contains(uri.host.toLowerCase()) ||
        uri.userInfo.isNotEmpty ||
        (uri.hasPort && uri.port != 443) ||
        uri.hasFragment) {
      return null;
    }
    final match = RegExp(r'^/([1-9][0-9]{0,15})/?$').firstMatch(uri.path);
    return match?.group(1);
  }

  @override
  bool canResolve(String rawLink) => roomIdFromUrl(rawLink) != null;

  @override
  Future<LiveFavorite> resolveFavorite(String rawLink) async {
    final roomId = roomIdFromUrl(rawLink);
    if (roomId == null) {
      throw const LiveRoomResolutionException('不是受支持的斗鱼直播间链接');
    }

    final data = await _getRoomInfo(roomId);
    final canonicalId = data['room_id']?.toString().trim();
    final title = data['room_name']?.toString().trim();
    if (canonicalId == null ||
        canonicalId.isEmpty ||
        int.tryParse(canonicalId) == null ||
        title == null ||
        title.isEmpty) {
      throw const LiveRoomResolutionException('无法验证该斗鱼直播间');
    }

    final isReplay = _asInt(data['videoLoop']) == 1 || title.startsWith('【回放】');
    final isLive = !isReplay && _asInt(data['show_status']) == 1;
    return LiveFavorite(
      platformId: platformId,
      roomId: canonicalId,
      roomUrl: 'https://www.douyu.com/$canonicalId',
      title: title,
      anchorName: data['owner_name']?.toString(),
      coverUrl: data['room_pic']?.toString(),
      status: isReplay
          ? LiveFavoriteStatus.replay
          : isLive
          ? LiveFavoriteStatus.live
          : LiveFavoriteStatus.offline,
    );
  }

  @override
  Future<LiveFavorite> refreshFavorite(LiveFavorite favorite) =>
      resolveFavorite(favorite.roomUrl);

  static Future<Map<String, Object?>> _fetchRoomInfo(String roomId) async {
    final response = await Request().get(
      'https://www.douyu.com/betard/$roomId',
      options: Options(
        headers: {
          'referer': 'https://www.douyu.com/$roomId',
          'user-agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
              '(KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36',
        },
      ),
    );
    Object? payload = response.data;
    if (payload is String) {
      try {
        payload = jsonDecode(payload);
      } on FormatException {
        throw const LiveRoomResolutionException('斗鱼返回了无法识别的房间数据');
      }
    }
    if (payload is! Map || payload['room'] is! Map) {
      throw const LiveRoomResolutionException('无法验证该斗鱼直播间');
    }
    return Map<String, Object?>.from(payload['room'] as Map);
  }
}

typedef DouyinRecordingRoomLookup = Future<LiveRoom> Function({
  required String platform,
  required String roomId,
});
typedef DouyinWebRidRoomLookup = Future<LiveRoom> Function(String webRid);

/// Adapts Pure Live's strict Douyin room resolver for saved rooms and recording.
class DouyinLivePlatformAdapter implements LivePlatformAdapter {
  DouyinLivePlatformAdapter({
    DouyinRecordingRoomLookup? getRoomDetailForRecording,
    DouyinWebRidRoomLookup? getRoomDetailByWebRid,
  }) : _getRoomDetailForRecording =
           getRoomDetailForRecording ?? _fetchRecordingRoom,
       _getRoomDetailByWebRid = getRoomDetailByWebRid ?? _fetchWebRidRoom;

  final DouyinRecordingRoomLookup _getRoomDetailForRecording;
  final DouyinWebRidRoomLookup _getRoomDetailByWebRid;

  @override
  String get platformId => 'douyin';

  static final _douyinRoomIdPattern = RegExp(r'^[1-9][0-9]{0,19}$');

  static bool isLegacyAccountFavorite(LiveFavorite favorite) =>
      favorite.platformId == 'douyin' &&
      !_douyinRoomIdPattern.hasMatch(favorite.roomId) &&
      roomIdFromUrl(favorite.roomUrl) == null;

  static String? roomIdFromUrl(String rawLink) {
    final uri = Uri.tryParse(rawLink.trim());
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.userInfo.isNotEmpty ||
        (uri.hasPort && uri.port != 443) ||
        uri.hasFragment) {
      return null;
    }

    final host = uri.host.toLowerCase();
    final roomPath = switch (host) {
      'live.douyin.com' => r'^/([1-9][0-9]{0,19})/?$',
      'www.douyin.com' || 'douyin.com' => r'^/root/live/([1-9][0-9]{0,19})/?$',
      'webcast.amemv.com' => r'^/douyin/webcast/reflow/([1-9][0-9]{0,19})/?$',
      _ => null,
    };
    if (roomPath == null) return null;
    return RegExp(roomPath).firstMatch(uri.path)?.group(1);
  }

  @override
  bool canResolve(String rawLink) => roomIdFromUrl(rawLink) != null;

  /// Uses the vendored Pure Live recording-specific resolver, retaining its
  /// strict transport errors and the stream metadata needed by FFmpeg.
  Future<LiveRoom> resolveRoomForRecording(String rawLink) async {
    final roomId = roomIdFromUrl(rawLink);
    if (roomId == null) {
      throw const LiveRoomResolutionException('不是受支持的抖音直播间链接');
    }
    final uri = Uri.parse(rawLink.trim());
    final room = uri.host.toLowerCase() != 'webcast.amemv.com'
        ? await _getRoomDetailByWebRid(roomId)
        : await _getRoomDetailForRecording(
            platform: platformId,
            roomId: roomId,
          );
    final resolvedId = room.roomId?.trim() ?? '';
    if (room.platform?.trim().toLowerCase() != platformId ||
        !RegExp(r'^[1-9][0-9]{0,19}$').hasMatch(resolvedId)) {
      throw const LiveRoomResolutionException('无法验证该抖音直播间');
    }
    if (!_douyinRoomIdPattern.hasMatch(resolvedId) ||
        room.effectiveLiveStatus == LiveStatus.unknown ||
        room.effectiveLiveStatus == LiveStatus.banned) {
      throw const LiveRoomResolutionException('无法确认该抖音直播间状态，请稍后重试');
    }
    return room;
  }

  @override
  Future<LiveFavorite> resolveFavorite(String rawLink) async {
    final room = await resolveRoomForRecording(rawLink);
    final roomId = room.roomId!.trim();
    return LiveFavorite(
      platformId: platformId,
      roomId: roomId,
      roomUrl: 'https://live.douyin.com/$roomId',
      title: room.title,
      anchorName: room.nick,
      coverUrl: room.cover,
      status: switch (room.effectiveLiveStatus) {
        LiveStatus.live => LiveFavoriteStatus.live,
        LiveStatus.offline => LiveFavoriteStatus.offline,
        LiveStatus.replay => LiveFavoriteStatus.replay,
        LiveStatus.unknown || LiveStatus.banned => LiveFavoriteStatus.unknown,
      },
    );
  }

  @override
  Future<LiveFavorite> refreshFavorite(LiveFavorite favorite) {
    final roomUrl =
        roomIdFromUrl(favorite.roomUrl) == null &&
            _douyinRoomIdPattern.hasMatch(favorite.roomId)
        ? 'https://live.douyin.com/${favorite.roomId}'
        : favorite.roomUrl;
    return resolveFavorite(roomUrl);
  }

  static Future<LiveRoom> _fetchRecordingRoom({
    required String platform,
    required String roomId,
  }) => DouyinSite().getRoomDetailForRecording(
    platform: platform,
    roomId: roomId,
  );

  static Future<LiveRoom> _fetchWebRidRoom(String webRid) =>
      DouyinSite().getRoomDetailByWebRid(webRid);
}

/// Resolves direct stream links through Pure Live's room and playback contract.
class PureLiveDirectLinkAdapter implements LivePlatformAdapter {
  PureLiveDirectLinkAdapter({LiveSite? site})
    : _site = site ?? PureLiveDirectLinkSite();

  final LiveSite _site;

  @override
  String get platformId => 'pure_live';

  static Uri? uriFromLink(String rawLink) {
    final uri = Uri.tryParse(rawLink.trim());
    if (uri == null ||
        !{'http', 'https'}.contains(uri.scheme.toLowerCase()) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment) {
      return null;
    }
    final path = uri.path.toLowerCase();
    if (!path.endsWith('.m3u8') &&
        !path.endsWith('.flv') &&
        !path.endsWith('.mp4')) {
      return null;
    }
    return uri;
  }

  @override
  bool canResolve(String rawLink) => uriFromLink(rawLink) != null;

  @override
  Future<LiveFavorite> resolveFavorite(String rawLink) async {
    final uri = uriFromLink(rawLink);
    if (uri == null) {
      throw const LiveRoomResolutionException('不是受支持的直播流链接');
    }
    final roomId = uri.toString();
    final room = LiveRoom(
      roomId: roomId,
      title: uri.pathSegments.isEmpty ? uri.host : uri.pathSegments.last,
      nick: uri.host,
      area: '自定义直播源',
      watching: '',
      cover: '',
      avatar: '',
      status: true,
      liveStatus: LiveStatus.live,
      platform: _site.id,
      link: roomId,
      data: roomId,
    );
    final urls = normalizeResolvedPlayUrls(
      await _site.getPlayUrls(
        detail: room,
        quality:
            (await _site.getPlayQualites(detail: room)).firstOrNull ??
            (throw const LiveRoomResolutionException('Pure Live 未识别该直播流链接')),
      ),
    );
    if (urls.isEmpty) {
      throw const LiveRoomResolutionException('该直播流链接没有可播放地址');
    }
    return LiveFavorite(
      platformId: platformId,
      roomId: roomId,
      roomUrl: roomId,
      title: room.title,
      anchorName: uri.host,
      status: LiveFavoriteStatus.live,
    );
  }

  @override
  Future<LiveFavorite> refreshFavorite(LiveFavorite favorite) =>
      resolveFavorite(favorite.roomUrl);
}

class PureLiveDirectLinkSite extends LiveSite {
  @override
  String get id => 'pure_live';

  @override
  String get name => '自定义直播源';

  @override
  LiveDanmaku getDanmaku() => EmptyDanmaku();

  @override
  Future<LiveRoom> getRoomDetail({
    required String platform,
    required String roomId,
  }) async {
    final uri = PureLiveDirectLinkAdapter.uriFromLink(roomId);
    if (uri == null) {
      throw const LiveRoomResolutionException('不是受支持的直播流链接');
    }
    return LiveRoom(
      roomId: roomId,
      title: uri.pathSegments.isEmpty ? uri.host : uri.pathSegments.last,
      nick: uri.host,
      area: '自定义直播源',
      watching: '',
      cover: '',
      avatar: '',
      status: true,
      liveStatus: LiveStatus.live,
      platform: id,
      link: roomId,
      data: roomId,
    );
  }

  @override
  Future<List<LivePlayQuality>> getPlayQualites({
    required LiveRoom detail,
  }) async {
    final link = detail.data?.toString().trim() ?? '';
    if (PureLiveDirectLinkAdapter.uriFromLink(link) == null) return const [];
    return [
      LivePlayQuality(
        quality: '默认',
        id: 'default',
        sort: 1,
        data: <String>[link],
      ),
    ];
  }

  @override
  Future<List<String>> getPlayUrls({
    required LiveRoom detail,
    required LivePlayQuality quality,
  }) async {
    final data = quality.data;
    return data is List
        ? data.map((value) => value.toString().trim()).toList(growable: false)
        : const [];
  }
}

int? _asInt(Object? value) =>
    value is num ? value.toInt() : int.tryParse(value?.toString() ?? '');

class LiveFavoriteAddService {
  LiveFavoriteAddService({
    required Iterable<LivePlatformAdapter> adapters,
    required this.repository,
  }) : _adapters = List.unmodifiable(adapters);

  final List<LivePlatformAdapter> _adapters;
  final LiveFavoriteRepository repository;

  List<LivePlatformAdapter> get adapters => _adapters;

  Future<LiveFavorite> addFromLink(String rawLink) async {
    final favorite = await resolveFromLink(rawLink);
    await repository.add(favorite);
    return favorite;
  }

  Future<LiveFavorite> resolveFromLink(String rawLink) async {
    for (final adapter in _adapters) {
      if (!adapter.canResolve(rawLink)) continue;
      final favorite = await adapter.resolveFavorite(rawLink);
      if (favorite.platformId != adapter.platformId) {
        throw const LiveRoomResolutionException(
          '平台解析器返回了不匹配的房间信息',
        );
      }
      return favorite;
    }
    throw const LiveRoomResolutionException('暂不支持此直播间链接');
  }
}
