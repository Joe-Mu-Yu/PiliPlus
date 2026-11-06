import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart' show Builder, Size, SizedBox, ValueKey;
import 'package:PiliPlus/models/common/live_favorite.dart';
import 'package:PiliPlus/models/common/nav_bar_config.dart';
import 'package:PiliPlus/pages/pure_live_follow/controller.dart';
import 'package:PiliPlus/pages/pure_live_follow/iptv_management_page.dart';
import 'package:PiliPlus/pages/pure_live_follow/iptv_page.dart';
import 'package:PiliPlus/pages/pure_live_follow/link_parser_page.dart';
import 'package:PiliPlus/pages/pure_live_follow/view.dart';
import 'package:PiliPlus/pages/recorder_center/view.dart';
import 'package:PiliPlus/services/live_favorite_repository.dart';
import 'package:PiliPlus/services/live_platform_adapter.dart';
import 'package:PiliPlus/services/pure_live_recording_preferences.dart';
import 'package:drift/native.dart';
import 'package:get/get.dart';
import 'package:hive_ce/hive.dart';
import 'package:material_ui/material_ui.dart' show TextField;
import 'package:pure_live/common/models/live_room.dart'
    show LiveRoom, LiveStatus;
import 'package:pure_live/common/services/settings/iptv_settings_controller.dart';
import 'package:pure_live/core/common/http_header_policy.dart';
import 'package:pure_live/core/iptv/local/database.dart' as database;
import 'package:pure_live/core/iptv/services/epg_import_manager.dart';
import 'package:pure_live/core/iptv/services/iptv_import_manager.dart';
import 'package:pure_live/core/iptv/services/iptv_sync_engine.dart';
import 'package:pure_live/core/interface/live_site.dart';
import 'package:pure_live/host/recording_i18n.dart';
import 'package:pure_live/model/live_play_quality.dart';
import 'package:pure_live/plugins/db_service.dart';

