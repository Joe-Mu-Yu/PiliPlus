import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/recorder/services/ffmpeg_service.dart';

void main() {
  test('upstream FFmpeg progress rejects impossible source timestamps', () {
    expect(normalizeLiveRecordedSeconds(rawMilliseconds: 12_000, wallSeconds: 13), 12);
    expect(normalizeLiveRecordedSeconds(rawMilliseconds: 2_147_483_648_000, wallSeconds: 9), 9);
    expect(normalizeLiveRecordedSeconds(rawMilliseconds: -1, wallSeconds: 5), 0);
  });
}
