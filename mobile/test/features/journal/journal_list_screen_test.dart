import 'dart:convert';

import 'package:ai_diary/core/theme/app_theme.dart';
import 'package:ai_diary/features/journal/data/journal_entry.dart';
import 'package:ai_diary/features/journal/data/journal_mood.dart';
import 'package:ai_diary/features/journal/data/journal_repository.dart';
import 'package:ai_diary/features/journal/journal_scope.dart';
import 'package:ai_diary/features/journal/presentation/delete_entry_dialog.dart';
import 'package:ai_diary/features/journal/presentation/journal_list_screen.dart';
import 'package:ai_diary/features/journal/presentation/write_journal_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Saved entries written at [at], as the repository stores them.
Map<String, Object> seed(List<(String, DateTime, JournalMood?)> entries) => {
      'journal.entries': jsonEncode([
        for (final (index, (body, at, mood)) in entries.indexed)
          {
            'id': 'e$index',
            'createdAt': at.toIso8601String(),
            'updatedAt': at.toIso8601String(),
            'bodyVersion': 1,
            'body': body,
            'mood': mood?.name,
            'guided': null,
          },
      ]),
    };

Future<void> _pump(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(412, 915);
  addTearDown(tester.view.reset);
  final journals = await LocalJournalRepository.open();
  // Above the app, as in main.dart: screens pushed from the list see it.
  await tester.pumpWidget(JournalScope(
    repository: journals,
    child: MaterialApp(
      theme: AppTheme.light,
      home: const JournalListScreen(),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Every entry, newest first, grouped by month', (tester) async {
    SharedPreferences.setMockInitialValues(seed([
      ('Đi dạo hồ Tây\nGió mát', DateTime(2026, 9, 15, 8), JournalMood.calm),
      (
        'Lo về bài kiểm tra\nNgày mai thi toán',
        DateTime(2026, 10, 20, 21, 5),
        JournalMood.anxious
      ),
      ('Hôm nay ổn', DateTime(2026, 10, 25, 7, 30), null),
    ]));
    await _pump(tester);
    expect(find.text('3 bài viết'), findsOneWidget);
    final october = tester.getTopLeft(find.text('Tháng 10/2026')).dy;
    final september = tester.getTopLeft(find.text('Tháng 9/2026')).dy;
    expect(october, lessThan(september));
    // Newest first inside the month.
    expect(tester.getTopLeft(find.text('Hôm nay ổn')).dy,
        lessThan(tester.getTopLeft(find.text('Lo về bài kiểm tra')).dy));
    // Day, title, glimpse, time and mood.
    final row = find.byKey(const ValueKey('journal-list-entry-e1'));
    for (final text in ['20', 'T3', 'Ngày mai thi toán', '21:05 · Lo lắng']) {
      expect(
          find.descendant(of: row, matching: find.text(text)), findsOneWidget,
          reason: text);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('Search ignores accents; chips keep one mood', (tester) async {
    SharedPreferences.setMockInitialValues(seed([
      ('Đi dạo hồ Tây', DateTime(2026, 9, 15), JournalMood.calm),
      ('Lo về bài kiểm tra', DateTime(2026, 10, 20), JournalMood.anxious),
      ('Hôm nay ổn', DateTime(2026, 10, 25), null),
    ]));
    await _pump(tester);
    // Only the moods that were picked.
    expect(find.text('Bình yên'), findsOneWidget);
    expect(find.text('Lo lắng'), findsOneWidget);
    expect(find.text(JournalMood.happy.label), findsNothing);

    await tester.enterText(
        find.byKey(const ValueKey('journal-list-search')), 'bai kiem');
    await tester.pumpAndSettle();
    expect(find.text('Lo về bài kiểm tra'), findsOneWidget);
    expect(find.text('Đi dạo hồ Tây'), findsNothing);
    expect(find.text('Hôm nay ổn'), findsNothing);

    await tester.enterText(
        find.byKey(const ValueKey('journal-list-search')), 'không có');
    await tester.pumpAndSettle();
    expect(find.text('Không tìm thấy bài viết phù hợp.'), findsOneWidget);

    await tester.enterText(
        find.byKey(const ValueKey('journal-list-search')), '');
    await tester.tap(find.text('Bình yên'));
    await tester.pumpAndSettle();
    expect(find.text('Đi dạo hồ Tây'), findsOneWidget);
    expect(find.text('Lo về bài kiểm tra'), findsNothing);
    // Tapped again, every mood is back.
    await tester.tap(find.text('Bình yên'));
    await tester.pumpAndSettle();
    expect(find.text('Lo về bài kiểm tra'), findsOneWidget);
  });

  testWidgets('An entry opens in the editor; edits show in the list',
      (tester) async {
    SharedPreferences.setMockInitialValues(
        seed([('Một ngày dài', DateTime(2026, 10, 20), null)]));
    await _pump(tester);
    await tester.tap(find.byKey(const ValueKey('journal-list-entry-e0')));
    await tester.pumpAndSettle();
    expect(find.byType(WriteJournalScreen), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Một ngày dài');
    // Saved from the editor (here straight to the store the screen uses).
    final journals =
        JournalScope.of(tester.element(find.byType(WriteJournalScreen)));
    await journals.update(
        'e0', const JournalContent(body: 'Một ngày dài nhưng vui'));
    await tester.tap(find.byTooltip('Đóng'));
    await tester.pumpAndSettle();
    expect(find.text('Một ngày dài nhưng vui'), findsOneWidget);
  });

  testWidgets('The bin asks first, then deletes the entry', (tester) async {
    SharedPreferences.setMockInitialValues(seed([
      ('Đi dạo hồ Tây', DateTime(2026, 10, 15), null),
      ('Hôm nay ổn', DateTime(2026, 10, 25), null),
    ]));
    await _pump(tester);
    final bin = find.byKey(const ValueKey('journal-list-delete-e1'));

    // Canceled: nothing goes, and the editor did not open.
    await tester.tap(bin);
    await tester.pumpAndSettle();
    final dialog = find.byType(DeleteEntryDialog);
    expect(find.text(DeleteEntryDialog.title), findsOneWidget);
    // Which entry: when it was written and its first line.
    for (final text in ['25/10/2026 · 00:00', 'Hôm nay ổn']) {
      expect(find.descendant(of: dialog, matching: find.text(text)),
          findsOneWidget,
          reason: text);
    }
    await tester.tap(find.text(DeleteEntryDialog.cancelLabel));
    await tester.pumpAndSettle();
    expect(find.byType(WriteJournalScreen), findsNothing);
    expect(find.text('Hôm nay ổn'), findsOneWidget);

    await tester.tap(bin);
    await tester.pumpAndSettle();
    await tester.tap(find.text(DeleteEntryDialog.confirmLabel));
    await tester.pumpAndSettle();
    expect(find.text('Hôm nay ổn'), findsNothing);
    expect(find.text('Đi dạo hồ Tây'), findsOneWidget);
    expect(find.text('1 bài viết'), findsOneWidget);

    // The last one gone: back to the invitation.
    await tester.tap(find.byKey(const ValueKey('journal-list-delete-e0')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(DeleteEntryDialog.confirmLabel));
    await tester.pumpAndSettle();
    expect(find.text('Chưa có bài nhật ký nào'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('A failed delete stays in the dialog and offers a retry',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(412, 915);
    addTearDown(tester.view.reset);
    final entry = JournalEntry(
      id: 'e0',
      createdAt: DateTime(2026, 10, 27, 17, 25),
      updatedAt: DateTime(2026, 10, 27, 17, 25),
      bodyVersion: 1,
      content: const JournalContent(body: 'Lúc này mình cảm thấy lo lắng.'),
    );
    var calls = 0;
    bool? result;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async => result = await DeleteEntryDialog.show(
            context,
            entry: entry,
            onConfirm: () async {
              if (++calls == 1) throw StateError('offline');
            },
          ),
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(DeleteEntryDialog.confirmLabel));
    await tester.pumpAndSettle();
    expect(find.text(DeleteEntryDialog.failed), findsOneWidget);
    expect(find.byType(DeleteEntryDialog), findsOneWidget);

    await tester.tap(find.text(DeleteEntryDialog.retryLabel));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(find.byType(DeleteEntryDialog), findsNothing);
    expect(result, isTrue);
  });

  testWidgets('Study writing says where it was written', (tester) async {
    final at = DateTime(2026, 10, 27, 17, 25).toIso8601String();
    SharedPreferences.setMockInitialValues({
      'journal.entries': jsonEncode([
        {
          'id': 's1',
          'createdAt': at,
          'updatedAt': at,
          'bodyVersion': 1,
          'body': 'Một tách trà ấm.',
          'mood': null,
          'guided': null,
          'source': {
            'kind': 'challenge',
            'id': 'gratitude-seven',
            'task': 1,
            'label': 'Challenge · Nhiệm vụ 2',
          },
        },
      ]),
    });
    await _pump(tester);
    expect(find.text('17:25 · Challenge · Nhiệm vụ 2'), findsOneWidget);
  });

  testWidgets('No entries yet: an invitation to write', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await _pump(tester);
    expect(find.text('Chưa có bài nhật ký nào'), findsOneWidget);
    await tester.tap(find.text('Viết bài đầu tiên'));
    await tester.pumpAndSettle();
    expect(find.byType(WriteJournalScreen), findsOneWidget);
  });

  test('Folding finds Vietnamese words typed without accents', () {
    expect(JournalListScreen.fold('Hôm nay Đi HỌC'), 'hom nay di hoc');
  });
}
