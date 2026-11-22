import 'dart:async';

import 'package:flutter/services.dart';
import 'package:PiliPlus/models/common/live_favorite.dart';
import 'package:PiliPlus/pages/live_follow/view.dart' as account_follow;
import 'package:PiliPlus/pages/pure_live_follow/iptv_page.dart';
import 'package:PiliPlus/pages/pure_live_follow/link_parser_page.dart';
import 'package:PiliPlus/pages/recorder_center/view.dart';
import 'package:PiliPlus/pages/pure_live_follow/controller.dart';
import 'package:PiliPlus/services/hive_live_favorite_store.dart';
import 'package:PiliPlus/services/live_favorite_repository.dart';
import 'package:PiliPlus/services/live_platform_adapter.dart';
import 'package:PiliPlus/services/service_locator.dart';
import 'package:PiliPlus/utils/page_utils.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:get/get.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pure_live/recorder/models/record_status.dart';
import 'package:pure_live/recorder/pages/recorder/recorder_controller.dart';

class PureLiveFollowPage extends StatefulWidget {
  const PureLiveFollowPage({super.key, this.controller, this.onStartRecording});

  final PureLiveFollowController? controller;
  final Future<void> Function(LiveFavorite favorite)? onStartRecording;

  @override
  State<PureLiveFollowPage> createState() => _PureLiveFollowPageState();
}

