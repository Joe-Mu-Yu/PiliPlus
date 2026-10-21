import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/host/recording_common.dart' as recording;

final class _ProbeService {}

void main() {
  test('recording bridge exposes the host GetX dependency registry API', () {
    final service = _ProbeService();

    recording.Get.put<_ProbeService>(service);
    expect(recording.Get.isRegistered<_ProbeService>(), isTrue);
    expect(recording.Get.find<_ProbeService>(), same(service));
    recording.Get.delete<_ProbeService>();
  });
}
