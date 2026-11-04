import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/core/interface/live_site.dart';
import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/model/live_play_quality.dart';
import 'package:PiliPlus/services/pure_live_playback_source.dart';

void main() {
  test('resolves a room to its first native playback URL', () async {
    final site = _FakeLiveSite();

    final source = await PureLivePlaybackSource(site).resolve('room-123');

    expect(source.room.roomId, 'room-123');
    expect(source.quality.quality, '原画');
    expect(source.url, 'https://stream.example/live.m3u8');
  });

  test('fails clearly when the room has no playable stream', () async {
    final site = _FakeLiveSite(qualities: const []);

    await expectLater(
      PureLivePlaybackSource(site).resolve('room-123'),
      throwsA(isA<StateError>()),
    );
  });

  test(
    'exposes quality and CDN line choices for in-player switching',
    () async {
      final site = _FakeLiveSite(
        qualities: [
          LivePlayQuality(quality: '蓝光'),
          LivePlayQuality(quality: '高清'),
        ],
        urls: const [
          'https://stream.example/line-1.m3u8',
          'https://stream.example/line-2.m3u8',
        ],
      );
      final resolver = PureLivePlaybackSource(site);
      final catalog = await resolver.discover('room-123');

      final selected = await resolver.resolveSelection(
        catalog,
        qualityIndex: 1,
        lineIndex: 1,
      );

      expect(selected.qualities.map((item) => item.quality), ['蓝光', '高清']);
      expect(selected.quality.quality, '高清');
      expect(selected.lines, site.urls);
      expect(selected.lineIndex, 1);
      expect(selected.url, site.urls[1]);
    },
  );

  test('reports offline rooms before attempting stream resolution', () async {
    final site = _FakeLiveSite(roomStatus: LiveStatus.offline);

    await expectLater(
      PureLivePlaybackSource(site).resolve('room-123'),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('当前未开播'),
        ),
      ),
    );
    expect(site.qualityRequests, 0);
  });

  test('does not request playback when room status is unknown', () async {
    final site = _FakeLiveSite(roomStatus: LiveStatus.unknown);

    await expectLater(
      PureLivePlaybackSource(site).resolve('room-123'),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('无法确认'),
        ),
      ),
    );
    expect(site.qualityRequests, 0);
  });

  test('uses portrait decoder metadata instead of a fixed landscape ratio', () {
    expect(
      PureLivePlaybackSource.aspectRatioForDimensions(width: 720, height: 1280),
      closeTo(9 / 16, .001),
    );
    expect(
      PureLivePlaybackSource.aspectRatioForDimensions(
        width: 1920,
        height: 1080,
      ),
      closeTo(16 / 9, .001),
    );
    expect(
      PureLivePlaybackSource.aspectRatioForDimensions(width: 0, height: 0),
      closeTo(16 / 9, .001),
    );
  });
}

class _FakeLiveSite extends LiveSite {
  _FakeLiveSite({
    List<LivePlayQuality>? qualities,
    this.roomStatus = LiveStatus.live,
    List<String>? urls,
  }) : qualities = qualities ?? [LivePlayQuality(quality: '原画')],
       urls = urls ?? const ['https://stream.example/live.m3u8'] {
    id = 'douyin';
  }

  final List<LivePlayQuality> qualities;
  final LiveStatus roomStatus;
  final List<String> urls;
  int qualityRequests = 0;

  @override
  Future<LiveRoom> getRoomDetail({
    required String platform,
    required String roomId,
  }) async => LiveRoom()
    ..platform = platform
    ..roomId = roomId
    ..liveStatus = roomStatus;

  @override
  Future<List<LivePlayQuality>> getPlayQualites({
    required LiveRoom detail,
  }) async {
    qualityRequests++;
    return qualities;
  }

  @override
  Future<List<String>> getPlayUrls({
    required LiveRoom detail,
    required LivePlayQuality quality,
  }) async => urls;
}
