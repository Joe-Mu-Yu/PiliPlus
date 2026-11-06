import 'dart:async';

import 'package:PiliPlus/models/common/live_favorite.dart';
import 'package:PiliPlus/pages/pure_live_follow/iptv_management_page.dart';
import 'package:PiliPlus/pages/pure_live_follow/playback_page.dart';
import 'package:PiliPlus/services/service_locator.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pure_live/core/iptv/local/database.dart' as database;
import 'package:pure_live/plugins/db_service.dart';

@visibleForTesting
bool iptvChannelMatches(
  database.Channel channel, {
  String query = '',
  String? group,
  String? streamType,
}) {
  if (channel.hidden) return false;
  if (group != null && channel.groupTitle != group) return false;
  if (streamType != null && channel.streamType != streamType) return false;
  final normalizedQuery = query.trim().toLowerCase();
  if (normalizedQuery.isEmpty) return true;
  return [channel.name, channel.tvgName, channel.groupTitle].any(
    (value) => value?.toLowerCase().contains(normalizedQuery) ?? false,
  );
}

class PureLiveIptvPage extends StatefulWidget {
  const PureLiveIptvPage({super.key});

  @override
  State<PureLiveIptvPage> createState() => _PureLiveIptvPageState();
}

class _PureLiveIptvPageState extends State<PureLiveIptvPage> {
  late Future<void> _initialization;
  final _searchController = TextEditingController();
  List<database.Provider> _providers = const [];
  List<database.Channel> _channels = const [];
  String? _selectedProviderId;
  String? _selectedGroup;
  String? _selectedStreamType;
  String? _loadError;
  bool _providerSelectionInitialized = false;
  bool _favoritesOnly = false;
  bool _loading = false;
  int _loadEpoch = 0;

  database.AppDatabase get _database => Get.find<DbService>().db;

  @override
  void initState() {
    super.initState();
    _initialization = _initialize();
  }

  Future<void> _initialize() async {
    await setupPureLiveIptvServices();
    await _reload();
  }

  @override
  void dispose() {
    _loadEpoch++;
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final epoch = ++_loadEpoch;
    if (mounted) {
      setState(() {
        _loading = true;
        _loadError = null;
      });
    }
    try {
      final providers = await _database.getAllProviders()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      if (!mounted || epoch != _loadEpoch) return;

      if (!_providerSelectionInitialized) {
        _selectedProviderId = providers.firstOrNull?.id;
        _providerSelectionInitialized = true;
      } else if (_selectedProviderId != null &&
          !providers.any((item) => item.id == _selectedProviderId)) {
        _selectedProviderId = providers.firstOrNull?.id;
      }

      final List<database.Channel> channels;
      if (_favoritesOnly) {
        channels = await _database.getFavoriteChannels();
      } else if (_selectedProviderId case final providerId?) {
        channels = await _database.getChannelsForProvider(providerId);
      } else {
        channels = (await Future.wait(
          providers.map((item) => _database.getChannelsForProvider(item.id)),
        )).expand((items) => items).toList();
      }
      if (!mounted || epoch != _loadEpoch) return;
      channels.sort(_compareChannels);
      final groups = channels
          .map((item) => item.groupTitle?.trim())
          .whereType<String>()
          .where((item) => item.isNotEmpty)
          .toSet();
      final types = channels.map((item) => item.streamType).toSet();
      setState(() {
        _providers = providers;
        _channels = channels;
        if (!groups.contains(_selectedGroup)) _selectedGroup = null;
        if (!types.contains(_selectedStreamType)) {
          _selectedStreamType = null;
        }
      });
    } catch (error) {
      if (mounted && epoch == _loadEpoch) {
        setState(() => _loadError = '频道加载失败：$error');
      }
    } finally {
      if (mounted && epoch == _loadEpoch) {
        setState(() => _loading = false);
      }
    }
  }

  int _compareChannels(database.Channel a, database.Channel b) {
    final aNumber = a.channelNumber;
    final bNumber = b.channelNumber;
    if (aNumber != null || bNumber != null) {
      if (aNumber == null) return 1;
      if (bNumber == null) return -1;
      final numberOrder = aNumber.compareTo(bNumber);
      if (numberOrder != 0) return numberOrder;
    }
    return _channelName(a).toLowerCase().compareTo(
      _channelName(b).toLowerCase(),
    );
  }

