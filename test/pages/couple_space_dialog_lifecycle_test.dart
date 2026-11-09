import 'package:PiliPlus/pages/couple_space/view.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('comment input rejects empty text and returns trimmed content', (
    tester,
  ) async {
    String? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () async {
                result = await showDialog<String>(
                  context: context,
                  builder: (context) => const CoupleSpaceCommentInputDialog(),
                );
              },
              child: const Text('评论'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('评论'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '发送'))
          .onPressed,
      isNull,
    );

    await tester.enterText(find.byType(TextField), '  我也想你  ');
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '发送'))
          .onPressed,
      isNotNull,
    );
    await tester.tap(find.widgetWithText(FilledButton, '发送'));
    await tester.pumpAndSettle();
    expect(result, '我也想你');
    expect(tester.takeException(), isNull);
  });

  testWidgets('text editor owns its controller through the pop animation', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () => showDialog<String>(
                context: context,
                builder: (context) => const CoupleSpaceTextInputDialog(
                  title: '空间设置',
                  initialValue: '我们的小窝',
                ),
              ),
              child: const Text('编辑'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('编辑'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '新的小窝');
    await tester.tap(find.widgetWithText(FilledButton, '保存'));

    await tester.pump(const Duration(milliseconds: 50));
    expect(tester.takeException(), isNull);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
