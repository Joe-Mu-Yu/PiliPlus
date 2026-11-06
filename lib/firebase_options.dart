// Firebase project identifiers are safe to keep here, but the API key is
// injected at compile time so credential scanners and repository history do
// not become a distribution channel for it.
import 'package:firebase_core/firebase_core.dart';

abstract final class HyperFirebaseOptions {
  static const _androidApiKey = String.fromEnvironment(
    'HYPER_FIREBASE_ANDROID_API_KEY',
  );

  static FirebaseOptions get android {
    if (_androidApiKey.isEmpty) {
      throw StateError(
        'Missing HYPER_FIREBASE_ANDROID_API_KEY compile-time definition.',
      );
    }
    return _android;
  }

  static const _android = FirebaseOptions(
    apiKey: _androidApiKey,
    appId: "1:1043412509094:android:c756fedaf492e29141ef67",
    messagingSenderId: "1043412509094",
    projectId: "hyperpiliplus",
    storageBucket: "hyperpiliplus.firebasestorage.app",
  );
}
