import 'dart:io';

import 'package:PiliPlus/utils/storage.dart';
import 'package:dio/dio.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

const coupleSpaceCloudBaseEnvId = 'urban-iguana-d9g3i6yg86c256bd4';
const _deviceIdKey = 'coupleSpace.cloudbase.deviceId.v1';

class CoupleSpaceCloudException implements Exception {
  const CoupleSpaceCloudException(
    this.message, {
    this.code,
    this.statusCode,
  });

  final String message;
  final String? code;
  final int? statusCode;

  @override
  String toString() => message;
}

class CoupleSpaceConflictException extends CoupleSpaceCloudException {
  const CoupleSpaceConflictException()
    : super('云端内容已被另一位成员更新，请重试', code: 'COUPLE_SPACE_CONFLICT');
}

class CoupleSpaceSession {
  const CoupleSpaceSession({
    required this.accessToken,
    required this.refreshToken,
    required this.userId,
    required this.expiresAt,
    required this.account,
  });

  final String accessToken;
  final String refreshToken;
  final String userId;
  final DateTime expiresAt;
  final String account;
}

class CoupleSpaceCloudSnapshot {
  const CoupleSpaceCloudSnapshot({
    required this.spaceId,
    required this.name,
    required this.memberA,
    required this.memberB,
    required this.revision,
    required this.payload,
  });

  final String spaceId;
  final String name;
  final String memberA;
  final String? memberB;
  final int revision;
  final Map<String, dynamic> payload;
}

class CoupleSpaceCloudRepository {
  static final CoupleSpaceCloudRepository appSession =
      CoupleSpaceCloudRepository();

  CoupleSpaceCloudRepository({
    Dio? dio,
    String? baseUrl,
    String? deviceId,
  }) : _baseUrlOverride = baseUrl,
       _deviceIdOverride = deviceId,
       _dio =
           dio ??
           Dio(
             BaseOptions(
               connectTimeout: const Duration(seconds: 15),
               receiveTimeout: const Duration(seconds: 30),
             ),
           );

  final Dio _dio;
  final String? _baseUrlOverride;
  final String? _deviceIdOverride;
  final Uuid _uuid = const Uuid();
  CoupleSpaceSession? _session;

  String get _baseUrl =>
      _baseUrlOverride ??
      'https://$coupleSpaceCloudBaseEnvId.api.tcloudbasegateway.com';
  String get userId => _session?.userId ?? '';
  String get account => _session?.account ?? '';
  bool get isSignedIn => _session != null;

  String get _deviceId {
    if (_deviceIdOverride != null) return _deviceIdOverride;
    final current = GStorage.localCache.get(_deviceIdKey)?.toString();
    if (current != null && current.isNotEmpty) return current;
    final created = _uuid.v4();
    GStorage.localCache.put(_deviceIdKey, created);
    return created;
  }

  Future<void> signIn({
    required String account,
    required String password,
  }) async {
    final data = await _requestJson(
      'POST',
      '/auth/v1/signin',
      body: {'user${'name'}': account.trim(), 'password': password},
      authenticated: false,
    );
    final token = _asMap(data);
    _session = CoupleSpaceSession(
      accessToken: token['access_token']?.toString() ?? '',
      refreshToken: token['refresh_token']?.toString() ?? '',
      userId: token['sub']?.toString() ?? '',
      expiresAt: DateTime.now().add(
        Duration(seconds: (token['expires_in'] as num?)?.toInt() ?? 7200),
      ),
      account: account.trim(),
    );
    if (_session!.accessToken.isEmpty || _session!.userId.isEmpty) {
      _session = null;
      throw const CoupleSpaceCloudException('CloudBase 登录响应缺少用户令牌');
    }
  }

  void signOut() => _session = null;

  Future<CoupleSpaceCloudSnapshot?> loadSpace() async {
    final rows = _asList(
      await _requestJson(
        'GET',
        '/v1/rdb/rest/couple_spaces',
        query: {
          'select': 'id,name,member_a,member_b',
          'order': 'created_at.asc',
          'limit': 1,
        },
      ),
    );
    if (rows.isEmpty) return null;
    final space = _asMap(rows.first);
    final spaceId = space['id'].toString();
    final states = _asList(
      await _requestJson(
        'GET',
        '/v1/rdb/rest/couple_space_state',
        query: {'space_id': 'eq.$spaceId', 'select': '*', 'limit': 1},
      ),
    );
    final state = states.isEmpty ? <String, dynamic>{} : _asMap(states.first);
    return CoupleSpaceCloudSnapshot(
      spaceId: spaceId,
      name: space['name']?.toString() ?? '我们的小窝',
      memberA: space['member_a']?.toString() ?? '',
      memberB: space['member_b']?.toString(),
      revision: (state['revision'] as num?)?.toInt() ?? 0,
      payload: _asMap(state['payload']),
    );
  }

