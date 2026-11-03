import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:PiliPlus/http/init.dart';

const movieSiteBaseUrl = 'https://www.sotvla6.cc/';

class MovieHotItem {
  const MovieHotItem({required this.title, required this.posterUrl});

  final String title;
  final String posterUrl;

  factory MovieHotItem.fromJson(Map<String, dynamic> json) => MovieHotItem(
    title: json['title']?.toString() ?? '',
    posterUrl: _secureUrl(json['pic']?.toString() ?? ''),
  );
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

  factory MovieSearchItem.fromJson(Map<String, dynamic> json) {
    final apiId = json['_api_id']?.toString() ?? '';
    final vodId = json['vod_id']?.toString() ?? '';
    return MovieSearchItem(
      title: json['vod_name']?.toString() ?? '',
      posterUrl: _secureUrl(json['vod_pic']?.toString() ?? ''),
      category: json['vod_class']?.toString() ?? '',
      year: json['vod_year']?.toString() ?? '',
      description: json['vod_blurb']?.toString() ?? '',
      detailUrl: Uri.parse(movieSiteBaseUrl).resolveUri(
        Uri(
          path: 'detail.php',
          queryParameters: {'api_id': apiId, 'vod_id': vodId},
        ),
      ),
    );
  }
}

class MovieSearchResponse {
  const MovieSearchResponse({required this.items, required this.total});

  final List<MovieSearchItem> items;
  final int total;
}

class MovieCatalogService {
  MovieCatalogService({Dio? dio}) : _dio = dio;

  Dio? _dio;
  Dio get _client => _dio ??= Request.dio;

  Future<List<MovieHotItem>> fetchHot(String tab) async {
    final response = await _client.get<Object?>(
      '$movieSiteBaseUrl/api/hot_movie.php',
      queryParameters: {'source': 'guduo', 'tab': tab},
      options: Options(
        headers: const {
          'Accept': 'application/json,text/html;q=0.9,*/*;q=0.8',
          'User-Agent':
              'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 '
              '(KHTML, like Gecko) Chrome/126.0.0.0 Mobile Safari/537.36',
        },
        receiveTimeout: const Duration(seconds: 20),
      ),
    );
    final data = _asMap(response.data);
    final rawItems = data['items'];
    if (rawItems is! List) {
      throw const FormatException('热播接口没有返回影片列表');
    }
    return rawItems
        .whereType<Map>()
        .map((item) => MovieHotItem.fromJson(Map<String, dynamic>.from(item)))
        .where((item) => item.title.isNotEmpty)
        .toList(growable: false);
  }

  Future<MovieSearchResponse> search(String query) async {
    final response = await _client.get<String>(
      '${movieSiteBaseUrl}search.php',
      queryParameters: {'q': query},
      options: Options(
        responseType: ResponseType.plain,
        headers: const {
          'Accept': 'text/html,application/xhtml+xml,*/*;q=0.8',
          'User-Agent':
              'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 '
              '(KHTML, like Gecko) Chrome/126.0.0.0 Mobile Safari/537.36',
        },
        receiveTimeout: const Duration(seconds: 20),
      ),
    );
    return parseSearchHtml(response.data ?? '');
  }

  static MovieSearchResponse parseSearchHtml(String source) {
    final document = html_parser.parse(source);
    final script = document
        .querySelectorAll('script')
        .firstWhere(
          (script) => script.text.contains('window.SOTV_SEARCH_PROGRESS'),
          orElse: () => throw const FormatException('网页没有影视搜索数据'),
        );
    final match = RegExp(
      r'window\.SOTV_SEARCH_PROGRESS\s*=\s*(\{.*?\});',
      dotAll: true,
    ).firstMatch(script.text);
    if (match == null) {
      throw const FormatException('无法读取影视搜索数据');
    }
    final bootstrap = _asMap(jsonDecode(match.group(1)!));
    final rawItems = bootstrap['items'];
    if (rawItems is! List) {
      throw const FormatException('搜索接口没有返回影片列表');
    }
    final total =
        int.tryParse(bootstrap['total']?.toString() ?? '') ?? rawItems.length;
    final items = rawItems
        .whereType<Map>()
        .map(
          (item) => MovieSearchItem.fromJson(Map<String, dynamic>.from(item)),
        )
        .where((item) => item.title.isNotEmpty)
        .toList(growable: false);
    return MovieSearchResponse(items: items, total: total);
  }

  static Map<String, dynamic> _asMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is String) {
      final decoded = jsonDecode(value);
      if (decoded is Map<String, dynamic>) return decoded;
    }
    throw const FormatException('影视接口返回格式不正确');
  }
}

String _secureUrl(String value) {
  final uri = Uri.tryParse(value);
  if (uri == null || !uri.hasAuthority) return '';
  return uri.scheme == 'http' ? uri.replace(scheme: 'https').toString() : value;
}
