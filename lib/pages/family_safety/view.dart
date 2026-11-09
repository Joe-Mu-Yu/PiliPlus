import 'package:PiliPlus/pages/couple_space/cloudbase_repository.dart';
import 'package:PiliPlus/pages/family_safety/cloudbase_repository.dart';
import 'package:PiliPlus/pages/family_safety/location_service.dart';
import 'package:PiliPlus/pages/family_safety/model.dart';
import 'package:PiliPlus/utils/permission_handler.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class FamilySafetyPage extends StatefulWidget {
  const FamilySafetyPage({
    super.key,
    this.repository,
    this.locationService,
  });

  final FamilySafetyCloudRepository? repository;
  final FamilyLocationService? locationService;

  @override
  State<FamilySafetyPage> createState() => _FamilySafetyPageState();
}

class _FamilySafetyPageState extends State<FamilySafetyPage> {
  late final FamilySafetyCloudRepository _repository =
      widget.repository ?? FamilySafetyCloudRepository();
  late final FamilyLocationService _locationService =
      widget.locationService ?? FamilyLocationService();

  final _accountController = TextEditingController();
  final _passwordController = TextEditingController();
  final _familyNameController = TextEditingController(text: '我的家庭');
  final _inviteController = TextEditingController();
  final _messageController = TextEditingController(text: '请确认你现在是否安全');

