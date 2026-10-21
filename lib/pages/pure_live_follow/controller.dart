import 'package:PiliPlus/models/common/live_favorite.dart';
import 'package:PiliPlus/services/live_favorite_repository.dart';
import 'package:PiliPlus/services/live_platform_adapter.dart';
import 'package:get/get.dart';

class PureLiveFollowController extends GetxController {
  PureLiveFollowController({
    required LiveFavoriteRepository repository,
    required Iterable<LivePlatformAdapter> adapters,
  }) : _repository = repository,
       _addService = LiveFavoriteAddService(
         adapters: adapters,
         repository: repository,
       );

  final LiveFavoriteRepository _repository;
  final LiveFavoriteAddService _addService;
  final favorites = <LiveFavorite>[].obs;
  final isLoading = false.obs;
  final isAdding = false.obs;
  final errorMessage = RxnString();

  Future<void> load({bool markUnverified = false}) async {
    isLoading.value = true;
    errorMessage.value = null;
    try {
      final loaded = await _repository.all();
      favorites.assignAll(
        markUnverified
            ? loaded
                  .map(
                    (favorite) => LiveFavorite.fromJson({
                      ...favorite.toJson(),
                      'status': LiveFavoriteStatus.unknown.name,
                    }),
                  )
                  .toList(growable: false)
            : loaded,
      );
    } catch (error) {
      errorMessage.value = _messageFor(error);
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> addFromLink(String link) async {
    isAdding.value = true;
    errorMessage.value = null;
    try {
      await _addService.addFromLink(link);
      await load();
      return true;
    } catch (error) {
      errorMessage.value = _messageFor(error);
      return false;
    } finally {
      isAdding.value = false;
    }
  }

  Future<void> refreshFavorites() async {
    isLoading.value = true;
    errorMessage.value = null;
    try {
      final current = await _repository.all();
      final adapters = {
        for (final adapter in _addService.adapters) adapter.platformId: adapter,
      };
      final failures = <String>{};
      await Future.wait(
        current.map((favorite) async {
          final adapter = adapters[favorite.platformId];
          if (adapter == null) {
            await _repository.update(
              LiveFavorite.fromJson({
                ...favorite.toJson(),
                'status': LiveFavoriteStatus.unknown.name,
              }),
            );
            return;
          }
          try {
            await _repository.update(await adapter.refreshFavorite(favorite));
          } catch (_) {
            failures.add(favorite.platformId);
            // A failed status request is not evidence that the room is live.
            // Preserve its metadata but remove it from the live bucket.
            await _repository.update(
              LiveFavorite.fromJson({
                ...favorite.toJson(),
                'status': LiveFavoriteStatus.unknown.name,
              }),
            );
          }
        }),
      );
      favorites.assignAll(await _repository.all());
      if (failures.isNotEmpty) {
        errorMessage.value = '部分平台刷新失败：${failures.join('、')}';
      }
    } catch (error) {
      errorMessage.value = _messageFor(error);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> remove(String identityKey) async {
    errorMessage.value = null;
    try {
      await _repository.remove(identityKey);
      favorites.removeWhere((favorite) => favorite.identityKey == identityKey);
    } catch (error) {
      errorMessage.value = _messageFor(error);
    }
  }

  Future<void> updateTags(String identityKey, Iterable<String> tagIds) async {
    errorMessage.value = null;
    try {
      await _repository.updateTags(identityKey, tagIds);
      final index = favorites.indexWhere(
        (favorite) => favorite.identityKey == identityKey,
      );
      if (index >= 0) {
        final current = favorites[index];
        favorites[index] = LiveFavorite.fromJson({
          ...current.toJson(),
          'tagIds': tagIds.toList(growable: false),
        });
      }
    } catch (error) {
      errorMessage.value = _messageFor(error);
    }
  }

  String _messageFor(Object error) => switch (error) {
    FormatException(:final message) => message,
    _ => error.toString(),
  };
}
