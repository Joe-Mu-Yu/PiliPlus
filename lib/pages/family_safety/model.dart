enum FamilySafetyRole { careRecipient, caregiver }

enum FamilyCheckInStatus { pending, shared, declined, expired }

class FamilySafetyGroup {
  const FamilySafetyGroup({
    required this.id,
    required this.name,
    required this.careRecipientId,
    required this.caregiverId,
    required this.status,
    required this.consentVersion,
    required this.createdAt,
  });

  factory FamilySafetyGroup.fromJson(Map<String, dynamic> json) =>
      FamilySafetyGroup(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '我的家庭',
        careRecipientId: json['care_recipient_id']?.toString() ?? '',
        caregiverId: _nullableString(json['caregiver_id']),
        status: json['status']?.toString() ?? 'active',
        consentVersion: json['consent_version']?.toString() ?? '',
        createdAt: _dateTime(json['created_at']),
      );

  final String id;
  final String name;
  final String careRecipientId;
  final String? caregiverId;
  final String status;
  final String consentVersion;
  final DateTime? createdAt;

  bool get isPaired => caregiverId?.isNotEmpty == true;
}

class FamilyCheckInRequest {
  const FamilyCheckInRequest({
    required this.id,
    required this.groupId,
    required this.message,
    required this.status,
    required this.requestedAt,
    required this.expiresAt,
  });

  factory FamilyCheckInRequest.fromJson(Map<String, dynamic> json) =>
      FamilyCheckInRequest(
        id: json['id']?.toString() ?? '',
        groupId: json['group_id']?.toString() ?? '',
        message: json['message']?.toString() ?? '',
        status: FamilyCheckInStatus.values.firstWhere(
          (value) => value.name == json['status']?.toString(),
          orElse: () => FamilyCheckInStatus.expired,
        ),
        requestedAt: _dateTime(json['requested_at']),
        expiresAt: _dateTime(json['expires_at']),
      );

  final String id;
  final String groupId;
  final String message;
  final FamilyCheckInStatus status;
  final DateTime? requestedAt;
  final DateTime? expiresAt;

  bool get isPending =>
      status == FamilyCheckInStatus.pending &&
      (expiresAt == null || expiresAt!.isAfter(DateTime.now()));
}

class FamilySharedLocation {
  const FamilySharedLocation({
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    required this.capturedAt,
    required this.expiresAt,
  });

  factory FamilySharedLocation.fromJson(Map<String, dynamic> json) =>
      FamilySharedLocation(
        latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
        longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
        accuracyMeters: (json['accuracy_meters'] as num?)?.toDouble() ?? 0,
        capturedAt: _dateTime(json['captured_at']),
        expiresAt: _dateTime(json['expires_at']),
      );

  final double latitude;
  final double longitude;
  final double accuracyMeters;
  final DateTime? capturedAt;
  final DateTime? expiresAt;

  bool get isExpired =>
      expiresAt != null && !expiresAt!.isAfter(DateTime.now());
}

class FamilySafetyEvent {
  const FamilySafetyEvent({
    required this.id,
    required this.actorId,
    required this.type,
    required this.createdAt,
  });

  factory FamilySafetyEvent.fromJson(Map<String, dynamic> json) =>
      FamilySafetyEvent(
        id: (json['id'] as num?)?.toInt() ?? 0,
        actorId: json['actor_id']?.toString() ?? '',
        type: json['event_type']?.toString() ?? '',
        createdAt: _dateTime(json['created_at']),
      );

  final int id;
  final String actorId;
  final String type;
  final DateTime? createdAt;
}

class FamilySafetySnapshot {
  const FamilySafetySnapshot({
    required this.group,
    required this.currentUserId,
    required this.latestRequest,
    required this.latestLocation,
    required this.events,
  });

  factory FamilySafetySnapshot.fromJson(Map<String, dynamic> json) {
    final group = _map(json['group']);
    final request = _map(json['latest_request']);
    final location = _map(json['latest_location']);
    final events = json['events'];
    return FamilySafetySnapshot(
      group: FamilySafetyGroup.fromJson(group),
      currentUserId: json['current_user_id']?.toString() ?? '',
      latestRequest: request.isEmpty
          ? null
          : FamilyCheckInRequest.fromJson(request),
      latestLocation: location.isEmpty
          ? null
          : FamilySharedLocation.fromJson(location),
      events: events is List
          ? events
                .map(_map)
                .where((item) => item.isNotEmpty)
                .map(FamilySafetyEvent.fromJson)
                .toList(growable: false)
          : const [],
    );
  }

  final FamilySafetyGroup group;
  final String currentUserId;
  final FamilyCheckInRequest? latestRequest;
  final FamilySharedLocation? latestLocation;
  final List<FamilySafetyEvent> events;

  FamilySafetyRole get role => currentUserId == group.careRecipientId
      ? FamilySafetyRole.careRecipient
      : FamilySafetyRole.caregiver;
}

Map<String, dynamic> familySafetyMap(dynamic value) => _map(value);

Map<String, dynamic> _map(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  if (value is List && value.length == 1) return _map(value.first);
  return <String, dynamic>{};
}

String? _nullableString(dynamic value) {
  final text = value?.toString();
  return text == null || text.isEmpty ? null : text;
}

DateTime? _dateTime(dynamic value) =>
    value == null ? null : DateTime.tryParse(value.toString())?.toLocal();
