import 'package:PiliPlus/pages/webview/movie_webview_shell.dart';
import 'package:PiliPlus/common/widgets/app_material_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('movie site allowlist only accepts Gimy hosts', () {
    expect(isMovieSiteUrl('https://gimytv.biz/voddetail/42.html'), isTrue);
    expect(isMovieSiteUrl('https://www.gimytv.biz/video/42-1.html'), isTrue);
    expect(isMovieSiteUrl('https://www.sotvla6.cc/detail.php'), isFalse);
    expect(isMovieSiteUrl('https://gimytv.biz.example.com/'), isFalse);
  });

  testWidgets('movie app bar exposes a working native back control', (
    tester,
  ) async {
    var backCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: MovieWebViewAppBar(
            title: '示例影片',
            progress: 0.5,
            onBack: () => backCalls++,
          ),
        ),
      ),
    );

    expect(find.text('示例影片'), findsOneWidget);
    expect(find.byTooltip('返回'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);

    await tester.tap(find.byTooltip('返回'));
    await tester.pump();
    expect(backCalls, 1);
  });

  testWidgets('movie shell supplies localizations for root navigator routes', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MovieWebViewAppBar(
          title: '示例影片',
          progress: 1,
          onBack: () {},
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.byType(AppMaterialLocalizations), findsOneWidget);
  });

  testWidgets('movie shell adds no browser tools over website content', (
    tester,
  ) async {
    var contentTaps = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MovieWebViewShell(
            child: GestureDetector(
              key: const Key('movie-web-content'),
              behavior: HitTestBehavior.opaque,
              onTap: () => contentTaps++,
              child: const ColoredBox(
                color: Colors.transparent,
                child: Center(child: Text('网页内容')),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.byTooltip('网页工具'), findsNothing);
    await tester.tap(find.byKey(const Key('movie-web-content')));
    await tester.pump();
    expect(contentTaps, 1);
  });
}
