import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/core/site/douyin/douyin_site.dart';

void main() {
  group('Douyin room page state parser', () {
    test('parses escaped state spanning multiple HTML lines', () {
      const source =
          r'''{\"state\":{\"appStore\":{\"roomStore\":{\"roomInfo\":{}}}}}]\n''';

      expect(
        DouyinSite.parseRoomPageState(source)['appStore'],
        containsPair('roomStore', contains('roomInfo')),
      );
    });

    test('reports a readable format error when room state is absent', () {
      expect(
        () => DouyinSite.parseRoomPageState('<html>verification</html>'),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains('抖音房间页面数据格式异常'),
          ),
        ),
      );
    });

    test('parses a sanitized offline Douyin room page', () async {
      final source = File(
        const String.fromEnvironment(
          'DOUYIN_PAGE',
          defaultValue: 'test/fixtures/douyin_room_page.html',
        ),
      ).readAsStringSync();
      final state = DouyinSite.parseRoomPageState(source);
      final roomInfo =
          (state['roomStore'] as Map)['roomInfo'] as Map<String, dynamic>;

      expect((roomInfo['room'] as Map)['id_str'], '7704089152689621787');
      expect((roomInfo['room'] as Map)['status'], 4);
      expect((roomInfo['anchor'] as Map)['nickname'], '诺子酱Lino');

      final previousCookie = DouyinSite.cookie;
      DouyinSite.cookie = 'offline-test';
      final room = await DouyinSite()
          .parseRoomPageToLiveRoomForTesting('124915647724', source)
          .whenComplete(() => DouyinSite.cookie = previousCookie);
      expect(room.roomId, '124915647724');
      expect(room.title, '兄弟你好香');
      expect(room.nick, '诺子酱Lino');
      expect(room.avatar, startsWith('https://'));
      expect(room.status, isFalse);
      expect(room.effectiveLiveStatus.name, 'offline');
      expect(room.data, isEmpty);
    });
  });
}
