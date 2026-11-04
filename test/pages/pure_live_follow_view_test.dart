import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart' show Builder, SizedBox, ValueKey;
import 'package:PiliPlus/models/common/live_favorite.dart';
import 'package:PiliPlus/models/common/nav_bar_config.dart';
import 'package:PiliPlus/pages/pure_live_follow/controller.dart';
import 'package:PiliPlus/pages/pure_live_follow/view.dart';
import 'package:PiliPlus/pages/recorder_center/view.dart';
import 'package:PiliPlus/services/live_favorite_repository.dart';
import 'package:PiliPlus/services/live_platform_adapter.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart' show TextField;
import 'package:pure_live/common/models/live_room.dart'
    show LiveRoom, LiveStatus;

void main() {
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
    expect(find.byTooltip('添加直播间'), findsOneWidget);
    expect(tester.takeException(), isNull);
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
