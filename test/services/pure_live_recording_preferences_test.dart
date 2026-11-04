import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:PiliPlus/services/pure_live_recording_preferences.dart';
import 'package:pure_live/host/recording_room_volume.dart';

void main() {
  late Directory directory;
  late Box<dynamic> settings;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('pure-live-preferences-');
    Hive.init(directory.path);
    settings = await Hive.openBox<dynamic>('setting');
    PureLiveRecordingPreferences.configure(settings);
  });

  tearDown(() async {
    await settings.close();
    await Hive.close();
    await directory.delete(recursive: true);
  });

  test(
    'reads and writes the host settings box with the recorder preference API',
    () async {
      await PureLiveRecordingPreferences.setBool('recorder_test_flag', true);
      await PureLiveRecordingPreferences.setString(
        'recorder_test_text',
        'saved',
      );

      expect(
        PureLiveRecordingPreferences.getBool('recorder_test_flag'),
        isTrue,
      );
      expect(
        PureLiveRecordingPreferences.getString('recorder_test_text'),
        'saved',
      );
      expect(
        PureLiveRecordingPreferences.containsKey('recorder_test_flag'),
        isTrue,
      );
    },
  );

  test(
    'ignores non-finite room volume writes without changing persisted settings',
    () async {
      await RecordingRoomVolume.write('douyin', '12345', double.nan);

      expect(PureLiveRecordingPreferences.containsKey('roomVolumes'), isFalse);
    },
  );
}
