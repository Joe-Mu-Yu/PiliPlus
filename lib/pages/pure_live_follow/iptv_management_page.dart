import 'dart:async';

import 'package:PiliPlus/common/widgets/native_navigation_occlusion.dart';
import 'package:PiliPlus/services/service_locator.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pure_live/common/services/settings/iptv_settings_controller.dart';
import 'package:pure_live/core/iptv/local/database.dart' as database;
import 'package:pure_live/core/iptv/services/epg_import_manager.dart';
import 'package:pure_live/core/iptv/services/epg_sync_engine.dart';
import 'package:pure_live/core/iptv/services/iptv_import_manager.dart';
import 'package:pure_live/core/iptv/services/iptv_sync_engine.dart';
import 'package:pure_live/plugins/db_service.dart';

@visibleForTesting
Uri? parseIptvSubscriptionUrl(String value) {
  final input = value.trim();
  if (input.isEmpty || RegExp(r'\s').hasMatch(input)) return null;
  final uri = Uri.tryParse(input);
  if (uri == null || uri.host.isEmpty) return null;
  final scheme = uri.scheme.toLowerCase();
  if (scheme != 'http' && scheme != 'https') return null;
  try {
    if (uri.hasPort && (uri.port < 1 || uri.port > 65535)) return null;
  } on FormatException {
    return null;
  }
  return uri.scheme == scheme ? uri : uri.replace(scheme: scheme);
}

@visibleForTesting
bool iptvResourceIsNetwork(String? value) =>
    value != null && parseIptvSubscriptionUrl(value) != null;

class PureLiveIptvManagementPage extends StatefulWidget {
  const PureLiveIptvManagementPage({super.key});

  @override
  State<PureLiveIptvManagementPage> createState() =>
      _PureLiveIptvManagementPageState();
}

