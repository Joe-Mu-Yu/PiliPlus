enum LiveFavoriteStatus { unknown, live, offline, replay }

/// A room saved in PiliPlus, independent from a platform account's follow list.
class LiveFavorite {
  LiveFavorite({
    required String platformId,
    required String roomId,
    required String roomUrl,
    this.title,
    this.anchorName,
    this.coverUrl,
    this.status = LiveFavoriteStatus.unknown,
    Iterable<String> tagIds = const [],
  }) : platformId = _required(platformId, 'platformId').toLowerCase(),
       roomId = _required(roomId, 'roomId'),
       roomUrl = _validatedUrl(roomUrl),
       tagIds = List.unmodifiable(
         tagIds.map((tag) => tag.trim()).where((tag) => tag.isNotEmpty).toSet(),
       );

  final String platformId;
  final String roomId;
  final String roomUrl;
  final String? title;
  final String? anchorName;
  final String? coverUrl;
  final LiveFavoriteStatus status;
  final List<String> tagIds;

  /// Platform IDs are case-insensitive; room IDs retain adapter-defined casing.
  String get identityKey => '$platformId:$roomId';

  Map<String, Object?> toJson() => {
    'platformId': platformId,
    'roomId': roomId,
    'roomUrl': roomUrl,
    'title': title,
    'anchorName': anchorName,
    'coverUrl': coverUrl,
    'status': status.name,
    'tagIds': tagIds,
  };

  factory LiveFavorite.fromJson(Map<String, Object?> json) {
    final statusName = json['status'] as String?;
    final status = LiveFavoriteStatus.values
        .where((value) => value.name == statusName)
        .firstOrNull;
    return LiveFavorite(
      platformId: json['platformId'] as String,
      roomId: json['roomId'] as String,
      roomUrl: json['roomUrl'] as String,
      title: json['title'] as String?,
      anchorName: json['anchorName'] as String?,
      coverUrl: json['coverUrl'] as String?,
      status: status ?? LiveFavoriteStatus.unknown,
      tagIds: (json['tagIds'] as List<Object?>? ?? const [])
          .whereType<String>(),
    );
  }

  static String _required(String value, String name) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(value, name, 'must not be empty');
    }
    return normalized;
  }

  static String _validatedUrl(String value) {
    final normalized = _required(value, 'roomUrl');
    final uri = Uri.tryParse(normalized);
    if (uri == null ||
        !{'http', 'https'}.contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      throw ArgumentError.value(
        value,
        'roomUrl',
        'must be an absolute HTTP(S) URL without user info',
      );
    }
    return uri.toString();
  }
}
