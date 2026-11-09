import 'package:PiliPlus/pages/couple_space/cloudbase_repository.dart';
import 'package:PiliPlus/pages/family_safety/location_service.dart';
import 'package:PiliPlus/pages/family_safety/model.dart';

const familySafetyConsentVersion = 'family-safety-v1';

class FamilySafetyCloudRepository {
  FamilySafetyCloudRepository({CoupleSpaceCloudRepository? cloud})
    : _cloud = cloud ?? CoupleSpaceCloudRepository.appSession;

  final CoupleSpaceCloudRepository _cloud;

  bool get isSignedIn => _cloud.isSignedIn;
  String get account => _cloud.account;

  Future<void> signIn({
    required String account,
    required String password,
  }) => _cloud.signIn(account: account, password: password);

  void signOut() => _cloud.signOut();

  Future<FamilySafetySnapshot?> loadSnapshot() async {
    final result = await _cloud.authenticatedRpc(
      'get_family_safety_snapshot',
      {'p_group_id': null},
    );
    final json = familySafetyMap(result);
    return json.isEmpty ? null : FamilySafetySnapshot.fromJson(json);
  }

  Future<FamilySafetyGroup> createGroup(String name) async {
    final result = await _cloud.authenticatedRpc(
      'create_family_safety_group',
      {
        'p_name': name.trim(),
        'p_consent_version': familySafetyConsentVersion,
      },
    );
    return FamilySafetyGroup.fromJson(familySafetyMap(result));
  }

  Future<String> createInvite(String groupId) async {
    final result = await _cloud.authenticatedRpc(
      'create_family_safety_invite',
      {'p_group_id': groupId},
    );
    if (result is String) return result;
    final json = familySafetyMap(result);
    return (json['create_family_safety_invite'] ?? json['token'] ?? '')
        .toString();
  }

  Future<FamilySafetyGroup> joinGroup(String inviteCode) async {
    final result = await _cloud.authenticatedRpc(
      'join_family_safety_group',
      {
        'p_token': inviteCode.trim(),
        'p_consent_version': familySafetyConsentVersion,
      },
    );
    return FamilySafetyGroup.fromJson(familySafetyMap(result));
  }

  Future<void> requestCheckIn({
    required String groupId,
    required String message,
  }) async {
    await _cloud.authenticatedRpc(
      'request_family_check_in',
      {'p_group_id': groupId, 'p_message': message.trim()},
    );
  }

  Future<void> shareLocation({
    required String requestId,
    required FamilyCapturedLocation location,
  }) async {
    await _cloud.authenticatedRpc(
      'respond_family_check_in',
      {
        'p_request_id': requestId,
        'p_action': 'share',
        'p_latitude': location.latitude,
        'p_longitude': location.longitude,
        'p_accuracy_meters': location.accuracyMeters,
        'p_captured_at': location.capturedAt.toUtc().toIso8601String(),
      },
    );
  }

  Future<void> declineCheckIn(String requestId) async {
    await _cloud.authenticatedRpc(
      'respond_family_check_in',
      {
        'p_request_id': requestId,
        'p_action': 'decline',
        'p_latitude': null,
        'p_longitude': null,
        'p_accuracy_meters': null,
        'p_captured_at': null,
      },
    );
  }

  Future<void> revokeGroup(String groupId) async {
    await _cloud.authenticatedRpc(
      'revoke_family_safety_group',
      {'p_group_id': groupId},
    );
  }

  Future<void> deleteGroup(String groupId) async {
    await _cloud.authenticatedRpc(
      'delete_family_safety_group',
      {'p_group_id': groupId},
    );
  }
}
