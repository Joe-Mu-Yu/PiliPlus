import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pure_live/common/utils/toast_util.dart';
import 'package:pure_live/plugins/db_service.dart';
import 'package:pure_live/plugins/file_utils.dart';
import 'package:pure_live/plugins/locale_helper.dart';
import 'package:pure_live/core/common/http_client.dart';
import 'package:pure_live/common/global/app_path_manager.dart';
import 'package:pure_live/core/iptv/local/database.dart' as database;
import 'package:pure_live/core/iptv/services/iptv_import_manager.dart';

class IptvSyncEngine {
  static final IptvSyncEngine instance = IptvSyncEngine();
  IptvSyncEngine({
    IptvImportManager? importManager,
    Future<Directory> Function()? temporaryDirectory,
  }) : _iptvImportManager = importManager ?? IptvImportManager(),
       _temporaryDirectory = temporaryDirectory ?? getTemporaryDirectory;

  final IptvImportManager _iptvImportManager;
  final Future<Directory> Function() _temporaryDirectory;

  Future<bool> syncPlaylist(
    database.Provider provider, {
    bool showTips = false,
  }) async {
    Directory? temporary;
    bool success = false;
    try {
      final url = provider.url;
      if (url == null || url.trim().isEmpty) return false;
      final uri = Uri.tryParse(url);
      final network = uri?.scheme == 'http' || uri?.scheme == 'https';
      File file;
      if (network) {
        final content = await HttpClient.instance.getText(url);
        final trimmed = content.trim();
        if (trimmed.isEmpty) return false;
        final ext = provider.type.startsWith('.')
            ? provider.type.toLowerCase()
            : '.${provider.type.toLowerCase()}';
        if (!{'.m3u', '.m3u8', '.txt'}.contains(ext)) return false;
        if (ext != '.txt' && !trimmed.startsWith('#EXTM3U')) return false;
        if (ext == '.txt' && !trimmed.contains(',')) return false;
        final root = await _temporaryDirectory();
        await root.create(recursive: true);
        temporary = await root.createTemp('iptv-sync-');
        file = await File(p.join(temporary.path, 'input$ext'))
            .writeAsString(content);
      } else {
        file = uri?.scheme == 'file' ? File.fromUri(uri!) : File(url);
      }
      // The importer verifies this exact snapshot again; never delete by name
      // or recreate a provider removed/edited while the network request ran.
      success = await _iptvImportManager.importIptvFile(
        file: file,
        providerName: provider.name,
        expectedProvider: provider,
        isHot: provider.id == FileUtils.systemHotProviderId,
        url: network ? url : '',
        forceUpdate: true,
        showTips: false,
      );
      return success;
    } catch (e) {
      debugPrint('IPTV Sync Process Error: $e');
      return false;
    } finally {
      if (temporary != null) {
        try {
          await temporary.delete(recursive: true);
        } catch (e) {
          debugPrint('IPTV sync temporary cleanup failed: $e');
        }
      }
      if (showTips)
        ToastUtil.show(i18n(success ? 'sync_success' : 'sync_failed'));
    }
  }

  /// Deletes exactly the resource shown by the management page.
  ///
  /// Name-based deletion can remove an unrelated subscription when two sources
  /// share a display name. Local imports are copied into the IPTV cache, so only
  /// that owned copy is removed; the user's original file is never touched.
  Future<bool> deletePlaylist(
    database.Provider provider, {
    Directory? cacheDirectory,
  }) async {
    try {
      final db = Get.find<DbService>().db;
      var deleted = false;
      await db.transaction(() async {
        final current = await db.getProviderById(provider.id);
        if (current != provider) return;
        await (db.delete(
          db.epgMappings,
        )..where((table) => table.providerId.equals(provider.id))).go();
        await (db.delete(
          db.channels,
        )..where((table) => table.providerId.equals(provider.id))).go();
        await (db.delete(
          db.providers,
        )..where((table) => table.id.equals(provider.id))).go();
        deleted = true;
      });
      if (!deleted) return false;
      try {
        await _deleteOwnedPlaylistCache(
          provider,
          cacheDirectory: cacheDirectory,
        );
      } catch (error) {
        // Database deletion is authoritative. A stale cache file can be
        // reclaimed later and must not turn a committed deletion into failure.
        debugPrint('Deleted playlist cache cleanup failed: $error');
      }
      return true;
    } catch (error) {
      debugPrint('Delete playlist failed: $error');
      return false;
    }
  }

  Future<void> _deleteOwnedPlaylistCache(
    database.Provider provider, {
    Directory? cacheDirectory,
  }) async {
    final value = provider.url?.trim();
    if (value == null || value.isEmpty) return;
    final uri = Uri.tryParse(value);
    if (uri?.scheme == 'http' || uri?.scheme == 'https') return;
    final path = uri?.scheme == 'file'
        ? File.fromUri(uri!).path
        : uri != null && uri.hasScheme && !p.isAbsolute(value)
        ? null
        : value;
    if (path == null) return;
    final cache =
        cacheDirectory ??
        await AppPathManager().getDir(AppPathManager.dirIptvCache);
    final absolutePath = p.absolute(path);
    if (!p.isWithin(p.absolute(cache.path), absolutePath)) return;
    final fileName = p.basename(absolutePath);
    final owned = RegExp(
      r'^playlist_[0-9a-f-]{36}\.(m3u8?|txt)$',
      caseSensitive: false,
    ).hasMatch(fileName);
    if (!owned) return;
    final type = await FileSystemEntity.type(absolutePath, followLinks: false);
    if (type == FileSystemEntityType.file ||
        type == FileSystemEntityType.link) {
      await File(absolutePath).delete();
    }
  }

  Future<bool> deletePlaylistsByName(String providerName) async {
    try {
      final db = Get.find<DbService>().db;
      final cleanName = providerName.trim().toLowerCase();
      final dir = await AppPathManager().getDir(AppPathManager.dirIptvCache);

      final List<database.Provider> existingProviders = await db
          .getAllProviders();
      final matchedItems = existingProviders
          .where((p) => p.name.trim().toLowerCase() == cleanName)
          .toList();

      if (matchedItems.isNotEmpty) {
        for (final item in matchedItems) {
          await db.deleteProviderAndChannels(item.id);
          await db.deleteMappingsByProviderId(item.id);

          final String dotExt = item.type.startsWith('.')
              ? item.type
              : '.${item.type}';
          final cachedFile = File(p.join(dir.path, '${item.id}$dotExt'));
          if (await cachedFile.exists()) {
            await cachedFile.delete();
          }
        }
      }
      return true;
    } catch (e) {
      debugPrint("Delete playlists by name crashed: $e");
      return false;
    }
  }
}
