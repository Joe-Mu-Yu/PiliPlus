import 'package:pure_live/host/recording_common.dart';
import 'package:pure_live/recorder/pages/recorder/recorder_controller.dart';

class RecorderBinding extends Binding {
  @override
  List<Bind> dependencies() {
    return [Bind.lazyPut(() => RecorderController())];
  }
}