class _PureLiveFollowPageState extends State<PureLiveFollowPage>
    with SingleTickerProviderStateMixin {
  static const _controllerTag = 'pure_live_follow';
  late final PureLiveFollowController _controller;
  late final bool _ownsController;
  late final TabController _statusTabs;
  String? _platformFilter;
  String? _tagFilter;

  @override
  void initState() {
    super.initState();
    _statusTabs = TabController(length: 3, vsync: this);
    _ownsController = widget.controller == null;
    _controller =
        widget.controller ??
        Get.put(
          PureLiveFollowController(
            repository: LiveFavoriteRepository(
              HiveLiveFavoriteStore(GStorage.setting),
            ),
            adapters: [
              BilibiliLivePlatformAdapter(),
              DouyuLivePlatformAdapter(),
              DouyinLivePlatformAdapter(),
              PureLiveDirectLinkAdapter(),
            ],
          ),
          tag: _controllerTag,
        );
    unawaited(
      _ownsController ? _verifyRoomsOnOpen() : _controller.load(),
    );
  }

  Future<void> _verifyRoomsOnOpen() async {
    await _controller.load(markUnverified: true);
    if (mounted) unawaited(_controller.refreshFavorites());
  }

  @override
  void dispose() {
    _statusTabs.dispose();
    if (_ownsController &&
        Get.isRegistered<PureLiveFollowController>(tag: _controllerTag)) {
      Get.delete<PureLiveFollowController>(tag: _controllerTag);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('直播关注'),
        titleSpacing: 16,
        actions: [
          PopupMenuButton<_LiveHeaderAction>(
            tooltip: '更多直播功能与筛选',
            onSelected: _onHeaderAction,
            itemBuilder: (context) => _buildHeaderMenuItems(),
          ),
          IconButton(
            tooltip: '录制中心',
            key: const ValueKey('recorder-center-action'),
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => const RecorderCenterPage(),
              ),
            ),
            icon: const Icon(Icons.fiber_manual_record_outlined),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Obx(() {
        return Column(
          children: [
            if (_controller.errorMessage.value case final message?)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 2, 12, 8),
                child: Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        size: 19,
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          message,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onErrorContainer,
                              ),
                        ),
                      ),
                      TextButton(
                        onPressed: _controller.refreshFavorites,
                        child: const Text('重试'),
                      ),
                    ],
                  ),
                ),
              ),
            Expanded(
              child: TabBarView(
                controller: _statusTabs,
                children: List.generate(3, _buildStatusPage),
              ),
            ),
          ],
        );
      }),
    );
  }

  List<PopupMenuEntry<_LiveHeaderAction>> _buildHeaderMenuItems() {
    final platforms =
        _controller.favorites.map((item) => item.platformId).toSet().toList()
          ..sort();
    final tags =
        _controller.favorites.expand((item) => item.tagIds).toSet().toList()
          ..sort();
    return [
      const PopupMenuItem<_LiveHeaderAction>(
        value: _LiveHeaderAction.linkParser(),
        child: ListTile(leading: Icon(Icons.link), title: Text('链接解析')),
      ),
      const PopupMenuItem<_LiveHeaderAction>(
        value: _LiveHeaderAction.iptv(),
        child: ListTile(
          leading: Icon(Icons.playlist_play),
          title: Text('IPTV 频道'),
        ),
      ),
      const PopupMenuItem<_LiveHeaderAction>(
        value: _LiveHeaderAction.addFavorite(),
        child: ListTile(leading: Icon(Icons.add_link), title: Text('添加到关注')),
      ),
      const PopupMenuItem<_LiveHeaderAction>(
        value: _LiveHeaderAction.accountFollows(),
        child: ListTile(
          leading: Icon(Icons.live_tv_outlined),
          title: Text('B站账号关注'),
        ),
      ),
      const PopupMenuDivider(),
      for (var index = 0; index < 3; index++)
        PopupMenuItem(
          value: _LiveHeaderAction.status(index),
          child: ListTile(
            leading: Icon(
              _statusTabs.index == index
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
            ),
            title: Text(['直播中', '录播', '未开播'][index]),
          ),
        ),
      const PopupMenuDivider(),
      PopupMenuItem(
        value: const _LiveHeaderAction.platform(null),
        child: ListTile(
          leading: Icon(_platformFilter == null ? Icons.check : Icons.public),
          title: const Text('全部平台'),
        ),
      ),
      for (final platform in platforms)
        PopupMenuItem(
          value: _LiveHeaderAction.platform(platform),
          child: ListTile(
            leading: Icon(
              _platformFilter == platform ? Icons.check : Icons.public,
            ),
            title: Text(_platformLabel(platform)),
          ),
        ),
      if (tags.isNotEmpty) ...[
        const PopupMenuDivider(),
        PopupMenuItem(
          value: const _LiveHeaderAction.tag(null),
          child: ListTile(
            leading: Icon(
              _tagFilter == null ? Icons.check : Icons.label_outline,
            ),
            title: const Text('全部标签'),
          ),
        ),
        for (final tag in tags)
          PopupMenuItem(
            value: _LiveHeaderAction.tag(tag),
            child: ListTile(
              leading: Icon(
                _tagFilter == tag ? Icons.check : Icons.label_outline,
              ),
              title: Text(tag),
            ),
          ),
      ],
    ];
  }

  void _onHeaderAction(_LiveHeaderAction action) {
    switch (action.type) {
      case _LiveHeaderActionType.linkParser:
        unawaited(_openLinkParser());
        break;
      case _LiveHeaderActionType.iptv:
        unawaited(_openIptv());
        break;
      case _LiveHeaderActionType.addFavorite:
        unawaited(_showAddDialog());
        break;
      case _LiveHeaderActionType.accountFollows:
        Get.to<void>(() => const account_follow.LiveFollowPage());
        break;
      case _LiveHeaderActionType.status:
        _statusTabs.animateTo(action.index!);
        break;
      case _LiveHeaderActionType.platform:
        setState(() => _platformFilter = action.value);
        break;
      case _LiveHeaderActionType.tag:
        setState(() => _tagFilter = action.value);
        break;
    }
  }

  Widget _buildStatusPage(int statusIndex) {
    return Obx(() {
      final filtered = _controller.favorites
          .where((favorite) {
            final statusMatches = switch (statusIndex) {
              0 => favorite.status == LiveFavoriteStatus.live,
              1 => favorite.status == LiveFavoriteStatus.replay,
              _ =>
                favorite.status == LiveFavoriteStatus.offline ||
                    favorite.status == LiveFavoriteStatus.unknown,
            };
            return statusMatches &&
                (_platformFilter == null ||
                    favorite.platformId == _platformFilter) &&
                (_tagFilter == null || favorite.tagIds.contains(_tagFilter));
          })
          .toList(growable: false);
      return RefreshIndicator(
        onRefresh: _controller.refreshFavorites,
        child: filtered.isEmpty
            ? ListView(
                key: ValueKey('favorite-empty-$statusIndex'),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 96),
                  Icon(
                    Icons.live_tv_outlined,
                    size: 48,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: Text(
                      _emptyMessage(statusIndex),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  if (_controller.favorites.isEmpty) ...[
                    const SizedBox(height: 8),
                    const Center(
                      child: Text('可粘贴直播间链接，或从右上角导入 IPTV 播放列表'),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: FilledButton.icon(
                        onPressed: _showAddDialog,
                        icon: const Icon(Icons.add_link),
                        label: const Text('添加直播间'),
                      ),
                    ),
                  ],
                ],
              )
            : LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final count = width >= 1000
                      ? 3
                      : width >= 600
                      ? 2
                      : 1;
                  return GridView.builder(
                    key: ValueKey('favorite-grid-$statusIndex'),
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: count,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      mainAxisExtent: count == 1 ? 124 : 200,
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) =>
                        _buildRoomCard(filtered[index]),
                  );
                },
              ),
      );
    });
  }

  Widget _buildRoomCard(LiveFavorite favorite) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: () => _openRoom(favorite),
        child: Row(
          children: [
            SizedBox(
              width: 116,
              height: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  favorite.coverUrl?.isNotEmpty == true
                      ? Image.network(
                          favorite.coverUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => _coverFallback(colors),
                        )
                      : _coverFallback(colors),
                  Positioned(
                    left: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: colors.surface.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _statusIcon(favorite.status),
                          const SizedBox(width: 5),
                          Text(
                            _statusLabel(favorite.status),
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 8, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      favorite.title?.isNotEmpty == true
                          ? favorite.title!
                          : favorite.roomId,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      favorite.anchorName?.isNotEmpty == true
                          ? favorite.anchorName!
                          : favorite.platformId,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (DouyinLivePlatformAdapter.isLegacyAccountFavorite(
                      favorite,
                    ))
                      Text(
                        '链接需要更新',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colors.error,
                        ),
                      ),
                    const Spacer(),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _platformLabel(favorite.platformId),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                        ),
                        if (DouyinLivePlatformAdapter.isLegacyAccountFavorite(
                          favorite,
                        ))
                          TextButton(
                            onPressed: () => _updateLegacyLink(favorite),
                            child: const Text('更新链接'),
                          ),
                        if (favorite.platformId == 'douyin' &&
                            favorite.status == LiveFavoriteStatus.live)
                          IconButton(
                            tooltip: '开始录制',
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(
                              Icons.fiber_manual_record_outlined,
                            ),
                            onPressed: () => _startRecording(favorite),
                          ),
                        PopupMenuButton<String>(
                          tooltip: '更多操作',
                          onSelected: (action) {
                            if (action == 'tags') _manageTags(favorite);
                            if (action == 'remove') _confirmRemove(favorite);
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'tags', child: Text('管理标签')),
                            PopupMenuItem(value: 'remove', child: Text('移除关注')),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _coverFallback(ColorScheme colors) => ColoredBox(
    color: colors.surfaceContainerHighest,
    child: Icon(Icons.live_tv_outlined, color: colors.onSurfaceVariant),
  );

  Widget _statusIcon(LiveFavoriteStatus status) => Icon(
    switch (status) {
      LiveFavoriteStatus.live => Icons.circle,
      LiveFavoriteStatus.replay => Icons.replay_circle_filled_outlined,
      LiveFavoriteStatus.offline => Icons.circle_outlined,
      LiveFavoriteStatus.unknown => Icons.help_outline,
    },
    size: 12,
  );

  String _statusLabel(LiveFavoriteStatus status) => switch (status) {
    LiveFavoriteStatus.live => '直播中',
    LiveFavoriteStatus.replay => '录播',
    LiveFavoriteStatus.offline => '未开播',
    LiveFavoriteStatus.unknown => '状态未知',
  };

  String _emptyMessage(int statusIndex) => switch (statusIndex) {
    0 => _controller.favorites.isEmpty ? '还没有关注的直播间' : '当前没有正在直播的房间',
    1 => '当前没有录播房间',
    _ => '当前没有未开播的房间',
  };

  String _platformLabel(String platform) => switch (platform) {
    'bilibili' => '哔哩哔哩',
    'douyu' => '斗鱼',
    'douyin' => '抖音',
    'pure_live' => '自定义直播源',
    'iptv' => 'IPTV',
    _ => platform,
  };

  Future<void> _startRecording(LiveFavorite favorite) async {
    final callback = widget.onStartRecording;
    if (callback != null) {
      await callback(favorite);
      return;
    }
    try {
      setupPureLiveRecordingServices();
      final room = await DouyinLivePlatformAdapter().resolveRoomForRecording(
        favorite.roomUrl,
      );
      final task = await Get.find<RecorderController>().addTask(room: room);
      if (!mounted) return;
      final message = switch (task?.status) {
        RecordStatus.running => '已开始录制',
        RecordStatus.preparing => '录制任务已提交，正在解析直播流',
        RecordStatus.queued => '录制任务已加入队列',
        RecordStatus.failed => '录制失败：${task?.lastError ?? '请查看录制中心'}',
        null => '未创建录制任务，请检查存储权限或稍后重试',
        _ => '录制任务已创建，请在录制中心查看状态',
      };
      // Native glass nav bar sits above Flutter overlays, so SnackBars show
      // through it; SmartDialog toasts render on the native layer instead.
      SmartDialog.showToast(message);
    } catch (error) {
      SmartDialog.showToast('开始录制失败：$error');
    }
  }

  void _openRoom(LiveFavorite favorite) {
    if (favorite.platformId == 'bilibili') {
      final roomId = int.tryParse(favorite.roomId);
      if (roomId != null) PageUtils.toLiveRoom(roomId);
      return;
    }
    unawaited(_openPureLiveRoom(favorite));
  }

  Future<void> _openPureLiveRoom(LiveFavorite favorite) async {
    try {
      if (favorite.platformId == 'pure_live' || favorite.platformId == 'iptv') {
        await Get.toNamed<void>(
          '/pure_live/live_play',
          arguments: favorite,
        );
        return;
      }
      if (favorite.platformId != 'douyin') {
        throw UnsupportedError('当前应用内播放先支持抖音，其他平台适配中');
      }
      await Get.toNamed<void>(
        '/pure_live/live_play',
        arguments: favorite,
      );
    } catch (error) {
      SmartDialog.showToast('打开直播间失败：$error');
    }
  }

  Future<void> _openIptv() => Navigator.of(context).push<void>(
    MaterialPageRoute<void>(builder: (_) => const PureLiveIptvPage()),
  );

  Future<void> _openLinkParser() => Navigator.of(context).push<void>(
    MaterialPageRoute<void>(builder: (_) => const PureLiveLinkParserPage()),
  );

  Future<void> _showAddDialog() async {
    final link = await showDialog<String>(
      context: context,
      builder: (_) => const _AddLiveRoomDialog(),
    );
    if (link == null || link.isEmpty || !mounted) return;
    final added = await _controller.addFromLink(link);
    if (!mounted) return;
    SmartDialog.showToast(
      added ? '已添加到关注' : _controller.errorMessage.value ?? '添加失败',
    );
  }

  Future<void> _updateLegacyLink(LiveFavorite favorite) async {
    final link = await showDialog<String>(
      context: context,
      builder: (_) => const _AddLiveRoomDialog(
        title: '更新直播间链接',
        submitLabel: '验证并更新',
      ),
    );
    if (link == null || link.isEmpty || !mounted) return;
    final updated = await _controller.updateLegacyDouyinLink(favorite, link);
    if (!mounted) return;
    SmartDialog.showToast(
      updated ? '直播间链接已更新' : _controller.errorMessage.value ?? '更新失败',
    );
  }

  Future<void> _confirmRemove(LiveFavorite favorite) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('移除关注？'),
        content: Text(
          '将从关注列表移除“${favorite.title?.isNotEmpty == true ? favorite.title : favorite.roomId}”。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('移除'),
          ),
        ],
      ),
    );
    if (confirmed == true) await _controller.remove(favorite.identityKey);
  }

  Future<void> _manageTags(LiveFavorite favorite) async {
    final input = TextEditingController(text: favorite.tagIds.join(', '));
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('管理标签'),
        content: TextField(
          controller: input,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: '标签',
            hintText: '多个标签用逗号分隔',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, input.text),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    input.dispose();
    if (result == null) return;
    await _controller.updateTags(
      favorite.identityKey,
      result.split(RegExp(r'[,，]')),
    );
  }
}

