import 'package:PiliPlus/services/audio_handler.dart';
import 'package:PiliPlus/services/audio_session.dart';
import 'package:PiliPlus/services/live_platform_adapter.dart';
import 'package:get/get.dart';
import 'package:pure_live/common/global/app_path_manager.dart';
import 'package:pure_live/common/services/settings/iptv_settings_controller.dart';
import 'package:pure_live/core/site/iptv/iptv_site.dart';
import 'package:pure_live/host/recording_site_registry.dart';
import 'package:pure_live/plugins/db_service.dart';
import 'package:pure_live/recorder/pages/record_settings/record_settings_controller.dart';
import 'package:pure_live/recorder/pages/recorder/recorder_controller.dart';
import 'package:pure_live/recorder/services/cache_service.dart';
import 'package:pure_live/recorder/services/stream_resolver_service.dart';

VideoPlayerServiceHandler? videoPlayerServiceHandler;
AudioSessionHandler? audioSessionHandler;
Future<void>? _pureLiveIptvSetup;

Future<void> setupServiceLocator() async {
  setupPureLiveRecordingServices();
  final audio = await initAudioService();
  videoPlayerServiceHandler = audio;
  audioSessionHandler = AudioSessionHandler();
}

void setupPureLiveRecordingServices() {
  RecordingSiteRegistry.register('pure_live', PureLiveDirectLinkSite.new);
  RecordingSiteRegistry.register('iptv', IptvSite.new);
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

/// Starts the vendored IPTV data layer only when the user opens IPTV.
///
/// Hyper-PiliPlus owns Flutter startup and Hive initialization, so calling the
/// full Pure Live app initializer would replace unrelated app-wide services.
/// This host bridge initializes only the path, settings and Drift services
/// required by the original IPTV import, EPG and management modules.
Future<void> setupPureLiveIptvServices() async {
  final pending = _pureLiveIptvSetup;
  if (pending != null) return pending;

  final setup = _setupPureLiveIptvServices();
  _pureLiveIptvSetup = setup;
  try {
    await setup;
  } catch (_) {
    if (identical(_pureLiveIptvSetup, setup)) _pureLiveIptvSetup = null;
    rethrow;
  }
}

Future<void> _setupPureLiveIptvServices() async {
  await AppPathManager().initialize();

  if (!Get.isRegistered<DbService>()) {
    final database = DbService();
    await database.init();
    Get.put<DbService>(database, permanent: true);
  }
  if (!Get.isRegistered<IptvSettingsController>()) {
    Get.put<IptvSettingsController>(
      IptvSettingsController(),
      permanent: true,
    );
  }
}