  FamilySafetySnapshot? _snapshot;
  bool _loading = false;
  bool _consentAccepted = false;
  bool _passwordVisible = false;
  String? _inviteCode;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (_repository.isSignedIn) {
      _accountController.text = _repository.account;
      _load();
    }
  }

  @override
  void dispose() {
    _accountController.dispose();
    _passwordController.dispose();
    _familyNameController.dispose();
    _inviteController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await action();
    } on CoupleSpaceCloudException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on FamilyLocationException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
      if (error.canOpenSettings) {
        final open = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('需要位置权限'),
            content: Text(error.message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('打开设置'),
              ),
            ],
          ),
        );
        if (open == true) await openAppSettings();
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _load() => _run(() async {
    final snapshot = await _repository.loadSnapshot();
    if (mounted) {
      setState(() {
        _snapshot = snapshot;
        if (snapshot == null) _inviteCode = null;
      });
    }
  });

  Future<void> _signIn() => _run(() async {
    if (_accountController.text.trim().isEmpty ||
        _passwordController.text.isEmpty) {
      throw const CoupleSpaceCloudException('请输入云端账号和密码');
    }
    await _repository.signIn(
      account: _accountController.text,
      password: _passwordController.text,
    );
    _passwordController.clear();
    final snapshot = await _repository.loadSnapshot();
    if (mounted) setState(() => _snapshot = snapshot);
  });

  Future<void> _createGroup() => _run(() async {
    _requireConsent();
    await _repository.createGroup(_familyNameController.text);
    final snapshot = await _repository.loadSnapshot();
    if (mounted) setState(() => _snapshot = snapshot);
  });

  Future<void> _joinGroup() => _run(() async {
    _requireConsent();
    if (_inviteController.text.trim().isEmpty) {
      throw const CoupleSpaceCloudException('请输入被照护端生成的邀请码');
    }
    await _repository.joinGroup(_inviteController.text);
    _inviteController.clear();
    final snapshot = await _repository.loadSnapshot();
    if (mounted) setState(() => _snapshot = snapshot);
  });

  void _requireConsent() {
    if (!_consentAccepted) {
      throw const CoupleSpaceCloudException('请先阅读并确认位置共享规则');
    }
  }

  Future<void> _createInvite() => _run(() async {
    final group = _snapshot!.group;
    final invite = await _repository.createInvite(group.id);
    if (invite.isEmpty) {
      throw const CoupleSpaceCloudException('云端没有返回邀请码');
    }
    if (mounted) setState(() => _inviteCode = invite);
  });

  Future<void> _requestCheckIn() => _run(() async {
    await _repository.requestCheckIn(
      groupId: _snapshot!.group.id,
      message: _messageController.text,
    );
    final snapshot = await _repository.loadSnapshot();
    if (mounted) setState(() => _snapshot = snapshot);
  });

  Future<void> _shareLocation(FamilyCheckInRequest request) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('共享这一次位置？'),
        content: const Text(
          '确认后才会读取当前位置，并只向已绑定的照护端共享。云端仅保留最新一条，24 小时后失效；不会在后台持续定位。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确认并共享'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _run(() async {
      final location = await _locationService.captureOnce();
      await _repository.shareLocation(
        requestId: request.id,
        location: location,
      );
      final snapshot = await _repository.loadSnapshot();
      if (mounted) setState(() => _snapshot = snapshot);
    });
  }

  Future<void> _decline(FamilyCheckInRequest request) => _run(() async {
    await _repository.declineCheckIn(request.id);
    final snapshot = await _repository.loadSnapshot();
    if (mounted) setState(() => _snapshot = snapshot);
  });

  Future<void> _revoke() async {
    final confirmed = await _confirmDestructive(
      title: '停止位置共享？',
      body: '双方将立即失去家庭安全访问权，云端当前位置会立刻删除。以后可以重新配对。',
      action: '停止共享',
    );
    if (!confirmed) return;
    await _run(() async {
      await _repository.revokeGroup(_snapshot!.group.id);
      final snapshot = await _repository.loadSnapshot();
      if (mounted) setState(() => _snapshot = snapshot);
    });
  }

  Future<void> _deleteData() async {
    final confirmed = await _confirmDestructive(
      title: '删除全部家庭安全数据？',
      body: '家庭关系、报平安记录、访问记录和当前位置都将永久删除，此操作无法恢复。',
      action: '永久删除',
    );
    if (!confirmed) return;
    await _run(() async {
      await _repository.deleteGroup(_snapshot!.group.id);
      if (mounted) setState(() => _snapshot = null);
    });
  }

  Future<bool> _confirmDestructive({
    required String title,
    required String body,
    required String action,
  }) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: Text(action),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _openMap(FamilySharedLocation location) async {
    final latitude = location.latitude.toStringAsFixed(6);
    final longitude = location.longitude.toStringAsFixed(6);
    final uri = Uri.parse(
      'geo:$latitude,$longitude?q=$latitude,$longitude(家庭安全位置)',
    );
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        mounted) {
      setState(() => _error = '没有可打开该位置的地图应用');
    }
  }

  void _signOut() {
    _repository.signOut();
    setState(() {
      _snapshot = null;
      _inviteCode = null;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('家庭安全'),
        actions: [
          if (_repository.isSignedIn)
            IconButton(
              tooltip: '刷新',
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh),
            ),
          if (_repository.isSignedIn)
            IconButton(
              tooltip: '退出云端账号',
              onPressed: _loading ? null : _signOut,
              icon: const Icon(Icons.logout),
            ),
        ],
      ),
      body: Stack(
        children: [
          ColoredBox(
            color: theme.colorScheme.surfaceContainerLowest,
            child: SafeArea(
              top: false,
              child: RefreshIndicator(
                onRefresh: _repository.isSignedIn ? _load : () async {},
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                  children: [
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 720),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildSafetyNotice(theme),
                            if (_error != null) ...[
                              const SizedBox(height: 12),
                              _buildError(theme),
                            ],
                            const SizedBox(height: 12),
                            if (!_repository.isSignedIn)
                              _buildLogin(theme)
                            else if (_snapshot == null)
                              _buildSetup(theme)
                            else
                              _buildFamily(theme, _snapshot!),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_loading)
            const Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: LinearProgressIndicator(),
            ),
        ],
      ),
    );
  }

  Widget _buildSafetyNotice(ThemeData theme) => _section(
    theme,
    title: '透明、按需、可撤销',
    icon: Icons.shield_outlined,
    child: const Text(
      '这不是静默追踪工具。只有被照护端明确回应报平安请求时才读取一次位置；不保存轨迹，不申请后台定位。双方都能停止共享或删除数据。',
    ),
  );

  Widget _buildError(ThemeData theme) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: theme.colorScheme.errorContainer,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.error_outline, color: theme.colorScheme.onErrorContainer),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            _error!,
            style: TextStyle(color: theme.colorScheme.onErrorContainer),
          ),
        ),
      ],
    ),
  );

  Widget _buildLogin(ThemeData theme) => _section(
    theme,
    title: '登录家庭服务账号',
    icon: Icons.account_circle_outlined,
    child: Column(
      children: [
        const Text('该账号独立于 B 站账号，并与“小窝”共用同一云端登录会话。应用不会保存密码。'),
        const SizedBox(height: 16),
        TextField(
          controller: _accountController,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: '云端用户名',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _passwordController,
          obscureText: !_passwordVisible,
          onSubmitted: (_) => _signIn(),
          autofillHints: const [AutofillHints.password],
          decoration: InputDecoration(
            labelText: '密码',
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              tooltip: _passwordVisible ? '隐藏密码' : '显示密码',
              onPressed: () =>
                  setState(() => _passwordVisible = !_passwordVisible),
              icon: Icon(
                _passwordVisible ? Icons.visibility_off : Icons.visibility,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: _loading ? null : _signIn,
            icon: const Icon(Icons.login),
            label: const Text('登录'),
          ),
        ),
      ],
    ),
  );

  Widget _buildSetup(ThemeData theme) => Column(
    children: [
      _section(
        theme,
        title: '开始前确认',
        icon: Icons.fact_check_outlined,
        child: CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: _consentAccepted,
          onChanged: _loading
              ? null
              : (value) => setState(() => _consentAccepted = value == true),
          title: const Text('我已理解并同意位置共享规则'),
          subtitle: const Text(
            '邀请码只能证明双方设备完成确认，不等同于法定监护关系认证。位置仅为安全联络用途，拒绝不会影响视频功能。',
          ),
        ),
      ),
      const SizedBox(height: 12),
      _section(
        theme,
        title: '我是被照护端',
        icon: Icons.person_pin_circle_outlined,
        child: Column(
          children: [
            const Text('先在需要共享位置的设备上创建家庭，再生成短时邀请码交给照护端。'),
            const SizedBox(height: 12),
            TextField(
              controller: _familyNameController,
              maxLength: 80,
              decoration: const InputDecoration(
                labelText: '家庭名称',
                border: OutlineInputBorder(),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: _loading ? null : _createGroup,
                icon: const Icon(Icons.add_circle_outline),
                label: const Text('创建家庭'),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      _section(
        theme,
        title: '我是照护端',
        icon: Icons.supervisor_account_outlined,
        child: Column(
          children: [
            const Text('输入被照护端当面提供的一次性邀请码。邀请码 15 分钟后失效。'),
            const SizedBox(height: 12),
            TextField(
              controller: _inviteController,
              textCapitalization: TextCapitalization.characters,
              maxLength: 32,
              decoration: const InputDecoration(
                labelText: '一次性邀请码',
                border: OutlineInputBorder(),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonalIcon(
                onPressed: _loading ? null : _joinGroup,
                icon: const Icon(Icons.group_add_outlined),
                label: const Text('加入家庭'),
              ),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _buildFamily(ThemeData theme, FamilySafetySnapshot snapshot) {
    if (snapshot.group.status == 'revoked') {
      return Column(
        children: [
          _section(
            theme,
            title: snapshot.group.name,
            icon: Icons.link_off,
            trailing: const Chip(label: Text('已停止共享')),
            child: const Text(
              '当前位置已删除，双方不能再请求或查看位置。你仍可查看历史操作记录，或永久删除该模块的全部数据。',
            ),
          ),
          const SizedBox(height: 12),
          _buildEvents(theme, snapshot),
          const SizedBox(height: 12),
          _buildDataControls(theme, revoked: true),
        ],
      );
    }
    final isRecipient = snapshot.role == FamilySafetyRole.careRecipient;
    return Column(
      children: [
        _section(
          theme,
          title: snapshot.group.name,
          icon: isRecipient
              ? Icons.person_pin_circle_outlined
              : Icons.supervisor_account_outlined,
          trailing: Chip(label: Text(isRecipient ? '被照护端' : '照护端')),
          child: Text(
            snapshot.group.isPaired
                ? '双方已绑定。所有位置请求和查看都会进入访问记录。'
                : '等待照护端加入。完成绑定前不会产生任何位置请求。',
          ),
        ),
        const SizedBox(height: 12),
        if (isRecipient)
          _buildRecipient(theme, snapshot)
        else
          _buildCaregiver(theme, snapshot),
        const SizedBox(height: 12),
        _buildEvents(theme, snapshot),
        const SizedBox(height: 12),
        _buildDataControls(theme),
      ],
    );
  }

  Widget _buildRecipient(ThemeData theme, FamilySafetySnapshot snapshot) {
    if (!snapshot.group.isPaired) {
      return _section(
        theme,
        title: '邀请照护端',
        icon: Icons.vpn_key_outlined,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('每次生成的邀请码只能使用一次，并在 15 分钟后失效。请当面或通过可信渠道提供。'),
            if (_inviteCode != null) ...[
              const SizedBox(height: 16),
              SelectableText(
                _inviteCode!,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: _inviteCode!));
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('邀请码已复制')),
                    );
                  }
                },
                icon: const Icon(Icons.copy),
                label: const Text('复制邀请码'),
              ),
            ],
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _loading ? null : _createInvite,
              icon: const Icon(Icons.key),
              label: Text(_inviteCode == null ? '生成邀请码' : '重新生成'),
            ),
          ],
        ),
      );
    }

    final request = snapshot.latestRequest;
    return _section(
      theme,
      title: request?.isPending == true ? '收到报平安请求' : '当前没有待回应请求',
      icon: request?.isPending == true
          ? Icons.notifications_active_outlined
          : Icons.notifications_none,
      child: request?.isPending == true
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  request!.message.isEmpty ? '照护端请求确认你是否安全' : request.message,
                ),
                const SizedBox(height: 8),
                Text(
                  '请求将于 ${_formatTime(request.expiresAt)} 失效',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: _loading ? null : () => _decline(request),
                      child: const Text('暂不共享'),
                    ),
                    FilledButton.icon(
                      onPressed: _loading
                          ? null
                          : () => _shareLocation(request),
                      icon: const Icon(Icons.my_location),
                      label: const Text('共享这一次位置'),
                    ),
                  ],
                ),
              ],
            )
          : const Text('应用不会自行获取位置。收到新请求后，刷新页面即可查看。'),
    );
  }

  Widget _buildCaregiver(ThemeData theme, FamilySafetySnapshot snapshot) {
    final request = snapshot.latestRequest;
    final location = snapshot.latestLocation;
    return Column(
      children: [
        _section(
          theme,
          title: '请求报平安',
          icon: Icons.notification_add_outlined,
          child: Column(
            children: [
              TextField(
                controller: _messageController,
                maxLength: 120,
                enabled: request?.isPending != true,
                decoration: const InputDecoration(
                  labelText: '给被照护端的说明',
                  border: OutlineInputBorder(),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: _loading || request?.isPending == true
                      ? null
                      : _requestCheckIn,
                  icon: const Icon(Icons.send_outlined),
                  label: Text(request?.isPending == true ? '等待回应' : '发送请求'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _section(
          theme,
          title: location == null ? '尚无可用位置' : '最近一次共享位置',
          icon: Icons.location_on_outlined,
          child: location == null
              ? const Text('只有被照护端明确同意后，这里才会出现位置。')
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '更新于 ${_formatTime(location.capturedAt)} · 精度约 ${location.accuracyMeters.round()} 米',
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '该位置将在 ${_formatTime(location.expiresAt)} 自动失效',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.tonalIcon(
                      onPressed: () => _openMap(location),
                      icon: const Icon(Icons.map_outlined),
                      label: const Text('用系统地图打开'),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildEvents(
    ThemeData theme,
    FamilySafetySnapshot snapshot,
  ) => _section(
    theme,
    title: '访问记录',
    icon: Icons.manage_history,
    child: snapshot.events.isEmpty
        ? const Text('暂无记录')
        : Column(
            children: snapshot.events
                .map(
                  (event) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: Icon(_eventIcon(event.type)),
                    title: Text(_eventLabel(event.type)),
                    subtitle: Text(
                      '${event.actorId == snapshot.currentUserId ? '你' : '另一位成员'} · ${_formatTime(event.createdAt)}',
                    ),
                  ),
                )
                .toList(growable: false),
          ),
  );

  Widget _buildDataControls(ThemeData theme, {bool revoked = false}) =>
      _section(
        theme,
        title: '关系与数据',
        icon: Icons.admin_panel_settings_outlined,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              revoked
                  ? '永久删除会清除家庭关系和该模块的全部记录。删除后可以重新建立家庭安全组。'
                  : '停止共享会立即删除当前位置；永久删除会同时清除家庭关系和该模块的全部记录。',
            ),
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: [
                if (!revoked)
                  OutlinedButton.icon(
                    onPressed: _loading ? null : _revoke,
                    icon: const Icon(Icons.link_off),
                    label: const Text('停止共享'),
                  ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.colorScheme.error,
                    foregroundColor: theme.colorScheme.onError,
                  ),
                  onPressed: _loading ? null : _deleteData,
                  icon: const Icon(Icons.delete_forever_outlined),
                  label: const Text('永久删除'),
                ),
              ],
            ),
          ],
        ),
      );

  Widget _section(
    ThemeData theme, {
    required String title,
    required IconData icon,
    required Widget child,
    Widget? trailing,
  }) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: theme.colorScheme.surfaceContainer,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(icon, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(child: Text(title, style: theme.textTheme.titleMedium)),
            ?trailing,
          ],
        ),
        const SizedBox(height: 12),
        child,
      ],
    ),
  );

  String _formatTime(DateTime? value) =>
      value == null ? '未知时间' : DateFormat('MM-dd HH:mm').format(value);

  String _eventLabel(String type) => switch (type) {
    'group_created' => '创建了家庭安全组',
    'invite_created' => '生成了新邀请码',
    'caregiver_joined' => '照护端完成绑定',
    'check_in_requested' => '发起了报平安请求',
    'location_shared' => '共享了一次位置',
    'check_in_declined' => '本次没有共享位置',
    'location_viewed' => '查看了最近位置',
    'group_revoked' => '停止了位置共享',
    _ => '家庭安全状态发生变化',
  };

  IconData _eventIcon(String type) => switch (type) {
    'location_shared' => Icons.my_location,
    'location_viewed' => Icons.visibility_outlined,
    'check_in_requested' => Icons.notification_add_outlined,
    'check_in_declined' => Icons.location_disabled_outlined,
    'group_revoked' => Icons.link_off,
    'caregiver_joined' => Icons.group_add_outlined,
    'invite_created' => Icons.vpn_key_outlined,
    _ => Icons.shield_outlined,
  };
}
