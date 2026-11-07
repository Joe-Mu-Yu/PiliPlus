import 'package:PiliPlus/pages/couple_space/couple_space_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
