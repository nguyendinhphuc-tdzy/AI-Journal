import 'package:ai_diary/core/theme/app_theme.dart';
import 'package:ai_diary/core/data/app_data.dart';
import 'package:ai_diary/features/journal/data/analysis_archive.dart';
import 'package:ai_diary/features/journal/data/saved_quotes.dart';
import 'package:ai_diary/features/journal/data/api_ai_service.dart';
import 'package:ai_diary/features/journal/data/journal_entry.dart';
import 'package:ai_diary/features/journal/data/journal_repository.dart';
import 'package:ai_diary/features/journal/journal_scope.dart';
import 'package:ai_diary/features/journal/presentation/ai_reflection_screen.dart';
import 'package:ai_diary/features/journal/presentation/journal_list_screen.dart';
import 'package:ai_diary/features/journal/presentation/kept_analysis_chip.dart';
import 'package:ai_diary/features/journal/presentation/write_journal_screen.dart';
import 'package:ai_diary/features/onboarding/data/onboarding_scope.dart';
import 'package:ai_diary/features/onboarding/data/onboarding_store.dart';
import 'package:ai_diary/features/streak/streak_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_ai.dart';

const _user = '11111111-2222-3333-4444-555555555555';

SavedAnalysis _saved(String entryId, {int bodyVersion = 1}) => SavedAnalysis(
      entryId: entryId,
      bodyVersion: bodyVersion,
      savedAt: DateTime(2026, 10, 29, 14, 31),
      analysis: AiAnalysis.fromJson(Map.of(FakeAi.reflection)),
      quote: (text: 'Một câu.', author: 'Tác giả A'),
    );

late InMemoryJournalRepository _journals;

