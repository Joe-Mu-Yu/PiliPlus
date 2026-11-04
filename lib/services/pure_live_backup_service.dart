import 'package:PiliPlus/models/common/live_favorite.dart';
import 'package:PiliPlus/services/live_favorite_repository.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';

class PureLiveBackupPlan {
  const PureLiveBackupPlan({
    required this.favorites,
    required this.unsupportedFavoriteCount,
    required this.invalidFavoriteCount,
    required this.historyCount,
    required this.preferences,
  });

  final List<LiveFavorite> favorites;
  final int unsupportedFavoriteCount;
  final int invalidFavoriteCount;
  final int historyCount;
  final Map<String, Object?> preferences;

  bool get hasImportableData => favorites.isNotEmpty || preferences.isNotEmpty;
}

/// Reads Pure Live v3 backups and this app's own deliberately limited backup.
/// It never imports account/session, WebDAV, proxy, location or consent data.
abstract final class PureLiveBackupService {
  static const int exportVersion = 1;
  static const String exportFormat = 'hyperPiliPlusBackupVersion';

  static const Map<String, String> _platformHosts = {
    'bilibili': 'live.bilibili.com',
    'douyu': 'www.douyu.com',
    'douyin': 'live.douyin.com',
  };

  static PureLiveBackupPlan inspect(Object? decoded) {
    if (decoded is! Map || decoded.keys.any((key) => key is! String)) {
      throw const FormatException('备份文件根节点必须是 JSON 对象');
    }
    final data = Map<String, dynamic>.from(decoded);
    if (data[exportFormat] == exportVersion) {
      return _inspectHyperBackup(data);
    }
    if (data['backupVersion'] == 3) {
      return _inspectPureLiveBackup(data);
    }
    throw const FormatException('不支持此备份格式或版本');
  }

  static PureLiveBackupPlan _inspectPureLiveBackup(
    Map<String, dynamic> data,
  ) {
    final favoriteSection = data['favorite'];
    final historySection = data['history'];
    if (favoriteSection != null && favoriteSection is! Map) {
      throw const FormatException('favorite 区段格式错误');
    }
    if (historySection != null && historySection is! Map) {
      throw const FormatException('history 区段格式错误');
    }
    final rawFavorites = favoriteSection is Map
        ? favoriteSection['favoriteRooms']
        : null;
    if (rawFavorites != null && rawFavorites is! List) {
      throw const FormatException('favoriteRooms 必须是数组');
    }

    final favorites = <LiveFavorite>[];
    var unsupported = 0;
    var invalid = 0;
    for (final raw in rawFavorites as List? ?? const []) {
      if (raw is! Map || raw.keys.any((key) => key is! String)) {
        invalid++;
        continue;
      }
      final item = Map<String, dynamic>.from(raw);
      final platform = item['platform']?.toString().trim().toLowerCase();
      final host = _platformHosts[platform];
      if (host == null) {
        unsupported++;
        continue;
      }
      final roomId = item['roomId']?.toString().trim() ?? '';
      if (!RegExp(r'^[A-Za-z0-9_-]{1,64}$').hasMatch(roomId)) {
        invalid++;
        continue;
      }
      final liveStatus = item['liveStatus'];
      final status = switch (liveStatus) {
        1 => LiveFavoriteStatus.live,
        2 => LiveFavoriteStatus.replay,
        0 => LiveFavoriteStatus.offline,
        _ => LiveFavoriteStatus.unknown,
      };
      try {
        favorites.add(
          LiveFavorite(
            platformId: platform!,
            roomId: roomId,
            roomUrl: 'https://$host/$roomId',
            title: _stringOrNull(item['title']),
            anchorName: _stringOrNull(item['nick']),
            coverUrl: _httpUrlOrNull(item['cover'] ?? item['avatar']),
            status: status,
            tagIds: (item['tagIds'] is List ? item['tagIds'] as List : const [])
                .whereType<String>(),
          ),
        );
      } on Object {
        invalid++;
      }
    }

    final preferences = <String, Object?>{};
    final app = data['app'];
    if (app != null && app is! Map) {
      throw const FormatException('app 区段格式错误');
    }
    if (app is Map && app['enableBackgroundPlay'] is bool) {
      preferences[SettingBoxKey.enableBackgroundPlay] =
          app['enableBackgroundPlay'];
    }
    final danmaku = data['danmaku'];
    if (danmaku != null && danmaku is! Map) {
      throw const FormatException('danmaku 区段格式错误');
    }
    final opacity = danmaku is Map ? danmaku['danmakuOpacity'] : null;
    if (opacity is num && opacity >= 0 && opacity <= 1) {
      preferences[SettingBoxKey.danmakuOpacity] = opacity.toDouble();
    }

    final rawHistory = historySection is Map
        ? historySection['historyRooms']
        : null;
    if (rawHistory != null && rawHistory is! List) {
      throw const FormatException('historyRooms 必须是数组');
    }
    return PureLiveBackupPlan(
      favorites: List.unmodifiable(favorites),
      unsupportedFavoriteCount: unsupported,
      invalidFavoriteCount: invalid,
      historyCount: (rawHistory as List?)?.length ?? 0,
      preferences: Map.unmodifiable(preferences),
    );
  }

