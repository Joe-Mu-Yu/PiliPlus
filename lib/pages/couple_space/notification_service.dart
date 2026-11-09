import 'package:PiliPlus/pages/couple_space/couple_space_model.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

abstract interface class CoupleSpaceNotifier {
  Future<bool> prepare();

  Future<bool> show(CoupleSpaceActivityNotification notification);
}

class CoupleSpaceNotificationService implements CoupleSpaceNotifier {
  CoupleSpaceNotificationService({
    MethodChannel? channel,
    Future<bool> Function()? requestPermission,
  }) : _channel = channel ?? const MethodChannel(_channelName),
       _requestPermission = requestPermission ?? _requestAndroidPermission;

  static const _channelName = 'hyper_piliplus/couple_space_notifications';

  final MethodChannel _channel;
  final Future<bool> Function() _requestPermission;
  Future<bool>? _permissionRequest;

  @override
  Future<bool> prepare() {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return Future.value(false);
    }
    return _permissionRequest ??= _prepareAndroidPermission();
  }

  Future<bool> _prepareAndroidPermission() async {
    try {
      return await _requestPermission();
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<bool> show(CoupleSpaceActivityNotification notification) async {
    if (!await prepare()) return false;
    try {
      return await _channel.invokeMethod<bool>('show', {
            'id': notification.id,
            'title': notification.title,
            'body': notification.body,
            'count': notification.count,
          }) ??
          false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  static Future<bool> _requestAndroidPermission() async =>
      (await Permission.notification.request()).isGranted;
}
