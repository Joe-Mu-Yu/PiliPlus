import 'package:pure_live/common/models/live_room.dart'
    show LiveRoom, LiveStatus;
import 'package:pure_live/core/interface/live_site.dart';
import 'package:pure_live/model/live_play_quality.dart';

class LivePlaybackCatalog {
  const LivePlaybackCatalog({required this.room, required this.qualities});

  final LiveRoom room;
  final List<LivePlayQuality> qualities;
}

class ResolvedLivePlaybackSource {
  const ResolvedLivePlaybackSource({
    required this.room,
    required this.quality,
    required this.url,
    required this.qualities,
    required this.lines,
    required this.qualityIndex,
    required this.lineIndex,
  });

  final LiveRoom room;
  final LivePlayQuality quality;
  final String url;
  final List<LivePlayQuality> qualities;
  final List<String> lines;
  final int qualityIndex;
  final int lineIndex;
}

class PureLivePlaybackSource {
  const PureLivePlaybackSource(this.site);

  static double aspectRatioForDimensions({
    required int width,
    required int height,
    double fallback = 16 / 9,
  }) {
    if (width <= 0 || height <= 0) return fallback;
    return (width / height).clamp(.45, 2.5).toDouble();
  }

  final LiveSite site;

  Future<LivePlaybackCatalog> discover(String roomId) async {
    final room = await site.getRoomDetail(platform: site.id, roomId: roomId);
    if (room.effectiveLiveStatus == LiveStatus.offline) {
      throw StateError('该直播间当前未开播，请确认直播间链接或稍后重试');
    }
    if (room.effectiveLiveStatus == LiveStatus.unknown ||
        room.effectiveLiveStatus == LiveStatus.banned) {
      throw StateError('暂时无法确认该直播间状态，请检查网络后重试');
    }
    final qualities = await site.getPlayQualites(detail: room);
    if (qualities.isEmpty) {
      throw StateError('该直播间当前没有可播放的清晰度');
    }
    return LivePlaybackCatalog(
      room: room,
      qualities: List.unmodifiable(qualities),
    );
  }

  Future<ResolvedLivePlaybackSource> resolve(
    String roomId, {
    int qualityIndex = 0,
    int lineIndex = 0,
  }) async {
    final catalog = await discover(roomId);
    return resolveSelection(
      catalog,
      qualityIndex: qualityIndex,
      lineIndex: lineIndex,
    );
  }

  Future<ResolvedLivePlaybackSource> resolveSelection(
    LivePlaybackCatalog catalog, {
    int qualityIndex = 0,
    int lineIndex = 0,
    ResolvedLivePlaybackSource? currentSource,
  }) async {
    if (qualityIndex < 0 || qualityIndex >= catalog.qualities.length) {
      throw RangeError.index(qualityIndex, catalog.qualities, 'qualityIndex');
    }
    final quality = catalog.qualities[qualityIndex];
    final List<String> lines;
    if (currentSource != null &&
        identical(currentSource.room, catalog.room) &&
        currentSource.qualityIndex == qualityIndex &&
        site is! LivePlayRecoveryResolver) {
      lines = currentSource.lines;
    } else {
      final resolution =
          currentSource != null &&
              identical(currentSource.room, catalog.room) &&
              site is LivePlayRecoveryResolver
          ? await site.resolvePlayUrlsForRecovery(
              detail: catalog.room,
              quality: quality,
            )
          : await site.resolvePlayUrls(
              detail: catalog.room,
              quality: quality,
            );
      lines = normalizeResolvedPlayUrls(resolution.urls);
    }
    if (lines.isEmpty) {
      throw StateError('直播平台未返回可播放的视频流地址');
    }
    if (lineIndex < 0 || lineIndex >= lines.length) {
      throw RangeError.index(lineIndex, lines, 'lineIndex');
    }
    final url = lines[lineIndex];
    final uri = Uri.tryParse(url);
    if (uri == null || !const {'http', 'https'}.contains(uri.scheme)) {
      throw StateError('直播平台未返回有效的视频流地址');
    }
    return ResolvedLivePlaybackSource(
      room: catalog.room,
      quality: quality,
      url: url,
      qualities: catalog.qualities,
      lines: lines,
      qualityIndex: qualityIndex,
      lineIndex: lineIndex,
    );
  }
}
