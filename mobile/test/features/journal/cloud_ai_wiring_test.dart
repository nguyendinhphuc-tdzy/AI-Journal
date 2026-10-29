import 'package:ai_diary/core/data/app_data.dart';
import 'package:ai_diary/core/theme/app_theme.dart';
import 'package:ai_diary/features/insights/presentation/emotion_week_screen.dart';
import 'package:ai_diary/features/journal/data/analysis_archive.dart';
import 'package:ai_diary/features/journal/data/api_ai_service.dart';
import 'package:ai_diary/features/journal/data/cloud_ai_api.dart';
import 'package:ai_diary/features/journal/data/cloud_analysis_sync.dart';
import 'package:ai_diary/features/journal/data/journal_entry.dart';
import 'package:ai_diary/features/journal/data/journal_repository.dart';
import 'package:ai_diary/features/journal/data/saved_quotes.dart';
import 'package:ai_diary/features/journal/journal_scope.dart';
import 'package:ai_diary/features/journal/presentation/ai_reflection_screen.dart';
import 'package:ai_diary/features/journal/presentation/write_journal_screen.dart';
import 'package:ai_diary/features/onboarding/data/onboarding_scope.dart';
import 'package:ai_diary/features/onboarding/data/onboarding_store.dart';
import 'package:ai_diary/features/streak/streak_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_ai.dart';

const _user = '11111111-2222-3333-4444-555555555555';

JournalEntry _entry(String id, {int version = 1, String body = 'Một ngày.'}) {
  final at = DateTime.now();
  return JournalEntry(
    id: id,
    createdAt: at,
    updatedAt: at,
    bodyVersion: version,
    content: JournalContent(body: body),
  );
}

SavedAnalysis _local(String entryId, {int version = 1}) => SavedAnalysis(
      entryId: entryId,
      bodyVersion: version,
      savedAt: DateTime(2026, 10, 20),
      analysis: AiAnalysis.fromJson(Map.of(FakeAi.reflection)),
    );

/// A list of entries with the ids given (e.g. server ones, "cloud-7").
class _Journals extends InMemoryJournalRepository {
  _Journals(this.fixed);

  final List<JournalEntry> fixed;

  @override
  Future<List<JournalEntry>> entries() async => fixed;
}

