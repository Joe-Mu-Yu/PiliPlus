import 'dart:io';

import 'package:PiliPlus/utils/permission_handler.dart';
import 'package:flutter/services.dart';

typedef FamilyLocationPermissionRequester = Future<PermissionStatus> Function();
typedef FamilyLocationInvoker = Future<dynamic> Function();

class FamilyCapturedLocation {
  const FamilyCapturedLocation({
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    required this.capturedAt,
  });

  final double latitude;
  final double longitude;
  final double accuracyMeters;
  final DateTime capturedAt;
}

class FamilyLocationException implements Exception {
  const FamilyLocationException(this.code, this.message);

  final String code;
  final String message;

  bool get canOpenSettings => code == 'permission_permanently_denied';

  @override
  String toString() => message;
}

class FamilyLocationService {
  FamilyLocationService({
    FamilyLocationPermissionRequester? permissionRequester,
    FamilyLocationInvoker? locationInvoker,
    bool? supported,
  }) : _permissionRequester =
           permissionRequester ??
           (() => Permission.locationWhenInUse.request()),
       _locationInvoker =
           locationInvoker ??
           (() => _channel.invokeMethod<dynamic>('getCurrentLocation')),
       _supported = supported ?? Platform.isAndroid;

  static const MethodChannel _channel = MethodChannel(
    'hyper_piliplus/family_location',
  );

  final FamilyLocationPermissionRequester _permissionRequester;
  final FamilyLocationInvoker _locationInvoker;
  final bool _supported;

  Future<FamilyCapturedLocation> captureOnce() async {
    if (!_supported) {
      throw const FamilyLocationException(
        'unsupported',
        '当前版本仅支持在 Android 设备上共享位置',
      );
    }

    final permission = await _permissionRequester();
    if (permission.isPermanentlyDenied) {
      throw const FamilyLocationException(
        'permission_permanently_denied',
        '位置权限已被永久拒绝，请在系统设置中手动开启',
      );
    }
    if (!permission.isGranted && !permission.isLimited) {
      throw const FamilyLocationException(
        'permission_denied',
        '未获得位置权限，本次没有共享任何位置',
      );
    }

    try {
      final result = await _locationInvoker();
      final map = result is Map
          ? Map<String, dynamic>.from(result)
          : <String, dynamic>{};
      final latitude = (map['latitude'] as num?)?.toDouble();
      final longitude = (map['longitude'] as num?)?.toDouble();
      final accuracy = (map['accuracyMeters'] as num?)?.toDouble();
      final capturedAtMs = (map['capturedAtMs'] as num?)?.toInt();
      if (latitude == null ||
          longitude == null ||
          accuracy == null ||
          capturedAtMs == null ||
          latitude < -90 ||
          latitude > 90 ||
          longitude < -180 ||
          longitude > 180 ||
          accuracy < 0) {
        throw const FamilyLocationException(
          'invalid_result',
          '设备返回了无效的位置，请稍后重试',
        );
      }
      return FamilyCapturedLocation(
        latitude: latitude,
        longitude: longitude,
        accuracyMeters: accuracy,
        capturedAt: DateTime.fromMillisecondsSinceEpoch(capturedAtMs),
      );
    } on PlatformException catch (error) {
      throw FamilyLocationException(
        error.code,
        switch (error.code) {
          'service_disabled' => '系统定位服务未开启，请开启后重试',
          'timeout' => '暂时无法取得当前位置，请到开阔位置后重试',
          'permission_denied' => '未获得位置权限，本次没有共享任何位置',
          'busy' => '正在获取位置，请稍候',
          _ => error.message ?? '无法获取当前位置',
        },
      );
    }
  }
}