void main() {
  setUpAll(RecordingI18n.initialize);

  testWidgets(
    'repairs a legacy account link only after verifying the new room',
    (tester) async {
      final store = _MemoryStore()
        ..values = [
          LiveFavorite(
            platformId: 'douyin',
            roomId: 'MS4wLjABAAAAlegacy_account',
            roomUrl: 'https://live.douyin.com/MS4wLjABAAAAlegacy_account',
            title: 'Saved anchor',
            tagIds: ['keep'],
          ).toJson(),
        ];
      final repository = LiveFavoriteRepository(store);
      final controller = PureLiveFollowController(
        repository: repository,
        adapters: [
          DouyinLivePlatformAdapter(
            getRoomDetailByWebRid: (roomId) async => LiveRoom(
              roomId: roomId,
              platform: 'douyin',
              title: 'Verified room',
              liveStatus: LiveStatus.live,
            ),
          ),
        ],
      );
      await tester.pumpWidget(
        GetMaterialApp(home: PureLiveFollowPage(controller: controller)),
      );
      await tester.pumpAndSettle();
      await controller.refreshFavorites();
      await tester.pumpAndSettle();
      await tester.tap(find.text('未开播'));
      await tester.pumpAndSettle();

      expect(find.text('链接需要更新'), findsOneWidget);
      expect(find.textContaining('部分平台刷新失败'), findsNothing);
      await tester.tap(find.text('更新链接'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField),
        'https://live.douyin.com/77',
      );
      await tester.tap(find.text('验证并更新'));
      await tester.pumpAndSettle();

      final updated = (await repository.all()).single;
      expect(updated.roomId, '77');
      expect(updated.title, 'Verified room');
      expect(updated.tagIds, ['keep']);
      expect(controller.errorMessage.value, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('直播平台 exposes Pure Live-style room states and add action', (
    tester,
  ) async {
    final controller = PureLiveFollowController(
      repository: LiveFavoriteRepository(_MemoryStore()),
      adapters: const [],
    );
    await tester.pumpWidget(
      GetMaterialApp(home: PureLiveFollowPage(controller: controller)),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('favorite-status-tabs')), findsOneWidget);
    expect(find.text('直播中'), findsOneWidget);
    expect(find.text('录播'), findsOneWidget);
    expect(find.text('未开播'), findsOneWidget);
    expect(find.text('录制'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('recorder-center-action')),
      findsOneWidget,
    );
    expect(find.byTooltip('链接解析'), findsOneWidget);
    expect(find.byTooltip('IPTV 频道'), findsOneWidget);
    expect(find.byTooltip('更多直播功能'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('link parser preserves jump and direct-link actions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    addTearDown(tester.view.resetPhysicalSize);
    PureLiveLinkTarget? openedRoom;
    String? copiedUrl;
    final resolver = PureLiveLinkResolver(
      sites: {'bilibili': _LinkParserFakeSite()},
    );

    await tester.pumpWidget(
      GetMaterialApp(
        home: PureLiveLinkParserPage(
          resolver: resolver,
          autoCheckClipboard: false,
          onOpenRoom: (target) async => openedRoom = target,
          copyText: (url) async => copiedUrl = url,
          notify: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('链接解析'), findsOneWidget);
    expect(find.text('直播间跳转'), findsOneWidget);
    expect(find.text('获取直链'), findsOneWidget);
    expect(find.text('支持解析列表'), findsOneWidget);

    await tester.enterText(
      find.byType(TextField).first,
      'https://live.bilibili.com/42',
    );
    await tester.tap(find.text('链接跳转'));
    await tester.pumpAndSettle();
    expect(openedRoom?.platform, 'bilibili');
    expect(openedRoom?.roomId, '42');

    await tester.enterText(
      find.byType(TextField).last,
      'https://live.bilibili.com/42',
    );
    await tester.tap(find.text('获取解析'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.text('原画'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.text('线路1'));
    await tester.pumpAndSettle();
    expect(copiedUrl, 'https://stream.example/live.m3u8');
    expect(tester.takeException(), isNull);
  });

  test(
    'link parser recognizes only the three supported platform hosts',
    () async {
      final resolver = PureLiveLinkResolver(
        sites: {'bilibili': _LinkParserFakeSite()},
      );

      expect(
        (await resolver.resolve('https://live.bilibili.com/42'))?.roomId,
        '42',
      );
      expect(
        (await resolver.resolve('https://www.huya.com/abc_1'))?.platform,
        'huya',
      );
      expect(
        (await resolver.resolve('https://www.douyu.com/123'))?.platform,
        'douyu',
      );
      expect(
        await resolver.resolve('https://www.huya.com.evil.test/abc'),
        isNull,
      );
      expect(await resolver.resolve('https://www.douyu.com/search'), isNull);
    },
  );

  test('IPTV channel filters cover query, group, type and hidden state', () {
    const channel = database.Channel(
      id: 'channel-1',
      providerId: 'provider-1',
      name: 'CCTV 1',
      tvgName: '央视综合',
      groupTitle: '央视频道',
      streamUrl: 'https://stream.example/live.m3u8',
      streamType: 'live',
      favorite: false,
      hidden: false,
      sortOrder: 0,
      isAutoUpdate: true,
    );
    expect(
      iptvChannelMatches(
        channel,
        query: '央视',
        group: '央视频道',
        streamType: 'live',
      ),
      isTrue,
    );
    expect(iptvChannelMatches(channel, query: '体育'), isFalse);
    expect(iptvChannelMatches(channel, group: '地方频道'), isFalse);
    expect(iptvChannelMatches(channel, streamType: 'vod'), isFalse);
    expect(
      iptvChannelMatches(
        const database.Channel(
          id: 'hidden',
          providerId: 'provider-1',
          name: 'Hidden',
          streamUrl: 'https://stream.example/hidden.m3u8',
          streamType: 'live',
          favorite: false,
          hidden: true,
          sortOrder: 0,
          isAutoUpdate: true,
        ),
      ),
      isFalse,
    );
  });

  test('IPTV subscription URLs stay distinct from channel stream URLs', () {
    expect(
      parseIptvSubscriptionUrl('HTTPS://example.com:8443/list.m3u')?.toString(),
      'https://example.com:8443/list.m3u',
    );
    expect(
      parseIptvSubscriptionUrl('https://example.com/guide.xml.gz'),
      isNotNull,
    );
    expect(parseIptvSubscriptionUrl('udp://@239.0.0.1:1234'), isNull);
    expect(parseIptvSubscriptionUrl('/storage/emulated/0/list.m3u'), isNull);
    expect(parseIptvSubscriptionUrl('https://example.com/a b.m3u'), isNull);
    expect(iptvResourceIsNetwork('http://example.com/list.txt'), isTrue);
    expect(iptvResourceIsNetwork('/data/user/0/cache/list.m3u'), isFalse);
  });

  test('main navigation maps its destinations to the requested pages', () {
    expect(NavigationBarType.follow.label, '直播');
    expect(NavigationBarType.follow.page, isA<PureLiveFollowPage>());
    expect(NavigationBarType.recorderCenter.label, '录制');
    expect(NavigationBarType.recorderCenter.page, isA<RecorderCenterPage>());
  });

  testWidgets('room status tabs show the matching saved rooms', (tester) async {
    final store = _MemoryStore()
      ..values = [
        LiveFavorite(
          platformId: 'douyin',
          roomId: '1',
          roomUrl: 'https://live.douyin.com/1',
          title: 'Live room',
          status: LiveFavoriteStatus.live,
        ).toJson(),
        LiveFavorite(
          platformId: 'douyin',
          roomId: '2',
          roomUrl: 'https://live.douyin.com/2',
          title: 'Replay room',
          status: LiveFavoriteStatus.replay,
        ).toJson(),
      ];
    final repository = LiveFavoriteRepository(store);
    final controller = PureLiveFollowController(
      repository: repository,
      adapters: const [],
    );
    await tester.pumpWidget(
      GetMaterialApp(home: PureLiveFollowPage(controller: controller)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Live room'), findsOneWidget);
    expect(find.text('Replay room'), findsNothing);
    await tester.tap(find.text('录播'));
    await tester.pumpAndSettle();
    expect(find.text('Replay room'), findsOneWidget);
    expect(find.text('Live room'), findsNothing);
    expect((await repository.all()), hasLength(2));
  });

  testWidgets('Douyin room opens in the native in-app player route', (
    tester,
  ) async {
    final controller = PureLiveFollowController(
      repository: LiveFavoriteRepository(
        _MemoryStore()
          ..values = [
            LiveFavorite(
              platformId: 'douyin',
              roomId: '123',
              roomUrl: 'https://live.douyin.com/123',
              title: 'Douyin live',
              status: LiveFavoriteStatus.live,
            ).toJson(),
          ],
      ),
      adapters: const [],
    );
    await tester.pumpWidget(
      GetMaterialApp(
        home: PureLiveFollowPage(controller: controller),
        getPages: [
          GetPage(
            name: '/pure_live/live_play',
            page: () => Builder(
              builder: (context) {
                final favorite = Get.arguments as LiveFavorite;
                return SizedBox(
                  key: ValueKey('${favorite.roomId}|${favorite.roomUrl}'),
                );
              },
            ),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Douyin live'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(
        const ValueKey('123|https://live.douyin.com/123'),
      ),
      findsOneWidget,
    );
  });

  test(
    'IPTV playlist and EPG imports share durable channels and mappings',
    () async {
      Get.reset();
      Get.testMode = true;
      final temporary = await Directory.systemTemp.createTemp(
        'hyper-iptv-test-',
      );
      final hiveDirectory = Directory('${temporary.path}/hive')..createSync();
      Hive.init(hiveDirectory.path);
      final settingsBox = await Hive.openBox<dynamic>('setting');
      PureLiveRecordingPreferences.configure(settingsBox);
      final db = database.AppDatabase.forTesting(NativeDatabase.memory());
      Get.put<DbService>(DbService()..db = db);
      final settings = Get.put(IptvSettingsController());
      final cache = Directory('${temporary.path}/cache')..createSync();
      final playlist = File('${temporary.path}/channels.m3u');
      final epg = File('${temporary.path}/guide.xml');
      final importer = IptvImportManager(
        cacheDirectory: () async => cache,
      );

      try {
        await playlist.writeAsString('''
#EXTM3U
#EXTINF:-1 tvg-id="cctv1" group-title="央视频道",CCTV 1
#EXTVLCOPT:http-user-agent=IptvTest/1.0
udp://@239.0.0.1:1234
''');
        expect(
          await importer.importIptvFile(
            file: playlist,
            providerName: '测试源',
            showTips: false,
          ),
          isTrue,
        );

        final provider = (await db.getAllProviders()).single;
        final firstChannel = (await db.getChannelsForProvider(provider.id))
            .single;
        expect(firstChannel.streamUrl, 'udp://@239.0.0.1:1234');
        expect(
          HttpHeaderPolicy.decode(firstChannel.httpHeadersJson),
          {'user-agent': 'IptvTest/1.0'},
        );
        expect(provider.url, isNot(playlist.path));
        expect(await File(provider.url!).exists(), isTrue);

        await epg.writeAsString('''
<?xml version="1.0" encoding="UTF-8"?>
<tv>
  <channel id="cctv1"><display-name>CCTV 1</display-name></channel>
</tv>
''');
        expect(
          await EpgImportManager(
            cacheDirectory: () async => cache,
          ).importEpgFile(
            file: epg,
            sourceName: '测试节目单',
            showTips: false,
          ),
          isTrue,
        );
        final source = (await db.getAllEpgSources()).single;
        settings.selectedSourceId.value = source.id;
        settings.selectedSourceName.value = source.name;
        await importer.runAutoEpgMapping(providerId: provider.id);
        final mapping = await db.getMappingByChannelId(
          firstChannel.id,
          providerId: provider.id,
        );
        expect(mapping?.epgSourceId, source.id);

        await db.toggleFavorite(firstChannel.id);
        await playlist.writeAsString('''
#EXTM3U
#EXTINF:-1 tvg-id="cctv1" group-title="央视频道",CCTV 综合
udp://@239.0.0.2:1234
''');
        expect(
          await importer.importIptvFile(
            file: playlist,
            providerName: provider.name,
            expectedProvider: provider,
            forceUpdate: true,
            showTips: false,
          ),
          isTrue,
        );
        final refreshedProvider = (await db.getAllProviders()).single;
        final refreshedChannel = (await db.getChannelsForProvider(provider.id))
            .single;
        expect(refreshedChannel.id, firstChannel.id);
        expect(refreshedChannel.favorite, isTrue);
        expect(refreshedChannel.streamUrl, 'udp://@239.0.0.2:1234');
        expect(await File(provider.url!).exists(), isFalse);
        expect(await File(refreshedProvider.url!).exists(), isTrue);

        expect(
          await IptvSyncEngine.instance.deletePlaylist(
            refreshedProvider,
            cacheDirectory: cache,
          ),
          isTrue,
        );
        expect(await db.getAllProviders(), isEmpty);
        expect(await db.getChannelsForProvider(provider.id), isEmpty);
        expect(await File(refreshedProvider.url!).exists(), isFalse);
      } finally {
        Get.reset();
        await db.close();
        await Hive.close();
        await temporary.delete(recursive: true);
      }
    },
  );
}

class _MemoryStore implements LiveFavoriteStore {
  List<Map<String, Object?>> values = [];

  @override
  Future<List<Map<String, Object?>>> read() async => values;

  @override
  Future<void> write(List<Map<String, Object?>> favorites) async {
    values = favorites;
  }
}

class _LinkParserFakeSite extends LiveSite {
  _LinkParserFakeSite() {
    id = 'bilibili';
  }

  @override
  Future<LiveRoom> getRoomDetail({
    required String platform,
    required String roomId,
  }) async => LiveRoom(
    platform: platform,
    roomId: roomId,
    liveStatus: LiveStatus.live,
  );

  @override
  Future<List<LivePlayQuality>> getPlayQualites({
    required LiveRoom detail,
  }) async => [LivePlayQuality(quality: '原画')];

  @override
  Future<List<String>> getPlayUrls({
    required LiveRoom detail,
    required LivePlayQuality quality,
  }) async => const ['https://stream.example/live.m3u8'];
}
