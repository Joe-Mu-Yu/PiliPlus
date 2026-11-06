import 'dart:io';

import 'package:PiliPlus/pages/movies/view.dart';
import 'package:PiliPlus/pages/movies/movie_catalog_service.dart';
import 'package:dio/dio.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:PiliPlus/utils/theme_utils.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:hive_ce/hive.dart';

void main() {
  late Directory directory;
  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('movie-theme-test-');
    Hive.init(directory.path);
    GStorage.setting = await Hive.openBox('setting');
    ThemeUtils.lightTheme = ThemeUtils.getThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
    );
  });
  tearDownAll(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  testWidgets('movie catalog follows the app color scheme', (tester) async {
    final appTheme = ThemeUtils.getThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
    );
    await tester.pumpWidget(
      GetMaterialApp(
        theme: appTheme,
        home: MovieHomePage(service: _FakeMovieCatalogService()),
      ),
    );
    await tester.pump();

    final pageTheme = Theme.of(tester.element(find.text('电视剧热播')));
    expect(pageTheme.colorScheme.primary, appTheme.colorScheme.primary);
    expect(find.byKey(const ValueKey('movie-netflix-theme')), findsNothing);
    expect(find.text('影视'), findsOneWidget);
    expect(find.text('电视剧热播'), findsOneWidget);
    final poster = tester.widget<Image>(find.byType(Image).first);
    expect((poster.image as ResizeImage).width, 420);
  });
}

class _FakeMovieCatalogService extends MovieCatalogService {
  _FakeMovieCatalogService() : super(Dio());

  @override
  Future<List<MovieHotItem>> fetchHot(String tab) async => [
    MovieHotItem(
      title: '示例影片',
      posterUrl: 'https://images.example/poster.jpg',
      detailUrl: Uri.parse('https://gimytv.biz/voddetail/42.html'),
    ),
  ];
}
