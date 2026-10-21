import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:PiliPlus/pages/recorder_center/recorder_material_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('record center AppBar supplies local MaterialLocalizations', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [],
        home: RecorderMaterialLocalizations(
          child: Scaffold(appBar: AppBar(title: const Text('录制中心'))),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('录制中心'), findsOneWidget);
  });
}
