import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/recorder/services/recording_segment_clock.dart';
import 'package:pure_live/recorder/services/video_processor_service.dart';

void main() {
  group('RecordingSegmentClock', () {
    const prefix = '20261108_020000_123';
    final first = RecordingSegmentClock.segmentName(prefix, 0);
    final second = RecordingSegmentClock.segmentName(prefix, 1);
    final third = RecordingSegmentClock.segmentName(prefix, 2);

    test('accepts a partial or omitted final row as an unclocked tail', () {
      final partial = RecordingSegmentClock.parse(
        '$first,0.000000,10.000000\n$second,10.000000,20.000000\n$third,20.0',
        prefix: prefix,
        segments: [first, second, third],
      );
      final omitted = RecordingSegmentClock.parse(
        '$first,0.000000,10.000000\n$second,10.000000,20.000000\n',
        prefix: prefix,
        segments: [first, second, third],
      );

      expect(partial.starts, [0, 10000000]);
      expect(omitted.starts, [0, 10000000]);
      expect(partial.paths.length, 2);
      expect(omitted.paths.length, 2);
    });

    test('rejects missing closed rows and malformed interior timestamps', () {
      expect(
        () => RecordingSegmentClock.parse(
          '$first,0.000000,10.000000\n$second,10.000000,20.000000\n',
          prefix: prefix,
          segments: [first, second, third, '20261108_020000_123_000003.clock-v1.ts'],
        ),
        throwsFormatException,
      );
      expect(
        () => RecordingSegmentClock.parse(
          '$first,0.000000,10.000000\n$second,invalid,20.000000\n$third,20.000000,30.000000\n',
          prefix: prefix,
          segments: [first, second, third],
        ),
        throwsFormatException,
      );
    });

    test('parses sequence numbers beyond six digits without lexical reordering', () {
      const longPrefix = 'long_recording';
      const sequence999999 = 'long_recording_999999.clock-v1.ts';
      const sequence1000000 = 'long_recording_1000000.clock-v1.ts';
      final files = [
        File('/tmp/$sequence1000000'),
        File('/tmp/$sequence999999'),
      ]..sort(VideoProcessorService.compareSegments);

      expect(files.map((file) => file.uri.pathSegments.last), [sequence999999, sequence1000000]);
      final clock = RecordingSegmentClock.parse(
        'long_recording_000000.clock-v1.ts,0.000000,10.000000\nlong_recording_000001.clock-v1.ts,10.000000,20.000000\n',
        prefix: longPrefix,
        segments: ['/tmp/long_recording_000000.clock-v1.ts', '/tmp/long_recording_000001.clock-v1.ts'],
      );
      expect(clock.starts, [0, 10000000]);
    });
  });
}
