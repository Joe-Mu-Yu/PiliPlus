import 'dart:math';

enum CoupleAnniversaryType {
  love('恋爱', 'love'),
  birthday('生日', 'birthday'),
  festival('节日', 'festival'),
  custom('自定义', 'custom');

  const CoupleAnniversaryType(this.label, this.value);

  final String label;
  final String value;

  static CoupleAnniversaryType fromValue(Object? value) => values.firstWhere(
    (type) => type.value == value,
    orElse: () => CoupleAnniversaryType.custom,
  );
}

enum CoupleAnniversaryRepeat {
  none('不重复', 'none'),
  yearly('每年', 'yearly');

  const CoupleAnniversaryRepeat(this.label, this.value);

  final String label;
  final String value;

  static CoupleAnniversaryRepeat fromValue(Object? value) => values.firstWhere(
    (repeat) => repeat.value == value,
    orElse: () => CoupleAnniversaryRepeat.none,
  );
}

DateTime coupleLocalDate(DateTime value) => DateTime.utc(
  value.year,
  value.month,
  value.day,
);

int coupleTogetherDayNumber(DateTime startDate, DateTime now) {
  final difference = coupleLocalDate(now).difference(
    coupleLocalDate(startDate),
  );
  if (difference.isNegative) return 0;
  return difference.inDays + 1;
}

Map<String, dynamic> normalizeCoupleAnniversary(
  Map<String, dynamic> source,
) {
  final normalized = Map<String, dynamic>.from(source);
  final type = CoupleAnniversaryType.fromValue(source['type']);
  final inferredRepeat =
      type == CoupleAnniversaryType.birthday ||
          type == CoupleAnniversaryType.festival
      ? CoupleAnniversaryRepeat.yearly
      : CoupleAnniversaryRepeat.none;
  normalized
    ..['id'] = source['id']?.toString() ?? ''
    ..['title'] = source['title']?.toString().trim() ?? ''
    ..['date'] = source['date']?.toString() ?? DateTime.now().toIso8601String()
    ..['type'] = type.value
    ..['repeat'] = source.containsKey('repeat')
        ? CoupleAnniversaryRepeat.fromValue(source['repeat']).value
        : inferredRepeat.value;
  return normalized;
}

class CoupleAnniversaryStatus {
  const CoupleAnniversaryStatus({
    required this.occurrence,
    required this.days,
    required this.label,
    required this.isUpcoming,
  });

  final DateTime occurrence;
  final int days;
  final String label;
  final bool isUpcoming;
}

CoupleAnniversaryStatus coupleAnniversaryStatus(
  Map<String, dynamic> raw,
  DateTime now,
) {
  final item = normalizeCoupleAnniversary(raw);
  final today = coupleLocalDate(now);
  final parsed = DateTime.tryParse(item['date'].toString()) ?? now;
  final eventDate = coupleLocalDate(parsed);
  final repeat = CoupleAnniversaryRepeat.fromValue(item['repeat']);
  if (repeat == CoupleAnniversaryRepeat.yearly) {
    var occurrence = _safeAnnualDate(
      today.year,
      eventDate.month,
      eventDate.day,
    );
    if (occurrence.isBefore(today)) {
      occurrence = _safeAnnualDate(
        today.year + 1,
        eventDate.month,
        eventDate.day,
      );
    }
    final days = occurrence.difference(today).inDays;
    return CoupleAnniversaryStatus(
      occurrence: occurrence,
      days: days,
      label: days == 0 ? '就是今天' : '还有 $days 天',
      isUpcoming: true,
    );
  }

  final delta = eventDate.difference(today).inDays;
  if (delta == 0) {
    return CoupleAnniversaryStatus(
      occurrence: eventDate,
      days: 0,
      label: '就是今天',
      isUpcoming: true,
    );
  }
  if (delta > 0) {
    return CoupleAnniversaryStatus(
      occurrence: eventDate,
      days: delta,
      label: '还有 $delta 天',
      isUpcoming: true,
    );
  }
  final elapsed = delta.abs();
  return CoupleAnniversaryStatus(
    occurrence: eventDate,
    days: elapsed,
    label: '已过去 $elapsed 天',
    isUpcoming: false,
  );
}

List<Map<String, dynamic>> sortCoupleAnniversaries(
  Iterable<Map<String, dynamic>> values,
  DateTime now,
) {
  final items = values.map(normalizeCoupleAnniversary).toList();
  return items..sort((left, right) {
    final leftStatus = coupleAnniversaryStatus(left, now);
    final rightStatus = coupleAnniversaryStatus(right, now);
    if (leftStatus.isUpcoming != rightStatus.isUpcoming) {
      return leftStatus.isUpcoming ? -1 : 1;
    }
    if (leftStatus.isUpcoming) {
      return leftStatus.occurrence.compareTo(rightStatus.occurrence);
    }
    return rightStatus.occurrence.compareTo(leftStatus.occurrence);
  });
}

DateTime _safeAnnualDate(int year, int month, int day) {
  final lastDay = DateTime.utc(year, month + 1, 0).day;
  return DateTime.utc(year, month, min(day, lastDay));
}
