import 'package:PiliPlus/pages/webview/movie_webview_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('movie shell adds no visible controls over website content', (
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

    expect(find.byType(AppBar), findsNothing);
    expect(find.byTooltip('网页工具'), findsNothing);
    await tester.tap(find.byKey(const Key('movie-web-content')));
    await tester.pump();
    expect(contentTaps, 1);
  });
}
