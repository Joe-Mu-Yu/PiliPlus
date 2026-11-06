import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/recorder/pages/recorder/recorder_controller.dart';
import 'package:pure_live/recorder/pages/recorder/recorder_page.dart';
import 'package:pure_live/recorder/pages/record_settings/record_settings_page.dart';
import 'package:pure_live/recorder/ffmpeg/ffmpeg_event.dart';
import 'package:pure_live/recorder/ffmpeg/ffmpeg_types.dart';
import 'package:pure_live/recorder/services/video_processor_service.dart';
import 'package:pure_live/recorder/services/recorder_continuation_policy.dart';

void main() {
  test(
    'the vendored original recorder controller is resolvable by the host app',
    () {
      expect(RecorderController, isNotNull);
      expect(RecorderPage, isNotNull);
      expect(RecordSettingsPage, isNotNull);
    },
  );

  test('merge errors preserve the native diagnostic message for the UI', () {
    final event = FFmpegEvent(
      taskId: 'merge-test',
      type: FFmpegEventType.error,
      data: {'message': '输入文件无法打开'},
    );

    expect(
      VideoProcessorService.mergeFailureMessage(event, fallback: '合并失败'),
      '输入文件无法打开',
    );
    expect(
      VideoProcessorService.mergeFailureMessage(
        FFmpegEvent(taskId: 'merge-test', type: FFmpegEventType.error),
        fallback: '合并失败',
      ),
      '合并失败',
    );
  });

  test('generic merge failures include the sanitized native error line', () {
    final event = FFmpegEvent(
      taskId: 'merge-test',
      type: FFmpegEventType.error,
      data: {
        'message': 'FFmpeg merge failed',
        'raw_logs': '[mp4] Could not find tag for codec unknown in stream #0',
      },
    );

    expect(
      VideoProcessorService.mergeFailureMessage(
        event,
        fallback: 'FFmpeg merge failed',
      ),
      contains('Could not find tag for codec unknown'),
    );
  });

  test('merge failures without a native diagnostic retain the fallback', () {
    final event = FFmpegEvent(
      taskId: 'merge-test',
      type: FFmpegEventType.error,
      data: {'message': 'FFmpeg merge failed', 'raw_logs': 'processing ended'},
    );

    expect(
      VideoProcessorService.mergeFailureMessage(
        event,
        fallback: 'FFmpeg merge failed',
      ),
      'FFmpeg merge failed',
    );
  });

  test('confirmed offline finalizes recorded attempts instead of waiting', () {
    expect(
      RecorderContinuationPolicy.shouldFinalizeAfterOfflineResolution(
        hasPendingAttempts: true,
      ),
      isTrue,
    );
    expect(
      RecorderContinuationPolicy.shouldFinalizeAfterOfflineResolution(
        hasPendingAttempts: false,
      ),
      isFalse,
    );
  });
}
