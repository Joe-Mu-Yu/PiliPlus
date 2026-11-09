import 'package:PiliPlus/pages/family_safety/location_service.dart';
import 'package:PiliPlus/utils/permission_handler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('captures one valid location after foreground permission', () async {
    final service = FamilyLocationService(
      supported: true,
      permissionRequester: () async => PermissionStatus.granted,
      locationInvoker: () async => {
        'latitude': 31.2,
        'longitude': 121.5,
        'accuracyMeters': 18.0,
        'capturedAtMs': 1794140400000,
      },
    );

    final location = await service.captureOnce();
    expect(location.latitude, 31.2);
    expect(location.longitude, 121.5);
    expect(location.accuracyMeters, 18);
  });

  test('does not invoke location when permission is denied', () async {
    var invoked = false;
    final service = FamilyLocationService(
      supported: true,
      permissionRequester: () async => PermissionStatus.denied,
      locationInvoker: () async {
        invoked = true;
        return <String, dynamic>{};
      },
    );

    await expectLater(
      service.captureOnce(),
      throwsA(
        isA<FamilyLocationException>().having(
          (error) => error.code,
          'code',
          'permission_denied',
        ),
      ),
    );
    expect(invoked, isFalse);
  });

  test('rejects unsupported platforms before requesting permission', () async {
    var requested = false;
    final service = FamilyLocationService(
      supported: false,
      permissionRequester: () async {
        requested = true;
        return PermissionStatus.granted;
      },
      locationInvoker: () async => <String, dynamic>{},
    );

    await expectLater(
      service.captureOnce(),
      throwsA(
        isA<FamilyLocationException>().having(
          (error) => error.code,
          'code',
          'unsupported',
        ),
      ),
    );
    expect(requested, isFalse);
  });
}
