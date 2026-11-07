import 'dart:async';

typedef CoupleSpacePeriodicScheduler = void Function() Function(
  Duration interval,
  void Function() callback,
);

class CoupleSpaceCloudSyncCoordinator {
  CoupleSpaceCloudSyncCoordinator({
    required this.interval,
    required this.canSync,
    required this.sync,
    this.onError,
    CoupleSpacePeriodicScheduler? periodicScheduler,
  }) : _periodicScheduler = periodicScheduler ?? _schedulePeriodic;

  final Duration interval;
  final bool Function() canSync;
  final Future<void> Function() sync;
  final void Function(Object error, StackTrace stackTrace)? onError;
  final CoupleSpacePeriodicScheduler _periodicScheduler;

  void Function()? _cancelTimer;
  bool _syncing = false;
  bool _disposed = false;

  void start() {
    if (_disposed || _cancelTimer != null) return;
    _cancelTimer = _periodicScheduler(
      interval,
      () => unawaited(syncNow()),
    );
  }

  Future<void> syncNow() async {
    if (_disposed || _syncing || !canSync()) return;
    _syncing = true;
    try {
      await sync();
    } catch (error, stackTrace) {
      onError?.call(error, stackTrace);
    } finally {
      _syncing = false;
    }
  }

  void dispose() {
    _disposed = true;
    _cancelTimer?.call();
    _cancelTimer = null;
  }

  static void Function() _schedulePeriodic(
    Duration interval,
    void Function() callback,
  ) {
    final timer = Timer.periodic(interval, (_) => callback());
    return timer.cancel;
  }
}
