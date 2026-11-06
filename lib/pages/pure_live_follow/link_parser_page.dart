import 'dart:async';

import 'package:PiliPlus/common/widgets/native_navigation_occlusion.dart';
import 'package:PiliPlus/models/common/live_favorite.dart';
import 'package:PiliPlus/services/pure_live_playback_source.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pure_live/core/interface/live_site.dart';
import 'package:pure_live/core/site/bilibili/bilibili_site.dart';
import 'package:pure_live/core/site/douyu/douyu_site.dart';
import 'package:pure_live/core/site/huya/huya_site.dart';
import 'package:pure_live/plugins/locale_helper.dart';

enum _LinkParserAction { jump, directLink }

class PureLiveLinkTarget {
  const PureLiveLinkTarget({
    required this.platform,
    required this.roomId,
    required this.roomUrl,
  });

  final String platform;
  final String roomId;
  final String roomUrl;
}

class PureLiveLinkResolver {
  PureLiveLinkResolver({Map<String, LiveSite>? sites, Dio? httpClient})
    : _sites = Map.unmodifiable(
        sites ??
            <String, LiveSite>{
              'bilibili': BiliBiliSite(),
              'huya': HuyaSite(),
              'douyu': DouyuSite(),
            },
      ),
      _httpClient = httpClient ?? Dio();

  static const supportContent = '''支持以下类型的链接解析：

哔哩哔哩：
https://live.bilibili.com/xxxxx
https://www.bilibili.com/xxxxx
https://b23.tv/xxxxx

虎牙直播：
https://www.huya.com/xxxxx

斗鱼直播：
https://www.douyu.com/xxxxx''';

  static final _urlPattern = RegExp(
    r'(?:https?://|www\.)[^\s<>]+',
    caseSensitive: false,
  );
  static final _bilibiliRoomId = RegExp(r'^[1-9][0-9]{0,12}$');
  static final _roomSlug = RegExp(r'^[a-zA-Z0-9_-]+$');
  static const _reservedSlugs = {
    'search',
    'category',
    'directory',
    'video',
    'user',
    'login',
  };

  final Map<String, LiveSite> _sites;
  final Dio _httpClient;

  LiveSite siteFor(String platform) =>
      _sites[platform] ?? (throw UnsupportedError('暂不支持 $platform 直链解析'));

  bool containsSupportedLink(String text) => _sharedUris(text).any(
    (uri) => _isSupportedHost(uri.host.toLowerCase()),
  );

  Future<PureLiveLinkTarget?> resolve(
    String text, {
    CancelToken? cancelToken,
  }) async {
    for (final uri in _sharedUris(text)) {
      final host = uri.host.toLowerCase();
      if (host == 'b23.tv' || host == 'www.b23.tv') {
        final expanded = await _expandB23(uri, cancelToken: cancelToken);
        final target = expanded == null ? null : _targetFromUri(expanded);
        if (target != null) return target;
        continue;
      }
      final target = _targetFromUri(uri);
      if (target != null) return target;
    }
    return null;
  }

  Iterable<Uri> _sharedUris(String text) sync* {
    for (final match in _urlPattern.allMatches(text)) {
      var value = match.group(0)!;
      if (value.toLowerCase().startsWith('www.')) value = 'https://$value';
      value = value.replaceFirst(
        RegExp(r'''[.,!?;:)\]}。！？、，；：）》」』”’"']+$'''),
        '',
      );
      final uri = Uri.tryParse(value);
      if (uri == null ||
          !{'http', 'https'}.contains(uri.scheme.toLowerCase()) ||
          uri.host.isEmpty ||
          uri.userInfo.isNotEmpty ||
          uri.hasFragment) {
        continue;
      }
      yield uri;
    }
  }

  bool _isSupportedHost(String host) => const {
    'live.bilibili.com',
    'bilibili.com',
    'www.bilibili.com',
    'b23.tv',
    'www.b23.tv',
    'huya.com',
    'www.huya.com',
    'douyu.com',
    'www.douyu.com',
  }.contains(host);

