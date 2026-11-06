import 'package:PiliPlus/pages/movies/movie_catalog_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('hot categories share one Gimy home-page request', () async {
    final requestedUris = <Uri>[];
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requestedUris.add(options.uri);
            handler.resolve(
              Response<String>(
                requestOptions: options,
                statusCode: 200,
                data: '''
<html><body>
  <section class="gimy-home-vod-section"><h2 class="gimy-home-section-heading">熱門電視劇</h2><ul><li><a class="video-pic" href="/voddetail/1.html" title="電視劇"><img src="/tv.jpg"></a></li></ul></section>
  <section class="gimy-home-vod-section"><h2 class="gimy-home-section-heading">熱門電影</h2><ul><li><a class="video-pic" href="/voddetail/2.html" title="電影"><img src="/movie.jpg"></a></li></ul></section>
  <section class="gimy-home-vod-section"><h2 class="gimy-home-section-heading">熱門動漫</h2><ul><li><a class="video-pic" href="/voddetail/3.html" title="動漫"><img src="/anime.jpg"></a></li></ul></section>
  <section class="gimy-home-vod-section"><h2 class="gimy-home-section-heading">熱門綜藝</h2><ul><li><a class="video-pic" href="/voddetail/4.html" title="綜藝"><img src="/variety.jpg"></a></li></ul></section>
</body></html>
''',
              ),
            );
          },
        ),
      );
    final service = MovieCatalogService(dio);

    final sections = await Future.wait([
      service.fetchHot('tv'),
      service.fetchHot('movie'),
      service.fetchHot('anime'),
      service.fetchHot('variety'),
    ]);

    expect(requestedUris, [Uri.parse(movieSiteBaseUrl)]);
    expect(sections.map((items) => items.single.title), [
      '電視劇',
      '電影',
      '動漫',
      '綜藝',
    ]);
  });

  test('search requests the Gimy vodsearch endpoint with wd', () async {
    Uri? requestedUri;
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requestedUri = options.uri;
            handler.resolve(
              Response<String>(
                requestOptions: options,
                statusCode: 200,
                data:
                    '<html><body><div id="content"></div>'
                    '<script>\$("#total").text(0);</script></body></html>',
              ),
            );
          },
        ),
      );

    final result = await MovieCatalogService(dio).search('海賊王');

    expect(requestedUri?.scheme, 'https');
    expect(requestedUri?.host, 'gimytv.biz');
    expect(requestedUri?.path, '/vodsearch/-------------.html');
    expect(requestedUri?.queryParameters['wd'], '海賊王');
    expect(result.items, isEmpty);
  });

  test('Gimy hot section parses poster and direct detail URL', () {
    final items = MovieCatalogService.parseHotHtml(
      '''
<html><body>
  <section class="gimy-home-vod-section">
    <h2 class="gimy-home-section-heading"><i>&#xe6bc;</i>熱門電視劇</h2>
    <ul>
      <li>
        <a class="video-pic" href="/voddetail/42.html" title="示例影片">
          <img src="http://images.example/poster.jpg" alt="示例影片">
        </a>
      </li>
      <li>
        <a class="video-pic" href="https://example.com/voddetail/99.html" title="站外影片">
          <img src="https://images.example/external.jpg" alt="站外影片">
        </a>
      </li>
    </ul>
  </section>
</body></html>
''',
      tab: 'tv',
    );

    expect(items, hasLength(1));
    expect(items.single.title, '示例影片');
    expect(items.single.posterUrl, 'https://images.example/poster.jpg');
    expect(
      items.single.detailUrl.toString(),
      'https://gimytv.biz/voddetail/42.html',
    );
  });

  test('Gimy search page parses movie data and total', () {
    final result = MovieCatalogService.parseSearchHtml('''
<html><body>
  <div id="content">
    <div class="details-info-min">
      <a class="video-pic" href="/voddetail/100822.html" title="海賊王"
         data-original="/upload/vod/one-piece.jpg"></a>
      <ul class="info">
        <li><a href="/voddetail/100822.html" title="海賊王">海賊王</a></li>
        <li><span>類型：</span><a>動漫</a></li>
        <li><span>年代：</span>1999</li>
        <li><span>詳細介紹：</span><span class="details-content-default">影片簡介</span></li>
      </ul>
    </div>
  </div>
  <script>\$("#total").text(1);</script>
</body></html>
''');

    expect(result.total, 1);
    expect(result.items, hasLength(1));
    expect(result.items.single.title, '海賊王');
    expect(result.items.single.category, '動漫');
    expect(result.items.single.year, '1999');
    expect(result.items.single.description, '影片簡介');
    expect(
      result.items.single.posterUrl,
      'https://gimytv.biz/upload/vod/one-piece.jpg',
    );
    expect(
      result.items.single.detailUrl.toString(),
      'https://gimytv.biz/voddetail/100822.html',
    );
  });

  test('valid empty Gimy search page returns no results', () {
    final result = MovieCatalogService.parseSearchHtml('''
<html><body>
  <div id="content"></div>
  <script>\$("#total").text(0);</script>
</body></html>
''');

    expect(result.total, 0);
    expect(result.items, isEmpty);
  });

  test('malformed search response produces a clear format error', () {
    expect(
      () => MovieCatalogService.parseSearchHtml(
        '<html><body>unknown</body></html>',
      ),
      throwsFormatException,
    );
  });
}
