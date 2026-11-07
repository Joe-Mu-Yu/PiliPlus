import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/recorder/pages/recorder/recorder_controller.dart';
import 'package:pure_live/recorder/pages/recorder/recorder_page.dart';
import 'package:pure_live/recorder/pages/record_settings/record_settings_page.dart';
import 'package:pure_live/recorder/ffmpeg/ffmpeg_event.dart';
import 'package:pure_live/recorder/ffmpeg/ffmpeg_types.dart';
import 'package:pure_live/recorder/models/live_record_task.dart';
import 'package:pure_live/recorder/services/video_processor_service.dart';
import 'package:pure_live/recorder/services/recorder_continuation_policy.dart';
import 'package:pure_live/host/recording_site_registry.dart';

void main() {
  test(
    'the vendored original recorder controller is resolvable by the host app',
    () {
      expect(RecorderController, isNotNull);
      expect(RecorderPage, isNotNull);
      expect(RecordSettingsPage, isNotNull);
    },
  );

  test('recording registry covers every native live playback platform', () {
    for (final platform in ['bilibili', 'douyin', 'douyu', 'huya']) {
      expect(
        RecordingSiteRegistry.isSupported(platform),
        isTrue,
        reason: '$platform playback must not expose an unsupported recorder',
      );
      expect(RecordingSiteRegistry.of(platform).id, platform);
    }
  });

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

  test('healthy merge stays strict while damaged input uses safe salvage', () {
    final strict = VideoProcessorService.buildMergeArguments(
      manifestPath: '/recording/input.ffconcat',
      outputPath: '/recording/output.mp4.partial',
      recoverDamagedInput: false,
    );
    final salvage = VideoProcessorService.buildMergeArguments(
      manifestPath: '/recording/input.ffconcat',
      outputPath: '/recording/output.mp4.partial',
      recoverDamagedInput: true,
    );

    expect(strict, contains('-xerror'));
    expect(strict, isNot(contains('+discardcorrupt')));
    expect(salvage, isNot(contains('-xerror')));
    expect(salvage, containsAllInOrder(['-fflags', '+discardcorrupt']));
    expect(salvage, containsAllInOrder(['-err_detect', 'ignore_err']));
    expect(salvage, containsAllInOrder(['-c', 'copy']));
    expect(
      VideoProcessorService.shouldDeleteSourceSegments(
        requested: true,
        damagedInput: false,
      ),
      isTrue,
    );
    expect(
      VideoProcessorService.shouldDeleteSourceSegments(
        requested: true,
        damagedInput: true,
      ),
      isFalse,
    );
  });

  test('merge source failure stage survives task persistence', () {
    final task = LiveRecordTask.fromJson({
      'taskId': 'douyin_1',
      'roomId': '1',
      'platform': 'douyin',
      'title': 'test',
      'nick': 'test',
      'avatar': '',
      'cover': '',
      'createTime': DateTime(2026).toIso8601String(),
      'lastErrorStage': 'merge.sourceMissing',
    });

    expect(task.lastErrorStage, 'merge.sourcemissing');
  });

  test('persisted native diagnostics redact stream credentials', () {
    final task = LiveRecordTask.fromJson({
      'taskId': 'douyin_1',
      'roomId': '1',
      'platform': 'douyin',
      'title': 'test',
      'nick': 'test',
      'avatar': '',
      'cover': '',
      'createTime': DateTime(2026).toIso8601String(),
    });
    task.markFailure(
      stage: 'ffmpeg.inputIntegrity',
      error: 'damaged input',
      diagnostic: 'packet corrupt https://cdn.example/live.flv?token=sample Cookie: sample-cookie',
    );
    final restored = LiveRecordTask.fromJson(task.toJson());

    expect(restored.lastDiagnostic, contains('packet corrupt'));
    expect(restored.lastDiagnostic, contains('[stream-url]'));
    expect(restored.lastDiagnostic, isNot(contains('sample-cookie')));
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