  PureLiveLinkTarget? _targetFromUri(Uri uri) {
    final host = uri.host.toLowerCase();
    final segments = uri.pathSegments
        .where((segment) => segment.isNotEmpty)
        .toList(growable: false);
    if (segments.isEmpty) return null;
    final roomId = segments.first;
    if ((host == 'live.bilibili.com' ||
            host == 'bilibili.com' ||
            host == 'www.bilibili.com') &&
        _bilibiliRoomId.hasMatch(roomId)) {
      return PureLiveLinkTarget(
        platform: 'bilibili',
        roomId: roomId,
        roomUrl: 'https://live.bilibili.com/$roomId',
      );
    }
    if ((host == 'huya.com' || host == 'www.huya.com') &&
        _validRoomSlug(roomId)) {
      return PureLiveLinkTarget(
        platform: 'huya',
        roomId: roomId,
        roomUrl: 'https://www.huya.com/$roomId',
      );
    }
    if ((host == 'douyu.com' || host == 'www.douyu.com') &&
        _validRoomSlug(roomId)) {
      return PureLiveLinkTarget(
        platform: 'douyu',
        roomId: roomId,
        roomUrl: 'https://www.douyu.com/$roomId',
      );
    }
    return null;
  }

  bool _validRoomSlug(String value) =>
      _roomSlug.hasMatch(value) &&
      !_reservedSlugs.contains(value.toLowerCase());

  Future<Uri?> _expandB23(
    Uri uri, {
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _httpClient.getUri<Object?>(
        uri,
        cancelToken: cancelToken,
        options: Options(
          followRedirects: true,
          maxRedirects: 5,
          responseType: ResponseType.plain,
          validateStatus: (status) => status != null && status < 400,
        ),
      );
      return response.realUri;
    } on DioException {
      return null;
    }
  }
}

class PureLiveLinkParserPage extends StatefulWidget {
  const PureLiveLinkParserPage({
    super.key,
    this.resolver,
    this.onOpenRoom,
    this.copyText,
    this.notify,
    this.autoCheckClipboard = true,
  });

  final PureLiveLinkResolver? resolver;
  final Future<void> Function(PureLiveLinkTarget target)? onOpenRoom;
  final Future<void> Function(String text)? copyText;
  final void Function(String message)? notify;
  final bool autoCheckClipboard;

  @override
  State<PureLiveLinkParserPage> createState() => _PureLiveLinkParserPageState();
}

class _PureLiveLinkParserPageState extends State<PureLiveLinkParserPage> {
  static const _networkTimeout = Duration(seconds: 12);

  late final PureLiveLinkResolver _resolver;
  final _jumpController = TextEditingController();
  final _directController = TextEditingController();
  _LinkParserAction? _action;
  CancelToken? _cancelToken;
  int _actionRevision = 0;

