import 'dart:async';
import 'dart:io';

import 'package:PiliPlus/firebase_options.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';

/// Firebase features owned by the Hyper-PiliPlus app.
///
/// Pure Live uses its own named Firebase app. The default Firebase app is kept
/// for this project's FCM and self-service location sharing.
class PrivateDeviceServices extends GetxService with WidgetsBindingObserver {
  static const broadcastTopic = 'hyperpiliplus_broadcast';
  final RxBool broadcastEnabled = false.obs;
  final RxBool locationSharingEnabled = false.obs;
  final RxBool isReady = false.obs;
  final RxString initializationError = ''.obs;

  FirebaseApp? _app;
  FirebaseAuth? _auth;
  FirebaseFirestore? _firestore;
  FirebaseMessaging? _messaging;
  // These app-lifetime listeners are cancelled in onClose.
  // ignore: cancel_subscriptions
  StreamSubscription<RemoteMessage>? _messageSubscription;
  // ignore: cancel_subscriptions
  StreamSubscription<RemoteMessage>? _messageOpenedSubscription;
  // The foreground-only location stream is cancelled when sharing stops.
  // ignore: cancel_subscriptions
  StreamSubscription<Position>? _positionSubscription;
  Future<void> _locationQueue = Future<void>.value();
  bool _foreground = false;
  bool _disposed = false;

  String get deviceAlias => GStorage.setting.get(
    SettingBoxKey.privateBroadcastDeviceAlias,
    defaultValue: 'Android 设备',
  );

