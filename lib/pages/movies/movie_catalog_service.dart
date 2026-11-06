import 'package:dio/dio.dart';
import 'package:html/dom.dart' show Element;
import 'package:html/parser.dart' as html_parser;

const movieSiteBaseUrl = 'https://gimytv.biz/';

const _movieRequestHeaders = <String, String>{
  'Accept': 'text/html,application/xhtml+xml,*/*;q=0.8',
  'User-Agent':
      'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/131.0.0.0 Mobile Safari/537.36',
};

const _hotSectionTitles = <String, String>{
  'tv': '熱門電視劇',
  'movie': '熱門電影',
  'anime': '熱門動漫',
  'variety': '熱門綜藝',
};

class MovieHotItem {
  const MovieHotItem({
    required this.title,
    required this.posterUrl,
    required this.detailUrl,
  });

  final String title;
  final String posterUrl;
  final Uri detailUrl;
}

class MovieSearchItem {
  const MovieSearchItem({
    required this.title,
    required this.posterUrl,
    required this.category,
    required this.year,
    required this.description,
    required this.detailUrl,
  });

  final String title;
  final String posterUrl;
  final String category;
  final String year;
  final String description;
  final Uri detailUrl;
}

class MovieSearchResponse {
  const MovieSearchResponse({required this.items, required this.total});

  final List<MovieSearchItem> items;
  final int total;
}

class MovieCatalogService {
  MovieCatalogService(this._dio);

  final Dio _dio;
  Future<String>? _homePage;

  Dio get _client => _dio;

  void clearHotCache() => _homePage = null;

  Future<List<MovieHotItem>> fetchHot(String tab) async {
    if (!_hotSectionTitles.containsKey(tab)) {
      throw ArgumentError.value(tab, 'tab', '不支持的影视分类');
    }
    final source = await (_homePage ??= _fetchHomePage());
    return parseHotHtml(source, tab: tab);
  }

  Future<String> _fetchHomePage() async {
    try {
      final response = await _client.get<String>(
        movieSiteBaseUrl,
        options: Options(
          responseType: ResponseType.plain,
          headers: _movieRequestHeaders,
          receiveTimeout: const Duration(seconds: 20),
        ),
      );
      return response.data ?? '';
    } catch (_) {
      _homePage = null;
      rethrow;
    }
  }

  Future<MovieSearchResponse> search(String query) async {
    final response = await _client.get<String>(
      Uri.parse(
        movieSiteBaseUrl,
      ).resolve('vodsearch/-------------.html').toString(),
      queryParameters: {'wd': query},
      options: Options(
        responseType: ResponseType.plain,
        headers: _movieRequestHeaders,
        receiveTimeout: const Duration(seconds: 20),
      ),
    );
    return parseSearchHtml(response.data ?? '');
  }

  static List<MovieHotItem> parseHotHtml(
    String source, {
    required String tab,
  }) {
    final expectedTitle = _hotSectionTitles[tab];
    if (expectedTitle == null) {
      throw ArgumentError.value(tab, 'tab', '不支持的影视分类');
    }

    final document = html_parser.parse(source);
    Element? targetSection;
    for (final section in document.querySelectorAll('.gimy-home-vod-section')) {
      final title = _normalizedText(
        section.querySelector('.gimy-home-section-heading')?.text ?? '',
      ).replaceAll(' ', '');
      if (title.contains(expectedTitle)) {
        targetSection = section;
        break;
      }
    }
    if (targetSection == null) {
      throw FormatException('网页没有返回$expectedTitle数据');
    }

    final items = <MovieHotItem>[];
    for (final link in targetSection.querySelectorAll(
      'ul > li > a.video-pic',
    )) {
      final image = link.querySelector('img');
      final title = _normalizedText(
        link.attributes['title'] ?? image?.attributes['alt'] ?? '',
      );
      final detailUrl = _movieDetailUri(link.attributes['href'] ?? '');
      if (title.isEmpty || detailUrl == null) continue;
      items.add(
        MovieHotItem(
          title: title,
          posterUrl: _siteUrl(
            image?.attributes['src'] ??
                image?.attributes['data-original'] ??
                link.attributes['data-original'] ??
                '',
          ),
          detailUrl: detailUrl,
        ),
      );
    }
    if (items.isEmpty) {
      throw const FormatException('热播页面没有返回影片列表');
    }
    return List.unmodifiable(items);
  }

  static MovieSearchResponse parseSearchHtml(String source) {
    final document = html_parser.parse(source);
    final content = document.querySelector('#content');
    if (content == null) {
      throw const FormatException('网页没有影视搜索数据');
    }

    final items = <MovieSearchItem>[];
    for (final result in content.querySelectorAll('.details-info-min')) {
      final posterLink = result.querySelector(
        'a.video-pic[href*="/voddetail/"]',
      );
      final titleLink = result.querySelector('a[href*="/voddetail/"]');
      final detailUrl = _movieDetailUri(
        posterLink?.attributes['href'] ?? titleLink?.attributes['href'] ?? '',
      );
      final title = _normalizedText(
        posterLink?.attributes['title'] ??
            titleLink?.attributes['title'] ??
            titleLink?.text ??
            '',
      );
      if (title.isEmpty || detailUrl == null) continue;

      final image = posterLink?.querySelector('img');
      items.add(
        MovieSearchItem(
          title: title,
          posterUrl: _siteUrl(
            posterLink?.attributes['data-original'] ??
                image?.attributes['src'] ??
                image?.attributes['data-original'] ??
                '',
          ),
          category: _labeledValue(result, const ['類型', '类型']),
          year: _labeledValue(result, const ['年代']),
          description: _normalizedText(
            result.querySelector('.details-content-default')?.text ?? '',
          ),
          detailUrl: detailUrl,
        ),
      );
    }

    final totalMatch = RegExp(
      r'''#total["']\)\.text\((\d+)\)''',
    ).firstMatch(source);
    final total = int.tryParse(totalMatch?.group(1) ?? '') ?? items.length;
    return MovieSearchResponse(items: List.unmodifiable(items), total: total);
  }
}

String _labeledValue(Element root, List<String> labels) {
  for (final item in root.querySelectorAll('li')) {
    final text = _normalizedText(item.text);
    for (final label in labels) {
      for (final separator in const ['：', ':']) {
        final prefix = '$label$separator';
        if (text.startsWith(prefix)) {
          return text.substring(prefix.length).trim();
        }
      }
    }
  }
  return '';
}

String _normalizedText(String value) =>
    value.replaceAll('\u00a0', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();

Uri? _siteUri(String value) {
  final parsed = Uri.tryParse(value.trim());
  if (parsed == null || value.trim().isEmpty) return null;
  final resolved = parsed.hasScheme
      ? parsed
      : Uri.parse(movieSiteBaseUrl).resolveUri(parsed);
  if (!resolved.hasAuthority ||
      (resolved.scheme != 'http' && resolved.scheme != 'https')) {
    return null;
  }
  return resolved.scheme == 'http'
      ? resolved.replace(scheme: 'https')
      : resolved;
}

String _siteUrl(String value) => _siteUri(value)?.toString() ?? '';

Uri? _movieDetailUri(String value) {
  final uri = _siteUri(value);
  if (uri == null) return null;
  final host = uri.host.toLowerCase();
  return host == 'gimytv.biz' || host.endsWith('.gimytv.biz') ? uri : null;
}