  @override
  void initState() {
    super.initState();
    _resolver = widget.resolver ?? PureLiveLinkResolver();
    _jumpController.addListener(_cancelEditedAction);
    _directController.addListener(_cancelEditedAction);
    if (widget.autoCheckClipboard) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _checkClipboard());
    }
  }

  void _cancelEditedAction() {
    if (_action != null) _cancelAction();
  }

  void _cancelAction() {
    _actionRevision++;
    _cancelToken?.cancel('Link parser action cancelled');
    _cancelToken = null;
    if (mounted && _action != null) setState(() => _action = null);
  }

  Future<void> _runAction(
    String text,
    _LinkParserAction action,
    Future<void> Function(String text, int revision, CancelToken cancelToken)
    task,
  ) async {
    if (_action != null) return;
    text = text.trim();
    if (text.isEmpty) {
      _notify(i18n('toolbox_empty_link'));
      return;
    }
    final revision = ++_actionRevision;
    final cancelToken = CancelToken();
    _cancelToken = cancelToken;
    setState(() => _action = action);
    try {
      await task(text, revision, cancelToken);
    } on _LinkParserCancelled {
      // Editing, cancelling and leaving are user intent, not failures.
    } catch (_) {
      if (_isActionActive(revision)) {
        _notify(
          i18n(
            action == _LinkParserAction.jump
                ? 'toolbox_parse_failed'
                : 'toolbox_get_url_failed',
          ),
        );
      }
    } finally {
      if (_isActionActive(revision)) {
        _cancelToken = null;
        setState(() => _action = null);
      }
    }
  }

  bool _isActionActive(int revision) =>
      mounted &&
      revision == _actionRevision &&
      !(_cancelToken?.isCancelled ?? true);

  void _checkAction(int revision) {
    if (!_isActionActive(revision)) throw const _LinkParserCancelled();
  }

  Future<T> _network<T>(Future<T> request, int revision) async {
    final value = await request.timeout(_networkTimeout);
    _checkAction(revision);
    return value;
  }

  Future<PureLiveLinkTarget> _resolveTarget(
    String text,
    int revision,
    CancelToken cancelToken,
  ) async {
    final target = await _network(
      _resolver.resolve(text, cancelToken: cancelToken),
      revision,
    );
    if (target == null) throw const FormatException('Unsupported live link');
    return target;
  }

  Future<void> _jumpToRoom(
    String text,
    int revision,
    CancelToken cancelToken,
  ) async {
    final target = await _resolveTarget(text, revision, cancelToken);
    FocusManager.instance.primaryFocus?.unfocus();
    final onOpenRoom = widget.onOpenRoom;
    if (onOpenRoom != null) {
      await onOpenRoom(target);
    } else {
      await Get.toNamed<void>(
        '/pure_live/live_play',
        arguments: LiveFavorite(
          platformId: target.platform,
          roomId: target.roomId,
          roomUrl: target.roomUrl,
          title: '${_platformLabel(target.platform)} · ${target.roomId}',
          anchorName: _platformLabel(target.platform),
        ),
      );
    }
    _checkAction(revision);
  }

  Future<void> _getDirectLink(
    String text,
    int revision,
    CancelToken cancelToken,
  ) async {
    final target = await _resolveTarget(text, revision, cancelToken);
    FocusManager.instance.primaryFocus?.unfocus();
    final playback = PureLivePlaybackSource(
      _resolver.siteFor(target.platform),
    );
    final catalog = await _network(
      playback.discover(target.roomId),
      revision,
    );
    final qualityIndex = await _choose(
      title: i18n('toolbox_select_quality'),
      itemCount: catalog.qualities.length,
      titleFor: (index) => catalog.qualities[index].quality,
    );
    _checkAction(revision);
    if (qualityIndex == null) return;
    final source = await _network(
      playback.resolveSelection(catalog, qualityIndex: qualityIndex),
      revision,
    );
    final lineIndex = await _choose(
      title: i18n('toolbox_select_line'),
      itemCount: source.lines.length,
      titleFor: (index) => i18n(
        'toolbox_line',
        args: {'index': '${index + 1}'},
      ),
      subtitleFor: (index) => source.lines[index],
    );
    _checkAction(revision);
    if (lineIndex == null) return;
    final url = source.lines[lineIndex];
    final copyText = widget.copyText;
    if (copyText == null) {
      await Clipboard.setData(ClipboardData(text: url));
    } else {
      await copyText(url);
    }
    _checkAction(revision);
    _notify(i18n('toolbox_copy_success'));
  }

  Future<int?> _choose({
    required String title,
    required int itemCount,
    required String Function(int index) titleFor,
    String Function(int index)? subtitleFor,
  }) => showDialog<int>(
    context: context,
    builder: (dialogContext) {
      final mediaQuery = MediaQuery.of(dialogContext);
      final maxHeight =
          (mediaQuery.size.height -
                  mediaQuery.padding.vertical -
                  mediaQuery.viewInsets.vertical -
                  32)
              .clamp(160.0, double.infinity)
              .toDouble();
      return Dialog(
        key: const ValueKey('link-parser-choice-dialog'),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 560, maxHeight: maxHeight),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  title,
                  style: Theme.of(dialogContext).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var index = 0; index < itemCount; index++)
                          ListTile(
                            title: Text(
                              titleFor(index),
                              textAlign: TextAlign.center,
                            ),
                            subtitle: subtitleFor == null
                                ? null
                                : Text(
                                    subtitleFor(index),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                            onTap: () => Navigator.pop(dialogContext, index),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: Text(i18n('cancel')),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );

  Future<void> _checkClipboard() async {
    if (!mounted ||
        _jumpController.text.isNotEmpty ||
        _directController.text.isNotEmpty) {
      return;
    }
    try {
      final text = (await Clipboard.getData(Clipboard.kTextPlain))?.text;
      if (!mounted || text == null || !_resolver.containsSupportedLink(text)) {
        return;
      }
      _jumpController.text = text;
      _directController.text = text;
      _notify(i18n('toolbox_auto_fill'));
    } on PlatformException {
      // Clipboard access is optional on restricted platforms.
    }
  }

  void _notify(String message) {
    if (!mounted) return;
    final notify = widget.notify;
    if (notify == null) {
      SmartDialog.showToast(message);
    } else {
      notify(message);
    }
  }

  @override
  void dispose() {
    _cancelAction();
    _jumpController
      ..removeListener(_cancelEditedAction)
      ..dispose();
    _directController
      ..removeListener(_cancelEditedAction)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => NativeNavigationForeground(
    child: Scaffold(
      appBar: AppBar(
        title: Text(i18n('toolbox_title')),
        centerTitle: true,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        children: [
          _buildSection(
            key: const ValueKey('link-parser-room-jump'),
            title: i18n('toolbox_room_jump'),
            controller: _jumpController,
            action: _LinkParserAction.jump,
            buttonIcon: Icons.play_circle_outline,
            buttonLabel: i18n('toolbox_link_jump'),
            onPressed: () => _runAction(
              _jumpController.text,
              _LinkParserAction.jump,
              _jumpToRoom,
            ),
          ),
          const SizedBox(height: 32),
          _buildSection(
            key: const ValueKey('link-parser-direct-link'),
            title: i18n('toolbox_get_direct_link'),
            controller: _directController,
            action: _LinkParserAction.directLink,
            buttonIcon: Icons.download_outlined,
            buttonLabel: i18n('toolbox_get_parse'),
            onPressed: () => _runAction(
              _directController.text,
              _LinkParserAction.directLink,
              _getDirectLink,
            ),
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 18,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Text(
                i18n('toolbox_support_list'),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SelectableText(
            PureLiveLinkResolver.supportContent,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.65,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _buildSection({
    required Key key,
    required String title,
    required TextEditingController controller,
    required _LinkParserAction action,
    required IconData buttonIcon,
    required String buttonLabel,
    required VoidCallback onPressed,
  }) => Theme(
    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
    child: ExpansionTile(
      key: key,
      initiallyExpanded: true,
      tilePadding: const EdgeInsets.symmetric(horizontal: 16),
      childrenPadding: EdgeInsets.zero,
      title: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      children: [
        TextField(
          controller: controller,
          minLines: 3,
          maxLines: 5,
          keyboardType: TextInputType.url,
          decoration: InputDecoration(
            hintText: i18n('toolbox_input_hint'),
            filled: true,
            fillColor: Theme.of(context).colorScheme.surfaceContainer,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            suffixIcon: IconButton(
              tooltip: i18n('clear'),
              onPressed: controller.clear,
              icon: const Icon(Icons.cancel_outlined),
            ),
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _action == null ? onPressed : null,
            icon: _action == action
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(buttonIcon),
            label: Text(buttonLabel),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
        if (_action == action)
          Center(
            child: TextButton(
              onPressed: _cancelAction,
              child: Text(i18n('cancel')),
            ),
          ),
      ],
    ),
  );
}

class _LinkParserCancelled implements Exception {
  const _LinkParserCancelled();
}

String _platformLabel(String platform) => switch (platform) {
  'bilibili' => '哔哩哔哩',
  'huya' => '虎牙直播',
  'douyu' => '斗鱼直播',
  _ => platform,
};
