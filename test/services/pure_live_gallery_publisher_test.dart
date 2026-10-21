import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:PiliPlus/services/pure_live_gallery_publisher.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'publishes only the finalized file path via the native gallery bridge',
    () async {
      const channel = MethodChannel('test/pure_live/gallery');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      Map<Object?, Object?>? received;
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'publishVideo');
        received = Map<Object?, Object?>.from(call.arguments as Map);
        return 'content://media/external/video/media/1';
      });

      final publisher = PureLiveGalleryPublisher(channel: channel);
      final uri = await publisher.publish('/app/records/record.mp4');

      expect(uri, 'content://media/external/video/media/1');
      expect(received, <Object?, Object?>{'path': '/app/records/record.mp4'});
      messenger.setMockMethodCallHandler(channel, null);
    },
  );

  test('does not call native bridge for an empty file path', () async {
    const channel = MethodChannel('test/pure_live/gallery/empty');
    final publisher = PureLiveGalleryPublisher(channel: channel);
    expect(await publisher.publish('  '), isNull);
  });
}