enum _LiveHeaderActionType {
  linkParser,
  iptv,
  addFavorite,
  accountFollows,
  status,
  platform,
  tag,
}

class _LiveHeaderAction {
  const _LiveHeaderAction._(this.type, {this.index, this.value});

  const _LiveHeaderAction.linkParser()
    : this._(_LiveHeaderActionType.linkParser);
  const _LiveHeaderAction.iptv() : this._(_LiveHeaderActionType.iptv);
  const _LiveHeaderAction.addFavorite()
    : this._(_LiveHeaderActionType.addFavorite);
  const _LiveHeaderAction.accountFollows()
    : this._(_LiveHeaderActionType.accountFollows);
  const _LiveHeaderAction.status(int index)
    : this._(_LiveHeaderActionType.status, index: index);
  const _LiveHeaderAction.platform(String? value)
    : this._(_LiveHeaderActionType.platform, value: value);
  const _LiveHeaderAction.tag(String? value)
    : this._(_LiveHeaderActionType.tag, value: value);

  final _LiveHeaderActionType type;
  final int? index;
  final String? value;
}

class _AddLiveRoomDialog extends StatefulWidget {
  const _AddLiveRoomDialog({
    this.title = '添加直播间',
    this.submitLabel = '验证并添加',
  });

  final String title;
  final String submitLabel;

  @override
  State<_AddLiveRoomDialog> createState() => _AddLiveRoomDialogState();
}

class _AddLiveRoomDialogState extends State<_AddLiveRoomDialog> {
  final _input = TextEditingController();

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: TextField(
      controller: _input,
      autofocus: true,
      keyboardType: TextInputType.url,
      decoration: InputDecoration(
        labelText: '直播间链接',
        hintText: '支持 B站、斗鱼、抖音房间，以及 M3U8/FLV/MP4 单条直播流',
        suffixIcon: IconButton(
          tooltip: '粘贴',
          icon: const Icon(Icons.content_paste),
          onPressed: () async {
            final data = await Clipboard.getData(Clipboard.kTextPlain);
            if (mounted && data?.text != null) _input.text = data!.text!.trim();
          },
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, _input.text.trim()),
        child: Text(widget.submitLabel),
      ),
    ],
  );
}
