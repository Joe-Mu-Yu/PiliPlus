import 'package:pure_live/host/recording_common.dart';
import 'package:pure_live/recorder/pages/record_settings/record_settings_controller.dart';

class RecordSettingsBinding extends Binding {
  @override
  List<Bind> dependencies() {
    return [Bind.lazyPut(() => RecordSettingsController())];
  }
}
