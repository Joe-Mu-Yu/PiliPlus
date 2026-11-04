import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Pure Live source migration', () {
    test('keeps the upstream recorder engine and platform adapters in source', () {
      final recorder = Directory('third_party/pure_live/lib/recorder');
      final sites = Directory('third_party/pure_live/lib/core/site');
      expect(File('third_party/pure_live/lib/recorder/ffmpeg/ffmpeg_manager.dart').existsSync(), isTrue);
      expect(File('third_party/pure_live/lib/recorder/services/recorder_background_service.dart').existsSync(), isTrue);
      expect(File('third_party/pure_live/lib/core/site/douyin/douyin_site.dart').existsSync(), isTrue);
      expect(File('third_party/pure_live/lib/modules/favorite/favorite_page.dart').existsSync(), isTrue);
      expect(File('third_party/pure_live/lib/core/index.dart').existsSync(), isTrue);
      expect(File('third_party/pure_live/lib/core/sites.dart').existsSync(), isTrue);
      expect(File('third_party/pure_live/pubspec.yaml').readAsStringSync(), contains('name: pure_live'));
      expect(recorder.existsSync(), isTrue);
      expect(sites.existsSync(), isTrue);
    });

    test('preserves Pure Live license text alongside migrated sources', () {
      final license = File('third_party/pure_live/LICENSE');
      expect(license.existsSync(), isTrue);
      expect(license.readAsStringSync(), contains('GNU AFFERO GENERAL PUBLIC LICENSE'));
    });
  });
}
