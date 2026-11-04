import 'package:PiliPlus/services/audio_handler.dart';
import 'package:PiliPlus/services/audio_session.dart';
import 'package:get/get.dart';
import 'package:pure_live/recorder/pages/record_settings/record_settings_controller.dart';
import 'package:pure_live/recorder/pages/recorder/recorder_controller.dart';
import 'package:pure_live/recorder/services/cache_service.dart';
import 'package:pure_live/recorder/services/stream_resolver_service.dart';

VideoPlayerServiceHandler? videoPlayerServiceHandler;
AudioSessionHandler? audioSessionHandler;

Future<void> setupServiceLocator() async {
  setupPureLiveRecordingServices();
  final audio = await initAudioService();
  videoPlayerServiceHandler = audio;
  audioSessionHandler = AudioSessionHandler();
}

void setupPureLiveRecordingServices() {
  if (!Get.isRegistered<CacheService>()) {
    Get.lazyPut(CacheService.new, fenix: true);
  }
  if (!Get.isRegistered<RecordSettingsController>()) {
    Get.lazyPut(RecordSettingsController.new, fenix: true);
  }
  if (!Get.isRegistered<RecorderController>()) {
    Get.lazyPut(RecorderController.new, fenix: true);
  }
  if (!Get.isRegistered<StreamResolverService>()) {
    Get.lazyPut(StreamResolverService.new, fenix: true);
  }
}
