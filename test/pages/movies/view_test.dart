import 'package:PiliPlus/common/widgets/main_layout.dart';
import 'package:PiliPlus/pages/movies/view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Android Movies embeds AVBox directly in the destination', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MovieHomePage(
          isAndroid: true,
          avboxViewBuilder: _buildEmbeddedMarker,
        ),
      ),
    );

    expect(find.text('embedded-avbox'), findsOneWidget);
    expect(find.text('打开 AVBox'), findsNothing);
    expect(find.byType(AndroidView), findsNothing);
    expect(
      tester.getSize(find.byKey(const ValueKey('embedded-avbox'))),
      tester.getSize(find.byType(MovieHomePage)),
    );
  });

  testWidgets('non-Android Movies shows an explicit unsupported state', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MovieHomePage(
          isAndroid: false,
          avboxViewBuilder: _buildEmbeddedMarker,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('embedded-avbox'), findsNothing);
    expect(find.text('当前平台暂不支持影视'), findsOneWidget);
    expect(find.textContaining('AVBox 集成目前仅支持 Android'), findsOneWidget);
    expect(find.text('打开 AVBox'), findsNothing);
  });

  testWidgets('Movies can paint through the host system-bar padding', (
    tester,
  ) async {
    const viewportSize = Size(390, 844);
    const hostSafePadding = EdgeInsets.fromLTRB(12, 32, 12, 0);
    tester.view.physicalSize = viewportSize;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: MainBodyViewport(
          safePadding: hostSafePadding,
          extendIntoSystemBars: true,
          extendIntoTopSystemBar: true,
          child: SizedBox.expand(key: ValueKey('movies-viewport')),
        ),
      ),
    );

    final viewport = find.byKey(const ValueKey('movies-viewport'));
    expect(tester.getTopLeft(viewport), Offset.zero);
    expect(tester.getSize(viewport), viewportSize);
  });

  testWidgets('Other destinations keep the host safe-area padding', (
    tester,
  ) async {
    const viewportSize = Size(390, 844);
    const hostSafePadding = EdgeInsets.fromLTRB(12, 32, 12, 0);
    tester.view.physicalSize = viewportSize;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: MainBodyViewport(
          safePadding: hostSafePadding,
          extendIntoSystemBars: false,
          child: SizedBox.expand(key: ValueKey('safe-viewport')),
        ),
      ),
    );

    final viewport = find.byKey(const ValueKey('safe-viewport'));
    expect(tester.getTopLeft(viewport), const Offset(12, 32));
    expect(tester.getSize(viewport), const Size(366, 812));
  });
}

Widget _buildEmbeddedMarker(BuildContext context) => const SizedBox.expand(
  key: ValueKey('embedded-avbox'),
  child: Text('embedded-avbox'),
);
