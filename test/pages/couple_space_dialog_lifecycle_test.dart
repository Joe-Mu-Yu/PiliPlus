import 'package:PiliPlus/pages/couple_space/view.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
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
