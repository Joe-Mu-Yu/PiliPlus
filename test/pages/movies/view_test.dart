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
}

Widget _buildEmbeddedMarker(BuildContext context) => const SizedBox.expand(
  key: ValueKey('embedded-avbox'),
  child: Text('embedded-avbox'),
);
