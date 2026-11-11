import 'dart:convert';
import 'dart:math';

const coupleSpaceCloudMediaPrefix = 'cloud:';
const coupleSpaceLivePhotoType = 'livePhoto';

class CoupleSpacePhoto {
  const CoupleSpacePhoto({
    required this.imagePath,
    this.videoPath,
    this.width,
    this.height,
  });

  final String imagePath;
  final String? videoPath;
  final int? width;
  final int? height;

  bool get isLivePhoto => videoPath?.isNotEmpty == true;

  Iterable<String> get mediaPaths sync* {
    yield imagePath;
    if (isLivePhoto) yield videoPath!;
  }

  Object toJson() {
    if (!isLivePhoto) return imagePath;
    return <String, dynamic>{
      'type': coupleSpaceLivePhotoType,
      'imagePath': imagePath,
      'videoPath': videoPath,
      if (width != null) 'width': width,
      if (height != null) 'height': height,
    };
  }

  static CoupleSpacePhoto? tryParse(Object? raw) {
    if (raw is Map) {
      final imagePath = (raw['imagePath'] ?? raw['path'])?.toString() ?? '';
      if (imagePath.isEmpty) return null;
      final videoPath = raw['videoPath']?.toString();
      return CoupleSpacePhoto(
        imagePath: imagePath,
        videoPath: videoPath?.isNotEmpty == true ? videoPath : null,
        width: _safeDimension(raw['width']),
        height: _safeDimension(raw['height']),
      );
    }
    final imagePath = raw?.toString() ?? '';
    return imagePath.isEmpty ? null : CoupleSpacePhoto(imagePath: imagePath);
  }

  @override
  bool operator ==(Object other) =>
      other is CoupleSpacePhoto &&
      imagePath == other.imagePath &&
      videoPath == other.videoPath;

  @override
  int get hashCode => Object.hash(imagePath, videoPath);
}

int? _safeDimension(Object? value) {
  final dimension = switch (value) {
    int value => value,
    num value => value.toInt(),
    String value => int.tryParse(value),
    _ => null,
  };
  return dimension != null && dimension > 0 ? dimension : null;
}

List<CoupleSpacePhoto> coupleMomentPhotos(Map<String, dynamic> moment) {
  final rawPhotos = moment['photos'];
  if (rawPhotos is List) {
    return rawPhotos
        .map(CoupleSpacePhoto.tryParse)
        .whereType<CoupleSpacePhoto>()
        .toList();
  }
  final legacy = CoupleSpacePhoto.tryParse(moment['path']);
  return legacy == null ? const [] : [legacy];
}

Map<String, dynamic> mergeCoupleMomentIntoPayload({
  required Map<String, dynamic> latestPayload,
  required Map<String, dynamic> moment,
}) {
  final merged = Map<String, dynamic>.from(
    jsonDecode(jsonEncode(latestPayload)) as Map,
  );
  final albums = List<Map<String, dynamic>>.from(
    (merged['albums'] as List? ?? const []).map(
      (item) => Map<String, dynamic>.from(item as Map),
    ),
  );
  final momentId = moment['id']?.toString();
  if (!albums.any((album) => album['id']?.toString() == momentId)) {
    albums.add(
      Map<String, dynamic>.from(jsonDecode(jsonEncode(moment)) as Map),
    );
  }
  albums.sort((a, b) {
    final aDate = DateTime.tryParse(
      (a['publishedAt'] ?? a['date']).toString(),
    );
    final bDate = DateTime.tryParse(
      (b['publishedAt'] ?? b['date']).toString(),
    );
    if (aDate == null) return bDate == null ? 0 : 1;
    if (bDate == null) return -1;
    return bDate.compareTo(aDate);
  });
  merged['albums'] = albums;
  return merged;
}

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
  final photos = coupleMomentPhotos(source);
  final embeddedAuthorId = source['authorId']?.toString().trim();
  final inferredAuthorId = photos
      .map((photo) => coupleCloudMediaOwnerId(photo.imagePath))
      .whereType<String>()
      .firstOrNull;
  final authorId = embeddedAuthorId?.isNotEmpty == true
      ? embeddedAuthorId!
      : inferredAuthorId ?? '';
  final embeddedAuthorName = source['authorName']?.toString().trim();
  final memberName = coupleMemberNames(payload)[authorId];
  normalized
    ..['photos'] = photos.map((photo) => photo.toJson()).toList()
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

class CoupleSpaceActivityNotification {
  const CoupleSpaceActivityNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.count,
  });

  final String id;
  final String title;
  final String body;
  final int count;
}

