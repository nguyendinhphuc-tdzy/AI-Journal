import 'dart:convert';

import 'package:ai_diary/core/data/app_data.dart';
import 'package:ai_diary/features/home/presentation/home_screen.dart';
import 'package:ai_diary/features/journal/ai_reflection_screen.dart';
import 'package:ai_diary/features/journal/data/journal_repository.dart';
import 'package:ai_diary/features/journal/presentation/journal_list_screen.dart';
import 'package:ai_diary/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _quote =
    'Hãy làm những gì bạn có thể, bằng những gì bạn có, ngay tại nơi bạn đang đứng.';

/// Entries written at the given times, as the repository stores them.
Map<String, Object> _seed(List<(String, DateTime)> entries) => {
      'journal.entries': jsonEncode([
        for (final (index, (body, at)) in entries.indexed)
          {
            'id': 'e$index',
            'createdAt': at.toIso8601String(),
            'updatedAt': at.toIso8601String(),
            'bodyVersion': 1,
            'body': body,
            'mood': null,
            'guided': null,
          },
      ]),
    };

Future<void> _pumpHome(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(412, 915);
  tester.view.padding = const FakeViewPadding(top: 44, bottom: 34);
  addTearDown(tester.view.reset);
  await tester
      .pumpWidget(AiDiaryApp(journals: await LocalJournalRepository.open()));
  await tester.pumpAndSettle();
}

Future<void> _scrollTo(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(target, 200,
      scrollable: find
          .descendant(
              of: find.byKey(const PageStorageKey('home-scroll')),
              matching: find.byType(Scrollable))
          .first);
  await tester.pumpAndSettle();
}

void main() {
  late List<Map<String, dynamic>> saved;
  setUp(() => saved = savedThisWeekItems.value);
  tearDown(() => savedThisWeekItems.value = saved);

  testWidgets('Home lists the latest three entries and opens all of them',
      (tester) async {
    final now = DateTime.now();
    SharedPreferences.setMockInitialValues(_seed([
      for (var i = 0; i < 5; i++)
        ('Bài số $i', now.subtract(Duration(minutes: 5 - i))),
    ]));
    await _pumpHome(tester);
    await _scrollTo(tester, find.byKey(const ValueKey('home-journal-all')));
    expect(find.text(HomeScreen.latestTitle), findsOneWidget);
    // Newest first, three of five.
    for (final shown in ['Bài số 4', 'Bài số 3', 'Bài số 2']) {
      expect(find.text(shown), findsOneWidget, reason: shown);
    }
    expect(find.text('Bài số 1'), findsNothing);
    expect(
        find.descendant(
            of: find.byKey(const ValueKey('home-latest-entry')),
            matching: find.text('Bài số 4')),
        findsOneWidget);
    expect(find.text('Xem tất cả (5)'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('home-journal-all')));
    await tester.pumpAndSettle();
    expect(find.byType(JournalListScreen), findsOneWidget);
    expect(find.text('Bài số 0'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('This week: the days written and how much', (tester) async {
    final now = DateTime.now();
    SharedPreferences.setMockInitialValues(_seed([
      ('Sáng nay', now.subtract(const Duration(minutes: 2))),
      ('Lúc nãy', now.subtract(const Duration(minutes: 1))),
      // Weeks ago: not this week.
      ('Hồi trước', now.subtract(const Duration(days: 40))),
    ]));
    await _pumpHome(tester);
    await _scrollTo(tester, find.byKey(const ValueKey('this-week-summary')));
    expect(find.text('2 bài viết · 1 ngày có viết'), findsOneWidget);
    expect(find.byKey(const ValueKey('this-week-written')), findsOneWidget);
    expect(find.text(HomeScreen.insightLabel), findsOneWidget);
  });

  testWidgets('A new week starts empty', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await _pumpHome(tester);
    await _scrollTo(tester, find.byKey(const ValueKey('this-week-summary')));
    expect(find.text('Tuần này bạn chưa viết bài nào.'), findsOneWidget);
    expect(find.byKey(const ValueKey('this-week-written')), findsNothing);
  });

  testWidgets('More options: copy, then unsave', (tester) async {
    SharedPreferences.setMockInitialValues({});
    savedThisWeekItems.value = [
      {'type': 'quote', 'content': _quote, 'author': 'Theodore Roosevelt'},
    ];
    final copied = <String>[];
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied.add((call.arguments as Map)['text'] as String);
      }
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
    await _pumpHome(tester);
    final more = find.byTooltip('Thêm lựa chọn');
    await _scrollTo(tester, more);
    // One saved item: no "see all".
    expect(find.byKey(const ValueKey('home-saved-all')), findsNothing);

    await tester.tap(more);
    await tester.pumpAndSettle();
    expect(find.text('Sao chép'), findsOneWidget);
    await tester.tap(find.text('Sao chép'));
    await tester.pumpAndSettle();
    expect(copied, ['$_quote (Theodore Roosevelt)']);
    expect(find.text('Đã sao chép'), findsOneWidget);

    await tester.tap(more);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bỏ lưu'));
    await tester.pumpAndSettle();
    expect(savedThisWeekItems.value, isEmpty);
    // Nothing saved: the section goes.
    expect(find.text(HomeScreen.savedTitle), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Saving a quote twice keeps one card', (tester) async {
    savedThisWeekItems.value = [
      {'type': 'quote', 'content': _quote, 'author': 'Theodore Roosevelt'},
      {'type': 'insight', 'content': 'An insight.'},
    ];
    await tester.pumpWidget(const MaterialApp(
        home: AIReflectionScreen(journalContent: 'Một ngày.')));
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lưu'));
    await tester.pump();
    final quotes = [
      for (final item in savedThisWeekItems.value)
        if (item['type'] == 'quote') item,
    ];
    expect(quotes, hasLength(1));
    // Moved to the top, the insight kept.
    expect(savedThisWeekItems.value.first['type'], 'quote');
    expect(savedThisWeekItems.value, hasLength(2));
    await tester.pump(const Duration(seconds: 5));
  });
}
