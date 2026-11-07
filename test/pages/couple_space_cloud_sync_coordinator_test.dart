import 'dart:async';

import 'package:PiliPlus/pages/couple_space/cloud_sync_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('polls on schedule only while shared state can sync', () async {
    var eligible = true;
    var syncCount = 0;
    var cancelled = false;
    late void Function() tick;
    final coordinator = CoupleSpaceCloudSyncCoordinator(
      interval: const Duration(seconds: 15),
      canSync: () => eligible,
      sync: () async {
        syncCount += 1;
      },
      periodicScheduler: (interval, callback) {
        expect(interval, const Duration(seconds: 15));
        tick = callback;
        return () => cancelled = true;
      },
    )..start();

    tick();
    await Future<void>.delayed(Duration.zero);
    expect(syncCount, 1);

    eligible = false;
    tick();
    await Future<void>.delayed(Duration.zero);
    expect(syncCount, 1);

    coordinator.dispose();
    expect(cancelled, isTrue);
    eligible = true;
    await coordinator.syncNow();
    expect(syncCount, 1);
  });

  test(
    'resume sync coalesces overlapping requests and reports failures',
    () async {
      var syncCount = 0;
      Object? reportedError;
      final firstSync = Completer<void>();
      final coordinator = CoupleSpaceCloudSyncCoordinator(
        interval: const Duration(minutes: 1),
        canSync: () => true,
        sync: () {
          syncCount += 1;
          if (syncCount == 1) return firstSync.future;
          throw StateError('network unavailable');
        },
        onError: (error, _) => reportedError = error,
      );

      final first = coordinator.syncNow();
      await coordinator.syncNow();
      expect(syncCount, 1);

      firstSync.complete();
      await first;
      await coordinator.syncNow();
      expect(syncCount, 2);
      expect(reportedError, isA<StateError>());

      coordinator.dispose();
    },
  );
}
