import 'dart:async';

import 'package:PiliPlus/common/widgets/scaffold/simple_scaffold.dart';
import 'package:PiliPlus/models/common/live_favorite.dart';
import 'package:PiliPlus/pages/recorder_center/view.dart';
import 'package:PiliPlus/services/pure_live_playback_source.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:pure_live/common/models/live_message.dart';
import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/core/interface/live_danmaku.dart';
import 'package:pure_live/core/interface/live_site.dart';
import 'package:pure_live/core/site/bilibili/bilibili_site.dart';
import 'package:pure_live/core/site/douyin/douyin_site.dart';
import 'package:pure_live/core/site/douyu/douyu_site.dart';
import 'package:pure_live/recorder/pages/recorder/recorder_controller.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class PureLivePlaybackPage extends StatefulWidget {
  const PureLivePlaybackPage({super.key, required this.favorite});

  final LiveFavorite favorite;

  @override
  State<PureLivePlaybackPage> createState() => _PureLivePlaybackPageState();
}

class _PureLivePlaybackPageState extends State<PureLivePlaybackPage> {
  static final Map<String, LiveSite> _liveSites = {
    'bilibili': BiliBiliSite(),
    'douyin': DouyinSite(),
    'douyu': DouyuSite(),
  };
  Player? _player;
  VideoController? _videoController;
  LivePlaybackCatalog? _catalog;
  ResolvedLivePlaybackSource? _activeSource;
  LiveDanmaku? _danmaku;
  StreamSubscription<bool>? _playingSubscription;
  StreamSubscription<dynamic>? _videoParamsSubscription;
  Timer? _sleepTimer;
  String? _error;
  String? _danmakuError;
  bool _loading = true;
  bool _showControls = true;
  bool _audioOnly = false;
  bool _fullscreen = false;
  bool? _portraitSource;
  bool _fullscreenOrientationLocked = false;
  bool _danmakuEnabled = true;
  bool _similarFilterEnabled = false;
  bool _loadingSuperChats = false;
  int _tabIndex = 0;
  int _tabRevision = 0;
  int _similarity = 85;
  int _cacheSeconds = 3;
  int _maxCacheCount = 100;
  double _danmakuOpacity = 1;
  double _danmakuSize = 18;
  final TextEditingController _nicknameController = TextEditingController(
    text: '本地观众',
  );
  String _localTitle = '听众';
  int _localCoins = 1000;
  int _localExperience = 0;
  final List<String> _localHistory = [];
  final List<LiveMessage> _messages = [];
  final List<({String text, DateTime time})> _recentSimilarity = [];
  final List<LiveSuperChatMessage> _superChats = [];
  final List<String> _blockedWords = [];
  final Set<String> _blockedUsers = {};
  final TextEditingController _captionController = TextEditingController();
  final TextEditingController _blockWordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    unawaited(_resolveAndPlay());
  }

  Future<void> _resolveAndPlay({
    int qualityIndex = 0,
    int lineIndex = 0,
    ResolvedLivePlaybackSource? currentSource,
  }) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final site = _siteForPlatform;
      final resolver = PureLivePlaybackSource(site);
      final catalog =
          _catalog ?? await resolver.discover(widget.favorite.roomId);
      final source = await resolver.resolveSelection(
        catalog,
        qualityIndex: qualityIndex,
        lineIndex: lineIndex,
        currentSource: currentSource,
      );
      if (!mounted) return;
      _catalog = catalog;
      _activeSource = source;
      var player = _player;
      if (player == null) {
        player = await Player.create();
        final videoController = await VideoController.create(player);
        _player = player;
        _videoController = videoController;
        _playingSubscription = player.stream.playing.listen((_) {
          if (mounted) setState(() {});
        });
        _videoParamsSubscription = player.stream.videoParams.listen((params) {
          final width = params.dw ?? params.w ?? 0;
          final height = params.dh ?? params.h ?? 0;
          if (width <= 0 || height <= 0) return;
          final portrait = height > width;
          if (mounted && _portraitSource != portrait) {
            setState(() => _portraitSource = portrait);
            if (_fullscreen) unawaited(_applyFullscreenOrientation());
          }
        });
        player.setMediaHeader(
          userAgent:
              'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 '
              '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
          referer: _refererForPlatform(widget.favorite.platformId),
        );
      }
      setState(() => _loading = false);
      await player.open(Media(source.url), play: true);
      if (_danmaku == null) await _connectDanmaku(site, source.room);
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = '解析或播放失败：$error';
        });
      }
    }
  }

  String _refererForPlatform(String platform) => switch (platform) {
    'douyin' => 'https://live.douyin.com',
    'bilibili' => 'https://live.bilibili.com',
    'douyu' => 'https://www.douyu.com',
    'huya' => 'https://www.huya.com',
    _ => widget.favorite.roomUrl,
  };

  Future<void> _connectDanmaku(dynamic site, LiveRoom room) async {
    final engine = (site as LiveSite).getDanmaku();
    _danmaku = engine;
    engine.onMessage = (message) {
      if (!mounted) return;
      if (_similarFilterEnabled && _isSimilarDuplicate(message)) return;
      setState(() {
        _messages.add(message);
        if (_messages.length > 500)
          _messages.removeRange(0, _messages.length - 500);
        if (message.type == LiveMessageType.online) {
          room.onlineViewers = message.message;
          room.watching = message.message;
        }
      });
    };
    engine.onReconnect = (message) {
      if (mounted) setState(() => _danmakuError = message);
    };
    engine.onClose = (message) {
      if (mounted) setState(() => _danmakuError = message);
    };
    engine.onReady = () {
      if (mounted) setState(() => _danmakuError = null);
    };
    try {
      if (room.danmakuData != null) await engine.start(room.danmakuData);
    } catch (error) {
      if (mounted) setState(() => _danmakuError = '弹幕连接失败：$error');
    }
  }

  @override
  void dispose() {
    _sleepTimer?.cancel();
    _playingSubscription?.cancel();
    _videoParamsSubscription?.cancel();
    if (_fullscreenOrientationLocked) {
      unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
      unawaited(
        SystemChrome.setPreferredOrientations(const [
          DeviceOrientation.portraitUp,
        ]),
      );
    }
    final engine = _danmaku;
    if (engine != null) unawaited(engine.stop());
    final player = _player;
    if (player != null) unawaited(player.dispose());
    _captionController.dispose();
    _blockWordController.dispose();
    _nicknameController.dispose();
    super.dispose();
  }

  bool _isSimilarDuplicate(LiveMessage message) {
    final now = DateTime.now();
    _recentSimilarity.removeWhere(
      (entry) => now.difference(entry.time).inSeconds > _cacheSeconds,
    );
    final text = message.message.trim().toLowerCase();
    for (final entry in _recentSimilarity) {
      if (_textSimilarity(text, entry.text) * 100 >= _similarity) return true;
    }
    _recentSimilarity.add((text: text, time: now));
    if (_recentSimilarity.length > _maxCacheCount) {
      _recentSimilarity.removeRange(
        0,
        _recentSimilarity.length - _maxCacheCount,
      );
    }
    return false;
  }

  double _textSimilarity(String a, String b) {
    if (a == b) return 1;
    if (a.isEmpty || b.isEmpty) return 0;
    var previous = List<int>.generate(b.length + 1, (index) => index);
    for (var i = 1; i <= a.length; i++) {
      final current = List<int>.filled(b.length + 1, 0)..[0] = i;
      for (var j = 1; j <= b.length; j++) {
        current[j] = [
          current[j - 1] + 1,
          previous[j] + 1,
          previous[j - 1] +
              (a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1),
        ].reduce((x, y) => x < y ? x : y);
      }
      previous = current;
    }
    return 1 - previous.last / (a.length > b.length ? a.length : b.length);
  }

  bool _isBlocked(LiveMessage message) {
    if (_blockedUsers.contains(message.userId)) return true;
    final text = message.message.toLowerCase();
    return _blockedWords.any((word) => text.contains(word.toLowerCase()));
  }

  List<LiveMessage> get _visibleMessages => _messages
      .where((message) => !_isBlocked(message))
      .toList(growable: false);

  Future<void> _chooseQuality() async {
    final catalog = _catalog;
    if (catalog == null) return;
    final selected = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(title: Text('选择清晰度')),
            for (var i = 0; i < catalog.qualities.length; i++)
              ListTile(
                title: Text(catalog.qualities[i].quality),
                trailing: i == _activeSource?.qualityIndex
                    ? const Icon(Icons.check)
                    : null,
                onTap: () => Navigator.pop(context, i),
              ),
          ],
        ),
      ),
    );
    if (selected != null && mounted) {
      await _resolveAndPlay(
        qualityIndex: selected,
        currentSource: _activeSource,
      );
    }
  }

  Future<void> _chooseLine() async {
    final source = _activeSource;
    if (source == null) return;
    final selected = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(title: Text('选择线路')),
            for (var i = 0; i < source.lines.length; i++)
              ListTile(
                title: Text('Line ${i + 1}'),
                subtitle: Text(_hostLabel(source.lines[i])),
                trailing: i == source.lineIndex
                    ? const Icon(Icons.check)
                    : null,
                onTap: () => Navigator.pop(context, i),
              ),
          ],
        ),
      ),
    );
    if (selected != null && mounted) {
      await _resolveAndPlay(
        qualityIndex: source.qualityIndex,
        lineIndex: selected,
        currentSource: source,
      );
    }
  }

  String _hostLabel(String url) => Uri.tryParse(url)?.host ?? '直播流';

  Future<void> _copyDirectLink() async {
    await _chooseQuality();
    final url = _activeSource?.url;
    if (url == null || !mounted) return;
    await Clipboard.setData(ClipboardData(text: url));
    _notice('当前直播流直链已复制');
  }

  Future<void> _openRoomPage() async {
    final uri = Uri.tryParse(widget.favorite.roomUrl);
    if (uri == null ||
        !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      _notice('无法打开直播间网页');
    }
  }

  Future<void> _shareRoom() async {
    await SharePlus.instance.share(
      ShareParams(
        text: '${widget.favorite.title ?? '直播间'}\n${widget.favorite.roomUrl}',
      ),
    );
  }

  Future<void> _openCast() async {
    final source = _activeSource;
    if (source == null) return;
    await Get.toNamed<void>(
      '/dlna',
      parameters: {
        'url': source.url,
        'title': widget.favorite.title ?? widget.favorite.anchorName ?? '直播',
      },
    );
  }

  Future<void> _record({required bool startImmediately}) async {
    final source = _activeSource;
    if (source == null) return;
    try {
      final task = await Get.find<RecorderController>().addTask(
        room: source.room,
        startImmediately: startImmediately,
      );
      if (task == null) {
        _notice('未能创建录制任务');
      } else {
        _notice(startImmediately ? '已提交录制任务' : '已加入监控');
      }
    } catch (error) {
      _notice('录制任务失败：$error');
    }
  }

  Future<void> _showRecordActions() async {
    final source = _activeSource;
    if (source == null) return;
    final controller = Get.find<RecorderController>();
    final exists = controller.tasks.any(
      (task) =>
          task.roomId == source.room.roomId &&
          task.platform == source.room.platform,
    );
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            const ListTile(title: Text('录制 / 监控')),
            ListTile(
              leading: const Icon(Icons.fiber_manual_record),
              title: const Text('立即开始录制'),
              onTap: () {
                Navigator.pop(context);
                unawaited(_record(startImmediately: true));
              },
            ),
            ListTile(
              leading: const Icon(Icons.playlist_add_check),
              title: const Text('加入开播监控'),
              onTap: () {
                Navigator.pop(context);
                unawaited(_record(startImmediately: false));
              },
            ),
            ListTile(
              leading: const Icon(Icons.video_library_outlined),
              title: const Text('打开录制中心'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => const RecorderCenterPage(),
                  ),
                );
              },
            ),
            if (exists)
              const ListTile(
                leading: Icon(Icons.info_outline),
                title: Text('此房间已有录制任务'),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _setRoomVolume() async {
    final player = _player;
    if (player == null) return;
    var volume = player.state.volume.clamp(0, 100).toDouble();
    final result = await showDialog<double>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('房间音量'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${volume.round()}%'),
              Slider(
                value: volume,
                min: 0,
                max: 100,
                divisions: 100,
                onChanged: (value) => setDialogState(() => volume = value),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('静音'),
                value: volume == 0,
                onChanged: (value) =>
                    setDialogState(() => volume = value ? 0 : 50),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, volume),
              child: const Text('确定'),
            ),
          ],
        ),
      ),
    );
    if (result != null) await player.setVolume(result);
  }

  Future<void> _setSleepTimer() async {
    const presets = [15, 30, 45, 60, 90, 120, 240, 480];
    final selected = await showModalBottomSheet<int?>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(title: Text('当前房间播放定时')),
            if (_sleepTimer != null)
              ListTile(
                leading: const Icon(Icons.timer_off_outlined),
                title: const Text('关闭定时'),
                onTap: () => Navigator.pop(context, 0),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                children: [
                  for (final minute in presets)
                    ActionChip(
                      label: Text('$minute 分钟'),
                      onPressed: () => Navigator.pop(context, minute),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
    if (selected == null) return;
    _sleepTimer?.cancel();
    if (selected == 0) {
      setState(() {});
      _notice('已关闭播放定时');
      return;
    }
    _sleepTimer = Timer(Duration(minutes: selected), () async {
      await _player?.pause();
      if (mounted) {
        setState(() => _sleepTimer = null);
        _notice('播放定时结束');
      }
    });
    setState(() {});
    _notice('已设置 $selected 分钟后暂停');
  }

  Future<void> _showPlayerMenu() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            const ListTile(title: Text('直播间')),
            _menuItem('open', Icons.open_in_new, '打开直播间网页'),
            _menuItem('switch', Icons.swap_horiz, '切换直播间'),
            _menuItem('cast', Icons.cast, '投屏'),
            _menuItem(
              'timer',
              Icons.timer_outlined,
              _sleepTimer == null ? '播放定时' : '播放定时（已开启）',
            ),
            _menuItem('volume', Icons.volume_up_outlined, '房间音量'),
            _menuItem('direct', Icons.link, '获取直链 / 选择画质'),
            _menuItem('share', Icons.share_outlined, '分享直播间'),
            _menuItem('local', Icons.auto_awesome, '本地互动'),
          ],
        ),
      ),
    );
    switch (action) {
      case 'open':
        await _openRoomPage();
      case 'switch':
        Get.back<void>();
      case 'cast':
        await _openCast();
      case 'timer':
        await _setSleepTimer();
      case 'volume':
        await _setRoomVolume();
      case 'direct':
        await _copyDirectLink();
      case 'share':
        await _shareRoom();
      case 'local':
        await _showLocalInteraction();
    }
  }

  Widget _menuItem(String value, IconData icon, String title) => ListTile(
    leading: Icon(icon),
    title: Text(title),
    onTap: () => Navigator.pop(context, value),
  );

  Future<void> _showLocalInteraction() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          8,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 20,
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('本地互动', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              const Text('仅保存在本机，不会发送到直播平台。'),
              const SizedBox(height: 12),
              TextField(
                controller: _nicknameController,
                decoration: const InputDecoration(labelText: '本地昵称'),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _captionController,
                decoration: const InputDecoration(
                  labelText: '发送本地弹幕',
                  border: OutlineInputBorder(),
                ),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendLocalCaption(closeSheet: true),
              ),
              const SizedBox(height: 12),
              Text('本地身份：$_localTitle · ${_nicknameController.text}'),
              Text('虚拟币：$_localCoins　经验：$_localExperience'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final title in ['听众', '夜猫子', '支持者', '守护者'])
                    ChoiceChip(
                      label: Text(title),
                      selected: _localTitle == title,
                      onSelected: (_) => setState(() => _localTitle = title),
                    ),
                ],
              ),
              Wrap(
                spacing: 8,
                children: [
                  for (final gift in const <(String, int)>[
                    ('小心心', 10),
                    ('荧光棒', 50),
                    ('热气球', 100),
                  ])
                    ActionChip(
                      label: Text('${gift.$1} · ${gift.$2}币'),
                      onPressed: () => _sendLocalGift(gift.$1, gift.$2),
                    ),
                  ActionChip(
                    label: const Text('本地充值 +100'),
                    onPressed: () => setState(() => _localCoins += 100),
                  ),
                ],
              ),
              if (_localHistory.isNotEmpty)
                Text('本地记录：${_localHistory.take(3).join('、')}'),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: () => _sendLocalCaption(closeSheet: true),
                  icon: const Icon(Icons.send),
                  label: const Text('仅本地显示'),
                ),
              ),
              const SizedBox(height: 8),
              if (_messages.where((item) => item.isLocal).isNotEmpty)
                Text(
                  '本地互动记录：${_messages.where((item) => item.isLocal).length} 条',
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _sendLocalCaption({bool closeSheet = false}) {
    final value = _captionController.text.trim();
    if (value.isEmpty) return;
    setState(() {
      _messages.add(
        LiveMessage(
          type: LiveMessageType.chat,
          userName: '$_localTitle · ${_nicknameController.text}',
          message: value,
          color: LiveMessageColor.white,
          isLocal: true,
        ),
      );
    });
    _captionController.clear();
    if (closeSheet && mounted) Navigator.of(context).maybePop();
  }

  void _sendLocalGift(String name, int price) {
    if (_localCoins < price) {
      _notice('虚拟币不足，请先充值');
      return;
    }
    setState(() {
      _localCoins -= price;
      _localExperience += price;
      final entry = '$name ×1';
      _localHistory.insert(0, entry);
      _messages.add(
        LiveMessage(
          type: LiveMessageType.gift,
          userName: '$_localTitle · ${_nicknameController.text}',
          message: '${_nicknameController.text} 送出 $entry（仅本地）',
          data: const {'local': true, 'price': 0},
          color: LiveMessageColor.white,
          isLocal: true,
        ),
      );
    });
    _notice('已在本机模拟赠送$name');
  }

  Widget _buildFullscreen() {
    final videoController = _videoController;
    final player = _player;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_audioOnly)
            const Center(
              child: Icon(Icons.headphones, size: 64, color: Colors.white54),
            )
          else if (videoController != null)
            Video(
              controller: videoController,
              controls: NoVideoControls,
              fit: BoxFit.contain,
            )
          else
            const ColoredBox(color: Colors.black),
          if (_showControls)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black.withValues(alpha: .28),
                child: Stack(
                  children: [
                    Positioned(
                      left: 12,
                      top: 28,
                      child: IconButton(
                        tooltip: '退出全屏',
                        onPressed: _toggleFullscreen,
                        color: Colors.white,
                        icon: const Icon(Icons.fullscreen_exit),
                      ),
                    ),
                    Positioned(
                      right: 8,
                      top: 28,
                      child: IconButton(
                        tooltip: '更多',
                        onPressed: _showPlayerMenu,
                        color: Colors.white,
                        icon: const Icon(Icons.more_vert),
                      ),
                    ),
                    Center(
                      child: IconButton.filledTonal(
                        onPressed: player == null
                            ? null
                            : () => player.state.playing
                                  ? player.pause()
                                  : player.play(),
                        iconSize: 40,
                        icon: Icon(
                          player?.state.playing == true
                              ? Icons.pause
                              : Icons.play_arrow,
                        ),
                      ),
                    ),
                    Positioned(
                      left: 8,
                      right: 8,
                      bottom: 18,
                      child: Row(
                        children: [
                          IconButton(
                            tooltip: _danmakuEnabled ? '关闭弹幕' : '开启弹幕',
                            onPressed: () => setState(
                              () => _danmakuEnabled = !_danmakuEnabled,
                            ),
                            color: Colors.white,
                            icon: Icon(
                              _danmakuEnabled
                                  ? Icons.subtitles
                                  : Icons.subtitles_off,
                            ),
                          ),
                          IconButton(
                            onPressed: () =>
                                setState(() => _audioOnly = !_audioOnly),
                            color: Colors.white,
                            icon: const Icon(Icons.headphones),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: _chooseQuality,
                            child: Text(
                              _activeSource?.quality.quality ?? '画质',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          TextButton(
                            onPressed: _chooseLine,
                            child: Text(
                              '线路 ${(_activeSource?.lineIndex ?? 0) + 1}',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (!_showControls)
            Positioned.fill(
              child: GestureDetector(
                onTap: () => setState(() => _showControls = true),
                behavior: HitTestBehavior.opaque,
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _loadSuperChats() async {
    final source = _activeSource;
    if (source == null || _loadingSuperChats) return;
    setState(() => _loadingSuperChats = true);
    try {
      final items = await _siteForPlatform.getSuperChatMessage(
        roomId: source.room.roomId ?? widget.favorite.roomId,
      );
      if (mounted)
        setState(
          () => _superChats
            ..clear()
            ..addAll(items),
        );
    } catch (error) {
      if (mounted) _notice('醒目留言暂不可用：$error');
    } finally {
      if (mounted) setState(() => _loadingSuperChats = false);
    }
  }

  LiveSite get _siteForPlatform {
    final site = _liveSites[widget.favorite.platformId.toLowerCase()];
    if (site == null) {
      throw UnsupportedError('暂不支持 ${widget.favorite.platformId} 播放');
    }
    return site;
  }

  void _onTabSelected(int index) {
    setState(() {
      _tabIndex = index;
      _tabRevision++;
    });
    if (index == 1) unawaited(_loadSuperChats());
  }

  void _notice(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    if (_fullscreen) return _buildFullscreen();
    final pageBackground = ColorScheme.of(context).surfaceContainerLowest;
    final player = _player;
    final controller = _videoController;
    final room = _activeSource?.room;
    final title = room?.title?.isNotEmpty == true
        ? room!.title!
        : (widget.favorite.title ?? '直播间');
    final anchor = room?.nick?.isNotEmpty == true
        ? room!.nick!
        : (widget.favorite.anchorName ?? widget.favorite.platformId);
    return SimpleScaffold(
      backgroundColor: pageBackground,
      appBar: AppBar(
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(
              '$anchor · ${widget.favorite.platformId.toUpperCase()}',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: '录制与监控',
            onPressed: _showRecordActions,
            icon: const Icon(Icons.fiber_manual_record_outlined),
          ),
          IconButton(
            tooltip: '更多播放选项',
            onPressed: _showPlayerMenu,
            icon: const Icon(Icons.more_vert),
          ),
        ],
      ),
      body: Material(
        color: pageBackground,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final naturalHeight = width / _videoAspectRatio;
            final heightLimit =
                constraints.maxHeight * (_portraitSource == true ? .56 : .52);
            final viewportHeight = naturalHeight.clamp(
              120.0,
              heightLimit,
            );
            return Column(
              children: [
                SizedBox(
                  width: width,
                  height: viewportHeight,
                  child: GestureDetector(
                    onTap: () => setState(() => _showControls = !_showControls),
                    onDoubleTap: () =>
                        player?.stream.playing.first.then((playing) {
                          if (playing) {
                            player.pause();
                          } else {
                            player.play();
                          }
                        }),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (_audioOnly)
                          const ColoredBox(
                            color: Color(0xFF101114),
                            child: Center(
                              child: Icon(
                                Icons.headphones,
                                color: Colors.white54,
                                size: 54,
                              ),
                            ),
                          )
                        else if (controller != null)
                          Video(
                            controller: controller,
                            controls: NoVideoControls,
                            fit: BoxFit.contain,
                          )
                        else
                          const ColoredBox(color: Color(0xFF101114)),
                        if (_loading)
                          const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircularProgressIndicator(),
                                SizedBox(height: 12),
                                Text(
                                  '正在获取直播流…',
                                  style: TextStyle(color: Colors.white70),
                                ),
                              ],
                            ),
                          )
                        else if (_error case final error?)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    error,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                  const SizedBox(height: 12),
                                  FilledButton.icon(
                                    onPressed: _resolveAndPlay,
                                    icon: const Icon(Icons.refresh),
                                    label: const Text('重新连接'),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else if (_showControls)
                          _buildVideoControls(player)
                        else if (_danmakuEnabled && _visibleMessages.isNotEmpty)
                          _buildDanmakuOverlay(),
                      ],
                    ),
                  ),
                ),
                _buildPlaybackInfo(room),
                _buildTabs(),
                Expanded(child: _buildTabContent()),
                if (_tabIndex == 0) _buildCaptionBar(),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildVideoControls(Player? player) => ColoredBox(
    color: Colors.black.withValues(alpha: .28),
    child: Stack(
      children: [
        Positioned(
          left: 12,
          top: 12,
          child: Text(
            widget.favorite.title ?? '直播中',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Positioned(
          right: 4,
          top: 0,
          child: Row(
            children: [
              IconButton(
                tooltip: _audioOnly ? '恢复画面' : '仅听声音',
                onPressed: () => setState(() => _audioOnly = !_audioOnly),
                color: Colors.white,
                icon: const Icon(Icons.headphones),
              ),
              IconButton(
                tooltip: '投屏',
                onPressed: _openCast,
                color: Colors.white,
                icon: const Icon(Icons.cast),
              ),
              IconButton(
                tooltip: '刷新直播流',
                onPressed: _resolveAndPlay,
                color: Colors.white,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
        ),
        Center(
          child: IconButton.filledTonal(
            tooltip: player?.state.playing == true ? '暂停' : '播放',
            onPressed: player == null
                ? null
                : () => player.state.playing ? player.pause() : player.play(),
            iconSize: 36,
            icon: Icon(
              player?.state.playing == true ? Icons.pause : Icons.play_arrow,
            ),
          ),
        ),
        Positioned(
          left: 8,
          right: 8,
          bottom: 4,
          child: Row(
            children: [
              IconButton(
                tooltip: player?.state.playing == true ? '暂停' : '播放',
                onPressed: player == null
                    ? null
                    : () =>
                          player.state.playing ? player.pause() : player.play(),
                color: Colors.white,
                icon: Icon(
                  player?.state.playing == true
                      ? Icons.pause
                      : Icons.play_arrow,
                ),
              ),
              IconButton(
                tooltip: '重新连接',
                onPressed: _resolveAndPlay,
                color: Colors.white,
                icon: const Icon(Icons.replay),
              ),
              const Spacer(),
              TextButton(
                onPressed: _chooseQuality,
                child: Text(
                  _activeSource?.quality.quality ?? '画质',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              IconButton(
                tooltip: _fullscreen ? '退出全屏' : '全屏',
                onPressed: _toggleFullscreen,
                color: Colors.white,
                icon: Icon(
                  _fullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Future<void> _toggleFullscreen() async {
    final next = !_fullscreen;
    if (next) {
      _fullscreenOrientationLocked = true;
      await _applyFullscreenOrientation();
    } else {
      _fullscreenOrientationLocked = false;
      await SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.portraitUp,
      ]);
    }
    await SystemChrome.setEnabledSystemUIMode(
      next ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
    );
    if (!next) _fullscreenOrientationLocked = false;
    if (mounted) setState(() => _fullscreen = next);
  }

  double get _videoAspectRatio {
    final params = _player?.state.videoParams;
    final explicitRatio = params?.aspect;
    if (explicitRatio != null && explicitRatio.isFinite && explicitRatio > 0) {
      return explicitRatio.clamp(.45, 2.5).toDouble();
    }
    final width = params?.dw ?? params?.w ?? 0;
    final height = params?.dh ?? params?.h ?? 0;
    return PureLivePlaybackSource.aspectRatioForDimensions(
      width: width,
      height: height,
      fallback: _portraitSource == true ? 9 / 16 : 16 / 9,
    );
  }

  Future<void> _applyFullscreenOrientation() async {
    final orientations = _portraitSource == true
        ? const [DeviceOrientation.portraitUp]
        : const [
            DeviceOrientation.landscapeLeft,
            DeviceOrientation.landscapeRight,
          ];
    await SystemChrome.setPreferredOrientations(orientations);
  }

  Widget _buildDanmakuOverlay() {
    final messages = _visibleMessages.reversed.take(3).toList().reversed;
    return IgnorePointer(
      child: Align(
        alignment: Alignment.topLeft,
        child: Padding(
          padding: const EdgeInsets.only(top: 52, left: 12, right: 80),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final message in messages)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: .35),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      child: Text(
                        '${message.userName}: ${message.message}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(
                            alpha: _danmakuOpacity,
                          ),
                          fontSize: _danmakuSize,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaybackInfo(LiveRoom? room) => SizedBox(
    height: 58,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          const Icon(Icons.visibility_outlined, size: 19),
          const SizedBox(width: 6),
          Expanded(
            child: Text('在线 ${room?.onlineViewers ?? room?.watching ?? '--'}'),
          ),
          TextButton(
            onPressed: _chooseQuality,
            child: Text(_activeSource?.quality.quality ?? '--'),
          ),
          TextButton(
            onPressed: _chooseLine,
            child: Text('线路 ${(_activeSource?.lineIndex ?? 0) + 1}'),
          ),
        ],
      ),
    ),
  );

  Widget _buildTabs() {
    const labels = ['弹幕列表', '醒目留言', '弹幕设置', '屏蔽列表'];
    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: labels.length,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (context, index) => TextButton(
          onPressed: () => _onTabSelected(index),
          child: Text(
            labels[index],
            style: TextStyle(
              color: _tabIndex == index
                  ? Theme.of(context).colorScheme.primary
                  : null,
              fontWeight: _tabIndex == index
                  ? FontWeight.w700
                  : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent() => KeyedSubtree(
    key: ValueKey('playback-tab-$_tabIndex-$_tabRevision'),
    child: switch (_tabIndex) {
      0 => _buildDanmakuList(),
      1 => _buildSuperChatList(),
      2 => _buildDanmakuSettings(),
      _ => _buildBlockList(),
    },
  );

  Widget _buildDanmakuList() {
    final messages = _visibleMessages;
    if (_danmakuError != null && messages.isEmpty) {
      return Center(child: Text(_danmakuError!));
    }
    if (messages.isEmpty) {
      return const Center(child: Text('等待直播间弹幕…'));
    }
    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[messages.length - index - 1];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            dense: true,
            leading: Icon(
              message.isLocal ? Icons.person_outline : Icons.circle,
              size: 12,
            ),
            title: Text(
              message.userName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(message.message),
            onLongPress: () => _showMessageActions(message),
          ),
        );
      },
    );
  }

  Future<void> _showMessageActions(LiveMessage message) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(title: Text(message.userName)),
            ListTile(
              leading: const Icon(Icons.block),
              title: const Text('屏蔽此用户'),
              onTap: () => Navigator.pop(context, 'user'),
            ),
            ListTile(
              leading: const Icon(Icons.text_fields),
              title: const Text('屏蔽这条关键词'),
              onTap: () => Navigator.pop(context, 'word'),
            ),
          ],
        ),
      ),
    );
    if (action == 'user' && message.userId.isNotEmpty)
      setState(() => _blockedUsers.add(message.userId));
    if (action == 'word' && message.message.trim().isNotEmpty)
      setState(() => _blockedWords.add(message.message.trim()));
    if (action != null) _notice('屏蔽规则已应用');
  }

  Widget _buildSuperChatList() {
    if (_loadingSuperChats)
      return const Center(child: CircularProgressIndicator());
    if (_superChats.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('暂无醒目留言'),
            TextButton.icon(
              onPressed: _loadSuperChats,
              icon: const Icon(Icons.refresh),
              label: const Text('刷新'),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _superChats.length,
      itemBuilder: (context, index) {
        final item = _superChats[index];
        return Card(
          child: ListTile(
            title: Text(item.userName),
            subtitle: Text(item.message),
            trailing: Text('¥${item.price}'),
          ),
        );
      },
    );
  }

  Widget _buildDanmakuSettings() => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      SwitchListTile(
        title: const Text('显示视频弹幕'),
        value: _danmakuEnabled,
        onChanged: (value) => setState(() => _danmakuEnabled = value),
      ),
      ListTile(
        title: const Text('弹幕透明度'),
        subtitle: Slider(
          value: _danmakuOpacity,
          onChanged: (value) => setState(() => _danmakuOpacity = value),
        ),
      ),
      ListTile(
        title: const Text('弹幕字号'),
        subtitle: Slider(
          value: _danmakuSize,
          min: 12,
          max: 30,
          divisions: 18,
          onChanged: (value) => setState(() => _danmakuSize = value),
        ),
      ),
      const Divider(),
      const ListTile(title: Text('弹幕显示密度模板')),
      Wrap(
        spacing: 8,
        children: [
          for (final preset in ['舒适', '均衡', '密集'])
            ActionChip(
              label: Text(preset),
              onPressed: () => setState(
                () => _danmakuSize = switch (preset) {
                  '舒适' => 16,
                  '均衡' => 18,
                  _ => 20,
                },
              ),
            ),
        ],
      ),
      const SizedBox(height: 16),
      ListTile(
        title: const Text('相似弹幕缓存时长'),
        subtitle: Slider(
          value: _cacheSeconds.toDouble(),
          min: 1,
          max: 30,
          divisions: 29,
          label: '$_cacheSeconds 秒',
          onChanged: (value) => setState(() => _cacheSeconds = value.round()),
        ),
      ),
      ListTile(
        title: const Text('最大缓存数量'),
        subtitle: Slider(
          value: _maxCacheCount.toDouble(),
          min: 20,
          max: 500,
          divisions: 24,
          label: '$_maxCacheCount',
          onChanged: (value) => setState(() => _maxCacheCount = value.round()),
        ),
      ),
    ],
  );

  Widget _buildBlockList() => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      SwitchListTile(
        title: const Text('启用相似弹幕过滤'),
        value: _similarFilterEnabled,
        onChanged: (value) => setState(() => _similarFilterEnabled = value),
      ),
      ListTile(
        title: const Text('相似度阈值'),
        subtitle: Slider(
          value: _similarity.toDouble(),
          min: 50,
          max: 100,
          divisions: 10,
          label: '$_similarity%',
          onChanged: (value) => setState(() => _similarity = value.round()),
        ),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _blockWordController,
        decoration: InputDecoration(
          labelText: '屏蔽关键词',
          suffixIcon: IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: _addBlockedWord,
          ),
        ),
        onSubmitted: (_) => _addBlockedWord(),
      ),
      const SizedBox(height: 8),
      for (final word in _blockedWords)
        ListTile(
          title: Text(word),
          trailing: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => setState(() => _blockedWords.remove(word)),
          ),
        ),
      for (final userId in _blockedUsers)
        ListTile(
          title: Text('用户 $userId'),
          trailing: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => setState(() => _blockedUsers.remove(userId)),
          ),
        ),
    ],
  );

  void _addBlockedWord() {
    final word = _blockWordController.text.trim();
    if (word.isEmpty) return;
    setState(() => _blockedWords.add(word));
    _blockWordController.clear();
  }

  Widget _buildCaptionBar() => SafeArea(
    top: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      child: Row(
        children: [
          IconButton(
            tooltip: '本地互动',
            onPressed: _showLocalInteraction,
            icon: const Icon(Icons.auto_awesome),
          ),
          Expanded(
            child: TextField(
              controller: _captionController,
              decoration: const InputDecoration(
                hintText: '发送本地弹幕',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendLocalCaption(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            tooltip: '仅本地发送',
            onPressed: _sendLocalCaption,
            icon: const Icon(Icons.send),
          ),
        ],
      ),
    ),
  );
}
