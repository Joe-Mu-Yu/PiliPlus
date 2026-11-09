import 'package:PiliPlus/pages/family_safety/cloudbase_repository.dart';
import 'package:PiliPlus/pages/family_safety/location_service.dart';
import 'package:PiliPlus/pages/family_safety/model.dart';
import 'package:PiliPlus/pages/family_safety/view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('logged out page explains transparent one-shot sharing', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: FamilySafetyPage(repository: _FakeFamilyRepository()),
      ),
    );

    expect(find.text('透明、按需、可撤销'), findsOneWidget);
    expect(find.text('登录家庭服务账号'), findsOneWidget);
    expect(find.textContaining('不是静默追踪工具'), findsOneWidget);
  });

  testWidgets('caregiver sees request and explicit empty location state', (
    tester,
  ) async {
    final repository = _FakeFamilyRepository(
      signedIn: true,
      snapshot: FamilySafetySnapshot(
        group: FamilySafetyGroup(
          id: 'family-a',
          name: '测试家庭',
          careRecipientId: 'recipient-a',
          caregiverId: 'caregiver-b',
          status: 'active',
          consentVersion: familySafetyConsentVersion,
          createdAt: DateTime(2026, 11, 8),
        ),
        currentUserId: 'caregiver-b',
        latestRequest: null,
        latestLocation: null,
        events: const [],
      ),
    );
    await tester.pumpWidget(
      MaterialApp(home: FamilySafetyPage(repository: repository)),
    );
    await tester.pumpAndSettle();

    expect(find.text('测试家庭'), findsOneWidget);
    expect(find.text('照护端'), findsOneWidget);
    expect(find.text('请求报平安'), findsOneWidget);
    expect(find.text('尚无可用位置'), findsOneWidget);
    expect(find.textContaining('只有被照护端明确同意'), findsOneWidget);
  });

  testWidgets('caregiver page remains scrollable on a narrow large-text view', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    final repository = _FakeFamilyRepository(
      signedIn: true,
      snapshot: FamilySafetySnapshot(
        group: FamilySafetyGroup(
          id: 'family-a',
          name: '测试家庭',
          careRecipientId: 'recipient-a',
          caregiverId: 'caregiver-b',
          status: 'active',
          consentVersion: familySafetyConsentVersion,
          createdAt: DateTime(2026, 11, 8),
        ),
        currentUserId: 'caregiver-b',
        latestRequest: null,
        latestLocation: null,
        events: const [],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(home: FamilySafetyPage(repository: repository)),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('永久删除'), findsOneWidget);
  });

  testWidgets('recipient explicitly confirms before sharing one location', (
    tester,
  ) async {
    final request = FamilyCheckInRequest(
      id: 'request-a',
      groupId: 'family-a',
      message: '请报平安',
      status: FamilyCheckInStatus.pending,
      requestedAt: DateTime(2026, 11, 9),
      expiresAt: DateTime(2026, 11, 10),
    );
    final repository = _FakeFamilyRepository(
      signedIn: true,
      snapshot: FamilySafetySnapshot(
        group: FamilySafetyGroup(
          id: 'family-a',
          name: '测试家庭',
          careRecipientId: 'recipient-a',
          caregiverId: 'caregiver-b',
          status: 'active',
          consentVersion: familySafetyConsentVersion,
          createdAt: DateTime(2026, 11, 8),
        ),
        currentUserId: 'recipient-a',
        latestRequest: request,
        latestLocation: null,
        events: const [],
      ),
    );
    final locationService = _FakeFamilyLocationService();
    await tester.pumpWidget(
      MaterialApp(
        home: FamilySafetyPage(
          repository: repository,
          locationService: locationService,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('共享这一次位置'));
    await tester.pumpAndSettle();
    expect(find.text('共享这一次位置？'), findsOneWidget);
    expect(locationService.captureCount, 0);
    expect(repository.sharedRequestId, isNull);

    await tester.tap(find.text('确认并共享'));
    await tester.pumpAndSettle();
    expect(locationService.captureCount, 1);
    expect(repository.sharedRequestId, 'request-a');
  });
}

class _FakeFamilyRepository extends FamilySafetyCloudRepository {
  _FakeFamilyRepository({this.signedIn = false, this.snapshot});

  final bool signedIn;
  final FamilySafetySnapshot? snapshot;
  String? sharedRequestId;

  @override
  bool get isSignedIn => signedIn;

  @override
  String get account => signedIn ? 'caregiver' : '';

  @override
  Future<FamilySafetySnapshot?> loadSnapshot() async => snapshot;

  @override
  Future<void> shareLocation({
    required String requestId,
    required FamilyCapturedLocation location,
  }) async {
    sharedRequestId = requestId;
  }
}

class _FakeFamilyLocationService extends FamilyLocationService {
  _FakeFamilyLocationService() : super(supported: true);

  int captureCount = 0;

  @override
  Future<FamilyCapturedLocation> captureOnce() async {
    captureCount += 1;
    return FamilyCapturedLocation(
      latitude: 39.916527,
      longitude: 116.397128,
      accuracyMeters: 5,
      capturedAt: DateTime(2026, 11, 9),
    );
  }
}
