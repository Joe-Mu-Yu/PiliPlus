import 'package:flutter_test/flutter_test.dart';
import 'package:PiliPlus/models/common/live_favorite.dart';
import 'package:PiliPlus/pages/pure_live_follow/controller.dart';
import 'package:PiliPlus/services/live_favorite_repository.dart';
import 'package:PiliPlus/services/live_platform_adapter.dart';

void main() {
  late _MemoryStore store;
  late LiveFavoriteRepository repository;
  late PureLiveFollowController controller;

  setUp(() {
    store = _MemoryStore();
    repository = LiveFavoriteRepository(store);
    controller = PureLiveFollowController(
      repository: repository,
      adapters: [_FakeAdapter()],
    );
  });

  test('loads persisted cross-platform rooms', () async {
    await repository.add(_favorite('douyu', '42'));

    await controller.load();

    expect(controller.favorites.single.identityKey, 'douyu:42');
  });

  test('does not expose a cached live flag before room verification', () async {
    await repository.add(
      LiveFavorite(
        platformId: 'test',
        roomId: '123',
        roomUrl: 'https://rooms.example/123',
        status: LiveFavoriteStatus.live,
      ),
    );

    await controller.load(markUnverified: true);

    expect(controller.favorites.single.status, LiveFavoriteStatus.unknown);
    expect((await repository.all()).single.status, LiveFavoriteStatus.live);
  });

  test('adds a validated room link and refreshes the list', () async {
    final added = await controller.addFromLink('https://rooms.example/123');

    expect(added, isTrue);
    expect(controller.favorites.single.identityKey, 'test:123');
    expect(controller.errorMessage.value, isNull);
  });

  test('keeps the collection unchanged when resolution fails', () async {
    final added = await controller.addFromLink('https://unknown.example/123');

    expect(added, isFalse);
    expect(controller.favorites, isEmpty);
    expect(controller.errorMessage.value, isNotEmpty);
  });

  test('removes a room by its platform-scoped identity', () async {
    await repository.add(_favorite('test', '123'));
    await controller.load();

    await controller.remove('test:123');

    expect(controller.favorites, isEmpty);
  });

  test('updates and persists the tags for a saved room', () async {
    await repository.add(_favorite('test', '123'));
    await controller.load();

    await controller.updateTags('test:123', ['music', 'chill']);

    expect(controller.favorites.single.tagIds, ['music', 'chill']);
    expect((await repository.all()).single.tagIds, ['music', 'chill']);
  });

  test(
    'refreshes supported rooms and moves unverifiable stale live rooms out of live',
    () async {
      await repository.add(_favorite('test', '123'));
      await repository.add(
        LiveFavorite(
          platformId: 'failing',
          roomId: '456',
          roomUrl: 'https://rooms.example/456',
          title: 'Last known live',
          status: LiveFavoriteStatus.live,
        ),
      );
      controller = PureLiveFollowController(
        repository: repository,
        adapters: [_RefreshAdapter(), _FailingRefreshAdapter()],
      );

      await controller.refreshFavorites();

      expect(
        controller.favorites
            .firstWhere((item) => item.platformId == 'test')
            .title,
        'Updated',
      );
      expect(
        controller.favorites
            .firstWhere((item) => item.platformId == 'failing')
            .roomId,
        '456',
      );
      expect(
        controller.favorites
            .firstWhere((item) => item.platformId == 'failing')
            .status,
        LiveFavoriteStatus.unknown,
      );
      expect(controller.errorMessage.value, contains('failing'));
    },
  );
}

LiveFavorite _favorite(String platform, String id) => LiveFavorite(
  platformId: platform,
  roomId: id,
  roomUrl: 'https://rooms.example/$id',
);

class _FakeAdapter implements LivePlatformAdapter {
  @override
  String get platformId => 'test';

  @override
  bool canResolve(String rawLink) => rawLink.contains('rooms.example');

  @override
  Future<LiveFavorite> resolveFavorite(String rawLink) async {
    if (!canResolve(rawLink)) {
      throw const LiveRoomResolutionException('unsupported link');
    }
    return _favorite('test', '123');
  }

  @override
  Future<LiveFavorite> refreshFavorite(LiveFavorite favorite) async => favorite;
}

class _RefreshAdapter extends _FakeAdapter {
  @override
  Future<LiveFavorite> refreshFavorite(LiveFavorite favorite) async =>
      LiveFavorite(
        platformId: favorite.platformId,
        roomId: favorite.roomId,
        roomUrl: favorite.roomUrl,
        title: 'Updated',
        status: LiveFavoriteStatus.live,
        tagIds: favorite.tagIds,
      );
}

class _FailingRefreshAdapter implements LivePlatformAdapter {
  @override
  String get platformId => 'failing';

  @override
  bool canResolve(String rawLink) => false;

  @override
  Future<LiveFavorite> resolveFavorite(String rawLink) =>
      throw const LiveRoomResolutionException('unsupported');

  @override
  Future<LiveFavorite> refreshFavorite(LiveFavorite favorite) =>
      throw StateError('network unavailable');
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
