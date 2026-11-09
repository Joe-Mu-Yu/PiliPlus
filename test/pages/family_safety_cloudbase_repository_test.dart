import 'dart:convert';
import 'dart:io';

import 'package:PiliPlus/pages/couple_space/cloudbase_repository.dart';
import 'package:PiliPlus/pages/family_safety/cloudbase_repository.dart';
import 'package:PiliPlus/pages/family_safety/location_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('family safety uses authenticated RPCs and parses a snapshot', () async {
    final requests = <String>[];
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final subscription = server.listen((request) async {
      final path = request.uri.path;
      requests.add('${request.method} $path');
      final response = request.response;
      response.headers.contentType = ContentType.json;
      if (path == '/auth/v1/signin') {
        response.write(
          jsonEncode({
            'access_token': 'access-token',
            'refresh_token': 'refresh-token',
            'sub': 'recipient-a',
            'expires_in': 7200,
          }),
        );
      } else {
        expect(request.headers.value('authorization'), 'Bearer access-token');
        final bodyText = await utf8.decoder.bind(request).join();
        final body = bodyText.isEmpty
            ? <String, dynamic>{}
            : Map<String, dynamic>.from(jsonDecode(bodyText) as Map);
        if (path.endsWith('/get_family_safety_snapshot')) {
          expect(body['p_group_id'], isNull);
          response.write(
            jsonEncode({
              'group': {
                'id': 'family-a',
                'name': '我的家庭',
                'care_recipient_id': 'recipient-a',
                'caregiver_id': 'caregiver-b',
                'status': 'active',
                'consent_version': familySafetyConsentVersion,
                'created_at': '2026-11-08T12:00:00Z',
              },
              'current_user_id': 'recipient-a',
              'latest_request': {
                'id': 'request-a',
                'group_id': 'family-a',
                'message': '请报平安',
                'status': 'pending',
                'requested_at': '2026-11-08T12:10:00Z',
                'expires_at': '2099-11-08T12:40:00Z',
              },
              'latest_location': null,
              'events': [
                {
                  'id': 1,
                  'actor_id': 'caregiver-b',
                  'event_type': 'check_in_requested',
                  'created_at': '2026-11-08T12:10:00Z',
                },
              ],
            }),
          );
        } else if (path.endsWith('/create_family_safety_invite')) {
          expect(body['p_group_id'], 'family-a');
          response.write(jsonEncode('INVITE-CODE'));
        } else if (path.endsWith('/request_family_check_in')) {
          expect(body['p_message'], '请确认安全');
          response.write(jsonEncode({'id': 'request-b'}));
        } else if (path.endsWith('/respond_family_check_in')) {
          expect(body['p_request_id'], 'request-a');
          expect(body['p_action'], 'share');
          expect(body['p_latitude'], 31.2);
          response.write(jsonEncode({'status': 'shared'}));
        } else if (path.endsWith('/revoke_family_safety_group') ||
            path.endsWith('/delete_family_safety_group')) {
          expect(body['p_group_id'], 'family-a');
          response.write(jsonEncode(true));
        } else {
          response
            ..statusCode = HttpStatus.notFound
            ..write(jsonEncode({'message': 'unexpected route'}));
        }
      }
      await response.close();
    });
    addTearDown(() async {
      await subscription.cancel();
      await server.close(force: true);
    });

    final cloud = CoupleSpaceCloudRepository(
      baseUrl: 'http://${server.address.address}:${server.port}',
      deviceId: 'family-test-device',
    );
    final repository = FamilySafetyCloudRepository(cloud: cloud);
    await repository.signIn(account: 'recipient', password: 'secret');

    final snapshot = await repository.loadSnapshot();
    expect(snapshot?.group.id, 'family-a');
    expect(snapshot?.role.name, 'careRecipient');
    expect(snapshot?.latestRequest?.isPending, isTrue);
    expect(snapshot?.events.single.type, 'check_in_requested');
    expect(await repository.createInvite('family-a'), 'INVITE-CODE');
    await repository.requestCheckIn(
      groupId: 'family-a',
      message: '请确认安全',
    );
    await repository.shareLocation(
      requestId: 'request-a',
      location: FamilyCapturedLocation(
        latitude: 31.2,
        longitude: 121.5,
        accuracyMeters: 25,
        capturedAt: DateTime.utc(2026, 11, 8, 12, 20),
      ),
    );
    await repository.revokeGroup('family-a');
    await repository.deleteGroup('family-a');

    expect(
      requests,
      contains('POST /v1/rdb/rest/rpc/get_family_safety_snapshot'),
    );
    expect(
      requests,
      contains('POST /v1/rdb/rest/rpc/respond_family_check_in'),
    );
  });
}
