import 'package:ai_diary/main.dart';
import 'package:ai_diary/core/theme/app_theme.dart';
import 'package:ai_diary/features/journal/presentation/write_journal_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final size in [const Size(320, 640), const Size(640, 320)]) {
    testWidgets('All tabs fit viewport $size', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(const AiDiaryApp());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      for (final tab in ['Study', 'Album', 'Explore', 'Home']) {
        await tester.tap(find.text(tab));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: tab);
      }
    });
  }

  testWidgets('Go Deeper opens reflection with keyboard visible',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 568);
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: const WriteJournalScreen(),
    ));
    await tester.enterText(find.byType(TextField), 'A peaceful afternoon.');
    await tester.tap(find.text('✨ Go Deeper'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 3));
    expect(find.text("✨ Nudaeng's thought..."), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
