import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:PiliPlus/common/widgets/scaffold/simple_scaffold.dart';
import 'package:PiliPlus/pages/couple_space/cloudbase_repository.dart';
import 'package:PiliPlus/pages/couple_space/cloud_sync_coordinator.dart';
import 'package:PiliPlus/pages/couple_space/couple_space_model.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:media_kit/media_kit.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';

const _storeKey = 'coupleSpace.data.v1';
const _tabs = ['首页', '相册', '纪念日', '心语', '我的'];
const _cloudPhotoPrefix = 'cloud:';

class CoupleSpacePage extends StatefulWidget {
  const CoupleSpacePage({super.key, this.cloudRepository});

  final CoupleSpaceCloudRepository? cloudRepository;

  @override
  State<CoupleSpacePage> createState() => _CoupleSpacePageState();
}

class _MomentCommentDialog extends StatefulWidget {
  const _MomentCommentDialog({required this.initialValue});

  final String initialValue;

  @override
  State<_MomentCommentDialog> createState() => _MomentCommentDialogState();
}

class _MomentCommentDialogState extends State<_MomentCommentDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialValue,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('评论'),
    content: TextField(
      controller: _controller,
      autofocus: true,
      maxLength: 300,
      decoration: const InputDecoration(hintText: '说点什么…'),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, _controller.text.trim()),
        child: const Text('发送'),
      ),
    ],
  );
}

class CoupleSpaceTextInputDialog extends StatefulWidget {
  const CoupleSpaceTextInputDialog({
    super.key,
    required this.title,
    required this.initialValue,
    this.hint,
  });

  final String title;
  final String initialValue;
  final String? hint;

  @override
  State<CoupleSpaceTextInputDialog> createState() =>
      _CoupleSpaceTextInputDialogState();
}

class _CoupleSpaceTextInputDialogState
    extends State<CoupleSpaceTextInputDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialValue,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: TextField(
      controller: _controller,
      autofocus: true,
      decoration: InputDecoration(hintText: widget.hint),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, _controller.text.trim()),
        child: const Text('保存'),
      ),
    ],
  );
}

class _MomentDraftDialog extends StatefulWidget {
  const _MomentDraftDialog({required this.photoCount});

  final int photoCount;

  @override
  State<_MomentDraftDialog> createState() => _MomentDraftDialogState();
}

class _MomentDraftDialogState extends State<_MomentDraftDialog> {
  final _caption = TextEditingController();
  DateTime _publishedAt = DateTime.now();

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  Future<void> _pickPublishedAt() async {
    final day = await showDatePicker(
      context: context,
      initialDate: _publishedAt,
      firstDate: DateTime(1970),
      lastDate: DateTime(2100),
    );
    if (day == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_publishedAt),
    );
    if (time == null || !mounted) return;
    setState(() {
      _publishedAt = DateTime(
        day.year,
        day.month,
        day.day,
        time.hour,
        time.minute,
      );
    });
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('发布朋友圈'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('已选择 ${widget.photoCount} 张照片'),
        const SizedBox(height: 12),
        TextField(
          controller: _caption,
          maxLines: 4,
          maxLength: 500,
          decoration: const InputDecoration(
            hintText: '这一刻的想法…',
            border: OutlineInputBorder(),
          ),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.schedule_outlined),
          title: const Text('发布时间'),
          subtitle: Text(_formatMomentDateTime(_publishedAt)),
          onTap: _pickPublishedAt,
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, {
          'caption': _caption.text.trim(),
          'publishedAt': _publishedAt.toIso8601String(),
        }),
        child: const Text('发布'),
      ),
    ],
  );
}

class _AnniversaryDialog extends StatefulWidget {
  const _AnniversaryDialog({this.initialValue});

  final Map<String, dynamic>? initialValue;

  @override
  State<_AnniversaryDialog> createState() => _AnniversaryDialogState();
}

class _AnniversaryDialogState extends State<_AnniversaryDialog> {
  late final TextEditingController _title;
  late DateTime _date;
  late CoupleAnniversaryType _type;
  late CoupleAnniversaryRepeat _repeat;

  @override
  void initState() {
    super.initState();
    final value = widget.initialValue == null
        ? <String, dynamic>{}
        : normalizeCoupleAnniversary(widget.initialValue!);
    _title = TextEditingController(text: value['title']?.toString() ?? '');
    _date =
        DateTime.tryParse(value['date']?.toString() ?? '') ?? DateTime.now();
    _type = CoupleAnniversaryType.fromValue(value['type']);
    _repeat = CoupleAnniversaryRepeat.fromValue(value['repeat']);
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(1970),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.initialValue == null ? '添加纪念日' : '编辑纪念日'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _title,
          decoration: const InputDecoration(labelText: '纪念日名称'),
        ),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: _pickDate,
          icon: const Icon(Icons.calendar_month),
          label: Text(_formatDate(_date)),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<CoupleAnniversaryType>(
          initialValue: _type,
          decoration: const InputDecoration(labelText: '类型'),
          items: CoupleAnniversaryType.values
              .map(
                (type) => DropdownMenuItem(
                  value: type,
                  child: Text(type.label),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value == null) return;
            setState(() {
              _type = value;
              if (value == CoupleAnniversaryType.birthday ||
                  value == CoupleAnniversaryType.festival) {
                _repeat = CoupleAnniversaryRepeat.yearly;
              }
            });
          },
        ),
        const SizedBox(height: 12),
        SegmentedButton<CoupleAnniversaryRepeat>(
          segments: CoupleAnniversaryRepeat.values
              .map(
                (repeat) => ButtonSegment(
                  value: repeat,
                  label: Text(repeat.label),
                ),
              )
              .toList(),
          selected: {_repeat},
          onSelectionChanged: (value) {
            setState(() => _repeat = value.first);
          },
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(
        onPressed: () {
          if (_title.text.trim().isNotEmpty) {
            Navigator.pop(context, {
              ...?widget.initialValue,
              'title': _title.text.trim(),
              'date': _date.toIso8601String(),
              'type': _type.value,
              'repeat': _repeat.value,
            });
          }
        },
        child: const Text('保存'),
      ),
    ],
  );
}

String _formatMomentDateTime(DateTime date) =>
    '${date.year}年${date.month}月${date.day}日 ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

String _formatDate(dynamic raw) {
  final date = DateTime.tryParse(raw?.toString() ?? '') ?? DateTime.now();
  return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
}

