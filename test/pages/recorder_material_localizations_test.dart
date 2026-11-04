import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:PiliPlus/pages/recorder_center/recorder_material_localizations.dart';
import 'package:material_ui/material_ui.dart' as mui;
import 'package:get/get.dart' as getx;
import 'package:pure_live/recorder/widgets/recorder_bounded_scroll.dart';

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

  testWidgets('record status selector follows light/dark app theme changes', (
    tester,
  ) async {
    final lightTheme = mui.ThemeData(
      colorScheme: mui.ColorScheme.fromSeed(
        seedColor: const mui.Color(0xFF008577),
        brightness: mui.Brightness.light,
      ),
    );
    final darkTheme = mui.ThemeData(
      colorScheme: mui.ColorScheme.fromSeed(
        seedColor: const mui.Color(0xFF008577),
        brightness: mui.Brightness.dark,
      ),
    );

    await tester.pumpWidget(
      getx.GetMaterialApp(
        theme: lightTheme,
        darkTheme: darkTheme,
        themeMode: mui.ThemeMode.light,
        home: const mui.DefaultTabController(
          length: 1,
          child: mui.Scaffold(
            body: RecorderStatusSelector(labels: ['全部']),
          ),
        ),
      ),
    );
    await tester.pump();

    mui.Material selectedButton() => tester.widget<mui.Material>(
      find
          .ancestor(
            of: find.byKey(const mui.ValueKey('recorder-status-0')),
            matching: find.byType(mui.Material),
          )
          .first,
    );

    expect(selectedButton().color, lightTheme.colorScheme.primaryContainer);

    getx.Get.changeThemeMode(mui.ThemeMode.dark);
    await tester.pumpAndSettle();
    expect(selectedButton().color, darkTheme.colorScheme.primaryContainer);
    expect(tester.takeException(), isNull);
  });
}
