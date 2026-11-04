import 'package:PiliPlus/pages/movies/movie_catalog_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('movie hot item converts insecure poster URLs to HTTPS', () {
    final item = MovieHotItem.fromJson({
      'title': '示例影片',
      'pic': 'http://images.example/poster.jpg',
    });

    expect(item.title, '示例影片');
    expect(item.posterUrl, 'https://images.example/poster.jpg');
  });

  test(
    'search bootstrap parses movie data and constructs an in-app detail URL',
    () {
      final result = MovieCatalogService.parseSearchHtml('''
<html><body><script>
window.SOTV_SEARCH_PROGRESS = {"items":[{"vod_id":"42","vod_name":"示例影片","vod_pic":"https://img.example/poster.jpg","vod_class":"电影","vod_year":"2026","vod_blurb":"简介","_api_id":7}],"total":1};
</script></body></html>
''');

      expect(result.total, 1);
      expect(result.items, hasLength(1));
      expect(result.items.single.title, '示例影片');
      expect(result.items.single.detailUrl.host, 'www.sotvla6.cc');
      expect(result.items.single.detailUrl.toString(), contains('api_id=7'));
      expect(result.items.single.detailUrl.toString(), contains('vod_id=42'));
    },
  );

  test('malformed search response produces a clear format error', () {
    expect(
      () => MovieCatalogService.parseSearchHtml(
        '<html><body>unknown</body></html>',
      ),
      throwsFormatException,
    );
  });
}
