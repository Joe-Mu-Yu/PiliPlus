import 'dart:convert';
import 'dart:io';

import 'package:PiliPlus/pages/couple_space/cloudbase_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('app pages reuse one CloudBase repository session', () {
    expect(
      CoupleSpaceCloudRepository.appSession,
      same(CoupleSpaceCloudRepository.appSession),
    );
  });

  test('CloudBase login errors are translated for the native UI', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final subscription = server.listen((request) async {
      request.response
        ..statusCode = HttpStatus.badRequest
        ..headers.contentType = ContentType.json
        ..write(
          jsonEncode({
            'error': 'invalid_username_or_password',
            'error_description': 'Username or password incorrect',
          }),
        );
      await request.response.close();
    });
    addTearDown(() async {
      await subscription.cancel();
      await server.close(force: true);
    });

    final repository = CoupleSpaceCloudRepository(
      baseUrl: 'http://${server.address.address}:${server.port}',
      deviceId: 'test-device',
    );
    await expectLater(
      repository.signIn(account: 'missing-user', password: 'wrong-password'),
      throwsA(
        isA<CoupleSpaceCloudException>().having(
          (error) => error.message,
          'message',
          '用户名或密码不正确',
        ),
      ),
    );
  });

  test('an invalid refresh token clears the reusable app session', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final subscription = server.listen((request) async {
      request.response.headers.contentType = ContentType.json;
      if (request.uri.path == '/auth/v1/signin') {
        await utf8.decoder.bind(request).join();
        request.response.write(
          jsonEncode({
            'access_token': 'expired-access-token',
            'refresh_token': 'revoked-refresh-token',
            'sub': 'uid-a',
            'expires_in': 0,
          }),
        );
      } else if (request.uri.path == '/auth/v1/token') {
        request.response
          ..statusCode = HttpStatus.badRequest
          ..write(jsonEncode({'error': 'invalid_refresh_token'}));
      }
      await request.response.close();
    });
    addTearDown(() async {
      await subscription.cancel();
      await server.close(force: true);
    });

    final repository = CoupleSpaceCloudRepository(
      baseUrl: 'http://${server.address.address}:${server.port}',
      deviceId: 'test-device',
    );
    await repository.signIn(account: 'member-a', password: 'secret');
    expect(repository.isSignedIn, isTrue);

    await expectLater(
      repository.loadSpace(),
      throwsA(
        isA<CoupleSpaceCloudException>()
            .having(
              (error) => error.code,
              'code',
              'SESSION_EXPIRED',
            )
            .having(
              (error) => error.message,
              'message',
              '小窝登录已过期，请重新登录',
            ),
      ),
    );
    expect(repository.isSignedIn, isFalse);
  });

  test(
    'CloudBase repository uses authenticated PG, RPC, and storage APIs',
    () async {
      final requests = <String>[];
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final subscription = server.listen((request) async {
        requests.add('${request.method} ${request.uri.path}');
        final response = request.response;
        response.headers.contentType = ContentType.json;
        if (request.uri.path == '/auth/v1/signin') {
          final body =
              jsonDecode(await utf8.decoder.bind(request).join()) as Map;
          expect(body['user${'name'}'], 'member-a');
          expect(body['password'], 'secret');
          response.write(
            jsonEncode({
              'access_token': 'access-token',
              'refresh_token': 'refresh-token',
              'sub': 'uid-a',
              'expires_in': 7200,
            }),
          );
        } else {
          expect(request.headers.value('authorization'), 'Bearer access-token');
          if (request.uri.path == '/v1/rdb/rest/couple_spaces') {
            response.write(
              jsonEncode([
                {
                  'id': 'space-a',
                  'name': '我们的小窝',
                  'member_a': 'uid-a',
                  'member_b': 'uid-b',
                },
              ]),
            );
          } else if (request.uri.path == '/v1/rdb/rest/couple_space_state') {
            response.write(
              jsonEncode([
                {
                  'space_id': 'space-a',
                  'payload': {'messages': []},
                  'revision': 2,
                },
              ]),
            );
          } else if (request.uri.path.endsWith('/save_couple_space_state')) {
            final body =
                jsonDecode(await utf8.decoder.bind(request).join()) as Map;
            expect(body['p_expected_revision'], 2);
            response.write(
              jsonEncode({'revision': 3, 'payload': body['p_payload']}),
            );
          } else if (request.uri.path.contains('/object/couple-space/')) {
            expect(request.headers.contentType?.mimeType, 'image/jpeg');
            expect(
              await request.fold<int>(0, (sum, bytes) => sum + bytes.length),
              4,
            );
            response.write(jsonEncode({'Key': request.uri.path}));
          } else if (request.uri.path.contains('/object/sign/couple-space/')) {
            response.write(
              jsonEncode({'fullSignedURL': 'https://example.test/photo'}),
            );
          } else {
            response
              ..statusCode = HttpStatus.notFound
              ..write(jsonEncode({'message': 'unexpected test route'}));
          }
        }
        await response.close();
      });
      addTearDown(() async {
        await subscription.cancel();
        await server.close(force: true);
      });

      final repository = CoupleSpaceCloudRepository(
        baseUrl: 'http://${server.address.address}:${server.port}',
        deviceId: 'test-device',
      );
      await repository.signIn(account: 'member-a', password: 'secret');
      expect(repository.userId, 'uid-a');

      final snapshot = await repository.loadSpace();
      expect(snapshot?.spaceId, 'space-a');
      expect(snapshot?.revision, 2);
      final restoredSnapshot = await repository.loadSpace();
      expect(restoredSnapshot?.spaceId, 'space-a');
      expect(
        requests.where((request) => request == 'POST /auth/v1/signin'),
        hasLength(1),
      );
      expect(
        requests.where(
          (request) => request == 'GET /v1/rdb/rest/couple_spaces',
        ),
        hasLength(2),
      );
      expect(
        await repository.saveState(
          spaceId: 'space-a',
          expectedRevision: 2,
          payload: {'messages': []},
        ),
        3,
      );

      final tempDirectory = await Directory.systemTemp.createTemp(
        'couple-space-',
      );
      addTearDown(() => tempDirectory.delete(recursive: true));
      final photo = File('${tempDirectory.path}/photo.jpg')
        ..writeAsBytesSync([1, 2, 3, 4]);
      final key = await repository.uploadPhoto(spaceId: 'space-a', file: photo);
      expect(key, startsWith('space-a/uid-a/'));
      expect(
        await repository.signedPhotoUrl(key),
        'https://example.test/photo',
      );

      expect(requests, contains('POST /auth/v1/signin'));
      expect(requests, contains('GET /v1/rdb/rest/couple_spaces'));
      expect(
        requests,
        contains('POST /v1/rdb/rest/rpc/save_couple_space_state'),
      );
    },
  );
}