CoupleSpaceActivityNotification? coupleSpaceNotificationForChanges({
  required Map<String, dynamic> previousPayload,
  required Map<String, dynamic> currentPayload,
  required String currentUserId,
}) {
  final changes = <({String id, String body})>[];
  final previousMoments = _coupleEntriesById(previousPayload['albums']);
  final currentMoments = _coupleEntries(currentPayload['albums']);
  for (final moment in currentMoments) {
    final momentId = _coupleEntryId(moment);
    final previous = previousMoments[momentId];
    if (previous == null) {
      if (_isOtherCoupleMember(moment, currentUserId)) {
        final author = coupleEntryAuthorName(
          payload: currentPayload,
          entry: moment,
          fallback: 'TA',
        );
        final photoCount = (moment['photos'] as List?)?.length ?? 0;
        changes.add((
          id: 'moment:$momentId',
          body: '$author 发布了${photoCount > 0 ? '$photoCount 张照片' : '一条相册动态'}',
        ));
      }
      continue;
    }
    _collectNewCoupleComments(
      changes: changes,
      previousEntry: previous,
      currentEntry: moment,
      currentPayload: currentPayload,
      currentUserId: currentUserId,
      entryLabel: '相册动态',
    );
  }

  final previousMessages = _coupleEntriesById(previousPayload['messages']);
  final currentMessages = _coupleEntries(currentPayload['messages']);
  for (final message in currentMessages) {
    final messageId = _coupleEntryId(message);
    final previous = previousMessages[messageId];
    if (previous == null) {
      if (_isOtherCoupleMember(message, currentUserId)) {
        final author = coupleEntryAuthorName(
          payload: currentPayload,
          entry: message,
          fallback: 'TA',
        );
        final isVoice = message['type'] == 'voice';
        final text = message['text']?.toString().trim() ?? '';
        changes.add((
          id: 'message:$messageId',
          body: isVoice
              ? '$author 发来一条语音心语'
              : text.isEmpty
              ? '$author 发来一条心语'
              : '$author：${_coupleNotificationExcerpt(text)}',
        ));
      }
      continue;
    }
    _collectNewCoupleComments(
      changes: changes,
      previousEntry: previous,
      currentEntry: message,
      currentPayload: currentPayload,
      currentUserId: currentUserId,
      entryLabel: '心语',
    );
  }

  if (changes.isEmpty) return null;
  final latest = changes.first;
  return CoupleSpaceActivityNotification(
    id: latest.id,
    title: changes.length == 1 ? '小窝有新消息' : '小窝有 ${changes.length} 条新消息',
    body: latest.body,
    count: changes.length,
  );
}

List<Map<String, dynamic>> _coupleEntries(Object? raw) => raw is List
    ? raw.whereType<Map>().map(Map<String, dynamic>.from).toList()
    : const [];

Map<String, Map<String, dynamic>> _coupleEntriesById(Object? raw) => {
  for (final entry in _coupleEntries(raw)) _coupleEntryId(entry): entry,
};

String _coupleEntryId(Map<String, dynamic> entry) {
  final id = entry['id']?.toString();
  if (id != null && id.isNotEmpty) return id;
  return '${entry['authorId']}:${entry['date'] ?? entry['publishedAt']}:${entry['text'] ?? entry['caption']}';
}

bool _isOtherCoupleMember(
  Map<String, dynamic> entry,
  String currentUserId,
) {
  final authorId = entry['authorId']?.toString() ?? '';
  return authorId.isNotEmpty && authorId != currentUserId;
}

void _collectNewCoupleComments({
  required List<({String id, String body})> changes,
  required Map<String, dynamic> previousEntry,
  required Map<String, dynamic> currentEntry,
  required Map<String, dynamic> currentPayload,
  required String currentUserId,
  required String entryLabel,
}) {
  final previousIds = _coupleEntries(previousEntry['comments'])
      .map(_coupleEntryId)
      .toSet();
  for (final comment in _coupleEntries(currentEntry['comments'])) {
    final commentId = _coupleEntryId(comment);
    if (previousIds.contains(commentId) ||
        !_isOtherCoupleMember(comment, currentUserId)) {
      continue;
    }
    final author = coupleEntryAuthorName(
      payload: currentPayload,
      entry: comment,
      fallback: 'TA',
    );
    final text = comment['text']?.toString().trim() ?? '';
    changes.add((
      id: 'comment:$commentId',
      body: text.isEmpty
          ? '$author 评论了你的$entryLabel'
          : '$author 评论$entryLabel：${_coupleNotificationExcerpt(text)}',
    ));
  }
}

String _coupleNotificationExcerpt(String text) {
  const maxCharacters = 48;
  final characters = text.runes.toList();
  if (characters.length <= maxCharacters) return text;
  return '${String.fromCharCodes(characters.take(maxCharacters))}…';
}

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
