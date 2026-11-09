import 'dart:math';

const coupleSpaceCloudMediaPrefix = 'cloud:';

Map<String, String> coupleMemberNames(Map<String, dynamic> payload) =>
    Map<String, dynamic>.from(
      payload['memberNames'] as Map? ?? const <String, dynamic>{},
    ).map((key, value) => MapEntry(key, value.toString().trim()));

String coupleCurrentMemberName({
  required Map<String, dynamic> payload,
  required String userId,
  required String account,
}) {
  final stored = coupleMemberNames(payload)[userId];
  if (stored != null && stored.isNotEmpty) return stored;
  final normalizedAccount = account.trim();
  return normalizedAccount.isEmpty ? '我' : normalizedAccount;
}

String coupleEntryAuthorName({
  required Map<String, dynamic> payload,
  required Map<String, dynamic> entry,
  String fallback = '我们',
}) {
  final embedded = entry['authorName']?.toString().trim();
  if (embedded != null && embedded.isNotEmpty) return embedded;
  final authorId = entry['authorId']?.toString();
  final memberName = authorId == null
      ? null
      : coupleMemberNames(payload)[authorId];
  if (memberName != null && memberName.isNotEmpty) return memberName;
  final legacy = entry['author']?.toString().trim();
  if (legacy != null && legacy.isNotEmpty) return legacy;
  return fallback;
}

String? coupleCloudMediaOwnerId(Object? rawPath) {
  final path = rawPath?.toString() ?? '';
  if (!path.startsWith(coupleSpaceCloudMediaPrefix)) return null;
  final segments = path
      .substring(coupleSpaceCloudMediaPrefix.length)
      .split('/');
  if (segments.length < 3 || segments[1].isEmpty) return null;
  return segments[1];
}

Map<String, dynamic> normalizeCoupleComment(Map<String, dynamic> source) {
  final normalized = Map<String, dynamic>.from(source);
  final authorName = source['authorName']?.toString().trim();
  final legacyAuthor = source['author']?.toString().trim();
  normalized
    ..['id'] = source['id']?.toString() ?? ''
    ..['authorId'] = source['authorId']?.toString() ?? ''
    ..['authorName'] = authorName?.isNotEmpty == true
        ? authorName
        : legacyAuthor ?? ''
    ..['text'] = source['text']?.toString().trim() ?? ''
    ..['createdAt'] = source['createdAt']?.toString() ?? '';
  return normalized;
}

Map<String, dynamic> normalizeCoupleMoment(
  Map<String, dynamic> source,
  Map<String, dynamic> payload,
) {
  final normalized = Map<String, dynamic>.from(source);
  final rawPhotos = source['photos'];
  final photos = rawPhotos is List
      ? rawPhotos.map((path) => path.toString()).toList()
      : <String>[
          if (source['path']?.toString().isNotEmpty == true)
            source['path'].toString(),
        ];
  final embeddedAuthorId = source['authorId']?.toString().trim();
  final inferredAuthorId = photos
      .map(coupleCloudMediaOwnerId)
      .whereType<String>()
      .firstOrNull;
  final authorId = embeddedAuthorId?.isNotEmpty == true
      ? embeddedAuthorId!
      : inferredAuthorId ?? '';
  final embeddedAuthorName = source['authorName']?.toString().trim();
  final memberName = coupleMemberNames(payload)[authorId];
  normalized
    ..['photos'] = photos
    ..remove('path')
    ..['authorId'] = authorId
    ..['authorName'] = embeddedAuthorName?.isNotEmpty == true
        ? embeddedAuthorName
        : memberName ?? ''
    ..['comments'] = (source['comments'] as List? ?? const [])
        .map(
          (comment) => normalizeCoupleComment(
            Map<String, dynamic>.from(comment as Map),
          ),
        )
        .toList();
  return normalized;
}

Map<String, dynamic> createCoupleComment({
  required String id,
  required String authorId,
  required String authorName,
  required String text,
  required DateTime createdAt,
}) => {
  'id': id,
  'authorId': authorId,
  'authorName': authorName,
  'text': text.trim(),
  'createdAt': createdAt.toUtc().toIso8601String(),
};

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