class _CoupleSpacePageState extends State<CoupleSpacePage>
    with WidgetsBindingObserver {
  static const _cloudSyncInterval = Duration(seconds: 15);

  ColorScheme get _colors => ColorScheme.of(context);
  Color get _accent => _colors.primary;
  Color get _textColor => _colors.onSurface;
  Color get _mutedColor => _colors.onSurfaceVariant;
  late Map<String, dynamic> _data;
  late final Map<String, dynamic> _legacyData;
  late final CoupleSpaceCloudRepository _cloud;
  final _account = TextEditingController();
  final _password = TextEditingController();
  final _inviteCode = TextEditingController();
  final Map<String, String> _photoUrls = {};
  final AudioRecorder _voiceRecorder = AudioRecorder();
  final Uuid _uuid = const Uuid();
  CoupleSpaceCloudSnapshot? _snapshot;
  Future<void> _saveQueue = Future<void>.value();
  late final CoupleSpaceCloudSyncCoordinator _cloudSync;
  final List<StreamSubscription<dynamic>> _voicePlayerSubscriptions = [];
  Player? _voicePlayer;
  Future<Player?>? _voicePlayerInitialization;
  StreamSubscription<RecordState>? _voiceRecordStateSubscription;
  Timer? _dayRefreshTimer;
  Timer? _recordingTimer;
  int _pendingSaves = 0;
  bool _restoringSession = false;
  bool _busy = false;
  bool _recordingVoice = false;
  bool _uploadingVoice = false;
  bool _voicePlaying = false;
  int _recordingSeconds = 0;
  String? _recordingPath;
  String? _playingVoicePath;
  String? _cloudError;
  int _tab = 0;
  int _heartMode = 0;
  String _mood = '🥰';
  final _message = TextEditingController();
  final _task = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cloud = widget.cloudRepository ?? CoupleSpaceCloudRepository.appSession;
    final raw = GStorage.localCache.get(_storeKey);
    _data = raw is String
        ? Map<String, dynamic>.from(jsonDecode(raw))
        : _initialData();
    _normalizePayload(_data);
    _legacyData = Map<String, dynamic>.from(jsonDecode(jsonEncode(_data)));
    _restoringSession = _cloud.isSignedIn;
    _cloudSync = CoupleSpaceCloudSyncCoordinator(
      interval: _cloudSyncInterval,
      canSync: () =>
          mounted &&
          !_restoringSession &&
          !_busy &&
          _pendingSaves == 0 &&
          _cloud.isSignedIn &&
          _snapshot != null,
      sync: () => _loadCloudSpace(showMessage: false, skipIfUnchanged: true),
      onError: (error, stackTrace) {
        debugPrint('CoupleSpace background sync failed: $error\n$stackTrace');
      },
    )..start();
    WidgetsBinding.instance.addObserver(this);
    _scheduleDayRefresh();
    if (_restoringSession) {
      unawaited(_restoreCloudSession());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cloudSync.dispose();
    _dayRefreshTimer?.cancel();
    _recordingTimer?.cancel();
    for (final subscription in _voicePlayerSubscriptions) {
      unawaited(subscription.cancel());
    }
    unawaited(_voiceRecordStateSubscription?.cancel());
    final player = _voicePlayer;
    if (player != null) unawaited(player.dispose());
    unawaited(_voiceRecorder.cancel());
    unawaited(_voiceRecorder.dispose());
    _message.dispose();
    _task.dispose();
    _account.dispose();
    _password.dispose();
    _inviteCode.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (mounted) setState(() {});
      _scheduleDayRefresh();
      unawaited(_cloudSync.syncNow());
    } else if (_recordingVoice &&
        (state == AppLifecycleState.inactive ||
            state == AppLifecycleState.paused ||
            state == AppLifecycleState.detached)) {
      unawaited(_cancelVoiceRecording(showMessage: false));
    }
  }

  static Map<String, dynamic> _initialData() => {
    'spaceName': '我们的小窝',
    'nickname': '我',
    'partner': 'TA',
    'startDate': DateTime.now().toIso8601String(),
    'albums': <dynamic>[],
    'days': <dynamic>[],
    'messages': <dynamic>[],
    'tasks': <dynamic>[],
    'letter': '',
  };

  void _normalizePayload(Map<String, dynamic> payload) {
    final messages = List<Map<String, dynamic>>.from(
      (payload['messages'] as List? ?? const []).map(
        (item) => Map<String, dynamic>.from(item as Map),
      ),
    );
    for (var index = 0; index < messages.length; index++) {
      final item = messages[index];
      item
        ..['id'] = item['id']?.toString().isNotEmpty == true
            ? item['id']
            : 'legacy-message-$index-${item['date'] ?? ''}'
        ..['type'] = item['type'] == 'voice' ? 'voice' : 'text'
        ..['text'] = item['text']?.toString() ?? '';
    }
    payload['messages'] = messages;

    final days = List<Map<String, dynamic>>.from(
      (payload['days'] as List? ?? const []).map(
        (item) => normalizeCoupleAnniversary(
          Map<String, dynamic>.from(item as Map),
        ),
      ),
    );
    for (var index = 0; index < days.length; index++) {
      if (days[index]['id']?.toString().isEmpty ?? true) {
        days[index]['id'] = 'legacy-day-$index-${days[index]['date']}';
      }
    }
    payload['days'] = days;
  }

  void _scheduleDayRefresh() {
    _dayRefreshTimer?.cancel();
    final now = DateTime.now();
    final nextDay = DateTime(now.year, now.month, now.day + 1);
    _dayRefreshTimer = Timer(nextDay.difference(now), () {
      if (mounted) setState(() {});
      _scheduleDayRefresh();
    });
  }

  Future<Player?> _initializeVoicePlayer() {
    if (_voicePlayer case final player?) return Future.value(player);
    return _voicePlayerInitialization ??= _createVoicePlayer().whenComplete(
      () => _voicePlayerInitialization = null,
    );
  }

  Future<Player?> _createVoicePlayer() async {
    try {
      final player = await Player.create();
      if (!mounted) {
        await player.dispose();
        return null;
      }
      _voicePlayer = player;
      _voicePlayerSubscriptions
        ..add(
          player.stream.playing.listen((playing) {
            if (mounted) setState(() => _voicePlaying = playing);
          }),
        )
        ..add(
          player.stream.completed.listen((completed) {
            if (completed && mounted) {
              setState(() => _voicePlaying = false);
            }
          }),
        );
      return player;
    } catch (error, stackTrace) {
      debugPrint('CoupleSpace voice player init failed: $error\n$stackTrace');
      return null;
    }
  }

  Future<bool> _save() {
    final completer = Completer<bool>();
    final previous = _saveQueue;
    _pendingSaves += 1;
    _saveQueue = () async {
      await previous;
      try {
        completer.complete(await _saveNow());
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      } finally {
        _pendingSaves -= 1;
      }
    }();
    return completer.future;
  }

  Future<bool> _saveNow() async {
    final snapshot = _snapshot;
    if (snapshot == null) return false;
    _storeCurrentMemberName();
    await GStorage.localCache.put(_storeKey, jsonEncode(_data));
    if (mounted) setState(() {});
    try {
      final revision = await _cloud.saveState(
        spaceId: snapshot.spaceId,
        expectedRevision: snapshot.revision,
        payload: _data,
      );
      _snapshot = CoupleSpaceCloudSnapshot(
        spaceId: snapshot.spaceId,
        name: snapshot.name,
        memberA: snapshot.memberA,
        memberB: snapshot.memberB,
        revision: revision,
        payload: _data,
      );
      await GStorage.localCache.delete(
        'coupleSpace.cloud.pending.${snapshot.spaceId}',
      );
      return true;
    } on CoupleSpaceConflictException {
      await _loadCloudSpace(showMessage: false);
      _showMessage('TA 刚刚更新了小窝，已载入最新内容，请再操作一次');
      return false;
    } catch (error) {
      await GStorage.localCache.put(
        'coupleSpace.cloud.pending.${snapshot.spaceId}',
        snapshot.revision,
      );
      _showMessage('云端保存失败，本机副本已保留：$error');
      return false;
    }
  }

  void _storeCurrentMemberName() {
    final names = Map<String, dynamic>.from(
      _data['memberNames'] as Map? ?? const <String, dynamic>{},
    );
    names[_cloud.userId] = _data['nickname']?.toString() ?? _cloud.account;
    _data['memberNames'] = names;
  }

  Future<void> _applySnapshot(CoupleSpaceCloudSnapshot snapshot) async {
    final payload = snapshot.payload.isEmpty
        ? _initialData()
        : Map<String, dynamic>.from(jsonDecode(jsonEncode(snapshot.payload)));
    final names = Map<String, dynamic>.from(
      payload['memberNames'] as Map? ?? const <String, dynamic>{},
    );
    final otherId = snapshot.memberA == _cloud.userId
        ? snapshot.memberB
        : snapshot.memberA;
    payload['spaceName'] = payload['spaceName'] ?? snapshot.name;
    payload['nickname'] = names[_cloud.userId]?.toString() ?? _cloud.account;
    payload['partner'] = otherId == null
        ? '等待 TA 加入'
        : names[otherId]?.toString() ?? 'TA';
    _normalizePayload(payload);
    _snapshot = snapshot;
    _data = payload;
    await GStorage.localCache.put(_storeKey, jsonEncode(_data));
    unawaited(_resolveMediaUrls());
  }

  Future<void> _resolveMediaUrls() async {
    final photoKeys = _list('albums')
        .expand(_momentPhotos)
        .where((path) => path.startsWith(_cloudPhotoPrefix))
        .map((path) => path.substring(_cloudPhotoPrefix.length));
    final audioKeys = _list('messages')
        .where((message) => message['type'] == 'voice')
        .map((message) => message['audioPath']?.toString() ?? '')
        .where((path) => path.startsWith(_cloudPhotoPrefix))
        .map((path) => path.substring(_cloudPhotoPrefix.length));
    final keys = {...photoKeys, ...audioKeys};
    for (final key in keys) {
      try {
        _photoUrls[key] = await _cloud.signedMediaUrl(key);
      } catch (_) {
        // The tile keeps its explicit broken-image state until a later refresh.
      }
    }
    if (mounted) setState(() {});
  }

  Future<void> _signIn() async {
    if (_account.text.trim().isEmpty || _password.text.isEmpty) {
      setState(() => _cloudError = '请输入 CloudBase 用户名和密码');
      return;
    }
    await _runCloudAction(() async {
      await _cloud.signIn(
        account: _account.text.trim(),
        password: _password.text,
      );
      _password.clear();
      await _loadCloudSpace(showMessage: false);
    });
  }

  Future<void> _restoreCloudSession() async {
    try {
      final snapshot = await _cloud.loadSpace();
      if (!mounted) return;
      if (snapshot != null) await _applySnapshot(snapshot);
    } catch (error) {
      if (!mounted) return;
      _cloudError = error.toString();
    } finally {
      if (mounted) setState(() => _restoringSession = false);
    }
  }

  void _signOut() {
    setState(() {
      _cloud.signOut();
      _snapshot = null;
      _photoUrls.clear();
      _cloudError = null;
    });
  }

  Future<void> _loadCloudSpace({
    bool showMessage = true,
    bool skipIfUnchanged = false,
  }) async {
    var snapshot = await _cloud.loadSpace();
    if (snapshot != null) {
      final pendingKey = 'coupleSpace.cloud.pending.${snapshot.spaceId}';
      final pendingRevision = GStorage.localCache.get(pendingKey);
      if (pendingRevision is int && pendingRevision == snapshot.revision) {
        final revision = await _cloud.saveState(
          spaceId: snapshot.spaceId,
          expectedRevision: snapshot.revision,
          payload: _data,
        );
        await GStorage.localCache.delete(pendingKey);
        snapshot = CoupleSpaceCloudSnapshot(
          spaceId: snapshot.spaceId,
          name: snapshot.name,
          memberA: snapshot.memberA,
          memberB: snapshot.memberB,
          revision: revision,
          payload: _data,
        );
      } else if (pendingRevision != null) {
        _showMessage('云端已有新内容，本机未同步副本已保留但没有覆盖 TA 的更新');
      }
      final current = _snapshot;
      if (skipIfUnchanged &&
          pendingRevision == null &&
          current?.spaceId == snapshot.spaceId &&
          current?.revision == snapshot.revision) {
        return;
      }
      await _applySnapshot(snapshot);
    }
    if (mounted) setState(() {});
    if (showMessage) _showMessage('已同步 CloudBase 最新内容');
  }

  Future<void> _createSpace() async {
    await _runCloudAction(() async {
      final payload = _initialData();
      payload['nickname'] = _cloud.account;
      payload['memberNames'] = {_cloud.userId: _cloud.account};
      await _applySnapshot(await _cloud.createSpace(payload));
    });
  }

  Future<void> _confirmCreateSpace() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认由你创建小窝？'),
        content: const Text(
          '两个人只能共用一个小窝。只有第一个人需要创建；如果 TA 已经创建，请取消并在下方输入 TA 发来的邀请码，不能两个人各自创建。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('我要加入 TA 的小窝'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('我是第一个人，继续创建'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) await _createSpace();
  }

  Future<void> _joinSpace() async {
    if (_inviteCode.text.trim().isEmpty) return;
    await _runCloudAction(() async {
      await _applySnapshot(await _cloud.joinSpace(_inviteCode.text.trim()));
      _inviteCode.clear();
    });
  }

  Future<void> _runCloudAction(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _cloudError = null;
    });
    try {
      await action();
    } catch (error) {
      _cloudError = error.toString();
      if (_snapshot != null) _showMessage('CloudBase 操作失败：$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  List<Map<String, dynamic>> _list(String key) =>
      List<Map<String, dynamic>>.from(
        (_data[key] as List? ?? []).map((e) => Map<String, dynamic>.from(e)),
      );

  List<String> _momentPhotos(Map<String, dynamic> moment) {
    final photos = moment['photos'];
    if (photos is List) {
      return photos.map((path) => path.toString()).toList();
    }
    final legacyPath = moment['path']?.toString();
    return legacyPath == null ? const [] : [legacyPath];
  }

  DateTime _momentTime(Map<String, dynamic> moment) =>
      DateTime.tryParse(
        (moment['publishedAt'] ?? moment['date']).toString(),
      ) ??
      DateTime.now();

  int get _photoCount => _list('albums').fold<int>(
    0,
    (count, moment) => count + _momentPhotos(moment).length,
  );

  Future<void> _updateMoment(
    Map<String, dynamic> moment,
    Map<String, dynamic> updates,
  ) async {
    final paths = _momentPhotos(moment);
    final albums = _list('albums');
    final index = albums.indexWhere((entry) {
      final entryPaths = _momentPhotos(entry);
      return paths.isNotEmpty &&
          entryPaths.isNotEmpty &&
          entryPaths.first == paths.first;
    });
    if (index < 0) return;
    albums[index].addAll(updates);
    _data['albums'] = albums;
    await _save();
  }

  Future<void> _addMomentComment(Map<String, dynamic> moment) async {
    final comment = await showDialog<String>(
      context: context,
      builder: (context) => const _MomentCommentDialog(
        initialValue: '',
      ),
    );
    if (comment == null || comment.isEmpty) return;
    final comments =
        (moment['comments'] as List? ?? [])
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList()
          ..add({
            'author': _data['nickname']?.toString() ?? '我',
            'text': comment,
            'createdAt': DateTime.now().toIso8601String(),
          });
    await _updateMoment(moment, {'comments': comments});
  }

  Future<void> _editText(String title, String key, {String? hint}) async {
    final value = await showDialog<String>(
      context: context,
      builder: (context) => CoupleSpaceTextInputDialog(
        title: title,
        initialValue: _data[key]?.toString() ?? '',
        hint: hint,
      ),
    );
    if (value != null && value.isNotEmpty) {
      _data[key] = value;
      await _save();
    }
  }

  Future<void> _addPhoto() async {
    final picked = await FilePicker.pickFiles(
      type: FileType.image,
    );
    if (picked.isEmpty) return;
    if (!mounted) return;

    final selected = picked.take(9).toList();
    if (picked.length > 9 && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('每条朋友圈最多选择 9 张照片')));
    }
    final draft = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _MomentDraftDialog(photoCount: selected.length),
    );
    if (draft == null) return;

    final snapshot = _snapshot;
    if (snapshot == null) return;
    final albums = _list('albums');
    final paths = <String>[];
    setState(() => _busy = true);
    try {
      for (final file in selected) {
        if (file.path == null) continue;
        final key = await _cloud.uploadPhoto(
          spaceId: snapshot.spaceId,
          file: File(file.path!),
        );
        paths.add('$_cloudPhotoPrefix$key');
        _photoUrls[key] = await _cloud.signedPhotoUrl(key);
      }
    } catch (error) {
      _showMessage('照片上传失败：$error');
      for (final path in paths) {
        try {
          await _cloud.deletePhoto(path.substring(_cloudPhotoPrefix.length));
        } catch (cleanupError, cleanupStackTrace) {
          debugPrint(
            'CoupleSpace photo rollback failed for $path: $cleanupError\n'
            '$cleanupStackTrace',
          );
        }
      }
      return;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (paths.isEmpty) return;
    albums
      ..add({
        'photos': paths,
        'caption': draft['caption'],
        'publishedAt': draft['publishedAt'],
        'date': draft['publishedAt'],
        'type': '日常',
      })
      ..sort((a, b) => _momentTime(b).compareTo(_momentTime(a)));
    _data['albums'] = albums;
    await _save();
  }

  String _momentDateTime(DateTime date) => _formatMomentDateTime(date);

  Future<void> _addDay([Map<String, dynamic>? existing]) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _AnniversaryDialog(initialValue: existing),
    );
    if (result != null) {
      final days = _list('days');
      result['id'] = result['id']?.toString().isNotEmpty == true
          ? result['id']
          : _uuid.v4();
      final index = existing == null
          ? -1
          : days.indexWhere((item) => item['id'] == existing['id']);
      if (index == -1) {
        days.add(result);
      } else {
        days[index] = result;
      }
      _data['days'] = days;
      await _save();
    }
  }

  String _date(dynamic raw) => _formatDate(raw);

  int get _togetherDays => coupleTogetherDayNumber(
    DateTime.tryParse(_data['startDate'].toString()) ?? DateTime.now(),
    DateTime.now(),
  );

  List<Map<String, dynamic>> get _sortedAnniversaries =>
      sortCoupleAnniversaries(_list('days'), DateTime.now());

  Future<void> _startVoiceRecording() async {
    if (_recordingVoice || _uploadingVoice) return;
    try {
      await _voicePlayer?.pause();
      final permitted = await _voiceRecorder.hasPermission();
      if (!permitted) {
        _showMessage('需要允许麦克风权限才能录制语音心语');
        return;
      }
      final cache = await getTemporaryDirectory();
      final path = p.join(
        cache.path,
        'couple-voice-${DateTime.now().millisecondsSinceEpoch}.m4a',
      );
      await _voiceRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 64000,
          sampleRate: 44100,
          numChannels: 1,
          autoGain: true,
          echoCancel: true,
          noiseSuppress: true,
        ),
        path: path,
      );
      _voiceRecordStateSubscription ??= _voiceRecorder.onStateChanged().listen(
        (state) {
          if (!mounted) return;
          switch (state) {
            case RecordState.pause:
              _recordingTimer?.cancel();
              break;
            case RecordState.record:
              if (_recordingVoice) _startRecordingTimer();
              break;
            case RecordState.stop:
              _recordingTimer?.cancel();
              break;
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          debugPrint('CoupleSpace recorder state failed: $error\n$stackTrace');
        },
      );
      if (!mounted) return;
      setState(() {
        _recordingVoice = true;
        _recordingSeconds = 0;
        _recordingPath = path;
      });
      _startRecordingTimer();
    } catch (error) {
      _showMessage('无法开始录音：$error');
    }
  }

  void _startRecordingTimer() {
    _recordingTimer?.cancel();
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || !_recordingVoice) {
        timer.cancel();
        return;
      }
      setState(() => _recordingSeconds += 1);
      if (_recordingSeconds >= 120) {
        timer.cancel();
        unawaited(_stopAndSendVoiceRecording());
      }
    });
  }

  Future<void> _cancelVoiceRecording({bool showMessage = true}) async {
    _recordingTimer?.cancel();
    _recordingTimer = null;
    try {
      await _voiceRecorder.cancel();
    } catch (_) {
      final path = _recordingPath;
      if (path != null) {
        final file = File(path);
        if (file.existsSync()) await file.delete();
      }
    }
    if (!mounted) return;
    setState(() {
      _recordingVoice = false;
      _recordingSeconds = 0;
      _recordingPath = null;
    });
    if (showMessage) _showMessage('已取消这次录音');
  }

  Future<void> _stopAndSendVoiceRecording() async {
    if (!_recordingVoice || _uploadingVoice) return;
    _recordingTimer?.cancel();
    _recordingTimer = null;
    final durationMs = max(1000, _recordingSeconds * 1000);
    setState(() {
      _recordingVoice = false;
      _uploadingVoice = true;
    });
    String? localPath;
    String? uploadedKey;
    try {
      localPath = await _voiceRecorder.stop() ?? _recordingPath;
      final snapshot = _snapshot;
      if (snapshot == null || localPath == null) {
        throw const CoupleSpaceCloudException('录音文件没有生成');
      }
      final file = File(localPath);
      if (!file.existsSync() || file.lengthSync() == 0) {
        throw const CoupleSpaceCloudException('录音文件为空，请重新录制');
      }
      uploadedKey = await _cloud.uploadMedia(
        spaceId: snapshot.spaceId,
        file: file,
      );
      final audioPath = '$_cloudPhotoPrefix$uploadedKey';
      _photoUrls[uploadedKey] = await _cloud.signedMediaUrl(uploadedKey);
      final messages = _list('messages')
        ..insert(0, {
          'id': _uuid.v4(),
          'type': 'voice',
          'text': '',
          'audioPath': audioPath,
          'audioDurationMs': durationMs,
          'authorId': _cloud.userId,
          'authorName': _data['nickname']?.toString() ?? _cloud.account,
          'mood': _mood,
          'date': DateTime.now().toIso8601String(),
        });
      _data['messages'] = messages;
      if (!await _save()) {
        final pending = GStorage.localCache.get(
          'coupleSpace.cloud.pending.${snapshot.spaceId}',
        );
        if (pending != null) {
          uploadedKey = null;
          _showMessage('网络暂不可用，语音已保存在本机并会在恢复后同步');
          return;
        }
        throw const CoupleSpaceCloudException('语音尚未写入共享小窝');
      }
      _showMessage('语音心语已发送');
    } catch (error) {
      if (uploadedKey != null) {
        try {
          await _cloud.deleteMedia(uploadedKey);
          _photoUrls.remove(uploadedKey);
        } catch (cleanupError, cleanupStackTrace) {
          debugPrint(
            'CoupleSpace voice rollback failed: $cleanupError\n$cleanupStackTrace',
          );
        }
      }
      _showMessage('语音发送失败：$error');
    } finally {
      final path = localPath ?? _recordingPath;
      if (path != null) {
        try {
          final file = File(path);
          if (file.existsSync()) await file.delete();
        } catch (_) {}
      }
      if (mounted) {
        setState(() {
          _uploadingVoice = false;
          _recordingSeconds = 0;
          _recordingPath = null;
        });
      }
    }
  }

  Future<void> _toggleVoicePlayback(Map<String, dynamic> message) async {
    final player = _voicePlayer ?? await _initializeVoicePlayer();
    final path = message['audioPath']?.toString() ?? '';
    if (player == null) {
      _showMessage('语音播放器还在初始化，请稍后重试');
      return;
    }
    if (!path.startsWith(_cloudPhotoPrefix)) {
      _showMessage('这条语音缺少有效的云端文件');
      return;
    }
    try {
      if (_playingVoicePath == path) {
        await player.playOrPause();
        return;
      }
      final key = path.substring(_cloudPhotoPrefix.length);
      final url = await _cloud.signedMediaUrl(key);
      _photoUrls[key] = url;
      setState(() => _playingVoicePath = path);
      await player.open(Media(url), play: true);
    } catch (error) {
      _showMessage('语音播放失败：$error');
    }
  }

  Future<void> _deleteMessage(Map<String, dynamic> message) async {
    final id = message['id']?.toString();
    final messages = _list('messages')
      ..removeWhere((item) => item['id']?.toString() == id);
    _data['messages'] = messages;
    if (!await _save()) return;
    final audioPath = message['audioPath']?.toString() ?? '';
    if (audioPath.startsWith(_cloudPhotoPrefix)) {
      final key = audioPath.substring(_cloudPhotoPrefix.length);
      try {
        if (_playingVoicePath == audioPath) {
          await _voicePlayer?.stop();
          _playingVoicePath = null;
        }
        await _cloud.deleteMedia(key);
        _photoUrls.remove(key);
      } catch (error) {
        _showMessage('心语已删除，但语音文件清理失败：$error');
      }
    }
  }

  String _voiceDuration(Object? raw) {
    final totalSeconds = ((raw as num?)?.toInt() ?? 0) ~/ 1000;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (_restoringSession) return _sessionRestorePage();
    if (!_cloud.isSignedIn) return _loginPage();
    if (_snapshot == null) return _spaceSetupPage();
    return SimpleScaffold(
      appBar: AppBar(
        title: Text(_tabs[_tab]),
        actions: [
          IconButton(
            tooltip: '同步 CloudBase',
            onPressed: _busy ? null : () => _runCloudAction(_loadCloudSpace),
            icon: _busy
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.cloud_sync_outlined),
          ),
          if (_tab == 0)
            IconButton(
              onPressed: () => _editText('空间设置', 'spaceName'),
              icon: const Icon(Icons.settings_outlined),
            ),
        ],
      ),
      body: Column(
        children: [
          _topNavigation(),
          Expanded(
            child: IndexedStack(
              index: _tab,
              children: [
                _home(),
                _album(),
                _anniversaries(),
                _heartTalk(),
                _profile(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sessionRestorePage() => SimpleScaffold(
    appBar: AppBar(title: const Text('小窝')),
    body: const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('正在恢复小窝登录…'),
        ],
      ),
    ),
  );

  Widget _loginPage() => SimpleScaffold(
    appBar: AppBar(title: const Text('登录小窝')),
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.cloud_outlined, size: 50, color: _accent),
                  const SizedBox(height: 14),
                  Text(
                    'CloudBase 私密小窝',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _textColor,
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '使用云开发用户名和密码登录。照片与记录只对小窝的两位成员开放。',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _mutedColor),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _account,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      labelText: 'CloudBase 用户名',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _password,
                    obscureText: true,
                    onSubmitted: (_) => _signIn(),
                    decoration: const InputDecoration(
                      labelText: '密码',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                  ),
                  if (_cloudError != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _cloudError!,
                      style: TextStyle(color: _colors.error, fontSize: 12),
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: _busy ? null : _signIn,
                    icon: _busy
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.login),
                    label: const Text('登录'),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '账号需先在 CloudBase 身份认证中创建；应用不会保存密码。',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: _mutedColor),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _spaceSetupPage() => SimpleScaffold(
    appBar: AppBar(
      title: const Text('连接小窝'),
      actions: [
        TextButton(
          onPressed: _signOut,
          child: const Text('退出'),
        ),
      ],
    ),
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '你好，${_cloud.account}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _textColor,
                  fontSize: 23,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '第一个人创建小窝并生成邀请码，第二个人输入邀请码加入。',
                textAlign: TextAlign.center,
                style: TextStyle(color: _mutedColor),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _busy ? null : _confirmCreateSpace,
                icon: const Icon(Icons.home_outlined),
                label: const Text('创建我们的小窝'),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 18),
                child: Row(
                  children: [
                    Expanded(child: Divider()),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text('或者'),
                    ),
                    Expanded(child: Divider()),
                  ],
                ),
              ),
              TextField(
                controller: _inviteCode,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'TA 发来的邀请码',
                  prefixIcon: Icon(Icons.key_outlined),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _busy ? null : _joinSpace,
                icon: const Icon(Icons.favorite_border),
                label: const Text('加入小窝'),
              ),
              if (_cloudError != null) ...[
                const SizedBox(height: 14),
                Text(
                  _cloudError!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _colors.error),
                ),
              ],
              if (_busy) ...[
                const SizedBox(height: 18),
                const Center(child: CircularProgressIndicator()),
              ],
            ],
          ),
        ),
      ),
    ),
  );

  Widget _topNavigation() => Container(
    margin: const EdgeInsets.fromLTRB(12, 2, 12, 8),
    padding: const EdgeInsets.all(5),
    decoration: BoxDecoration(
      color: _colors.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(24),
    ),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(
          _tabs.length,
          (i) => Padding(
            padding: const EdgeInsets.only(right: 4),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => setState(() => _tab = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: i == _tab
                      ? _colors.secondaryContainer
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      [
                        Icons.home_rounded,
                        Icons.photo_library_outlined,
                        Icons.event_available_outlined,
                        Icons.chat_bubble_outline,
                        Icons.person_outline,
                      ][i],
                      size: 18,
                      color: i == _tab
                          ? _accent
                          : _textColor.withValues(alpha: .7),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _tabs[i],
                      style: TextStyle(
                        fontSize: 12,
                        color: i == _tab
                            ? _accent
                            : _textColor.withValues(alpha: .72),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _scroll(List<Widget> children) => ListView(
    padding: const EdgeInsets.fromLTRB(16, 2, 16, 24),
    children: children,
  );
  Widget _card({
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(16),
  }) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: padding,
    decoration: BoxDecoration(
      color: _colors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(22),
      boxShadow: [
        BoxShadow(
          color: _accent.withValues(alpha: .06),
          blurRadius: 14,
          offset: const Offset(0, 5),
        ),
      ],
    ),
    child: Material(
      type: MaterialType.transparency,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: child,
    ),
  );
  Widget _heading(String title, {Widget? action}) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 4, 4, 10),
    child: Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: _textColor,
            ),
          ),
        ),
        ?action,
      ],
    ),
  );

  Widget _home() => LayoutBuilder(
    builder: (context, constraints) {
      final wide = constraints.maxWidth >= 720;
      final anniversaries = _sortedAnniversaries;
      final next = anniversaries.isEmpty ? null : anniversaries.first;
      final recentMessages = _list('messages').take(3).toList();
      final hero = _homeHero();
      final nextDay = _nextAnniversaryCard(next);
      final sharedLife = _sharedLifeSummary();
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          if (wide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 6, child: hero),
                const SizedBox(width: 16),
                Expanded(
                  flex: 4,
                  child: Column(
                    children: [nextDay, sharedLife],
                  ),
                ),
              ],
            )
          else ...[
            hero,
            nextDay,
            sharedLife,
          ],
          _heading('今天，想一起做什么？'),
          LayoutBuilder(
            builder: (context, actionConstraints) {
              final columns = actionConstraints.maxWidth >= 560 ? 4 : 2;
              final width =
                  (actionConstraints.maxWidth - (columns - 1) * 10) / columns;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _quickAction(
                    width,
                    Icons.edit_note_rounded,
                    '写心语',
                    '把此刻说给 TA',
                    () => setState(() {
                      _heartMode = 0;
                      _tab = 3;
                    }),
                  ),
                  _quickAction(
                    width,
                    Icons.mic_rounded,
                    '发语音',
                    '听见真实的声音',
                    () => setState(() {
                      _heartMode = 1;
                      _tab = 3;
                    }),
                  ),
                  _quickAction(
                    width,
                    Icons.add_photo_alternate_outlined,
                    '记照片',
                    '收藏今天的瞬间',
                    _addPhoto,
                  ),
                  _quickAction(
                    width,
                    Icons.event_available_outlined,
                    '加纪念日',
                    '给期待一个日期',
                    _addDay,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          _heading(
            '最近的心意',
            action: TextButton(
              onPressed: () => setState(() => _tab = 3),
              child: const Text('查看全部'),
            ),
          ),
          if (recentMessages.isEmpty)
            _card(
              child: Text(
                '还没有心语。第一句话、第一段声音，都可以从今天开始。',
                style: TextStyle(color: _mutedColor),
              ),
            )
          else
            ...recentMessages.map(_messageCard),
        ],
      );
    },
  );

  Widget _homeHero() => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [_colors.primaryContainer, _colors.tertiaryContainer],
      ),
      borderRadius: BorderRadius.circular(30),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                _data['spaceName'].toString(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: _colors.onPrimaryContainer,
                ),
              ),
            ),
            Icon(
              Icons.favorite_rounded,
              color: _colors.onTertiaryContainer,
              size: 20,
            ),
          ],
        ),
        const SizedBox(height: 26),
        Text(
          _togetherDays == 0 ? '我们的故事即将开始' : '和 ${_data['partner']} 在一起',
          style: TextStyle(color: _colors.onPrimaryContainer),
        ),
        const SizedBox(height: 2),
        if (_togetherDays > 0)
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: Text(
                  '$_togetherDays',
                  style: TextStyle(
                    height: 1,
                    fontSize: 54,
                    fontWeight: FontWeight.w700,
                    color: _colors.onPrimaryContainer,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 8, bottom: 5),
                child: Text(
                  '天',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: _colors.onPrimaryContainer,
                  ),
                ),
              ),
            ],
          ),
        const SizedBox(height: 18),
        Text(
          '从 ${_date(_data['startDate'])} 开始 · 起始日算第 1 天',
          style: TextStyle(
            fontSize: 12,
            color: _colors.onPrimaryContainer.withValues(alpha: .76),
          ),
        ),
      ],
    ),
  );

  Widget _nextAnniversaryCard(Map<String, dynamic>? item) {
    if (item == null) {
      return _card(
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.calendar_month_outlined, color: _accent),
          title: const Text('下一个值得期待的日子'),
          subtitle: const Text('添加生日、周年或共同计划'),
          trailing: const Icon(Icons.add_rounded),
          onTap: _addDay,
        ),
      );
    }
    final status = coupleAnniversaryStatus(item, DateTime.now());
    final type = CoupleAnniversaryType.fromValue(item['type']);
    return _card(
      child: InkWell(
        onTap: () => setState(() => _tab = 2),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('下一纪念日', style: TextStyle(color: _mutedColor)),
              const SizedBox(height: 12),
              Text(
                item['title'].toString(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w600,
                  color: _textColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                status.label,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: _accent,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${type.label} · ${_date(status.occurrence)}',
                style: TextStyle(fontSize: 12, color: _mutedColor),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sharedLifeSummary() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _heading(
        '共同生活',
        action: TextButton(
          onPressed: () => setState(() => _tab = 1),
          child: const Text('去相册'),
        ),
      ),
      _card(
        child: Row(
          children: [
            Expanded(child: _stat('📷', '照片', _photoCount)),
            Expanded(child: _stat('💌', '心语', _list('messages').length)),
            Expanded(child: _stat('✅', '清单', _list('tasks').length)),
            Expanded(child: _stat('🎂', '纪念日', _list('days').length)),
          ],
        ),
      ),
    ],
  );

  Widget _quickAction(
    double width,
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) => SizedBox(
    width: width,
    child: Material(
      color: _colors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: _accent),
              const SizedBox(height: 12),
              Text(
                title,
                style: TextStyle(
                  color: _textColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: _mutedColor),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _messageCard(Map<String, dynamic> message) {
    final isVoice = message['type'] == 'voice';
    final audioPath = message['audioPath']?.toString() ?? '';
    final isCurrent = audioPath.isNotEmpty && _playingVoicePath == audioPath;
    final author = message['authorName']?.toString().isNotEmpty == true
        ? message['authorName'].toString()
        : '我们';
    final date = DateTime.tryParse(message['date']?.toString() ?? '');
    return _card(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: _colors.secondaryContainer,
            child: Text(message['mood']?.toString() ?? '🥰'),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        author,
                        style: TextStyle(
                          color: _accent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      date == null ? '' : _formatMomentDateTime(date),
                      style: TextStyle(fontSize: 10, color: _mutedColor),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (isVoice)
                  Semantics(
                    button: true,
                    label: isCurrent && _voicePlaying ? '暂停语音' : '播放语音',
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () => _toggleVoicePlayback(message),
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 48),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: _colors.secondaryContainer,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isCurrent && _voicePlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              color: _colors.onSecondaryContainer,
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              Icons.graphic_eq_rounded,
                              color: _colors.onSecondaryContainer,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _voiceDuration(message['audioDurationMs']),
                              style: TextStyle(
                                color: _colors.onSecondaryContainer,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  Text(
                    message['text']?.toString() ?? '',
                    style: TextStyle(color: _textColor, height: 1.45),
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: '删除心语',
            visualDensity: VisualDensity.compact,
            onPressed: () => _confirmDelete(
              isVoice ? '删除这条语音心语？' : '删除这条心语？',
              () => _deleteMessage(message),
            ),
            icon: Icon(Icons.more_horiz, color: _mutedColor),
          ),
        ],
      ),
    );
  }

  Widget _stat(String emoji, String label, int count) => Column(
    children: [
      Text(emoji, style: const TextStyle(fontSize: 21)),
      const SizedBox(height: 5),
      Text(
        '$count',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: _textColor,
        ),
      ),
      Text(label, style: TextStyle(fontSize: 11, color: _mutedColor)),
    ],
  );

  Widget _album() {
    final moments = _list('albums')
      ..sort((a, b) => _momentTime(b).compareTo(_momentTime(a)));
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: _heading(
                  '朋友圈',
                  action: Text(
                    '$_photoCount 张照片',
                    style: TextStyle(fontSize: 12, color: _mutedColor),
                  ),
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: _addPhoto,
                icon: const Icon(Icons.add_a_photo_outlined),
                label: const Text('发照片'),
              ),
            ],
          ),
        ),
        Expanded(
          child: moments.isEmpty
              ? _empty(
                  '还没有朋友圈',
                  '选几张照片，记录你们的小窝日常',
                  Icons.photo_library_outlined,
                  action: FilledButton.tonalIcon(
                    onPressed: _addPhoto,
                    icon: const Icon(Icons.add_a_photo_outlined),
                    label: const Text('发布第一条'),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: moments.length,
                  itemBuilder: (context, index) {
                    final moment = moments[index];
                    final date = _momentTime(moment);
                    final previousDate = index == 0
                        ? null
                        : _momentTime(moments[index - 1]);
                    final beginsMonth =
                        previousDate == null ||
                        previousDate.year != date.year ||
                        previousDate.month != date.month;
                    return Column(
                      children: [
                        if (beginsMonth)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                '${date.year}年${date.month}月',
                                style: TextStyle(
                                  color: _mutedColor,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        _momentTile(moment, date),
                        if (index != moments.length - 1)
                          Divider(height: 1, color: _colors.outlineVariant),
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _momentTile(Map<String, dynamic> moment, DateTime date) {
    final photos = _momentPhotos(moment);
    final caption = moment['caption']?.toString() ?? '';
    final nickname = _data['nickname']?.toString() ?? '我';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 48,
            child: Column(
              children: [
                Text(
                  '${date.day}',
                  style: TextStyle(
                    fontSize: 24,
                    height: 1.05,
                    fontWeight: FontWeight.w600,
                    color: _textColor,
                  ),
                ),
                Text(
                  '${date.month}月',
                  style: TextStyle(fontSize: 12, color: _mutedColor),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 13,
                      backgroundColor: _colors.secondaryContainer,
                      child: Text(
                        nickname.isEmpty ? '我' : nickname.characters.first,
                        style: TextStyle(
                          fontSize: 12,
                          color: _colors.onSecondaryContainer,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        nickname,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: _accent,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: '删除这条动态',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _confirmDelete('删除这条朋友圈？', () async {
                        final albums = _list('albums')
                          ..removeWhere(
                            (entry) =>
                                _momentPhotos(entry).any(photos.contains),
                          );
                        _data['albums'] = albums;
                        if (!await _save()) return;
                        for (final path in photos) {
                          try {
                            if (path.startsWith(_cloudPhotoPrefix)) {
                              final key = path.substring(
                                _cloudPhotoPrefix.length,
                              );
                              await _cloud.deletePhoto(key);
                              _photoUrls.remove(key);
                            } else {
                              final file = File(path);
                              if (file.existsSync()) await file.delete();
                            }
                          } catch (error) {
                            _showMessage('动态已删除，但照片清理失败：$error');
                          }
                        }
                      }),
                      icon: Icon(
                        Icons.more_horiz,
                        color: _mutedColor,
                      ),
                    ),
                  ],
                ),
                if (caption.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(caption, style: TextStyle(color: _textColor)),
                ],
                if (photos.isNotEmpty) ...[
                  const SizedBox(height: 9),
                  _momentPhotoGrid(photos),
                ],
                const SizedBox(height: 6),
                Text(
                  _momentDateTime(date),
                  style: TextStyle(fontSize: 11, color: _mutedColor),
                ),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: () => _updateMoment(moment, {
                        'liked': moment['liked'] != true,
                      }),
                      icon: Icon(
                        moment['liked'] == true
                            ? Icons.favorite
                            : Icons.favorite_border,
                        size: 17,
                        color: moment['liked'] == true ? _accent : _mutedColor,
                      ),
                      label: Text(
                        moment['liked'] == true ? '已赞' : '赞',
                        style: TextStyle(color: _mutedColor),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => _addMomentComment(moment),
                      icon: Icon(
                        Icons.mode_comment_outlined,
                        size: 17,
                        color: _mutedColor,
                      ),
                      label: Text(
                        '评论',
                        style: TextStyle(color: _mutedColor),
                      ),
                    ),
                  ],
                ),
                if ((moment['comments'] as List? ?? []).isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: _colors.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: (moment['comments'] as List).map((item) {
                        final comment = Map<String, dynamic>.from(
                          item as Map,
                        );
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: RichText(
                            text: TextSpan(
                              style: TextStyle(
                                fontSize: 12,
                                color: _textColor,
                              ),
                              children: [
                                TextSpan(
                                  text: '${comment['author']}: ',
                                  style: TextStyle(
                                    color: _accent,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                TextSpan(text: comment['text'].toString()),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _momentPhotoGrid(List<String> paths) {
    final count = min(paths.length, 9);
    final columns = count == 1 ? 1 : (count == 4 ? 2 : 3);
    final tileSize = count == 1 ? 156.0 : 94.0;
    const spacing = 4.0;
    return SizedBox(
      width: tileSize * columns + spacing * (columns - 1),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: count,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          crossAxisSpacing: spacing,
          mainAxisSpacing: spacing,
        ),
        itemBuilder: (context, index) => GestureDetector(
          onTap: () => _showMomentPhoto(paths[index]),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: _photo(paths[index], fit: BoxFit.cover),
          ),
        ),
      ),
    );
  }

  Future<void> _showMomentPhoto(String path) => showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: Colors.black,
      insetPadding: EdgeInsets.zero,
      child: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: InteractiveViewer(
          child: _photo(path, fit: BoxFit.contain, darkFallback: true),
        ),
      ),
    ),
  );

  Widget _photo(
    String path, {
    required BoxFit fit,
    bool darkFallback = false,
  }) {
    final fallback = ColoredBox(
      color: darkFallback ? Colors.black : _colors.surfaceContainerHighest,
      child: Icon(
        Icons.broken_image_outlined,
        color: darkFallback ? Colors.white : _accent,
        size: darkFallback ? 48 : 24,
      ),
    );
    if (!path.startsWith(_cloudPhotoPrefix)) {
      return Image.file(
        File(path),
        fit: fit,
        errorBuilder: (_, _, _) => fallback,
      );
    }
    final key = path.substring(_cloudPhotoPrefix.length);
    final url = _photoUrls[key];
    if (url == null) return fallback;
    return Image.network(
      url,
      fit: fit,
      errorBuilder: (_, _, _) => fallback,
    );
  }

  Widget _anniversaries() {
    final days = _sortedAnniversaries;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(child: _heading('我们的纪念日')),
              FilledButton.tonalIcon(
                onPressed: _addDay,
                icon: const Icon(Icons.add_rounded),
                label: const Text('添加'),
              ),
            ],
          ),
        ),
        Expanded(
          child: days.isEmpty
              ? _empty(
                  '记录第一个重要日子',
                  '生日、周年、旅行计划，都可以自动计算倒数或已经过去的天数',
                  Icons.calendar_month_outlined,
                  action: FilledButton.tonal(
                    onPressed: _addDay,
                    child: const Text('添加第一个日子'),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: days.length,
                  itemBuilder: (context, i) {
                    final item = days[i];
                    final type = CoupleAnniversaryType.fromValue(item['type']);
                    final repeat = CoupleAnniversaryRepeat.fromValue(
                      item['repeat'],
                    );
                    final status = coupleAnniversaryStatus(
                      item,
                      DateTime.now(),
                    );
                    return _card(
                      padding: EdgeInsets.zero,
                      child: InkWell(
                        onTap: () => _addDay(item),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
                          child: Row(
                            children: [
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: _colors.secondaryContainer,
                                  borderRadius: BorderRadius.circular(17),
                                ),
                                child: Icon(
                                  _anniversaryIcon(type),
                                  color: _colors.onSecondaryContainer,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item['title'].toString(),
                                      style: TextStyle(
                                        color: _textColor,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      '${_date(status.occurrence)} · ${type.label}'
                                      '${repeat == CoupleAnniversaryRepeat.yearly ? ' · 每年' : ''}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: _mutedColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                status.label,
                                style: TextStyle(
                                  color: status.isUpcoming
                                      ? _accent
                                      : _mutedColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              PopupMenuButton<String>(
                                tooltip: '纪念日操作',
                                onSelected: (action) {
                                  if (action == 'edit') {
                                    _addDay(item);
                                  } else if (action == 'delete') {
                                    _confirmDelete('删除这个纪念日？', () async {
                                      final updated = _list('days')
                                        ..removeWhere(
                                          (day) => day['id'] == item['id'],
                                        );
                                      _data['days'] = updated;
                                      await _save();
                                    });
                                  }
                                },
                                itemBuilder: (context) => const [
                                  PopupMenuItem(
                                    value: 'edit',
                                    child: Text('编辑'),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Text('删除'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  IconData _anniversaryIcon(CoupleAnniversaryType type) => switch (type) {
    CoupleAnniversaryType.love => Icons.favorite_rounded,
    CoupleAnniversaryType.birthday => Icons.cake_outlined,
    CoupleAnniversaryType.festival => Icons.celebration_outlined,
    CoupleAnniversaryType.custom => Icons.auto_awesome_outlined,
  };

  Widget _heartTalk() => _scroll([
    Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SegmentedButton<int>(
          segments: const [
            ButtonSegment(
              value: 0,
              icon: Icon(Icons.edit_note),
              label: Text('文字'),
            ),
            ButtonSegment(value: 1, icon: Icon(Icons.mic), label: Text('语音')),
            ButtonSegment(
              value: 2,
              icon: Icon(Icons.checklist_rounded),
              label: Text('一起做'),
            ),
          ],
          selected: {_heartMode},
          onSelectionChanged: (value) =>
              setState(() => _heartMode = value.first),
        ),
      ),
    ),
    if (_heartMode == 0) _textHeartComposer(),
    if (_heartMode == 1) _voiceHeartComposer(),
    if (_heartMode == 2) ..._taskWidgets(),
    if (_heartMode < 2) ...[
      _heading('我们的心语时间线'),
      if (_list('messages').isEmpty)
        _card(
          child: Text(
            '这里会按时间保存两个人的文字和声音。先留下一句吧。',
            style: TextStyle(color: _mutedColor),
          ),
        )
      else
        ..._list('messages').map(_messageCard),
    ],
  ]);

  Widget _textHeartComposer() => _card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '写给 ${_data['partner']}',
          style: TextStyle(
            color: _textColor,
            fontSize: 19,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Text('不用正式，想到什么就说什么。', style: TextStyle(color: _mutedColor)),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          children: ['🥰', '😊', '😘', '🤗', '🌙']
              .map(
                (mood) => InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: () => setState(() => _mood = mood),
                  child: CircleAvatar(
                    radius: 22,
                    backgroundColor: mood == _mood
                        ? _colors.secondaryContainer
                        : _colors.surfaceContainerHighest,
                    child: Text(mood),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _message,
          minLines: 3,
          maxLines: 6,
          maxLength: 240,
          decoration: InputDecoration(
            hintText: '今天有一句话想告诉 TA…',
            filled: true,
            fillColor: _colors.surfaceContainerLowest,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: () async {
              if (_message.text.trim().isEmpty) return;
              final items = _list('messages')
                ..insert(0, {
                  'id': _uuid.v4(),
                  'type': 'text',
                  'text': _message.text.trim(),
                  'authorId': _cloud.userId,
                  'authorName': _data['nickname']?.toString() ?? _cloud.account,
                  'mood': _mood,
                  'date': DateTime.now().toIso8601String(),
                });
              _data['messages'] = items;
              _message.clear();
              await _save();
            },
            icon: const Icon(Icons.send_rounded),
            label: const Text('发送'),
          ),
        ),
      ],
    ),
  );

  Widget _voiceHeartComposer() => _card(
    child: Column(
      children: [
        Text(
          _uploadingVoice
              ? '正在加密上传到你们的小窝…'
              : _recordingVoice
              ? '正在聆听你的声音'
              : '录一段只属于你们的声音',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _textColor,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _recordingVoice ? _recordingClock : '最长 2 分钟，松弛一点，像平时说话就好',
          style: TextStyle(color: _mutedColor),
        ),
        const SizedBox(height: 22),
        if (_uploadingVoice)
          const Padding(
            padding: EdgeInsets.all(24),
            child: CircularProgressIndicator(),
          )
        else
          Semantics(
            button: true,
            label: _recordingVoice ? '停止并发送录音' : '开始录音',
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: _recordingVoice
                  ? _stopAndSendVoiceRecording
                  : _startVoiceRecording,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _recordingVoice
                      ? _colors.errorContainer
                      : _colors.primaryContainer,
                  boxShadow: [
                    BoxShadow(
                      color: (_recordingVoice ? _colors.error : _accent)
                          .withValues(alpha: .18),
                      blurRadius: 24,
                    ),
                  ],
                ),
                child: Icon(
                  _recordingVoice ? Icons.stop_rounded : Icons.mic_rounded,
                  size: 40,
                  color: _recordingVoice
                      ? _colors.onErrorContainer
                      : _colors.onPrimaryContainer,
                ),
              ),
            ),
          ),
        if (_recordingVoice) ...[
          const SizedBox(height: 14),
          TextButton.icon(
            onPressed: _cancelVoiceRecording,
            icon: const Icon(Icons.close_rounded),
            label: const Text('取消这次录音'),
          ),
        ],
      ],
    ),
  );

  String get _recordingClock {
    final minutes = _recordingSeconds ~/ 60;
    final seconds = _recordingSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')} / 2:00';
  }

  List<Widget> _taskWidgets() => [
    _card(
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _task,
              decoration: const InputDecoration(
                hintText: '下次一起做什么？',
                border: InputBorder.none,
              ),
            ),
          ),
          IconButton(
            tooltip: '添加共同清单',
            onPressed: () async {
              if (_task.text.trim().isEmpty) return;
              final tasks = _list('tasks')
                ..insert(0, {
                  'id': _uuid.v4(),
                  'text': _task.text.trim(),
                  'done': false,
                  'createdAt': DateTime.now().toIso8601String(),
                });
              _data['tasks'] = tasks;
              _task.clear();
              await _save();
            },
            icon: Icon(Icons.add_circle, color: _accent),
          ),
        ],
      ),
    ),
    if (_list('tasks').isEmpty)
      _card(
        child: Text(
          '一起完成的小事，会比宏大的目标更常被记住。',
          style: TextStyle(color: _mutedColor),
        ),
      )
    else
      ..._list('tasks').asMap().entries.map(
        (entry) => _card(
          child: CheckboxListTile(
            value: entry.value['done'] == true,
            activeColor: _accent,
            contentPadding: EdgeInsets.zero,
            title: Text(
              entry.value['text'].toString(),
              style: TextStyle(
                decoration: entry.value['done'] == true
                    ? TextDecoration.lineThrough
                    : null,
              ),
            ),
            onChanged: (value) async {
              final tasks = _list('tasks');
              tasks[entry.key]['done'] = value;
              _data['tasks'] = tasks;
              await _save();
            },
            secondary: IconButton(
              tooltip: '删除清单',
              onPressed: () async {
                final tasks = _list('tasks')..removeAt(entry.key);
                _data['tasks'] = tasks;
                await _save();
              },
              icon: const Icon(Icons.delete_outline),
            ),
          ),
        ),
      ),
  ];

  Widget _profile() => _scroll([
    _card(
      child: Row(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: _colors.secondaryContainer,
            child: const Text('💗', style: TextStyle(fontSize: 25)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _data['nickname'].toString(),
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w600,
                    color: _textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '和 ${_data['partner']} 一起的第 $_togetherDays 天',
                  style: TextStyle(color: _mutedColor),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _editText('修改昵称', 'nickname'),
            icon: Icon(Icons.edit_outlined, color: _accent),
          ),
        ],
      ),
    ),
    _heading('我们的记录'),
    _card(
      child: Row(
        children: [
          Expanded(child: _stat('📸', '照片', _photoCount)),
          Expanded(child: _stat('💌', '留言', _list('messages').length)),
          Expanded(child: _stat('🗓️', '日子', _list('days').length)),
        ],
      ),
    ),
    _heading('空间与邀请'),
    _card(
      child: Column(
        children: [
          _profileAction(Icons.home_outlined, '空间设置', '空间名称与在一起的日子', () async {
            await _editText('空间名称', 'spaceName');
          }),
          const Divider(height: 18),
          _profileAction(
            Icons.calendar_month_outlined,
            '在一起的日子',
            _date(_data['startDate']),
            _pickStartDate,
          ),
          const Divider(height: 18),
          _profileAction(
            Icons.mail_outline,
            '写一封信',
            '保存一段想对 TA 说的话',
            () => _editText('给 TA 的信', 'letter', hint: '写下想说的话'),
          ),
          if (_hasLegacyData && !_legacyDataMigrated) ...[
            const Divider(height: 18),
            _profileAction(
              Icons.cloud_upload_outlined,
              '迁移本机旧数据',
              '把原来的照片和记录上传到当前小窝',
              _migrateLegacyData,
            ),
          ],
        ],
      ),
    ),
    _card(
      child: Row(
        children: [
          Icon(Icons.lock_outline, color: _accent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'CloudBase 私有存储 · 仅两位成员可见',
              style: TextStyle(color: _textColor),
            ),
          ),
          TextButton(
            onPressed: _createInvite,
            child: const Text('邀请 TA'),
          ),
        ],
      ),
    ),
    TextButton.icon(
      onPressed: _signOut,
      icon: const Icon(Icons.logout),
      label: const Text('退出小窝账号'),
    ),
  ]);

  bool get _hasLegacyData =>
      ['albums', 'days', 'messages', 'tasks'].any(
        (key) => (_legacyData[key] as List? ?? const []).isNotEmpty,
      ) ||
      (_legacyData['letter']?.toString().isNotEmpty ?? false);

  bool get _legacyDataMigrated {
    final spaceId = _snapshot?.spaceId;
    if (spaceId == null) return false;
    return GStorage.localCache.get('coupleSpace.migrated.$spaceId') == true;
  }

  Future<void> _migrateLegacyData() async {
    final snapshot = _snapshot;
    if (snapshot == null || _legacyDataMigrated) return;
    await _runCloudAction(() async {
      final migrated = Map<String, dynamic>.from(
        jsonDecode(jsonEncode(_legacyData)),
      );
      final albums = List<Map<String, dynamic>>.from(
        (migrated['albums'] as List? ?? const []).map(
          (item) => Map<String, dynamic>.from(item as Map),
        ),
      );
      for (final moment in albums) {
        final uploaded = <String>[];
        for (final path in _momentPhotos(moment)) {
          if (path.startsWith(_cloudPhotoPrefix)) {
            uploaded.add(path);
            continue;
          }
          final file = File(path);
          if (!file.existsSync()) continue;
          final key = await _cloud.uploadPhoto(
            spaceId: snapshot.spaceId,
            file: file,
          );
          uploaded.add('$_cloudPhotoPrefix$key');
          _photoUrls[key] = await _cloud.signedPhotoUrl(key);
        }
        moment['photos'] = uploaded;
        moment.remove('path');
      }
      migrated['albums'] = albums;
      migrated['memberNames'] = {
        ...Map<String, dynamic>.from(
          _data['memberNames'] as Map? ?? const <String, dynamic>{},
        ),
        _cloud.userId: migrated['nickname']?.toString() ?? _cloud.account,
      };
      _normalizePayload(migrated);
      _data = migrated;
      final saved = await _save();
      if (!saved) throw const CoupleSpaceCloudException('本机数据尚未写入云端');
      await GStorage.localCache.put(
        'coupleSpace.migrated.${snapshot.spaceId}',
        true,
      );
      _showMessage('本机旧数据已迁移到 CloudBase');
    });
  }

  Future<void> _createInvite() async {
    final snapshot = _snapshot;
    if (snapshot == null) return;
    await _runCloudAction(() async {
      final code = await _cloud.createInvite(snapshot.spaceId);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('邀请 TA 加入'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('邀请码 15 分钟内有效，只能使用一次：'),
              const SizedBox(height: 12),
              SelectableText(
                code,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('完成'),
            ),
          ],
        ),
      );
    });
  }

  Widget _profileAction(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(icon, color: _accent),
    title: Text(title, style: TextStyle(color: _textColor)),
    subtitle: Text(
      subtitle,
      style: TextStyle(fontSize: 12, color: _mutedColor),
    ),
    trailing: Icon(Icons.chevron_right, color: _mutedColor),
    onTap: onTap,
  );

  Future<void> _pickStartDate() async {
    final date =
        DateTime.tryParse(_data['startDate'].toString()) ?? DateTime.now();
    final result = await showDatePicker(
      context: context,
      initialDate: date,
      firstDate: DateTime(1970),
      lastDate: DateTime.now(),
    );
    if (result != null) {
      _data['startDate'] = result.toIso8601String();
      await _save();
    }
  }

  Widget _empty(
    String title,
    String subtitle,
    IconData icon, {
    Widget? action,
  }) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 82,
            height: 82,
            decoration: BoxDecoration(
              color: _colors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Icon(icon, size: 38, color: _accent),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w500,
              color: _textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(color: _mutedColor),
          ),
          if (action != null) ...[const SizedBox(height: 16), action],
        ],
      ),
    ),
  );

  Future<void> _confirmDelete(
    String title,
    Future<void> Function() action,
  ) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (yes == true) await action();
  }
}