  Future<void> initialize() async {
    if (!Platform.isAndroid) return;

    try {
      _app = await Firebase.initializeApp(
        options: HyperFirebaseOptions.android,
      );
      _auth = FirebaseAuth.instanceFor(app: _app!);
      _firestore = FirebaseFirestore.instanceFor(app: _app!)
        ..settings = const Settings(persistenceEnabled: false);
      _messaging = FirebaseMessaging.instance;

      _messageSubscription = FirebaseMessaging.onMessage.listen(_showMessage);
      _messageOpenedSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
        _showMessage,
      );
      WidgetsBinding.instance.addObserver(this);
      isReady.value = true;

      final initialMessage = await _messaging!.getInitialMessage();
      if (initialMessage != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!_disposed) _showMessage(initialMessage);
        });
      }

      if (GStorage.setting.get(
        SettingBoxKey.enablePrivateBroadcast,
        defaultValue: false,
      )) {
        await _syncBroadcastSubscriptionSafely();
      } else {
        broadcastEnabled.value = false;
      }

      if (GStorage.setting.get(
        SettingBoxKey.locationCleanupPending,
        defaultValue: false,
      )) {
        unawaited(_deleteOwnLocation());
      }

      locationSharingEnabled.value = GStorage.setting.get(
        SettingBoxKey.enableLocationSharing,
        defaultValue: false,
      );
      if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        unawaited(_resumeLocationSharingSafely());
      }
    } catch (error) {
      initializationError.value = _friendlyError(error);
    }
  }

  Future<void> setBroadcastEnabled(bool enabled) async {
    _requireReady();
    if (!enabled) {
      await _messaging!.unsubscribeFromTopic(broadcastTopic);
      await GStorage.setting.put(SettingBoxKey.enablePrivateBroadcast, false);
      broadcastEnabled.value = false;
      return;
    }

    final permission = await _messaging!.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (!_notificationPermissionGranted(permission.authorizationStatus)) {
      throw StateError('未获得通知权限，请在系统设置中允许 Hyper-PiliPlus 发送通知。');
    }

    await _messaging!.subscribeToTopic(broadcastTopic);
    await GStorage.setting.put(SettingBoxKey.enablePrivateBroadcast, true);
    broadcastEnabled.value = true;
  }

  Future<void> setLocationSharingEnabled(bool enabled) async {
    _requireReady();
    if (!enabled) {
      locationSharingEnabled.value = false;
      await GStorage.setting.put(SettingBoxKey.enableLocationSharing, false);
      await _stopLocationStream();
      await GStorage.setting.put(SettingBoxKey.locationCleanupPending, true);
      unawaited(_deleteOwnLocation());
      return;
    }

    if (!await Geolocator.isLocationServiceEnabled()) {
      throw StateError('请先在系统设置中开启定位服务。');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      throw StateError('定位权限已被永久拒绝，请到系统设置中允许“使用期间”定位。');
    }
    if (permission == LocationPermission.denied) {
      throw StateError('未获得定位权限，位置共享保持关闭。');
    }

    await _ensureAnonymousUser();
    await GStorage.setting.put(SettingBoxKey.enableLocationSharing, true);
    locationSharingEnabled.value = true;
    if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
      await _resumeLocationSharing();
    }
  }

  Future<void> setDeviceAlias(String alias) async {
    final normalized = alias.trim();
    if (normalized.isEmpty) throw StateError('设备别名不能为空。');
    if (normalized.length > 48) throw StateError('设备别名最多 48 个字符。');
    await GStorage.setting.put(
      SettingBoxKey.privateBroadcastDeviceAlias,
      normalized,
    );
  }

  Future<void> _syncBroadcastSubscription() async {
    final settings = await _messaging!.getNotificationSettings();
    if (_notificationPermissionGranted(settings.authorizationStatus)) {
      await _messaging!.subscribeToTopic(broadcastTopic);
      broadcastEnabled.value = true;
    } else {
      await _messaging!.unsubscribeFromTopic(broadcastTopic);
      broadcastEnabled.value = false;
    }
  }

  bool _notificationPermissionGranted(AuthorizationStatus status) =>
      status == AuthorizationStatus.authorized ||
      status == AuthorizationStatus.provisional;

  void _showMessage(RemoteMessage message) {
    final title =
        message.notification?.title ?? message.data['title']?.toString();
    final body = message.notification?.body ?? message.data['body']?.toString();
    final text = [
      if (title?.trim().isNotEmpty == true) title!.trim(),
      if (body?.trim().isNotEmpty == true) body!.trim(),
    ].join('\n');
    if (text.isNotEmpty) SmartDialog.showToast(text);
  }

  Future<void> _ensureAnonymousUser() async {
    if (_auth!.currentUser != null) return;
    await _auth!.signInAnonymously();
  }

  Future<void> _resumeLocationSharing() async {
    if (_disposed || !isReady.value || !locationSharingEnabled.value) return;
    _foreground = true;

    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      locationSharingEnabled.value = false;
      await GStorage.setting.put(SettingBoxKey.enableLocationSharing, false);
      await _stopLocationStream();
      await GStorage.setting.put(SettingBoxKey.locationCleanupPending, true);
      unawaited(_deleteOwnLocation());
      return;
    }
    if (!await Geolocator.isLocationServiceEnabled()) return;
    if (_positionSubscription != null) return;

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.medium,
      distanceFilter: 100,
    );
    _positionSubscription =
        Geolocator.getPositionStream(
          locationSettings: locationSettings,
        ).listen(
          (position) => unawaited(_writePosition(position)),
          onError: (Object error) {
            debugPrint(
              '[PrivateDeviceServices] Location stream failed: $error',
            );
          },
        );
  }

  Future<void> _writePosition(Position position) async {
    if (!_foreground || !locationSharingEnabled.value) return;
    await _enqueueLocationOperation(() async {
      if (!_foreground || !locationSharingEnabled.value) return;
      try {
        await _ensureAnonymousUser();
        if (!_foreground || !locationSharingEnabled.value) return;
        final uid = _auth!.currentUser!.uid;
        await _firestore!.collection('device_locations').doc(uid).set({
          'alias': deviceAlias,
          'latitude': position.latitude,
          'longitude': position.longitude,
          'accuracyMeters': position.accuracy,
          'updatedAt': FieldValue.serverTimestamp(),
          'platform': 'android',
        });
      } catch (error) {
        debugPrint('[PrivateDeviceServices] Location upload failed: $error');
      }
    });
  }

  Future<void> _deleteOwnLocation() => _enqueueLocationOperation(() async {
    try {
      await _ensureAnonymousUser();
      final uid = _auth!.currentUser!.uid;
      await _firestore!
          .collection('device_locations')
          .doc(uid)
          .delete()
          .timeout(const Duration(seconds: 8));
      await GStorage.setting.put(SettingBoxKey.locationCleanupPending, false);
    } catch (error) {
      debugPrint('[PrivateDeviceServices] Location cleanup pending: $error');
    }
  });

  Future<void> _enqueueLocationOperation(
    Future<void> Function() operation,
  ) {
    final next = _locationQueue.then((_) => operation());
    _locationQueue = next.catchError((Object error) {
      debugPrint('[PrivateDeviceServices] Location operation failed: $error');
    });
    return next;
  }

  Future<void> _stopLocationStream() async {
    _foreground = false;
    final subscription = _positionSubscription;
    _positionSubscription = null;
    await subscription?.cancel();
  }

  void _requireReady() {
    if (!Platform.isAndroid) throw StateError('此功能目前仅支持 Android。');
    if (!isReady.value) {
      throw StateError(
        initializationError.value.isEmpty
            ? 'Firebase 尚未初始化。'
            : initializationError.value,
      );
    }
  }

  String _friendlyError(Object error) {
    final text = error.toString();
    if (text.contains('FirebaseOptions') || text.contains('google-services')) {
      return 'Firebase 配置不可用，请检查 Android 应用配置文件。';
    }
    return 'Firebase 初始化失败：$error';
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (isReady.value) {
        if (GStorage.setting.get(
          SettingBoxKey.enablePrivateBroadcast,
          defaultValue: false,
        )) {
          unawaited(_syncBroadcastSubscriptionSafely());
        }
        unawaited(_resumeLocationSharingSafely());
        if (GStorage.setting.get(
          SettingBoxKey.locationCleanupPending,
          defaultValue: false,
        )) {
          unawaited(_deleteOwnLocation());
        }
      }
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(_stopLocationStream());
    }
  }

  Future<void> _syncBroadcastSubscriptionSafely() async {
    try {
      await _syncBroadcastSubscription();
    } catch (error) {
      debugPrint('[PrivateDeviceServices] Notification sync failed: $error');
      broadcastEnabled.value = false;
    }
  }

  Future<void> _resumeLocationSharingSafely() async {
    try {
      await _resumeLocationSharing();
    } catch (error) {
      debugPrint('[PrivateDeviceServices] Location resume failed: $error');
    }
  }

  @override
  void onClose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_messageSubscription?.cancel());
    unawaited(_messageOpenedSubscription?.cancel());
    unawaited(_stopLocationStream());
    super.onClose();
  }
}
