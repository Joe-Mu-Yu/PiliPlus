import 'dart:async';

import 'package:PiliPlus/models/common/live_favorite.dart';

abstract interface class LiveFavoriteStore {
  Future<List<Map<String, Object?>>> read();
  Future<void> write(List<Map<String, Object?>> favorites);
}

/// Persists app-owned cross-platform room favorites, not account follows.
class LiveFavoriteRepository {
  LiveFavoriteRepository(this._store);

  final LiveFavoriteStore _store;
  Future<void> _mutationTail = Future<void>.value();

  Future<List<LiveFavorite>> all() async =>
      (await _store.read()).map(LiveFavorite.fromJson).toList();

  Future<List<LiveFavorite>> forPlatform(String platformId) async {
    final platform = platformId.trim().toLowerCase();
    return (await all())
        .where((favorite) => favorite.platformId == platform)
        .toList();
  }

  Future<void> add(LiveFavorite favorite) => _serialize(() async {
    final favorites = await all();
    if (favorites.any((item) => item.identityKey == favorite.identityKey)) {
      return;
    }
    await _store.write(
      [...favorites, favorite].map((item) => item.toJson()).toList(),
    );
  });

  Future<void> merge(Iterable<LiveFavorite> incoming) => _serialize(() async {
    final favorites = await all();
    final identities = favorites.map((item) => item.identityKey).toSet();
    for (final favorite in incoming) {
      if (identities.add(favorite.identityKey)) {
        favorites.add(favorite);
      }
    }
    await _store.write(favorites.map((item) => item.toJson()).toList());
  });

  Future<void> update(LiveFavorite favorite) => _serialize(() async {
    final favorites = await all();
    final index = favorites.indexWhere(
      (item) => item.identityKey == favorite.identityKey,
    );
    if (index < 0) return;
    final old = favorites[index];
    favorites[index] = LiveFavorite.fromJson({
      ...favorite.toJson(),
      'tagIds': old.tagIds,
    });
    await _store.write(favorites.map((item) => item.toJson()).toList());
  });

  Future<void> updateTags(String identityKey, Iterable<String> tagIds) =>
      _serialize(() async {
        final favorites = await all();
        final index = favorites.indexWhere(
          (item) => item.identityKey == identityKey,
        );
        if (index < 0) return;
        final current = favorites[index];
        favorites[index] = LiveFavorite.fromJson({
          ...current.toJson(),
          'tagIds': tagIds.toList(growable: false),
        });
        await _store.write(favorites.map((item) => item.toJson()).toList());
      });

  Future<void> remove(String identityKey) => _serialize(() async {
    final favorites = await all();
    final remaining = favorites
        .where((item) => item.identityKey != identityKey)
        .toList();
    if (remaining.length == favorites.length) return;
    await _store.write(remaining.map((item) => item.toJson()).toList());
  });

  Future<void> _serialize(Future<void> Function() operation) async {
    final previous = _mutationTail;
    final next = Completer<void>();
    _mutationTail = next.future;
    await previous;
    try {
      await operation();
    } finally {
      next.complete();
    }
  }
}
