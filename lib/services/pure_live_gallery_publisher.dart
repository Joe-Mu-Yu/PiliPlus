import 'package:flutter/services.dart';

/// Publishes finalized Pure Live recordings to Android's shared video library.
/// The recorder itself continues writing into its app-owned directory.
class PureLiveGalleryPublisher {
  PureLiveGalleryPublisher({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('pure_live/gallery');

  final MethodChannel _channel;

  Future<String?> publish(String path) async {
    if (path.trim().isEmpty) return null;
    return _channel.invokeMethod<String>('publishVideo', <String, Object>{
      'path': path,
    });
  }
}
