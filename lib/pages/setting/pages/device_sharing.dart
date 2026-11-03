import 'dart:io';

import 'package:PiliPlus/common/widgets/miuix_switch.dart';
import 'package:PiliPlus/common/widgets/scaffold/simple_scaffold.dart';
import 'package:PiliPlus/services/private_device_services.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

class DeviceSharingPage extends StatefulWidget {
  const DeviceSharingPage({super.key});

  @override
  State<DeviceSharingPage> createState() => _DeviceSharingPageState();
}

class _DeviceSharingPageState extends State<DeviceSharingPage> {
  final _services = Get.find<PrivateDeviceServices>();
  bool _broadcastBusy = false;
  bool _locationBusy = false;

  Future<void> _setBroadcast(bool enabled) async {
    if (_broadcastBusy) return;
    setState(() => _broadcastBusy = true);
    try {
      await _services.setBroadcastEnabled(enabled);
    } catch (error) {
      SmartDialog.showToast(error.toString().replaceFirst('Bad state: ', ''));
    } finally {
      if (mounted) setState(() => _broadcastBusy = false);
    }
  }

  Future<void> _setLocationSharing(bool enabled) async {
    if (_locationBusy) return;
    if (enabled) {
      final accepted = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('开启位置共享？'),
          content: const Text(
            '开启后，仅在 Hyper-PiliPlus 位于前台且你授予定位权限时，'
            '应用会把此设备的最新经纬度、定位精度、设备别名和更新时间'
            '写入你的 Firebase 项目。每台设备只保留一条最新记录，不保存轨迹。'
            '关闭共享会停止更新并请求删除该记录；如果卸载应用或清除应用数据，'
            '服务器无法收到删除请求，最后一条记录可能需要你在 Firebase 控制台手动删除。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('暂不开启'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('继续'),
            ),
          ],
        ),
      );
      if (accepted != true || !mounted) return;
    }

    setState(() => _locationBusy = true);
    try {
      await _services.setLocationSharingEnabled(enabled);
      if (!enabled) {
        SmartDialog.showToast('位置共享已关闭；云端删除将在网络可用时完成');
      }
    } catch (error) {
      SmartDialog.showToast(error.toString().replaceFirst('Bad state: ', ''));
    } finally {
      if (mounted) setState(() => _locationBusy = false);
    }
  }

  Future<void> _editAlias() async {
    final controller = TextEditingController(text: _services.deviceAlias);
    final alias = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('设备别名'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 48,
          decoration: const InputDecoration(hintText: '例如：客厅手机'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (alias == null || !mounted) return;
    try {
      await _services.setDeviceAlias(alias);
      setState(() {});
      SmartDialog.showToast('已保存；下次位置更新时同步到 Firebase');
    } catch (error) {
      SmartDialog.showToast(error.toString().replaceFirst('Bad state: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAndroid = Platform.isAndroid;
    final theme = Theme.of(context);
    return SimpleScaffold(
      appBar: AppBar(title: const Text('广播与位置共享')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              '个人消息和设备位置由你自己的 Firebase 项目管理。位置共享默认关闭，'
              '每台设备都需要单独开启并授权。',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ),
          Obx(() {
            final error = _services.initializationError.value;
            if (error.isEmpty || !isAndroid) return const SizedBox.shrink();
            return ListTile(
              leading: Icon(
                Icons.cloud_off_outlined,
                color: theme.colorScheme.error,
              ),
              title: Text(
                error,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            );
          }),
          Obx(
            () => ListTile(
              leading: const Icon(Icons.notifications_active_outlined),
              title: const Text('接收个人公告'),
              subtitle: Text(
                isAndroid ? '订阅你的广播消息；系统通知权限需保持允许' : '目前仅支持 Android',
              ),
              trailing: PiliMiuixSwitch(
                value: _services.broadcastEnabled.value,
                enabled:
                    isAndroid && _services.isReady.value && !_broadcastBusy,
                onChanged: isAndroid && _services.isReady.value
                    ? _setBroadcast
                    : null,
              ),
            ),
          ),
          Obx(
            () => ListTile(
              leading: const Icon(Icons.my_location_outlined),
              title: const Text('位置共享'),
              subtitle: Text(
                isAndroid ? '仅在应用前台更新；关闭后删除云端最新位置' : '目前仅支持 Android',
              ),
              trailing: PiliMiuixSwitch(
                value: _services.locationSharingEnabled.value,
                enabled: isAndroid && _services.isReady.value && !_locationBusy,
                onChanged: isAndroid && _services.isReady.value
                    ? _setLocationSharing
                    : null,
              ),
            ),
          ),
          Obx(
            () => _services.locationSharingEnabled.value
                ? ListTile(
                    leading: const Icon(Icons.label_outline),
                    title: const Text('设备别名'),
                    subtitle: Text(_services.deviceAlias),
                    trailing: const Icon(Icons.edit_outlined),
                    onTap: _editAlias,
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
