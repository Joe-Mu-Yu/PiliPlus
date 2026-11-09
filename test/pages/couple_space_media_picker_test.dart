import 'dart:io';

import 'package:PiliPlus/pages/couple_space/couple_space_media_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MotionPhotoExtractor', () {
    late Directory directory;

    setUp(() {
      directory = Directory.systemTemp.createTempSync(
        'couple-motion-photo-test-',
      );
    });

    tearDown(() {
      if (directory.existsSync()) directory.deleteSync(recursive: true);
    });

    test('从 JPEG 尾部提取完整 MP4 容器', () async {
      const mp4 = <int>[
        0x00,
        0x00,
        0x00,
        0x10,
        0x66,
        0x74,
        0x79,
        0x70,
        0x69,
        0x73,
        0x6f,
        0x6d,
        0x00,
        0x00,
        0x00,
        0x00,
      ];
      final source = File('${directory.path}/motion.jpg')
        ..writeAsBytesSync([
          0xff,
          0xd8,
          0x01,
          0x02,
          0xff,
          0xd9,
          ...mp4,
        ]);

      final extracted = await MotionPhotoExtractor.extract(
        source,
        destinationDirectory: directory,
      );

      expect(extracted, isNotNull);
      expect(extracted!.readAsBytesSync(), mp4);
    });

    test('普通 JPEG 和非 JPEG 不会伪装成动态照片', () async {
      final still = File('${directory.path}/still.jpg')
        ..writeAsBytesSync([0xff, 0xd8, 0x01, 0x02, 0xff, 0xd9]);
      final invalid = File('${directory.path}/invalid.jpg')
        ..writeAsBytesSync(List<int>.filled(32, 0));

      expect(
        await MotionPhotoExtractor.extract(
          still,
          destinationDirectory: directory,
        ),
        isNull,
      );
      expect(
        await MotionPhotoExtractor.extract(
          invalid,
          destinationDirectory: directory,
        ),
        isNull,
      );
    });

    test('JPEG 结束标记前出现 ftyp 时不会误判', () async {
      final source = File('${directory.path}/embedded-ftyp.jpg')
        ..writeAsBytesSync([
          0xff,
          0xd8,
          0x00,
          0x00,
          0x00,
          0x10,
          0x66,
          0x74,
          0x79,
          0x70,
          0x69,
          0x73,
          0x6f,
          0x6d,
          0x00,
          0x00,
          0x00,
          0x00,
          0xff,
          0xd9,
        ]);

      expect(
        await MotionPhotoExtractor.extract(
          source,
          destinationDirectory: directory,
        ),
        isNull,
      );
    });
  });

  group('CoupleSpaceMediaPicker iOS bridge', () {
    const channel = MethodChannel('test/couple-space-media-picker');

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('解析 Live Photo 并清理系统导出的临时文件', () async {
      final directory = Directory.systemTemp.createTempSync(
        'couple-live-photo-test-',
      );
      final image = File('${directory.path}/cover.jpg')..writeAsBytesSync([1]);
      final video = File('${directory.path}/motion.mov')..writeAsBytesSync([2]);
      MethodCall? received;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            received = call;
            return [
              {
                'imagePath': image.path,
                'videoPath': video.path,
                'width': 1920,
                'height': '1440',
              },
            ];
          });
      final picker = CoupleSpaceMediaPicker(channel: channel, isIOS: true);

      final picked = await picker.pick(limit: 9);

      expect(received?.method, 'pickMedia');
      expect(received?.arguments, {'limit': 9});
      expect(picked.single.imagePath, image.path);
      expect(picked.single.videoPath, video.path);
      expect(picked.single.width, 1920);
      expect(picked.single.height, 1440);
      expect(picked.single.isLivePhoto, isTrue);

      await picked.single.cleanup();
      expect(directory.existsSync(), isFalse);
    });
  });
}