Future<void> _pump(WidgetTester tester, Widget home, FakeAi ai,
    {List<JournalEntry> entries = const [], bool aiOn = true}) async {
  final onboarding = await OnboardingStore.open(userId: _user);
  if (!aiOn) await onboarding.saveAiInApp(false);
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(412, 915);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(AiRemoteScope(
    service: ai.service,
    child: OnboardingScope(
      store: onboarding,
      child: JournalScope(
        repository: _Journals(entries),
        child: MaterialApp(theme: AppTheme.light, home: home),
      ),
    ),
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    StreakState.shared.reset();
    CloudAnalysisSync.reset();
  });

  group('B1: a server journal is analysed on the server', () {
    testWidgets(
        'after saving: POST /journals/{n}/analysis, kept as the '
        'account\'s, not /ai/reflection', (tester) async {
      final ai = FakeAi();
      final entry = _entry('cloud-7');
      await _pump(
          tester,
          AiReflectionScreen(
              journalContent: entry.body, remote: ai.service, entry: entry),
          ai);
      await tester.pump(const Duration(seconds: 1));
      expect(ai.analyzed, [7]);
      expect(ai.reflectionSent, isEmpty);
      expect(find.text('Nhẹ nhõm'), findsOneWidget);
      final kept = (await AnalysisArchive.open(userId: _user)).of('cloud-7');
      expect(kept?.cloud, isTrue);
      expect(kept?.analysis.moodScore, 80);
    });

    testWidgets(
        'an entry kept on the device only: /ai/reflection, kept here '
        'only', (tester) async {
      final ai = FakeAi();
      final entry = _entry('local-3');
      await _pump(
          tester,
          AiReflectionScreen(
              journalContent: entry.body, remote: ai.service, entry: entry),
          ai);
      await tester.pump(const Duration(seconds: 1));
      expect(ai.analyzed, isEmpty);
      expect(ai.reflectionSent, hasLength(1));
      final kept = (await AnalysisArchive.open(userId: _user)).of('local-3');
      expect(kept?.cloud, isFalse);
    });

    testWidgets('the quota reached: says so', (tester) async {
      final ai = FakeAi()
        ..failPath = '/journals/7/analysis'
        ..failStatus = 429;
      final entry = _entry('cloud-7');
      await _pump(
          tester,
          AiReflectionScreen(
              journalContent: entry.body, remote: ai.service, entry: entry),
          ai);
      await tester.pump(const Duration(seconds: 1));
      expect(find.text(AIReflectionScreen.quotaFailed), findsOneWidget);
    });
  });

  group('Reading again', () {
    testWidgets(
        'opening a server entry reads its analysis (GET only), '
        'never asks for a new one', (tester) async {
      final ai = FakeAi();
      ai.serverAnalyses[7] = ai.analysisRead(7, feedback: 'up');
      await _pump(tester, WriteJournalScreen(entry: _entry('cloud-7')), ai);
      await tester.pump(const Duration(milliseconds: 300));
      expect(ai.requests, contains('GET /journals/7/analysis'));
      expect(ai.analyzed, isEmpty);
      expect(find.text(WriteJournalScreen.reviewLabel), findsOneWidget);
      expect(find.text(WriteJournalScreen.analyzeToAccountLabel), findsNothing);

      // B3: the rating given before shows, and a tap goes to the server.
      await tester.tap(find.text(WriteJournalScreen.reviewLabel));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      final up = find
          .byWidgetPredicate((w) => w is IconButton && w.tooltip == 'Hữu ích');
      expect(tester.widget<IconButton>(up).isSelected, isTrue);
      expect(find.text(AIReflectionScreen.deviceOnly), findsNothing);
      await tester.tap(find.byTooltip('Chưa hữu ích'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(ai.requests, contains('PUT /journals/7/analysis/feedback'));
      expect(ai.serverAnalyses[7]!['feedback'], 'down');
    });

    testWidgets(
        'a device-only analysis of a server entry: kept and shown, '
        'said to be on this device, an explicit way to the account',
        (tester) async {
      final ai = FakeAi();
      await (await AnalysisArchive.open(userId: _user)).save(_local('cloud-7'));
      await _pump(tester, WriteJournalScreen(entry: _entry('cloud-7')), ai);
      await tester.pump(const Duration(milliseconds: 300));
      expect(ai.analyzed, isEmpty, reason: 'never by itself');
      expect(find.text(WriteJournalScreen.reviewLabel), findsOneWidget);
      expect(
          find.text(WriteJournalScreen.analyzeToAccountLabel), findsOneWidget);
      await tester.tap(find.text(WriteJournalScreen.reviewLabel));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text(AIReflectionScreen.deviceOnly), findsOneWidget);
    });

    testWidgets(
        'with AI off: the analysis still reads, but nothing new is '
        'offered', (tester) async {
      final ai = FakeAi();
      await (await AnalysisArchive.open(userId: _user)).save(_local('cloud-7'));
      await _pump(tester, WriteJournalScreen(entry: _entry('cloud-7')), ai,
          aiOn: false);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text(WriteJournalScreen.reviewLabel), findsOneWidget);
      expect(find.text(WriteJournalScreen.analyzeToAccountLabel), findsNothing);
      expect(ai.analyzed, isEmpty);
    });

    testWidgets('edited since the analysis: "Phân tích bản đã sửa"',
        (tester) async {
      final ai = FakeAi();
      ai.serverAnalyses[7] = ai.analysisRead(7, bodyVersion: 1);
      await _pump(
          tester, WriteJournalScreen(entry: _entry('cloud-7', version: 2)), ai);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text(WriteJournalScreen.analyzeEditedLabel), findsOneWidget);
    });
  });

  group('Sync from the server', () {
    test('brings the account\'s analyses, never runs or uploads any', () async {
      final ai = FakeAi();
      ai.serverAnalyses[7] = ai.analysisRead(7);
      final archive = await AnalysisArchive.open(userId: _user);
      await archive.save(_local('local-1'));
      await CloudAnalysisSync.sync(CloudAiApi(ai.client), userId: _user);
      expect(archive.of('cloud-7')?.cloud, isTrue);
      expect(archive.of('local-1')?.cloud, isFalse, reason: 'left as it was');
      expect(ai.requests.where((r) => !r.startsWith('GET')), isEmpty);
    });

    test('a newer device analysis is not overwritten by an older one',
        () async {
      final ai = FakeAi();
      ai.serverAnalyses[7] = ai.analysisRead(7, bodyVersion: 1);
      final archive = await AnalysisArchive.open(userId: _user);
      await archive.save(_local('cloud-7', version: 2));
      await CloudAnalysisSync.sync(CloudAiApi(ai.client), userId: _user);
      expect(archive.of('cloud-7')?.bodyVersion, 2);
      expect(archive.of('cloud-7')?.cloud, isFalse);
    });
  });

  group('B2: saved quotes on the account', () {
    test('saved and let go on the server; kept here before stays here only',
        () async {
      final ai = FakeAi();
      final quotes =
          await SavedQuotes.open(userId: _user, cloud: CloudAiApi(ai.client));
      // One from before the account sync: never sent up by itself.
      final device = await SavedQuotes.open(userId: _user);
      await device.save('Câu cũ.', 'Tác giả cũ');
      expect(ai.serverQuotes, isEmpty);

      await quotes.save('Câu mới.', 'Tác giả mới');
      expect(ai.serverQuotes.single['text'], 'Câu mới.');
      expect(
          quotes.all().firstWhere((q) => q.text == 'Câu mới.').id, isNotNull);

      // Kept on another phone: there after a refresh.
      ai.serverQuotes.add({
        'id': '22222222-0000-0000-0000-000000000001',
        'text': 'Từ máy khác.',
        'author': 'Tác giả B',
        'source': null,
        'saved_at': '2026-10-28T08:00:00Z',
      });
      await quotes.refresh();
      expect([for (final q in quotes.all()) q.text],
          containsAll(['Câu mới.', 'Từ máy khác.', 'Câu cũ.']));
      expect(savedThisWeekItems.value.where((i) => i['type'] == 'quote'),
          hasLength(3));

      await quotes.remove('Câu mới.');
      expect(
          ai.serverQuotes.map((q) => q['text']), isNot(contains('Câu mới.')));
      await quotes.remove('Câu cũ.');
      expect(ai.requests.where((r) => r.startsWith('DELETE')), hasLength(1),
          reason: 'the device-only one is let go here only');
    });

    test('a guest keeps quotes on the device only', () async {
      final quotes = await SavedQuotes.open(userId: 'local-guest');
      await quotes.save('Câu.', 'Tác giả');
      expect(quotes.all().single.id, isNull);
    });
  });

  group('D: the week from the server', () {
    testWidgets('scores from the server; the AI writes only on a tap',
        (tester) async {
      final ai = FakeAi();
      final today = DateTime.now();
      final monday = DateTime(today.year, today.month, today.day)
          .subtract(Duration(days: today.weekday - 1));
      String day(int i) {
        final d = monday.add(Duration(days: i));
        return '${d.year}-${d.month.toString().padLeft(2, '0')}-'
            '${d.day.toString().padLeft(2, '0')}';
      }

      ai.week = {
        'days': [
          for (var i = 0; i < 7; i++)
            {
              'date': day(i),
              'journal_count': i == today.weekday - 1 ? 1 : 0,
              'analyzed_count': i == today.weekday - 1 ? 1 : 0,
              'score': i == today.weekday - 1 ? 64.0 : null,
            },
        ],
        'top_emotions': [
          {'mood_group': 'mixed', 'count': 2},
        ],
      };
      await _pump(tester, const EmotionWeekScreen(), ai,
          entries: [_entry('cloud-7')]);
      await tester.pumpAndSettle();
      expect(find.text('64'), findsOneWidget, reason: 'the server\'s score');
      expect(ai.requests.where((r) => r.contains('generate_summary=true')),
          isEmpty);
      await tester.scrollUntilVisible(
          find.text(EmotionWeekScreen.summaryButton), 200,
          scrollable: find.byType(Scrollable).first);
      expect(find.text('Lẫn lộn'), findsOneWidget,
          reason: 'mixed, as the server counts it');
      expect(find.text(EmotionWeekScreen.summaryNote), findsOneWidget);

      await tester.ensureVisible(find.text(EmotionWeekScreen.summaryButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text(EmotionWeekScreen.summaryButton));
      await tester.pump();
      await tester.pumpAndSettle();
      expect(ai.requests.where((r) => r.contains('generate_summary=true')),
          hasLength(1));
      expect(find.text(ai.weekSummary), findsOneWidget);
      expect(find.text(EmotionWeekScreen.summaryBy), findsOneWidget);
    });

    testWidgets('AI off: no way to have the week written', (tester) async {
      final ai = FakeAi();
      await _pump(tester, const EmotionWeekScreen(), ai,
          entries: [_entry('cloud-7')], aiOn: false);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
          find.text(EmotionWeekScreen.summaryAiOff), 200,
          scrollable: find.byType(Scrollable).first);
      expect(find.text(EmotionWeekScreen.summaryButton), findsNothing);
      expect(ai.requests.where((r) => r.contains('generate_summary=true')),
          isEmpty);
    });
  });
}
