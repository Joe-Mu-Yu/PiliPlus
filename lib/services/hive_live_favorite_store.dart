import 'package:hive_ce/hive.dart';
import 'package:PiliPlus/services/live_favorite_repository.dart';

class HiveLiveFavoriteStore implements LiveFavoriteStore {
  HiveLiveFavoriteStore(this.box, {this.key = 'pureLiveRoomFavorites'});

  final Box<dynamic> box;
  final String key;

  @override
  Future<List<Map<String, Object?>>> read() async {
    final raw = box.get(key);
    if (raw == null) {
      return [];
    }
    if (raw is! List) {
      throw const FormatException('Saved live favorites are not a list');
    }
    return raw.map((item) {
      if (item is! Map) {
        throw const FormatException('Saved live favorite is not an object');
      }
      return item.map((key, value) => MapEntry(key.toString(), value));
    }).toList();
  }

  @override
  Future<void> write(List<Map<String, Object?>> favorites) =>
      box.put(key, favorites);
}