  Future<CoupleSpaceCloudSnapshot> createSpace(
    Map<String, dynamic> payload,
  ) async {
    final result = _asMap(
      await _rpc('create_couple_space', {
        'p_name': payload['spaceName']?.toString() ?? '我们的小窝',
        'p_payload': payload,
      }),
    );
    return _snapshotFromRpc(result);
  }

  Future<CoupleSpaceCloudSnapshot> joinSpace(String inviteCode) async {
    final result = _asMap(
      await _rpc('join_couple_space', {'p_token': inviteCode.trim()}),
    );
    return _snapshotFromRpc(result);
  }

  Future<String> createInvite(String spaceId) async {
    final result = await _rpc('create_couple_space_invite', {
      'p_space_id': spaceId,
    });
    if (result is String) return result;
    final map = _asMap(result);
    return (map['create_couple_space_invite'] ?? map['token'] ?? result)
        .toString();
  }

  Future<int> saveState({
    required String spaceId,
    required int expectedRevision,
    required Map<String, dynamic> payload,
  }) async {
    try {
      final result = _asMap(
        await _rpc('save_couple_space_state', {
          'p_space_id': spaceId,
          'p_expected_revision': expectedRevision,
          'p_payload': payload,
        }),
      );
      return (result['revision'] as num?)?.toInt() ?? expectedRevision + 1;
    } on CoupleSpaceCloudException catch (error) {
      if (error.message.contains('COUPLE_SPACE_CONFLICT')) {
        throw const CoupleSpaceConflictException();
      }
      rethrow;
    }
  }

  Future<String> uploadPhoto({
    required String spaceId,
    required File file,
  }) => uploadMedia(spaceId: spaceId, file: file);

  Future<String> uploadMedia({
    required String spaceId,
    required File file,
  }) async {
    final extension = p.extension(file.path).toLowerCase();
    final key = '$spaceId/$userId/${_uuid.v4()}$extension';
    final mimeType = lookupMimeType(file.path) ?? 'application/octet-stream';
    await _authorizedRequest(
      'POST',
      '/v1/storages/object/couple-space/$key',
      body: await file.readAsBytes(),
      headers: {'Content-Type': mimeType, 'x-upsert': 'false'},
    );
    return key;
  }

  Future<String> signedPhotoUrl(String key) => signedMediaUrl(key);

  Future<String> signedMediaUrl(String key) async {
    final result = _asMap(
      await _requestJson(
        'POST',
        '/v1/storages/object/sign/couple-space/$key',
        body: {'expiresIn': 3600},
      ),
    );
    final url = (result['fullSignedURL'] ?? result['signedURL'])?.toString();
    if (url == null || url.isEmpty) {
      throw const CoupleSpaceCloudException('CloudBase 未返回文件访问地址');
    }
    return url;
  }

  Future<void> deletePhoto(String key) async {
    await deleteMedia(key);
  }

  Future<void> deleteMedia(String key) async {
    await _authorizedRequest(
      'DELETE',
      '/v1/storages/object/couple-space/$key',
    );
  }

  Future<dynamic> _rpc(String function, Map<String, dynamic> body) =>
      _requestJson('POST', '/v1/rdb/rest/rpc/$function', body: body);

  CoupleSpaceCloudSnapshot _snapshotFromRpc(Map<String, dynamic> result) =>
      CoupleSpaceCloudSnapshot(
        spaceId: result['id']?.toString() ?? '',
        name: result['name']?.toString() ?? '我们的小窝',
        memberA: result['member_a']?.toString() ?? '',
        memberB: result['member_b']?.toString(),
        revision: (result['revision'] as num?)?.toInt() ?? 0,
        payload: _asMap(result['payload']),
      );