Future<void> _pump(WidgetTester tester, Widget home, {FakeAi? ai}) async {
  final onboarding = await OnboardingStore.open(userId: _user);
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(412, 915);
  addTearDown(tester.view.reset);
  final app = OnboardingScope(
    store: onboarding,
    child: JournalScope(
      repository: _journals,
      child: MaterialApp(theme: AppTheme.light, home: home),
    ),
  );
  await tester.pumpWidget(
      ai == null ? app : AiRemoteScope(service: ai.service, child: app));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    StreakState.shared.reset();
    _journals = InMemoryJournalRepository();
  });

  group('AnalysisArchive', () {
    test('keeps an analysis per entry and gives it back whole', () async {
      final archive = await AnalysisArchive.open(userId: _user);
      await archive.save(_saved('e1'));
      final back = archive.of('e1')!;
      expect(back.bodyVersion, 1);
      expect(back.analysis.emotion, 'nhẹ nhõm');
      expect(back.analysis.observation, FakeAi.reflection['observation']);
      expect(back.quote?.author, 'Tác giả A');
      expect(back.savedAt, DateTime(2026, 10, 29, 14, 31));
      expect(archive.of('e2'), isNull);
    });

    test('one account never sees another\'s', () async {
      await (await AnalysisArchive.open(userId: _user)).save(_saved('e1'));
      final other = await AnalysisArchive.open(
          userId: '99999999-2222-3333-4444-555555555555');
      expect(other.of('e1'), isNull);
      expect(other.all(), isEmpty);
    });

    test('removed with its entry; unreadable counts as none', () async {
      final archive = await AnalysisArchive.open(userId: _user);
      await archive.save(_saved('e1'));
      await archive.remove('e1');
      expect(archive.of('e1'), isNull);
      SharedPreferences.setMockInitialValues(
          {'account.$_user.journal.analysis.e9': '{"broken": true}'});
      expect((await AnalysisArchive.open(userId: _user)).of('e9'), isNull);
    });
  });

  testWidgets('Saved with AI: the analysis is kept and read again from the '
      'entry, without asking the AI again', (tester) async {
    final ai = FakeAi();
    await _pump(tester, const WriteJournalScreen(), ai: ai);
    await tester.enterText(find.byType(TextField), 'Chiều nay đi dạo.');
    await tester.tap(find.text(WriteJournalScreen.finishLabel));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xác nhận'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(ai.reflectionSent, hasLength(1));

    final entry = (await _journals.entries()).single;
    final kept = (await AnalysisArchive.open(userId: _user)).of(entry.id);
    expect(kept, isNotNull);
    expect(kept!.bodyVersion, entry.bodyVersion);
    expect(kept.analysis.emotion, 'nhẹ nhõm');

    // Later, from "Nhật ký gần đây": the entry, then its analysis.
    await tester.pumpWidget(const SizedBox());
    await _pump(tester, WriteJournalScreen(entry: entry), ai: ai);
    await tester.tap(find.text(WriteJournalScreen.reviewLabel));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(AiReflectionScreen), findsOneWidget);
    expect(find.text('Nhẹ nhõm'), findsOneWidget);
    expect(find.textContaining('Phân tích ngày'), findsOneWidget);
    expect(find.textContaining('bản trước'), findsNothing);
    expect(ai.reflectionSent, hasLength(1), reason: 'nothing sent again');

    // The quote picked then is on the analysis, saved or not; "Tiếp tục"
    // goes straight back, not through the quote again.
    final quote = kept.quote!;
    await tester.scrollUntilVisible(
        find.widgetWithText(TextButton, 'Lưu'), 150,
        scrollable: find.byType(Scrollable).first);
    expect(find.text(quote.text), findsOneWidget);
    expect(find.text('– ${quote.author}'), findsOneWidget);
    final quotes = await SavedQuotes.open(userId: _user);
    expect(quotes.contains(quote.text), isFalse);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
    await tester.pump();
    await tester.tap(find.widgetWithText(TextButton, 'Lưu'));
    await tester.pump();
    await tester.pump();
    expect(quotes.contains(quote.text), isTrue);
    expect(find.widgetWithText(TextButton, 'Đã lưu'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Tiếp tục'), 150,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Tiếp tục'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text(quote.text), findsNothing,
        reason: 'no quote screen again');
    expect(find.byType(AiReflectionScreen), findsNothing);
    expect(find.byType(WriteJournalScreen), findsOneWidget,
        reason: 'back to the entry, not the streak');
  });

  group('SavedQuotes', () {
    test('kept per account, never twice, outlives a restart', () async {
      final mine = await SavedQuotes.open(userId: _user);
      await mine.save('Câu A.', 'Tác giả A');
      await mine.save('Câu B.', 'Tác giả B');
      await mine.save('Câu A.', 'Tác giả A');
      expect([for (final q in mine.all()) q.text], ['Câu A.', 'Câu B.'],
          reason: 'saved again: to the top, once');
      expect(savedThisWeekItems.value.where((i) => i['type'] == 'quote'),
          hasLength(2));
      final again = await SavedQuotes.open(userId: _user);
      expect(again.contains('Câu B.'), isTrue);
      final other = await SavedQuotes.open(
          userId: '99999999-2222-3333-4444-555555555555');
      expect(other.all(), isEmpty);
      await mine.remove('Câu A.');
      expect([for (final q in mine.all()) q.text], ['Câu B.']);
      expect(savedThisWeekItems.value.where((i) => i['type'] == 'quote'),
          hasLength(1));
    });
  });

  testWidgets('A saved quote says so when it shows again', (tester) async {
    final ai = FakeAi(analysis: {
      ...FakeAi.reflection,
      'quote': {'text': 'Một câu đã kiểm chứng.', 'author': 'Tác giả A'},
    });
    await (await SavedQuotes.open(userId: _user))
        .save('Một câu đã kiểm chứng.', 'Tác giả A');
    await _pump(tester, const WriteJournalScreen(), ai: ai);
    await tester.enterText(find.byType(TextField), 'Lại một ngày.');
    await tester.tap(find.text(WriteJournalScreen.finishLabel));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xác nhận'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('Tiếp tục'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Một câu đã kiểm chứng.'), findsOneWidget);
    expect(find.text('Đã lưu'), findsOneWidget, reason: 'not "Lưu" again');
    // A second tap lets it go.
    await tester.tap(find.text('Đã lưu'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Lưu'), findsOneWidget);
    expect((await SavedQuotes.open(userId: _user)).all(), isEmpty);
  });

  testWidgets('An entry without a kept analysis offers none', (tester) async {
    final entry =
        await _journals.create(const JournalContent(body: 'Không có AI.'));
    await _pump(tester, WriteJournalScreen(entry: entry));
    expect(find.text(WriteJournalScreen.reviewLabel), findsNothing);
  });

  testWidgets('Edited since: the analysis says it read an earlier version',
      (tester) async {
    final first = await _journals.create(const JournalContent(body: 'Một.'));
    final edited =
        await _journals.update(first.id, const JournalContent(body: 'Hai.'));
    await (await AnalysisArchive.open(userId: _user))
        .save(_saved(first.id, bodyVersion: first.bodyVersion));
    await _pump(tester, WriteJournalScreen(entry: edited));
    await tester.tap(find.text(WriteJournalScreen.reviewLabel));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.textContaining('cho bản trước khi bạn sửa'), findsOneWidget);
  });

  testWidgets('The list shows each entry\'s kept feeling; a tap reads it '
      'again', (tester) async {
    final kept = await _journals.create(const JournalContent(body: 'Có AI.'));
    await _journals.create(const JournalContent(body: 'Không có AI.'));
    await _pump(tester, const JournalListScreen());
    await tester.pumpAndSettle();
    expect(find.byType(KeptAnalysisChip), findsNWidgets(2));
    expect(find.text('Nhẹ nhõm'), findsNothing, reason: 'nothing kept yet');

    // Kept after the list is shown (the analysis comes after the save).
    await (await AnalysisArchive.open(userId: _user)).save(_saved(kept.id));
    await tester.pumpAndSettle();
    expect(find.text('Nhẹ nhõm'), findsOneWidget, reason: 'only that entry');

    await tester.tap(find.text('Nhẹ nhõm'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(AiReflectionScreen), findsOneWidget);
    expect(find.text(FakeAi.reflection['observation']!.replaceFirst('b', 'B')),
        findsOneWidget);
  });

  testWidgets('Deleting an entry deletes its analysis', (tester) async {
    final entry = await _journals.create(const JournalContent(body: 'Xóa.'));
    await (await AnalysisArchive.open(userId: _user)).save(_saved(entry.id));
    await _pump(tester, const JournalListScreen());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('journal-list-delete-${entry.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xóa bài viết').last);
    await tester.pumpAndSettle();
    expect(await _journals.entries(), isEmpty);
    expect((await AnalysisArchive.open(userId: _user)).of(entry.id), isNull);
  });
}
