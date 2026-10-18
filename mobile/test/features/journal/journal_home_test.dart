import 'package:ai_diary/features/journal/data/guided_template.dart';
import 'package:ai_diary/features/journal/data/journal_entry.dart';
import 'package:ai_diary/features/journal/data/journal_repository.dart';
import 'package:ai_diary/features/journal/presentation/write_journal_screen.dart';
import 'package:ai_diary/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pumpApp(WidgetTester tester, JournalRepository journals) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(412, 915);
  tester.view.padding = const FakeViewPadding(top: 44, bottom: 34);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(AiDiaryApp(journals: journals));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Home has no entry row for a new user', (tester) async {
    await _pumpApp(tester, InMemoryJournalRepository());
    expect(find.text('Nhật ký gần nhất'), findsNothing);
  });

  testWidgets('The onboarding entry shows on Home and opens in the editor',
      (tester) async {
    final journals = InMemoryJournalRepository();
    const template = GuidedTemplate.firstEntry;
    final fields = {'thought': 'chuyến đi'};
    final saved = await journals.create(JournalContent(
      body: template.render(fields: fields),
      guided: GuidedValues.of(template, fields),
    ));
    await _pumpApp(tester, journals);
    expect(find.text('Nhật ký gần nhất'), findsOneWidget);
    expect(find.text('Một điều đang ở trong đầu mình là chuyến đi.'),
        findsOneWidget);

    await tester.tap(find.text('Nhật ký gần nhất'));
    await tester.pumpAndSettle();
    final editor = tester.widget<TextField>(find.descendant(
        of: find.byType(WriteJournalScreen), matching: find.byType(TextField)));
    expect(editor.controller!.text, saved.body);

    // Finish without changes keeps the guided values and the version.
    await tester.tap(find.text('Finish'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final same = (await journals.entries()).single;
    expect(same.id, saved.id);
    expect(same.bodyVersion, 1);
    expect(same.content.guided, isNotNull);
    await tester.pump(const Duration(seconds: 5)); // the mock reflection
  });

  testWidgets('Editing in J01 updates the same entry id', (tester) async {
    final journals = InMemoryJournalRepository();
    final saved =
        await journals.create(const JournalContent(body: 'Hôm nay ổn.'));
    await _pumpApp(tester, journals);
    await tester.tap(find.text('Nhật ký gần nhất'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.descendant(
            of: find.byType(WriteJournalScreen),
            matching: find.byType(TextField)),
        'Hôm nay ổn hơn hôm qua.');
    await tester.tap(find.text('Finish'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final entries = await journals.entries();
    expect(entries, hasLength(1));
    expect(entries.single.id, saved.id);
    expect(entries.single.bodyVersion, 2);
    expect(entries.single.body, 'Hôm nay ổn hơn hôm qua.');
    await tester.pump(const Duration(seconds: 5)); // the mock reflection
  });

  testWidgets('A new J01 entry is saved on Finish', (tester) async {
    final journals = InMemoryJournalRepository();
    await _pumpApp(tester, journals);
    await tester.tap(find.text('Reflect ➔'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Một ngày bình thường.');
    await tester.tap(find.text('Finish'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect((await journals.entries()).single.body, 'Một ngày bình thường.');
    await tester.pump(const Duration(seconds: 5)); // the mock reflection
  });
}
