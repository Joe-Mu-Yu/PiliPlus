import 'dart:io';

import 'package:PiliPlus/pages/couple_space/cloudbase_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const accountA = String.fromEnvironment('COUPLE_SPACE_TEST_ACCOUNT_A');
  const passwordA = String.fromEnvironment('COUPLE_SPACE_TEST_PASSWORD_A');
  const accountB = String.fromEnvironment('COUPLE_SPACE_TEST_ACCOUNT_B');
  const passwordB = String.fromEnvironment('COUPLE_SPACE_TEST_PASSWORD_B');
  const hasCredentials =
      accountA != '' && passwordA != '' && accountB != '' && passwordB != '';

  test(
    'two authenticated members share state and private photos',
    () async {
      final memberA = CoupleSpaceCloudRepository(deviceId: 'live-test-a');
      final memberB = CoupleSpaceCloudRepository(deviceId: 'live-test-b');

      await memberA.signIn(account: accountA, password: passwordA);
      await memberB.signIn(account: accountB, password: passwordB);
      expect(memberA.userId, isNotEmpty);
      expect(memberB.userId, isNotEmpty);
      expect(memberA.userId, isNot(memberB.userId));

      final initialPayload = <String, dynamic>{
        'spaceName': 'CloudBase 双用户验收小窝',
        'messages': <Map<String, dynamic>>[],
        'tasks': <Map<String, dynamic>>[],
        'albums': <Map<String, dynamic>>[],
      };
      final created = await memberA.createSpace(initialPayload);
      expect(created.memberA, memberA.userId);
      expect(created.memberB, isNull);
      expect(created.revision, 0);

      final invite = await memberA.createInvite(created.spaceId);
      expect(invite, isNotEmpty);
      final joined = await memberB.joinSpace(invite);
      expect(joined.spaceId, created.spaceId);
      expect(joined.memberB, memberB.userId);

      final revisionOne = await memberA.saveState(
        spaceId: created.spaceId,
        expectedRevision: joined.revision,
        payload: {
          ...initialPayload,
          'messages': [
            {'text': '来自成员 A 的真实云端消息'},
          ],
        },
      );
      final seenByB = await memberB.loadSpace();
      expect(seenByB?.revision, revisionOne);
      expect(
        (seenByB?.payload['messages'] as List).single['text'],
        '来自成员 A 的真实云端消息',
      );

      final tempDirectory = await Directory.systemTemp.createTemp(
        'couple-space-live-',
      );
      addTearDown(() => tempDirectory.delete(recursive: true));
      final photo = File('${tempDirectory.path}/pixel.png')
        ..writeAsBytesSync(_onePixelPng);
      final photoKey = await memberA.uploadPhoto(
        spaceId: created.spaceId,
        file: photo,
      );
      expect(photoKey, startsWith('${created.spaceId}/${memberA.userId}/'));
      final signedUrl = await memberB.signedPhotoUrl(photoKey);
      expect(Uri.parse(signedUrl).hasScheme, isTrue);
      await memberB.deletePhoto(photoKey);

      final revisionTwo = await memberB.saveState(
        spaceId: created.spaceId,
        expectedRevision: revisionOne,
        payload: {
          ...seenByB!.payload,
          'tasks': [
            {'title': '来自成员 B 的真实云端任务', 'done': false},
          ],
        },
      );
      final seenByA = await memberA.loadSpace();
      expect(seenByA?.revision, revisionTwo);
      expect(
        (seenByA?.payload['tasks'] as List).single['title'],
        '来自成员 B 的真实云端任务',
      );

      await expectLater(
        memberA.saveState(
          spaceId: created.spaceId,
          expectedRevision: revisionOne,
          payload: initialPayload,
        ),
        throwsA(isA<CoupleSpaceConflictException>()),
      );
    },
    skip: hasCredentials ? false : '需要显式传入两名临时 CloudBase 用户凭据',
  );
}

const _onePixelPng = <int>[
  0x89,
  0x50,
  0x4e,
  0x47,
  0x0d,
  0x0a,
  0x1a,
  0x0a,
  0x00,
  0x00,
  0x00,
  0x0d,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1f,
  0x15,
  0xc4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0d,
  0x49,
  0x44,
  0x41,
  0x54,
  0x08,
  0xd7,
  0x63,
  0xf8,
  0xcf,
  0xc0,
  0xf0,
  0x1f,
  0x00,
  0x05,
  0x00,
  0x01,
  0xff,
  0x89,
  0x99,
  0x3d,
  0x1d,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4e,
  0x44,
  0xae,
  0x42,
  0x60,
  0x82,
];