  Future<dynamic> _requestJson(
    String method,
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    bool authenticated = true,
  }) async {
    final response = authenticated
        ? await _authorizedRequest(method, path, body: body, query: query)
        : await _performRequest(method, path, body: body, query: query);
    return response.data;
  }

  Future<Response<dynamic>> _authorizedRequest(
    String method,
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    Map<String, dynamic>? headers,
  }) async {
    if (_session == null) {
      throw const CoupleSpaceCloudException('请先登录小窝');
    }
    if (DateTime.now().isAfter(
      _session!.expiresAt.subtract(const Duration(minutes: 2)),
    )) {
      await _refreshSession();
    }
    try {
      return await _performRequest(
        method,
        path,
        body: body,
        query: query,
        headers: {
          'Authorization': 'Bearer ${_session!.accessToken}',
          ...?headers,
        },
      );
    } on CoupleSpaceCloudException catch (error) {
      if (error.statusCode == 401 && _session!.refreshToken.isNotEmpty) {
        await _refreshSession();
        return _performRequest(
          method,
          path,
          body: body,
          query: query,
          headers: {
            'Authorization': 'Bearer ${_session!.accessToken}',
            ...?headers,
          },
        );
      }
      rethrow;
    }
  }

  Future<void> _refreshSession() async {
    final current = _session;
    if (current == null || current.refreshToken.isEmpty) {
      throw const CoupleSpaceCloudException('小窝登录已过期，请重新登录');
    }
    try {
      final token = _asMap(
        await _requestJson(
          'POST',
          '/auth/v1/token',
          authenticated: false,
          body: {
            'grant_type': 'refresh_token',
            'refresh_token': current.refreshToken,
          },
        ),
      );
      final accessToken = token['access_token']?.toString() ?? '';
      if (accessToken.isEmpty) {
        throw const CoupleSpaceCloudException(
          '小窝登录已过期，请重新登录',
          code: 'SESSION_EXPIRED',
        );
      }
      _session = CoupleSpaceSession(
        accessToken: accessToken,
        refreshToken:
            token['refresh_token']?.toString() ?? current.refreshToken,
        userId: token['sub']?.toString() ?? current.userId,
        expiresAt: DateTime.now().add(
          Duration(seconds: (token['expires_in'] as num?)?.toInt() ?? 7200),
        ),
        account: current.account,
      );
    } on CoupleSpaceCloudException catch (error) {
      if (error.statusCode == 400 || error.statusCode == 401) {
        signOut();
        throw CoupleSpaceCloudException(
          '小窝登录已过期，请重新登录',
          code: 'SESSION_EXPIRED',
          statusCode: error.statusCode,
        );
      }
      rethrow;
    }
  }

  Future<Response<dynamic>> _performRequest(
    String method,
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    Map<String, dynamic>? headers,
  }) async {
    try {
      return await _dio.request<dynamic>(
        '$_baseUrl$path',
        data: body,
        queryParameters: query,
        options: Options(
          method: method,
          headers: {'x-device-id': _deviceId, ...?headers},
        ),
      );
    } on DioException catch (error) {
      final body = error.response?.data;
      final map = _asMap(body);
      final message =
          map['error_description']?.toString() ??
          map['message']?.toString() ??
          map['error']?.toString() ??
          error.message ??
          'CloudBase 请求失败';
      throw CoupleSpaceCloudException(
        _friendlyMessage(message),
        code: map['code']?.toString() ?? map['error']?.toString(),
        statusCode: error.response?.statusCode,
      );
    }
  }

  String _friendlyMessage(String message) {
    final normalized = message.toLowerCase();
    if (normalized.contains('invalid_user${'name'}_or_password') ||
        normalized.contains('user${'name'} or password incorrect')) {
      return '用户名或密码不正确';
    }
    if (message.contains('USER_ALREADY_HAS_SPACE')) return '这个账号已经加入了一个小窝';
    if (message.contains('INVITE_INVALID_OR_EXPIRED')) return '邀请码无效或已过期';
    if (message.contains('SPACE_ALREADY_PAIRED')) return '这个小窝已经绑定了两位成员';
    if (message.contains('SPACE_ACCESS_DENIED')) return '你没有访问这个小窝的权限';
    return message;
  }

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    if (value is List && value.length == 1) return _asMap(value.first);
    return <String, dynamic>{};
  }

  static List<dynamic> _asList(dynamic value) =>
      value is List ? value : const <dynamic>[];
}
