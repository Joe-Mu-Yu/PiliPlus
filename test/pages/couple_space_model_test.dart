import 'package:PiliPlus/pages/couple_space/couple_space_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('小窝成员身份', () {
    test('成员映射缺失时不会继承另一成员的共享昵称', () {
      final payload = <String, dynamic>{
        'nickname': '小昱',
        'memberNames': <String, dynamic>{'uid-yu': '小昱'},
      };

      expect(
        coupleCurrentMemberName(
          payload: payload,
          userId: 'uid-yao',
          account: 'xiaoyao',
        ),
        'xiaoyao',
      );
    });

    test('旧相册动态从私有照片路径恢复真实发布者', () {
      final payload = <String, dynamic>{
        'memberNames': <String, dynamic>{
          'uid-yu': '小昱',
          'uid-yao': '小瑶',
        },
      };

      final moment = normalizeCoupleMoment({
        'photos': ['cloud:space-a/uid-yao/photo.jpg'],
        'caption': '旧动态',
      }, payload);

      expect(moment['authorId'], 'uid-yao');
      expect(moment['authorName'], '小瑶');
      expect(
        coupleEntryAuthorName(payload: payload, entry: moment),
        '小瑶',
      );
    });

    test('动态自身作者优先于照片路径并兼容旧评论署名', () {
      final payload = <String, dynamic>{
        'memberNames': <String, dynamic>{
          'uid-yu': '小昱',
          'uid-yao': '小瑶',
        },
      };

      final moment = normalizeCoupleMoment({
        'authorId': 'uid-yu',
        'authorName': '小昱',
        'photos': ['cloud:space-a/uid-yao/photo.jpg'],
        'comments': [
          {'author': '旧昵称', 'text': '收到'},
        ],
      }, payload);

      expect(moment['authorId'], 'uid-yu');
      expect(moment['authorName'], '小昱');
      expect((moment['comments'] as List).single['authorName'], '旧昵称');
    });

    test('心语评论固定记录当前成员 UID、昵称和 UTC 时间', () {
      final comment = createCoupleComment(
        id: 'comment-a',
        authorId: 'uid-yao',
        authorName: '小瑶',
        text: '  我也想你  ',
        createdAt: DateTime.parse('2026-11-09T20:30:00+08:00'),
      );

      expect(comment['authorId'], 'uid-yao');
      expect(comment['authorName'], '小瑶');
      expect(comment['text'], '我也想你');
      expect(comment['createdAt'], '2026-11-09T12:30:00.000Z');
    });
  });

  group('coupleTogetherDayNumber', () {
    test('起始日计为第一天并随自然日变化', () {
      expect(
        coupleTogetherDayNumber(
          DateTime(2026, 11, 7, 23, 50),
          DateTime(2026, 11, 7, 23, 59),
        ),
        1,
      );
      expect(
        coupleTogetherDayNumber(
          DateTime(2026, 11, 7, 23, 50),
          DateTime(2026, 11, 8, 0, 1),
        ),
        2,
      );
    });

    test('未来日期显示为尚未开始', () {
      expect(
        coupleTogetherDayNumber(DateTime(2026, 11, 8), DateTime(2026, 11, 7)),
        0,
      );
    });
  });

  group('coupleAnniversaryStatus', () {
    test('年度纪念日计算下一次到来日期', () {
      final status = coupleAnniversaryStatus({
        'title': '生日',
        'date': '2000-11-10T00:00:00.000',
        'type': 'birthday',
        'repeat': 'yearly',
      }, DateTime(2026, 11, 7));

      expect(status.label, '还有 3 天');
      expect(status.occurrence, DateTime.utc(2026, 11, 10));
    });

    test('年度 2 月 29 日在非闰年回落到月末', () {
      final status = coupleAnniversaryStatus({
        'title': '特别的一天',
        'date': '2024-02-29T00:00:00.000',
        'repeat': 'yearly',
      }, DateTime(2025, 2, 27));

      expect(status.occurrence, DateTime.utc(2025, 2, 28));
      expect(status.label, '还有 1 天');
    });

    test('一次性日期区分未来与已经过去', () {
      expect(
        coupleAnniversaryStatus({
          'title': '旅行',
          'date': '2026-11-09T00:00:00.000',
        }, DateTime(2026, 11, 7)).label,
        '还有 2 天',
      );
      expect(
        coupleAnniversaryStatus({
          'title': '相遇',
          'date': '2026-11-05T00:00:00.000',
        }, DateTime(2026, 11, 7)).label,
        '已过去 2 天',
      );
    });

    test('列表优先显示最近将到日期，再显示已经过去的日期', () {
      final sorted = sortCoupleAnniversaries([
        {'title': '旧旅行', 'date': '2026-10-01T00:00:00.000'},
        {'title': '明天', 'date': '2026-11-08T00:00:00.000'},
        {
          'title': '每年生日',
          'date': '2000-11-10T00:00:00.000',
          'type': 'birthday',
          'repeat': 'yearly',
        },
      ], DateTime(2026, 11, 7));

      expect(
        sorted.map((item) => item['title']),
        ['明天', '每年生日', '旧旅行'],
      );
    });
  });
}