class _PureLiveIptvManagementPageState
    extends State<PureLiveIptvManagementPage> {
  late Future<void> _initialization;
  List<database.Provider> _providers = const [];
  List<database.EpgSource> _epgSources = const [];
  final Set<String> _busyResources = {};
  bool _loading = false;
  bool _syncingAll = false;
  String? _loadError;
  int _loadEpoch = 0;

  database.AppDatabase get _database => Get.find<DbService>().db;

  IptvSettingsController get _settings => IptvSettingsController.to;

  @override
  void initState() {
    super.initState();
    _initialization = _initialize();
  }

  @override
  void dispose() {
    _loadEpoch++;
    super.dispose();
  }

  Future<void> _initialize() async {
    await setupPureLiveIptvServices();
    await _refresh();
  }

  Future<void> _refresh() async {
    final epoch = ++_loadEpoch;
    if (mounted) {
      setState(() {
        _loading = true;
        _loadError = null;
      });
    }
    try {
      final providers = await _database.getAllProviders();
      if (!mounted || epoch != _loadEpoch) return;
      final epgSources = await _database.getAllEpgSources();
      if (!mounted || epoch != _loadEpoch) return;
      providers.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
      epgSources.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
      final selectedId = _settings.selectedSourceId.value;
      if (selectedId.isNotEmpty &&
          !epgSources.any((source) => source.id == selectedId)) {
        _settings.selectedSourceId.value = '';
        _settings.selectedSourceName.value = '';
      }
      if (_settings.selectedSourceId.value.isEmpty && epgSources.isNotEmpty) {
        _selectEpgSource(epgSources.first);
      }
      setState(() {
        _providers = providers;
        _epgSources = epgSources;
      });
    } catch (error) {
      if (mounted && epoch == _loadEpoch) {
        setState(() => _loadError = '资源加载失败：$error');
      }
    } finally {
      if (mounted && epoch == _loadEpoch) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => NativeNavigationForeground(
    child: Scaffold(
      appBar: AppBar(
        title: const Text('IPTV 导入与设置'),
        actions: [
          IconButton(
            tooltip: '同步已启用的网络源',
            onPressed: _loading || _syncingAll ? null : _syncAll,
            icon: _syncingAll
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync),
          ),
          IconButton(
            tooltip: '刷新资源',
            onPressed: _loading ? null : _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<void>(
        future: _initialization,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _buildFailure('IPTV 初始化失败：${snapshot.error}');
          }
          if (_loadError case final error?) return _buildFailure(error);
          return _buildBody();
        },
      ),
    ),
  );

  Widget _buildFailure(String message) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => setState(() {
              _initialization = _initialize();
            }),
            child: const Text('重试'),
          ),
        ],
      ),
    ),
  );

  Widget _buildBody() => RefreshIndicator(
    onRefresh: _refresh,
    child: ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
      children: [
        if (_loading) const LinearProgressIndicator(minHeight: 2),
        _buildImportCard(),
        const SizedBox(height: 12),
        _buildSettingsCard(),
        const SizedBox(height: 20),
        _buildSectionTitle('播放列表', _providers.length),
        if (_providers.isEmpty)
          _buildEmptyCard('还没有播放列表，可导入 M3U、M3U8 或 TXT 文件。')
        else
          for (final provider in _providers) _buildProviderCard(provider),
        const SizedBox(height: 20),
        _buildSectionTitle('EPG 节目单', _epgSources.length),
        if (_epgSources.isEmpty)
          _buildEmptyCard('还没有节目单，可导入 XML、XML.GZ 或 JSON 文件。')
        else
          for (final source in _epgSources) _buildEpgCard(source),
      ],
    ),
  );

  Widget _buildImportCard() => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('导入资源', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(
            '播放列表与节目单保存在 Pure Live 的同一 IPTV 数据库中。',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.tonalIcon(
                key: const ValueKey('iptv-import-playlist'),
                onPressed: _loading
                    ? null
                    : () => _showImportMenu(isEpg: false),
                icon: const Icon(Icons.playlist_add),
                label: const Text('导入播放列表'),
              ),
              FilledButton.tonalIcon(
                key: const ValueKey('iptv-import-epg'),
                onPressed: _loading ? null : () => _showImportMenu(isEpg: true),
                icon: const Icon(Icons.event_note_outlined),
                label: const Text('导入 EPG'),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  Widget _buildSettingsCard() => Card(
    child: Obx(
      () => Column(
        children: [
          SwitchListTile(
            key: const ValueKey('iptv-auto-sync-switch'),
            secondary: const Icon(Icons.sync),
            title: const Text('自动同步'),
            subtitle: const Text('仅更新各资源中已启用自动更新的网络源'),
            value: _settings.isAutoSyncEnabled.value,
            onChanged: (value) => _settings.isAutoSyncEnabled.value = value,
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.schedule),
            title: const Text('同步间隔'),
            subtitle: Text('${_settings.autoSyncHoursInterval.value} 小时'),
            enabled: _settings.isAutoSyncEnabled.value,
            onTap: _settings.isAutoSyncEnabled.value
                ? _selectSyncInterval
                : null,
          ),
          const Divider(height: 1),
          ListTile(
            key: const ValueKey('iptv-active-epg-source'),
            leading: const Icon(Icons.live_tv_outlined),
            title: const Text('当前 EPG 源'),
            subtitle: Text(
              _settings.selectedSourceName.value.isEmpty
                  ? '未选择'
                  : _settings.selectedSourceName.value,
            ),
            onTap: _selectActiveEpgSource,
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.public),
            title: const Text('自定义 User-Agent'),
            subtitle: Text(
              _settings.customIptvUserAgent.value.trim().isEmpty
                  ? '使用默认浏览器标识'
                  : _settings.customIptvUserAgent.value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: _editUserAgent,
          ),
        ],
      ),
    ),
  );

  Widget _buildSectionTitle(String title, int count) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
    child: Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
        Text('$count 个'),
      ],
    ),
  );

  Widget _buildEmptyCard(String message) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Text(message),
    ),
  );

  Widget _buildProviderCard(database.Provider provider) {
    final network = iptvResourceIsNetwork(provider.url);
    final key = 'playlist:${provider.id}';
    return _buildResourceCard(
      key: ValueKey(key),
      title: provider.name,
      url: provider.url ?? '',
      format: provider.type.toUpperCase(),
      lastRefresh: provider.lastRefresh,
      network: network,
      autoUpdate: provider.isAutoUpdate,
      busy: _busyResources.contains(key),
      onSync: network ? () => _syncProvider(provider) : null,
      onAutoUpdate: network
          ? (value) => _toggleProviderAutoUpdate(provider, value)
          : null,
      onDelete: () => _deleteProvider(provider),
    );
  }

  Widget _buildEpgCard(database.EpgSource source) {
    final network = iptvResourceIsNetwork(source.url);
    final key = 'epg:${source.id}';
    final selected = _settings.selectedSourceId.value == source.id;
    return _buildResourceCard(
      key: ValueKey(key),
      title: source.name,
      url: source.url,
      format: _epgFormat(source.url),
      lastRefresh: source.lastRefresh,
      network: network,
      autoUpdate: source.isAutoUpdate,
      busy: _busyResources.contains(key),
      selected: selected,
      onTap: () => _selectEpgSource(source),
      onSync: network ? () => _syncEpgSource(source) : null,
      onAutoUpdate: network
          ? (value) => _toggleEpgAutoUpdate(source, value)
          : null,
      onDelete: () => _deleteEpgSource(source),
    );
  }

  Widget _buildResourceCard({
    required Key key,
    required String title,
    required String url,
    required String format,
    required DateTime? lastRefresh,
    required bool network,
    required bool autoUpdate,
    required bool busy,
    required VoidCallback? onSync,
    required ValueChanged<bool>? onAutoUpdate,
    required VoidCallback onDelete,
    bool selected = false,
    VoidCallback? onTap,
  }) => Card(
    key: key,
    color: selected
        ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.35)
        : null,
    child: InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 10, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(selected ? Icons.radio_button_checked : Icons.source),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                _buildTag(format),
                const SizedBox(width: 6),
                _buildTag(network ? '网络' : '本地'),
              ],
            ),
            if (url.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                url,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 4),
            Text(
              lastRefresh == null
                  ? '尚未同步'
                  : '更新于 ${_formatDateTime(lastRefresh)}',
              style: Theme.of(context).textTheme.labelSmall,
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                if (network) ...[
                  Switch.adaptive(
                    value: autoUpdate,
                    onChanged: busy ? null : onAutoUpdate,
                  ),
                  const Text('自动更新'),
                  const Spacer(),
                ] else
                  const Spacer(),
                if (onSync != null)
                  IconButton(
                    tooltip: '立即同步',
                    onPressed: busy ? null : onSync,
                    icon: busy
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.sync),
                  ),
                IconButton(
                  tooltip: '删除资源',
                  onPressed: busy ? null : onDelete,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );

  Widget _buildTag(String label) => DecoratedBox(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Text(label, style: Theme.of(context).textTheme.labelSmall),
    ),
  );

  String _epgFormat(String url) {
    final path = Uri.tryParse(url)?.path.toLowerCase() ?? url.toLowerCase();
    if (path.endsWith('.json')) return 'JSON';
    if (path.endsWith('.gz')) return 'XML.GZ';
    return 'XML';
  }

  String _formatDateTime(DateTime value) {
    String two(int number) => number.toString().padLeft(2, '0');
    return '${value.year}-${two(value.month)}-${two(value.day)} '
        '${two(value.hour)}:${two(value.minute)}';
  }

  Future<void> _showImportMenu({required bool isEpg}) async {
    final action = await showModalBottomSheet<_ImportAction>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.folder_open),
              title: const Text('从本地文件导入'),
              subtitle: Text(isEpg ? 'XML、GZ、JSON' : 'M3U、M3U8、TXT'),
              onTap: () => Navigator.of(context).pop(_ImportAction.local),
            ),
            ListTile(
              leading: const Icon(Icons.cloud_download_outlined),
              title: const Text('从网络地址导入'),
              subtitle: const Text('保存订阅地址，之后可手动或自动同步'),
              onTap: () => Navigator.of(context).pop(_ImportAction.network),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    if (action == _ImportAction.local) {
      await _importLocal(isEpg: isEpg);
    } else {
      await _importNetwork(isEpg: isEpg);
    }
  }

  Future<void> _importLocal({required bool isEpg}) async {
    try {
      final success = isEpg
          ? await EpgImportManager().importFromLocalPicker()
          : await IptvImportManager().importFromLocalPicker();
      if (!mounted) return;
      _showMessage(success ? '导入成功' : '未导入资源');
      if (success) await _refresh();
    } catch (error) {
      if (mounted) _showMessage('导入失败：$error');
    }
  }

  Future<void> _importNetwork({required bool isEpg}) async {
    final success = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _NetworkImportDialog(
        isEpg: isEpg,
        submit: (url, name) => isEpg
            ? EpgImportManager().importFromNetworkUrl(
                url,
                name,
                showTips: false,
              )
            : IptvImportManager().importFromNetworkUrl(
                url,
                name,
                showTips: false,
              ),
      ),
    );
    if (!mounted || success != true) return;
    _showMessage('导入成功');
    await _refresh();
  }

  Future<void> _syncProvider(database.Provider provider) async {
    final key = 'playlist:${provider.id}';
    if (_busyResources.contains(key)) return;
    setState(() => _busyResources.add(key));
    try {
      final success = await IptvSyncEngine.instance.syncPlaylist(provider);
      if (mounted) _showMessage(success ? '播放列表同步成功' : '播放列表同步失败');
      if (success && mounted) await _refresh();
    } finally {
      _busyResources.remove(key);
      if (mounted) setState(() {});
    }
  }

  Future<void> _syncEpgSource(database.EpgSource source) async {
    final key = 'epg:${source.id}';
    if (_busyResources.contains(key)) return;
    setState(() => _busyResources.add(key));
    try {
      final success = await EpgSyncEngine.instance.updateEpgCache(
        source,
        forceUpdate: true,
      );
      if (mounted) _showMessage(success ? 'EPG 同步成功' : 'EPG 同步失败');
      if (success && mounted) await _refresh();
    } finally {
      _busyResources.remove(key);
      if (mounted) setState(() {});
    }
  }

  Future<void> _syncAll() async {
    final providers = _providers
        .where((item) => iptvResourceIsNetwork(item.url) && item.isAutoUpdate)
        .toList();
    final epgSources = _epgSources
        .where((item) => iptvResourceIsNetwork(item.url) && item.isAutoUpdate)
        .toList();
    final total = providers.length + epgSources.length;
    if (total == 0) {
      _showMessage('没有已启用自动更新的网络源');
      return;
    }
    setState(() => _syncingAll = true);
    var succeeded = 0;
    try {
      for (final provider in providers) {
        if (await IptvSyncEngine.instance.syncPlaylist(provider)) succeeded++;
      }
      for (final source in epgSources) {
        if (await EpgSyncEngine.instance.updateEpgCache(
          source,
          forceUpdate: true,
        )) {
          succeeded++;
        }
      }
      if (mounted) {
        _showMessage('同步完成：$succeeded/$total 个资源成功');
        await _refresh();
      }
    } finally {
      if (mounted) setState(() => _syncingAll = false);
    }
  }

  Future<void> _toggleProviderAutoUpdate(
    database.Provider provider,
    bool value,
  ) async {
    await _database.updateProviderUpdateStatus(provider.id, value);
    if (mounted) await _refresh();
  }

  Future<void> _toggleEpgAutoUpdate(
    database.EpgSource source,
    bool value,
  ) async {
    await _database.updateEpgSourceUpdateStatus(source.id, value);
    if (mounted) await _refresh();
  }

  Future<void> _deleteProvider(database.Provider provider) async {
    if (!await _confirmDelete('播放列表“${provider.name}”及其频道')) return;
    final success = await IptvSyncEngine.instance.deletePlaylist(provider);
    if (!mounted) return;
    _showMessage(success ? '播放列表已删除' : '播放列表已变化，请刷新后重试');
    await _refresh();
  }

  Future<void> _deleteEpgSource(database.EpgSource source) async {
    if (!await _confirmDelete('EPG“${source.name}”及其节目数据')) return;
    await _database.deleteEpgSourceCascading(source.id);
    if (_settings.selectedSourceId.value == source.id) {
      _settings.selectedSourceId.value = '';
      _settings.selectedSourceName.value = '';
    }
    if (!mounted) return;
    _showMessage('EPG 已删除');
    await _refresh();
  }

  Future<bool> _confirmDelete(String target) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('确认删除'),
          content: Text('将删除$target，此操作不可撤销。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('删除'),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _selectSyncInterval() async {
    final selected = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('同步间隔'),
        children: [
          RadioGroup<int>(
            groupValue: _settings.autoSyncHoursInterval.value,
            onChanged: (value) => Navigator.of(context).pop(value),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final hours in const [2, 6, 12, 24, 48, 72])
                  RadioListTile<int>(
                    value: hours,
                    title: Text('$hours 小时'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
    if (selected != null) _settings.autoSyncHoursInterval.value = selected;
  }

  Future<void> _selectActiveEpgSource() async {
    final selection = await showDialog<_EpgSelection>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('选择 EPG 源'),
        children: [
          RadioGroup<String>(
            groupValue: _settings.selectedSourceId.value,
            onChanged: (value) {
              final source = _epgSources
                  .where((item) => item.id == value)
                  .firstOrNull;
              Navigator.of(context).pop(_EpgSelection(source));
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const RadioListTile<String>(
                  value: '',
                  title: Text('不使用 EPG'),
                ),
                for (final source in _epgSources)
                  RadioListTile<String>(
                    value: source.id,
                    title: Text(source.name),
                    subtitle: Text(
                      source.url,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
    if (!mounted || selection == null) return;
    if (selection.source == null) {
      _settings.selectedSourceId.value = '';
      _settings.selectedSourceName.value = '';
    } else {
      _selectEpgSource(selection.source!);
    }
    setState(() {});
  }

  void _selectEpgSource(database.EpgSource source) {
    _settings.selectedSourceId.value = source.id;
    _settings.selectedSourceName.value = source.name;
  }

  Future<void> _editUserAgent() async {
    final controller = TextEditingController(
      text: _settings.customIptvUserAgent.value,
    );
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('自定义 User-Agent'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 4,
          maxLength: 500,
          decoration: const InputDecoration(
            hintText: '留空时使用默认浏览器标识',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value != null) _settings.customIptvUserAgent.value = value;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

enum _ImportAction { local, network }

class _EpgSelection {
  const _EpgSelection(this.source);

  final database.EpgSource? source;
}

class _NetworkImportDialog extends StatefulWidget {
  const _NetworkImportDialog({required this.isEpg, required this.submit});

  final bool isEpg;
  final Future<bool> Function(String url, String name) submit;

  @override
  State<_NetworkImportDialog> createState() => _NetworkImportDialogState();
}

class _NetworkImportDialogState extends State<_NetworkImportDialog> {
  final _urlController = TextEditingController();
  final _nameController = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _urlController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final uri = parseIptvSubscriptionUrl(_urlController.text);
    final name = _nameController.text.trim();
    if (uri == null || name.isEmpty) {
      setState(() {
        _error = uri == null ? '请输入完整的 HTTP(S) 地址' : '请输入资源名称';
      });
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    var success = false;
    try {
      success = await widget.submit(uri.toString(), name);
    } catch (_) {
      success = false;
    }
    if (!mounted) return;
    if (success) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _submitting = false;
        _error = '下载或解析失败，请检查地址和文件格式';
      });
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.isEpg ? '导入网络 EPG' : '导入网络播放列表'),
    content: SizedBox(
      width: 420,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const ValueKey('iptv-network-url'),
            controller: _urlController,
            readOnly: _submitting,
            autofocus: true,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: '订阅地址',
              hintText: 'https://example.com/source.m3u',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('iptv-network-name'),
            controller: _nameController,
            readOnly: _submitting,
            decoration: const InputDecoration(
              labelText: '资源名称',
              border: OutlineInputBorder(),
            ),
          ),
          if (_error case final error?) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                error,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ],
          if (_submitting) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
          ],
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: _submitting ? null : () => Navigator.of(context).pop(false),
        child: const Text('取消'),
      ),
      FilledButton(
        onPressed: _submitting ? null : _submit,
        child: const Text('导入'),
      ),
    ],
  );
}
