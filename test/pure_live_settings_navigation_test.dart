import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pure_live/recorder/pages/recorder/recorder_page.dart';

void main() {
  testWidgets('recorder settings uses app navigation and can be popped', (
    tester,
  ) async {
    await tester.pumpWidget(
      GetMaterialApp(
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        supportedLocales: const [Locale('en')],
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => openRecorderSettingsPage(
                pageBuilder: () => Localizations(
                  locale: const Locale('en'),
                  delegates: GlobalMaterialLocalizations.delegates,
                  child: Scaffold(
                    appBar: AppBar(
                      leadingWidth: 0,
                      titleSpacing: 0,
                      title: Row(
                        children: [
                          IconButton(
                            tooltip: '返回',
                            onPressed: Get.back<void>,
                            icon: const Icon(Icons.arrow_back),
                          ),
                          const Text('Recording settings'),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              child: const Text('Open settings'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open settings'));
    await tester.pumpAndSettle();
    expect(find.text('Recording settings'), findsOneWidget);
    expect(find.byTooltip('返回'), findsWidgets);

    await tester.tap(find.byTooltip('返回').last);
    await tester.pumpAndSettle();
    expect(find.text('Open settings'), findsOneWidget);
    expect(find.text('Recording settings'), findsNothing);
  });
}
