import 'package:flutter_test/flutter_test.dart';
import 'package:PiliPlus/models/common/live_favorite.dart';
import 'package:PiliPlus/services/live_favorite_repository.dart';

void main() {
  group('LiveFavorite', () {
    test('round-trips a cross-platform room without losing tags or status', () {
      final favorite = LiveFavorite(
        platformId: 'twitch',
        roomId: 'example_channel',
        roomUrl: 'https://twitch.tv/example_channel',
        title: 'Live now',
        anchorName: 'Example',
        coverUrl: 'https://cdn.example/cover.jpg',
        status: LiveFavoriteStatus.live,
        tagIds: const ['music'],
      );

      final restored = LiveFavorite.fromJson(favorite.toJson());

      expect(restored.identityKey, 'twitch:example_channel');
      expect(restored.title, 'Live now');
      expect(restored.status, LiveFavoriteStatus.live);
      expect(restored.tagIds, ['music']);
    });

    test(
      'normalizes platform identity but preserves platform-specific room id',
      () {
        final favorite = LiveFavorite(
          platformId: ' Twitch ',
          roomId: 'CaseSensitiveChannel',
          roomUrl: 'https://twitch.tv/CaseSensitiveChannel',
        );

        expect(favorite.identityKey, 'twitch:CaseSensitiveChannel');
      },
    );
  });

  group('LiveFavoriteRepository', () {
    late _MemoryFavoriteStore store;
    late LiveFavoriteRepository repository;

    setUp(() {
      store = _MemoryFavoriteStore();
      repository = LiveFavoriteRepository(store);
    });

    test('adds a room once by platform-scoped identity', () async {
      final first = _favorite('twitch', 'room');
      final duplicate = _favorite(' Twitch ', 'room');

      await repository.add(first);
      await repository.add(duplicate);

      expect((await repository.all()).length, 1);
      expect((await repository.all()).single.title, 'room');
    });

    test('keeps same room id on different platforms distinct', () async {
      await repository.add(_favorite('twitch', '123'));
      await repository.add(_favorite('douyu', '123'));

      expect((await repository.all()).map((item) => item.identityKey).toSet(), {
        'twitch:123',
        'douyu:123',
      });
    });

    test(
      'replaces a legacy identity without dropping other favorites',
      () async {
        await repository.add(_favorite('douyin', 'legacy'));
        await repository.add(_favorite('douyu', 'another'));

        await repository.replace(
          'douyin:legacy',
          LiveFavorite(
            platformId: 'douyin',
            roomId: '77',
            roomUrl: 'https://live.douyin.com/77',
            tagIds: ['preserved'],
          ),
        );

        expect(
          (await repository.all()).map((room) => room.identityKey),
          ['douyin:77', 'douyu:another'],
        );
        expect((await repository.all()).first.tagIds, ['preserved']);
      },
    );

    test(
      'rejects duplicate replacement without deleting the original',
      () async {
        await repository.add(_favorite('douyin', 'legacy'));
        await repository.add(_favorite('douyin', '77'));

        await expectLater(
          repository.replace('douyin:legacy', _favorite('douyin', '77')),
          throwsStateError,
        );

        expect(
          (await repository.all()).map((room) => room.identityKey),
          ['douyin:legacy', 'douyin:77'],
        );
      },
    );

    test('filters rooms by platform and persists removal', () async {
      await repository.add(_favorite('twitch', 'one'));
      await repository.add(_favorite('douyu', 'two'));
      final selected = await repository.forPlatform('douyu');

      expect(selected.map((item) => item.roomId), ['two']);
      await repository.remove(selected.single.identityKey);
      expect((await repository.all()).map((item) => item.platformId), [
        'twitch',
      ]);
      expect(store.writeCount, 3);
    });

    test('updates metadata without dropping user tags', () async {
      final original = LiveFavorite(
        platformId: 'twitch',
        roomId: 'channel',
        roomUrl: 'https://twitch.tv/channel',
        title: 'Old title',
        tagIds: const ['music'],
      );
      await repository.add(original);

      await repository.update(
        LiveFavorite(
          platformId: 'twitch',
          roomId: 'channel',
          roomUrl: 'https://twitch.tv/channel',
          title: 'New title',
          status: LiveFavoriteStatus.live,
        ),
      );

      final updated = (await repository.all()).single;
      expect(updated.title, 'New title');
      expect(updated.status, LiveFavoriteStatus.live);
      expect(updated.tagIds, ['music']);
    });

    test(
      'updates room tags without changing its other favorite fields',
      () async {
        final original = LiveFavorite(
          platformId: 'douyin',
          roomId: '123',
          roomUrl: 'https://live.douyin.com/123',
          title: 'Music stream',
          status: LiveFavoriteStatus.live,
          tagIds: const ['old'],
        );
        await repository.add(original);

        await repository.updateTags(original.identityKey, ['music', 'music']);

        final updated = (await repository.all()).single;
        expect(updated.tagIds, ['music']);
        expect(updated.title, 'Music stream');
        expect(updated.status, LiveFavoriteStatus.live);
      },
    );
  });
}

LiveFavorite _favorite(String platform, String roomId) => LiveFavorite(
  platformId: platform,
  roomId: roomId,
  roomUrl: 'https://example.com/$roomId',
  title: roomId,
);

class _MemoryFavoriteStore implements LiveFavoriteStore {
  List<Map<String, Object?>> values = [];
  int writeCount = 0;

  @override
  Future<List<Map<String, Object?>>> read() async => values;

  @override
  Future<void> write(List<Map<String, Object?>> favorites) async {
    values = favorites;
    writeCount++;
  }
}
