import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:PiliPlus/models/common/live_favorite.dart';
import 'package:PiliPlus/services/live_favorite_repository.dart';
import 'package:PiliPlus/services/pure_live_backup_service.dart';

class _MemoryFavoriteStore implements LiveFavoriteStore {
  List<Map<String, Object?>> values = [];

  @override
  Future<List<Map<String, Object?>>> read() async => values;

  @override
  Future<void> write(List<Map<String, Object?>> favorites) async {
    values = favorites;
  }
}

void main() {
  group('PureLiveBackupService', () {
    test(
      'converts supported Pure Live v3 favorites and compatible settings',
      () {
        final plan = PureLiveBackupService.inspect({
          'backupVersion': 3,
          'app': {'enableBackgroundPlay': true},
          'danmaku': {'danmakuOpacity': 0.65},
          'favorite': {
            'favoriteRooms': [
              {
                'platform': 'douyin',
                'roomId': '12345',
                'title': 'Room',
                'nick': 'Host',
                'cover': 'https://example.com/cover.jpg',
                'liveStatus': 1,
                'tagIds': ['tag-a'],
              },
              {'platform': 'unknown', 'roomId': '1'},
              {'platform': 'douyin', 'roomId': '../bad'},
            ],
          },
          'history': {
            'historyRooms': [
              {'roomId': 'room-a'},
            ],
          },
        });

        expect(plan.favorites, hasLength(1));
        expect(plan.favorites.single.platformId, 'douyin');
        expect(plan.favorites.single.roomUrl, 'https://live.douyin.com/12345');
        expect(plan.favorites.single.status, LiveFavoriteStatus.live);
        expect(plan.favorites.single.tagIds, ['tag-a']);
        expect(plan.unsupportedFavoriteCount, 1);
        expect(plan.invalidFavoriteCount, 1);
        expect(plan.historyCount, 1);
        expect(plan.preferences, {
          'enableBackgroundPlay': true,
          'danmakuOpacity': 0.65,
        });
      },
    );

    test(
      'merges imported favorites without replacing existing rooms',
      () async {
        final store = _MemoryFavoriteStore()
          ..values = [
            {
              'platformId': 'douyin',
              'roomId': 'existing',
              'roomUrl': 'https://live.douyin.com/existing',
              'tagIds': ['keep'],
            },
          ];
        final repository = LiveFavoriteRepository(store);
        final plan = PureLiveBackupService.inspect({
          'hyperPiliPlusBackupVersion': 1,
          'favorites': [
            {
              'platformId': 'douyin',
              'roomId': 'existing',
              'roomUrl': 'https://live.douyin.com/existing',
              'tagIds': ['replace'],
            },
            {
              'platformId': 'douyin',
              'roomId': 'new',
              'roomUrl': 'https://live.douyin.com/new',
            },
          ],
          'preferences': {},
        });

        await repository.merge(plan.favorites);

        expect(store.values, hasLength(2));
        expect(store.values.first['tagIds'], ['keep']);
        expect(store.values.last['roomId'], 'new');
      },
    );

    test('reads the Hyper-PiliPlus export schema', () {
      final plan = PureLiveBackupService.inspect({
        'hyperPiliPlusBackupVersion': 1,
        'sensitiveDataIncluded': false,
        'preferences': {'enableBackgroundPlay': false},
        'favorites': [
          {
            'platformId': 'douyu',
            'roomId': '123',
            'roomUrl': 'https://www.douyu.com/123',
            'status': 'offline',
          },
        ],
      });
      expect(plan.favorites.single.platformId, 'douyu');
      expect(plan.preferences, {'enableBackgroundPlay': false});
    });

    test('rejects malformed supported preference values before apply', () {
      expect(
        () => PureLiveBackupService.inspect({
          'hyperPiliPlusBackupVersion': 1,
          'preferences': {'danmakuOpacity': 2},
          'favorites': [],
        }),
        throwsFormatException,
      );
      expect(
        () => PureLiveBackupService.inspect({'backupVersion': 99}),
        throwsFormatException,
      );
    });

    test('inspects the user supplied backup when requested by environment', () {
      final path = Platform.environment['PURE_LIVE_BACKUP_TEST_FILE'];
      if (path == null || !File(path).existsSync()) {
        return;
      }
      final decoded = jsonDecode(File(path).readAsStringSync());
      final plan = PureLiveBackupService.inspect(decoded);
      expect(plan.favorites, hasLength(35));
      expect(plan.historyCount, 50);
      expect(plan.unsupportedFavoriteCount, 0);
      expect(plan.invalidFavoriteCount, 0);
      expect(plan.preferences, hasLength(2));
    });
  });
}
