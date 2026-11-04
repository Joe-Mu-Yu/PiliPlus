import 'package:pure_live/core/interface/live_site.dart';
import 'package:pure_live/core/site/douyin/douyin_site.dart';

/// Recording adapter registry. New adapters are enabled only after their
/// recording path has been integrated and verified in the host application.
class RecordingSiteRegistry {
  static const String douyin = 'douyin';

  static bool isSupported(String id) => id.trim().toLowerCase() == douyin;

  static LiveSite of(String id) {
    if (id.trim().toLowerCase() == douyin) return DouyinSite();
    throw StateError('Unsupported live recording site: $id');
  }
}
