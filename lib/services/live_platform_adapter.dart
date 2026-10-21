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

/// Adapts Pure Live's strict Douyin room resolver for saved rooms and recording.
class DouyinLivePlatformAdapter implements LivePlatformAdapter {
  DouyinLivePlatformAdapter({
    DouyinRecordingRoomLookup? getRoomDetailForRecording,
  }) : _getRoomDetailForRecording =
           getRoomDetailForRecording ?? _fetchRecordingRoom;

  final DouyinRecordingRoomLookup _getRoomDetailForRecording;

  @override
  String get platformId => 'douyin';

  static String? roomIdFromUrl(String rawLink) {
    final uri = Uri.tryParse(rawLink.trim());
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.toLowerCase() != 'live.douyin.com' ||
        uri.userInfo.isNotEmpty ||
        (uri.hasPort && uri.port != 443) ||
        uri.hasFragment) {
      return null;
    }
    return RegExp(r'^/([1-9][0-9]{0,19})/?$').firstMatch(uri.path)?.group(1);
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
    final room = await _getRoomDetailForRecording(
      platform: platformId,
      roomId: roomId,
    );
    final resolvedId = room.roomId?.trim() ?? '';
    if (room.platform?.trim().toLowerCase() != platformId ||
        !RegExp(r'^[1-9][0-9]{0,19}$').hasMatch(resolvedId)) {
      throw const LiveRoomResolutionException('无法验证该抖音直播间');
    }
    if (room.effectiveLiveStatus == LiveStatus.unknown ||
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
  Future<LiveFavorite> refreshFavorite(LiveFavorite favorite) =>
      resolveFavorite(favorite.roomUrl);

  static Future<LiveRoom> _fetchRecordingRoom({
    required String platform,
    required String roomId,
  }) => DouyinSite().getRoomDetailForRecording(
    platform: platform,
    roomId: roomId,
  );
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