  List<database.Channel> get _visibleChannels => _channels
      .where(
        (channel) => iptvChannelMatches(
          channel,
          query: _searchController.text,
          group: _selectedGroup,
          streamType: _selectedStreamType,
        ),
      )
      .toList(growable: false);

  List<String> get _groups =>
      _channels
          .map((item) => item.groupTitle?.trim())
          .whereType<String>()
          .where((item) => item.isNotEmpty)
          .toSet()
          .toList()
        ..sort();

  List<String> get _streamTypes =>
      _channels.map((item) => item.streamType).toSet().toList()..sort();

  Map<String, String> get _providerNames => {
    for (final provider in _providers) provider.id: provider.name,
  };

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('IPTV 频道'),
      actions: [
        IconButton(
          tooltip: '导入与设置',
          onPressed: _openSettings,
          icon: const Icon(Icons.playlist_add),
        ),
        IconButton(
          tooltip: '刷新频道',
          onPressed: _loading ? null : _reload,
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
        return _buildBody();
      },
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
            onPressed: () => setState(() => _initialization = _initialize()),
            child: const Text('重试'),
          ),
        ],
      ),
    ),
  );

  Widget _buildBody() {
    if (_loadError case final error?) return _buildFailure(error);
    final channels = _visibleChannels;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 2),
          child: TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: '搜索频道、别名或分组',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: '清除搜索',
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                      },
                      icon: const Icon(Icons.close),
                    ),
            ),
          ),
        ),
        _buildSourceFilters(),
        if (_groups.isNotEmpty)
          _buildValueFilters(
            key: const ValueKey('iptv-group-filters'),
            values: _groups,
            selected: _selectedGroup,
            allLabel: '全部分组',
            labelFor: (value) => value,
            onSelected: (value) => setState(() => _selectedGroup = value),
          ),
        if (_streamTypes.length > 1)
          _buildValueFilters(
            key: const ValueKey('iptv-type-filters'),
            values: _streamTypes,
            selected: _selectedStreamType,
            allLabel: '全部类型',
            labelFor: _streamTypeLabel,
            onSelected: (value) => setState(() => _selectedStreamType = value),
          ),
        if (_loading) const LinearProgressIndicator(minHeight: 2),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '${channels.length} 个频道',
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
        ),
        Expanded(
          child: channels.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _reload,
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 96),
                    itemCount: channels.length,
                    itemBuilder: (context, index) =>
                        _buildChannelCard(channels[index]),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildSourceFilters() => SizedBox(
    key: const ValueKey('iptv-source-filters'),
    height: 48,
    child: ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      children: [
        ChoiceChip(
          label: const Text('收藏'),
          selected: _favoritesOnly,
          onSelected: (_) async {
            setState(() => _favoritesOnly = true);
            await _reload();
          },
        ),
        const SizedBox(width: 8),
        ChoiceChip(
          label: const Text('全部源'),
          selected: !_favoritesOnly && _selectedProviderId == null,
          onSelected: (_) async {
            setState(() {
              _favoritesOnly = false;
              _selectedProviderId = null;
            });
            await _reload();
          },
        ),
        for (final provider in _providers) ...[
          const SizedBox(width: 8),
          ChoiceChip(
            label: Text(provider.name),
            selected: !_favoritesOnly && _selectedProviderId == provider.id,
            onSelected: (_) async {
              setState(() {
                _favoritesOnly = false;
                _selectedProviderId = provider.id;
              });
              await _reload();
            },
          ),
        ],
      ],
    ),
  );

  Widget _buildValueFilters({
    required Key key,
    required List<String> values,
    required String? selected,
    required String allLabel,
    required String Function(String value) labelFor,
    required ValueChanged<String?> onSelected,
  }) => SizedBox(
    key: key,
    height: 48,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      itemCount: values.length + 1,
      separatorBuilder: (_, _) => const SizedBox(width: 8),
      itemBuilder: (context, index) {
        final value = index == 0 ? null : values[index - 1];
        return ChoiceChip(
          label: Text(value == null ? allLabel : labelFor(value)),
          selected: selected == value,
          onSelected: (_) => onSelected(value),
        );
      },
    ),
  );

  Widget _buildEmptyState() => ListView(
    physics: const AlwaysScrollableScrollPhysics(),
    children: [
      const SizedBox(height: 88),
      Icon(
        _providers.isEmpty ? Icons.playlist_add : Icons.search_off,
        size: 52,
        color: Theme.of(context).colorScheme.outline,
      ),
      const SizedBox(height: 12),
      Center(
        child: Text(
          _providers.isEmpty ? '还没有 IPTV 播放列表' : '没有符合筛选条件的频道',
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
      const SizedBox(height: 8),
      Center(
        child: Text(
          _providers.isEmpty ? '可导入 M3U、M3U8 或 TXT 播放列表' : '尝试清除搜索或切换分组',
        ),
      ),
      const SizedBox(height: 16),
      Center(
        child: FilledButton.icon(
          onPressed: _providers.isEmpty ? _openSettings : _clearFilters,
          icon: Icon(_providers.isEmpty ? Icons.playlist_add : Icons.clear_all),
          label: Text(_providers.isEmpty ? '导入播放列表' : '清除筛选'),
        ),
      ),
    ],
  );

  Widget _buildChannelCard(database.Channel channel) {
    final provider = _providerNames[channel.providerId] ?? '未知播放源';
    final group = channel.groupTitle?.trim();
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        minTileHeight: 76,
        onTap: () => _openChannel(channel),
        leading: SizedBox.square(
          dimension: 52,
          child: channel.tvgLogo?.trim().isNotEmpty == true
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    channel.tvgLogo!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => _channelIcon(),
                  ),
                )
              : _channelIcon(),
        ),
        title: Text(
          _channelName(channel),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          [
            if (group?.isNotEmpty == true) group!,
            provider,
            _streamTypeLabel(channel.streamType),
          ].join(' · '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: channel.favorite ? '取消收藏' : '收藏频道',
              onPressed: () => _toggleFavorite(channel),
              icon: Icon(
                channel.favorite ? Icons.star : Icons.star_border,
              ),
            ),
            PopupMenuButton<String>(
              tooltip: '频道操作',
              onSelected: (action) {
                if (action == 'copy') unawaited(_copyStreamUrl(channel));
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'copy', child: Text('复制播放地址')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _channelIcon() => DecoratedBox(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Icon(
      Icons.live_tv_outlined,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    ),
  );

  String _channelName(database.Channel channel) {
    final tvgName = channel.tvgName?.trim();
    return tvgName?.isNotEmpty == true ? tvgName! : channel.name;
  }

  String _streamTypeLabel(String type) => switch (type) {
    'vod' => '电影',
    'series' => '剧集',
    _ => '直播',
  };

  Future<void> _openSettings() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const PureLiveIptvManagementPage(),
      ),
    );
    if (mounted) await _reload();
  }

  Future<void> _toggleFavorite(database.Channel channel) async {
    try {
      await _database.toggleFavorite(channel.id);
      await _reload();
    } catch (error) {
      if (mounted) _showMessage('收藏更新失败：$error');
    }
  }

  Future<void> _copyStreamUrl(database.Channel channel) async {
    await Clipboard.setData(ClipboardData(text: channel.streamUrl));
    if (mounted) _showMessage('播放地址已复制');
  }

  Future<void> _openChannel(database.Channel channel) async {
    try {
      final favorite = LiveFavorite(
        platformId: 'iptv',
        roomId: channel.id,
        roomUrl: channel.streamUrl,
        title: _channelName(channel),
        anchorName: channel.groupTitle,
        coverUrl: channel.tvgLogo,
        status: LiveFavoriteStatus.live,
      );
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => PureLivePlaybackPage(favorite: favorite),
        ),
      );
    } catch (error) {
      if (mounted) _showMessage('打开频道失败：$error');
    }
  }

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _selectedGroup = null;
      _selectedStreamType = null;
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
