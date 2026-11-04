import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:PiliPlus/services/hive_live_favorite_store.dart';

void main() {
  late Directory directory;
  late Box<dynamic> box;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('live_favorites_test_');
    Hive.init(directory.path);
    box = await Hive.openBox<dynamic>('settings');
  });

  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  test('stores favorite snapshots in the selected Hive box and key', () async {
    final store = HiveLiveFavoriteStore(box, key: 'favorites');
    const favorites = <Map<String, Object?>>[
      {
        'platformId': 'douyu',
        'roomId': '123',
        'roomUrl': 'https://www.douyu.com/123',
      },
    ];

    expect(await store.read(), isEmpty);
    await store.write(favorites);

    final restored = await HiveLiveFavoriteStore(box, key: 'favorites').read();
    expect(restored, favorites);
  });

  test(
    'rejects malformed stored snapshots instead of silently dropping data',
    () async {
      await box.put('favorites', 'invalid');

      await expectLater(
        HiveLiveFavoriteStore(box, key: 'favorites').read(),
        throwsFormatException,
      );
    },
  );
}