  static PureLiveBackupPlan _inspectHyperBackup(Map<String, dynamic> data) {
    final rawFavorites = data['favorites'];
    final rawPreferences = data['preferences'];
    if (rawFavorites is! List || rawPreferences is! Map) {
      throw const FormatException('Hyper-PiliPlus 备份结构不完整');
    }
    final favorites = <LiveFavorite>[];
    for (final raw in rawFavorites) {
      if (raw is! Map || raw.keys.any((key) => key is! String)) {
        throw const FormatException('收藏房间记录格式错误');
      }
      favorites.add(LiveFavorite.fromJson(Map<String, Object?>.from(raw)));
    }
    final preferences = <String, Object?>{};
    final backgroundPlay = rawPreferences[SettingBoxKey.enableBackgroundPlay];
    final opacity = rawPreferences[SettingBoxKey.danmakuOpacity];
    if (backgroundPlay != null) {
      if (backgroundPlay is! bool) {
        throw const FormatException('后台播放设置格式错误');
      }
      preferences[SettingBoxKey.enableBackgroundPlay] = backgroundPlay;
    }
    if (opacity != null) {
      if (opacity is! num || opacity < 0 || opacity > 1) {
        throw const FormatException('弹幕透明度设置格式错误');
      }
      preferences[SettingBoxKey.danmakuOpacity] = opacity.toDouble();
    }
    return PureLiveBackupPlan(
      favorites: List.unmodifiable(favorites),
      unsupportedFavoriteCount: 0,
      invalidFavoriteCount: 0,
      historyCount: 0,
      preferences: Map.unmodifiable(preferences),
    );
  }

  static Future<Map<String, Object?>> exportBackup(
    LiveFavoriteRepository favorites,
  ) async => {
    exportFormat: exportVersion,
    'sensitiveDataIncluded': false,
    'preferences': {
      SettingBoxKey.enableBackgroundPlay: GStorage.setting.get(
        SettingBoxKey.enableBackgroundPlay,
      ),
      SettingBoxKey.danmakuOpacity: GStorage.setting.get(
        SettingBoxKey.danmakuOpacity,
      ),
    }..removeWhere((_, value) => value == null),
    'favorites': (await favorites.all()).map((item) => item.toJson()).toList(),
  };

  static Future<void> apply(
    PureLiveBackupPlan plan,
    LiveFavoriteRepository favorites,
  ) async {
    if (!plan.hasImportableData) {
      throw const FormatException('文件中没有可导入的兼容数据');
    }
    await favorites.merge(plan.favorites);
    final backgroundPlay = plan.preferences[SettingBoxKey.enableBackgroundPlay];
    if (backgroundPlay is bool) {
      await GStorage.setting.put(
        SettingBoxKey.enableBackgroundPlay,
        backgroundPlay,
      );
    }
    final opacity = plan.preferences[SettingBoxKey.danmakuOpacity];
    if (opacity is double) {
      await GStorage.setting.put(SettingBoxKey.danmakuOpacity, opacity);
    }
  }

  static String? _stringOrNull(Object? value) {
    if (value is! String) return null;
    final result = value.trim();
    return result.isEmpty ? null : result;
  }

  static String? _httpUrlOrNull(Object? value) {
    final text = _stringOrNull(value);
    final uri = text == null ? null : Uri.tryParse(text);
    if (uri == null ||
        !{'http', 'https'}.contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      return null;
    }
    return uri.toString();
  }
}
