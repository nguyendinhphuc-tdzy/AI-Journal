import 'package:shared_preferences/shared_preferences.dart';
import 'package:ai_diary/features/journal/data/guided_template.dart';
import 'package:ai_diary/features/journal/data/journal_entry.dart';
import 'package:ai_diary/features/journal/data/journal_mood.dart';
import 'package:ai_diary/features/journal/data/journal_repository.dart';
import 'package:ai_diary/features/journal/presentation/write_journal_screen.dart';
import 'package:ai_diary/features/journal/presentation/ai_reflection_screen.dart';
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

/// The entry card under "Nhật ký gần đây" on Home.
Finder get _latest => find.byKey(const ValueKey('home-latest-entry'));

/// Scrolls Home down to "Nhật ký của bạn", below the scene.
Future<void> _scrollToLatest(WidgetTester tester) async {
  await tester.scrollUntilVisible(_latest, 200,
      scrollable: find
          .descendant(
              of: find.byKey(const PageStorageKey('home-scroll')),
              matching: find.byType(Scrollable))
          .first);
  await tester.pumpAndSettle();
}

/// Opens the entry card under "Nhật ký gần đây" on Home.
Future<void> _openLatest(WidgetTester tester) async {
  await _scrollToLatest(tester);
  final card = find.descendant(of: _latest, matching: find.byType(InkWell));
  await tester.ensureVisible(card);
  await tester.pumpAndSettle();
  await tester.tap(card);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets('The latest entry reads like a journal page', (tester) async {
    final journals = InMemoryJournalRepository();
    await journals.create(const JournalContent(
      body:
          'Một buổi chiều nhẹ nhõm\n\nĐi dạo quanh hồ, gió mát.\nVề nhà nấu cơm.',
      mood: JournalMood.calm,
    ));
    await _pumpApp(tester, journals);
    await _scrollToLatest(tester);
    Finder inCard(String text) =>
        find.descendant(of: _latest, matching: find.textContaining(text));
    // The day, the mood, the first line as title, the rest as a glimpse.
    expect(inCard('Hôm nay'), findsOneWidget);
    expect(inCard(JournalMood.calm.label), findsOneWidget);
    expect(
        find.descendant(
            of: _latest, matching: find.text('Một buổi chiều nhẹ nhõm')),
        findsOneWidget);
    expect(
        find.descendant(
            of: _latest,
            matching: find.text('Đi dạo quanh hồ, gió mát. Về nhà nấu cơm.')),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Empty and whitespace-only journals cannot finish',
      (tester) async {
    final journals = InMemoryJournalRepository();
    await _pumpApp(tester, journals);
    await tester.ensureVisible(find.text('Viết nhật ký'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Viết nhật ký'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Lưu nhật ký'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Bạn đã hoàn tất chưa?'), findsNothing);
    expect(find.byType(AiReflectionScreen), findsNothing);
    expect(
        find.text(
            'Vui lòng viết ít nhất một dòng nhật ký trước khi hoàn thành.'),
        findsOneWidget);
    expect(await journals.entries(), isEmpty);

    await tester.enterText(find.byType(TextField), '  \n \t  ');
    await tester.tap(find.text('Lưu nhật ký'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Bạn đã hoàn tất chưa?'), findsNothing);
    expect(find.byType(AiReflectionScreen), findsNothing);
    expect(find.byType(WriteJournalScreen), findsOneWidget);
    expect(await journals.entries(), isEmpty);
  });

  testWidgets('Clearing an existing journal cannot finish or overwrite it',
      (tester) async {
    final journals = InMemoryJournalRepository();
    final saved = await journals.create(
        const JournalContent(body: 'A previous meaningful journal entry.'));
    await _pumpApp(tester, journals);
    await _openLatest(tester);
    await tester.pumpAndSettle();

    await tester.enterText(
        find.descendant(
            of: find.byType(WriteJournalScreen),
            matching: find.byType(TextField)),
        ' \n  ');
    await tester.tap(find.text('Lưu nhật ký'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Bạn đã hoàn tất chưa?'), findsNothing);
    expect(find.byType(AiReflectionScreen), findsNothing);
    expect(find.byType(WriteJournalScreen), findsOneWidget);
    final entries = await journals.entries();
    expect(entries, hasLength(1));
    expect(entries.single.id, saved.id);
    expect(entries.single.bodyVersion, saved.bodyVersion);
    expect(entries.single.body, saved.body);
  });

  testWidgets('Follow-up is saved only after confirmation', (tester) async {
    final journals = InMemoryJournalRepository();
    await _pumpApp(tester, journals);
    await tester.ensureVisible(find.text('Viết nhật ký'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Viết nhật ký'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'School feels difficult.');
    // Going deeper turns on once there is something written.
    await tester.pump();
    await tester.tap(find.text('Nhìn lại cùng bạn'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'I am worried about exams.');
    await tester.tap(find.text('Lưu nhật ký'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Quay lại'));
    await tester.pumpAndSettle();
    expect(await journals.entries(), isEmpty);
    expect(find.text('I am worried about exams.'), findsOneWidget);
    await tester.tap(find.text('Lưu nhật ký'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xác nhận'));
    await tester.pumpAndSettle();
    expect((await journals.entries()).single.body,
        'School feels difficult.\n\nI am worried about exams.');
    await tester.pump(const Duration(seconds: 8));
  });

  testWidgets('Home has no entry row for a new user', (tester) async {
    await _pumpApp(tester, InMemoryJournalRepository());
    expect(find.text('Nhật ký gần đây'), findsNothing);
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
    await _scrollToLatest(tester);
    expect(find.text('Nhật ký gần đây'), findsOneWidget);
    expect(find.text('Một điều đang ở trong đầu mình là chuyến đi.'),
        findsOneWidget);

    await _openLatest(tester);
    await tester.pumpAndSettle();
    final editor = tester.widget<TextField>(find.descendant(
        of: find.byType(WriteJournalScreen), matching: find.byType(TextField)));
    expect(editor.controller!.text, saved.body);

    // Finish without changes keeps the guided values and the version.
    await tester.tap(find.text('Lưu nhật ký'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xác nhận'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final same = (await journals.entries()).single;
    expect(same.id, saved.id);
    expect(same.bodyVersion, 1);
    expect(same.content.guided, isNotNull);
    await tester.pump(const Duration(seconds: 8)); // the mock reflection
  });

  testWidgets('Editing in J01 updates the same entry id', (tester) async {
    final journals = InMemoryJournalRepository();
    final saved =
        await journals.create(const JournalContent(body: 'Hôm nay ổn.'));
    await _pumpApp(tester, journals);
    await _openLatest(tester);
    await tester.pumpAndSettle();
    await tester.enterText(
        find.descendant(
            of: find.byType(WriteJournalScreen),
            matching: find.byType(TextField)),
        'Hôm nay ổn hơn hôm qua.');
    await tester.tap(find.text('Lưu nhật ký'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xác nhận'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final entries = await journals.entries();
    expect(entries, hasLength(1));
    expect(entries.single.id, saved.id);
    expect(entries.single.bodyVersion, 2);
    expect(entries.single.body, 'Hôm nay ổn hơn hôm qua.');
    await tester.pump(const Duration(seconds: 8)); // the mock reflection
  });

  testWidgets('A new J01 entry is saved on Finish', (tester) async {
    final journals = InMemoryJournalRepository();
    await _pumpApp(tester, journals);
    await tester.ensureVisible(find.text('Viết nhật ký'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Viết nhật ký'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Một ngày bình thường.');
    await tester.tap(find.text('Lưu nhật ký'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xác nhận'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect((await journals.entries()).single.body, 'Một ngày bình thường.');
    await tester.pump(const Duration(seconds: 8)); // the mock reflection
  });
}
