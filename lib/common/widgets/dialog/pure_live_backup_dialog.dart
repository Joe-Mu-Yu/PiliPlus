import 'dart:convert';
import 'dart:typed_data';

import 'package:PiliPlus/common/widgets/dialog/simple_dialog_option.dart';
import 'package:PiliPlus/services/hive_live_favorite_store.dart';
import 'package:PiliPlus/services/live_favorite_repository.dart';
import 'package:PiliPlus/services/pure_live_backup_service.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_utils.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:material_ui/material_ui.dart';

Future<void> showPureLiveBackupDialog(BuildContext pageContext) => showDialog(
  context: pageContext,
  builder: (dialogContext) => SimpleDialog(
    title: const Text('Pure Live 备份迁移'),
    children: [
      DialogOption(
        child: const Text('导出 Hyper-PiliPlus 备份'),
        onPressed: () {
          Navigator.of(dialogContext).pop();
          _exportBackup();
        },
      ),
      DialogOption(
        child: const Text('导入 Pure Live / Hyper-PiliPlus 备份'),
        onPressed: () {
          Navigator.of(dialogContext).pop();
          _importBackup(pageContext);
        },
      ),
    ],
  ),
);

LiveFavoriteRepository _repository() => LiveFavoriteRepository(
  HiveLiveFavoriteStore(GStorage.setting),
);

Future<void> _exportBackup() async {
  try {
    final data = await PureLiveBackupService.exportBackup(_repository());
    await StorageUtils.saveBytes2File(
      name:
          'hyper_piliplus_backup_${DateTime.now().millisecondsSinceEpoch}.json',
      allowedExtensions: const ['json'],
      bytes: Uint8List.fromList(
        utf8.encode(const JsonEncoder.withIndent('  ').convert(data)),
      ),
    );
  } catch (error) {
    SmartDialog.showToast('导出失败：$error');
  }
}

Future<void> _importBackup(BuildContext context) async {
  try {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['txt', 'json'],
    );
    if (file == null) return;
    final decoded = jsonDecode(await file.xFile.readAsString());
    final plan = PureLiveBackupService.inspect(decoded);
    if (!context.mounted) return;
    final shouldImport = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final notes = <String>[
          '可导入收藏：${plan.favorites.length} 个（与现有收藏合并，重复项跳过）',
          if (plan.preferences.isNotEmpty)
            '可导入兼容设置：${plan.preferences.length} 项',
          if (plan.unsupportedFavoriteCount > 0)
            '不支持的平台收藏：${plan.unsupportedFavoriteCount} 个',
          if (plan.invalidFavoriteCount > 0)
            '格式无效的收藏：${plan.invalidFavoriteCount} 个',
          if (plan.historyCount > 0)
            '直播观看历史：${plan.historyCount} 条（当前应用没有对应的直播历史功能，不会导入）',
          if (plan.favorites.isEmpty && plan.preferences.isEmpty) '没有可导入的数据。',
        ];
        return AlertDialog(
          title: const Text('确认导入备份？'),
          content: Text(notes.join('\n\n')),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: plan.hasImportableData
                  ? () => Navigator.of(dialogContext).pop(true)
                  : null,
              child: const Text('导入'),
            ),
          ],
        );
      },
    );
    if (shouldImport != true) return;
    await PureLiveBackupService.apply(plan, _repository());
    SmartDialog.showToast('导入完成：收藏已合并到直播收藏');
  } catch (error) {
    SmartDialog.showToast('导入失败：$error');
  }
}
