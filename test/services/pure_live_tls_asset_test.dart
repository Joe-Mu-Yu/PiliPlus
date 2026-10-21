import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/recorder/services/ffmpeg_tls_trust_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Pure Live CA bundle is packaged at its package asset URI', () async {
    final data = await rootBundle.load(FFmpegTlsTrustStore.assetPath);
    final bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );

    expect(bytes, isNotEmpty);
    expect(sha256.convert(bytes).toString(), FFmpegTlsTrustStore.bundleSha256);
  });
}
