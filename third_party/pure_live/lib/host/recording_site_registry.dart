import 'package:pure_live/core/interface/live_site.dart';
import 'package:pure_live/core/site/bilibili/bilibili_site.dart';
import 'package:pure_live/core/site/douyin/douyin_site.dart';
import 'package:pure_live/core/site/douyu/douyu_site.dart';
import 'package:pure_live/core/site/huya/huya_site.dart';

typedef RecordingSiteFactory = LiveSite Function();

/// Recording adapter registry. New adapters are enabled only after their
/// recording path has been integrated and verified in the host application.
class RecordingSiteRegistry {
  static const String bilibili = 'bilibili';
  static const String douyin = 'douyin';
  static const String douyu = 'douyu';
  static const String huya = 'huya';

  static final Map<String, RecordingSiteFactory> _factories = {
    bilibili: BiliBiliSite.new,
    douyin: DouyinSite.new,
    douyu: DouyuSite.new,
    huya: HuyaSite.new,
  };

  static void register(String id, RecordingSiteFactory factory) {
    final normalizedId = id.trim().toLowerCase();
    if (normalizedId.isEmpty) {
      throw ArgumentError.value(id, 'id', 'Recording site id cannot be empty');
    }
    _factories[normalizedId] = factory;
  }

  static bool isSupported(String id) =>
      _factories.containsKey(id.trim().toLowerCase());

  static LiveSite of(String id) {
    final factory = _factories[id.trim().toLowerCase()];
    if (factory != null) return factory();
    throw StateError('Unsupported live recording site: $id');
  }
}
