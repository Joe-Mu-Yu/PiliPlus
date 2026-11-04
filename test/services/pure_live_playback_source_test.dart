import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/core/interface/live_site.dart';
import 'package:pure_live/core/site/douyin/douyin_site.dart';
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

  test(
    'preserves every distinct native Douyin line and its signed query',
    () async {
      final room = LiveRoom()
        ..platform = 'douyin'
        ..roomId = 'room-123';
      final catalog = LivePlaybackCatalog(
        room: room,
        qualities: [
          LivePlayQuality(
            quality: '原画',
            data: [
              ' https://stream.example/live.flv?sign=one ',
              'https://stream.example/live.m3u8?sign=two',
              'https://backup.example/live.flv?sign=three',
              'https://stream.example/live.flv?sign=one',
              '',
            ],
          ),
        ],
      );

      final source = await PureLivePlaybackSource(DouyinSite())
          .resolveSelection(
            catalog,
            lineIndex: 2,
          );

      expect(source.lines, [
        'https://stream.example/live.flv?sign=one',
        'https://stream.example/live.m3u8?sign=two',
        'https://backup.example/live.flv?sign=three',
      ]);
      expect(source.url, 'https://backup.example/live.flv?sign=three');
    },
  );

  test('does not invent backup lines for a single native URL', () async {
    final source = await PureLivePlaybackSource(_FakeLiveSite()).resolve(
      'room-123',
    );

    expect(source.lines, ['https://stream.example/live.m3u8']);
  });

  test(
    'switches to the displayed line even if the next response reorders CDNs',
    () async {
      final site = _FakeLiveSite(
        urls: [
          'https://stream.example/line-1.m3u8?sign=original',
          'https://backup.example/line-2.m3u8?sign=original',
        ],
      );
      final resolver = PureLivePlaybackSource(site);
      final catalog = await resolver.discover('room-123');
      final displayed = await resolver.resolveSelection(catalog);
      site.urls
        ..clear()
        ..addAll([
          'https://backup.example/line-2.m3u8?sign=new',
          'https://stream.example/line-1.m3u8?sign=new',
        ]);

      final selected = await resolver.resolveSelection(
        catalog,
        lineIndex: 1,
        currentSource: displayed,
      );

      expect(selected.url, 'https://backup.example/line-2.m3u8?sign=original');
      expect(selected.lineIndex, 1);
      expect(selected.lines, [
        'https://stream.example/line-1.m3u8?sign=original',
        'https://backup.example/line-2.m3u8?sign=original',
      ]);
      expect(site.urlRequests, 1);
    },
  );

  test('resolves fresh lines when changing quality', () async {
    final site = _FakeLiveSite(
      qualities: [
        LivePlayQuality(quality: '原画'),
        LivePlayQuality(quality: '高清'),
      ],
      urls: ['https://stream.example/original.m3u8'],
    );
    final resolver = PureLivePlaybackSource(site);
    final catalog = await resolver.discover('room-123');
    final displayed = await resolver.resolveSelection(catalog);
    site.urls[0] = 'https://stream.example/hd.m3u8';

    final selected = await resolver.resolveSelection(
      catalog,
      qualityIndex: 1,
      currentSource: displayed,
    );

    expect(selected.quality.quality, '高清');
    expect(selected.url, 'https://stream.example/hd.m3u8');
    expect(site.urlRequests, 2);
  });

  test('does not reuse lines from a different room catalog', () async {
    final site = _FakeLiveSite(
      urls: ['https://stream.example/room-123.m3u8'],
    );
    final resolver = PureLivePlaybackSource(site);
    final displayed = await resolver.resolve('room-123');
    site.urls[0] = 'https://stream.example/room-456.m3u8';
    final catalog = await resolver.discover('room-456');

    final selected = await resolver.resolveSelection(
      catalog,
      currentSource: displayed,
    );

    expect(selected.room.roomId, 'room-456');
    expect(selected.url, 'https://stream.example/room-456.m3u8');
  });

  test('keeps re-resolving lines for signed recovery platforms', () async {
    final site = _RecoveringFakeLiveSite();
    final resolver = PureLivePlaybackSource(site);
    final catalog = await resolver.discover('room-123');
    final displayed = await resolver.resolveSelection(catalog);
    expect(displayed.url, 'https://stream.example/live.m3u8?sign=old');
    expect(site.recoveryRequests, 0);

    final selected = await resolver.resolveSelection(
      catalog,
      currentSource: displayed,
    );

    expect(selected.url, 'https://backup.example/live.m3u8?sign=fresh');
    expect(site.urlRequests, 1);
    expect(site.recoveryRequests, 1);
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
  int urlRequests = 0;

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
  }) async {
    urlRequests++;
    return urls;
  }
}

class _RecoveringFakeLiveSite extends _FakeLiveSite
    implements LivePlayRecoveryResolver {
  _RecoveringFakeLiveSite()
    : super(urls: ['https://stream.example/live.m3u8?sign=old']);

  int recoveryRequests = 0;

  @override
  Future<LivePlayUrlResolution> resolvePlayUrlsForRecoveryRaw({
    required LiveRoom detail,
    required LivePlayQuality quality,
  }) async {
    recoveryRequests++;
    return LivePlayUrlResolution(
      urls: ['https://backup.example/live.m3u8?sign=fresh'],
    );
  }
}
