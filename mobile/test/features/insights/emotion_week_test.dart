import 'package:ai_diary/core/theme/app_theme.dart';
import 'package:ai_diary/features/insights/data/emotion_scale.dart';
import 'package:ai_diary/features/insights/data/emotion_week.dart';
import 'package:ai_diary/features/insights/presentation/emotion_week_screen.dart';
import 'package:ai_diary/features/journal/data/analysis_archive.dart';
import 'package:ai_diary/features/journal/data/api_ai_service.dart';
import 'package:ai_diary/features/journal/data/journal_entry.dart';
import 'package:ai_diary/features/journal/data/journal_repository.dart';
import 'package:ai_diary/features/journal/journal_scope.dart';
import 'package:ai_diary/features/onboarding/data/onboarding_scope.dart';
import 'package:ai_diary/features/onboarding/data/onboarding_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _user = '11111111-2222-3333-4444-555555555555';

JournalEntry _entry(String id, DateTime at) => JournalEntry(
      id: id,
      createdAt: at,
      updatedAt: at,
      bodyVersion: 1,
      content: JournalContent(body: 'bài $id'),
    );

SavedAnalysis _analysis(String entryId, String emotion, DateTime at) =>
    SavedAnalysis(
      entryId: entryId,
      bodyVersion: 1,
      savedAt: at,
      analysis: AiAnalysis(
        emotion: emotion,
        observation: 'nhận xét cho $entryId.',
        reflection: 'góc nhìn.',
        question: 'câu hỏi?',
      ),
    );

void main() {
  group('Sorting the AI\'s words into groups', () {
    test('a plain feeling', () {
      expect(groupsOf('Thất vọng').map((g) => g.id), ['sad']);
      expect(groupsOf('Bình yên').map((g) => g.id), ['calm']);
      expect(scoreOf('Vui'), 90);
    });

    test('a mixed feeling counts both, its score between them', () {
      expect(groupsOf('Nặng nề nhưng tìm thấy sự dịu nhẹ').map((g) => g.id),
          ['calm', 'tired']);
      expect(scoreOf('Nặng nề nhưng tìm thấy sự dịu nhẹ'), 60);
    });

    test('"không vui" is not joy; unknown words have no score', () {
      expect(groupsOf('không vui').map((g) => g.id), isNot(contains('joy')));
      expect(scoreOf('xyz'), isNull);
    });

    test('every group\'s score is on the 0–100 line', () {
      for (final group in emotionGroups) {
        expect(group.score, inInclusiveRange(0, 100));
        expect(group.words, isNotEmpty);
      }
    });
  });

  group('A week', () {
    // Wednesday 28/10/2026: the week is 26/10 (Monday) to 01/11.
    final wednesday = DateTime(2026, 10, 28, 10);

    test('Monday to Sunday, entries and analyses by day', () {
      final entries = [
        _entry('a', DateTime(2026, 10, 26, 9)),
        _entry('b', DateTime(2026, 10, 28, 9)),
        _entry('c', DateTime(2026, 10, 28, 21)),
        _entry('old', DateTime(2026, 10, 19, 9)),
      ];
      final week = EmotionWeek.of(wednesday, entries, {
        'a': _analysis('a', 'Vui', DateTime(2026, 10, 26, 9)),
        'b': _analysis('b', 'Buồn', DateTime(2026, 10, 28, 9)),
        'c': _analysis('c', 'Bình yên', DateTime(2026, 10, 28, 21)),
        'gone': _analysis('gone', 'Vui', DateTime(2026, 10, 27)),
      });
      expect(week.monday, DateTime(2026, 10, 26));
      expect(week.sunday, DateTime(2026, 11, 1));
      expect(week.entries, 3, reason: 'not last week');
      expect(week.analysed, 3, reason: 'not an analysis without its entry');
      expect(week.days[0].score, 90);
      expect(week.days[1].score, isNull);
      expect(week.days[2].entries, 2);
      expect(week.days[2].score, (25 + 80) / 2);
      expect(week.days[2].emotions, ['Bình yên', 'Buồn'],
          reason: 'latest first');
      expect(week.standout.first.group.id, 'joy',
          reason: 'one each: the lighter first');
    });

    test('an entry without an analysis counts, with no score', () {
      final week = EmotionWeek.of(
          wednesday, [_entry('a', DateTime(2026, 10, 27, 9))], const {});
      expect(week.days[1].entries, 1);
      expect(week.days[1].score, isNull);
      expect(week.standout, isEmpty);
    });
  });

  group('The screen', () {
    late InMemoryJournalRepository journals;

    Future<void> pump(WidgetTester tester,
        {Size size = const Size(390, 844), double scale = 1}) async {
      final onboarding = await OnboardingStore.open(userId: _user);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(OnboardingScope(
        store: onboarding,
        child: JournalScope(
          repository: journals,
          child: MaterialApp(
            theme: AppTheme.light,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: const EmotionWeekScreen(),
          ),
        ),
      ));
      await tester.pumpAndSettle();
    }

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      journals = InMemoryJournalRepository();
    });

    Future<JournalEntry> write(String emotion) async {
      final entry = await journals.create(JournalContent(body: emotion));
      await (await AnalysisArchive.open(userId: _user)).save(
          _analysis(entry.id, emotion, DateTime.now()));
      return entry;
    }

    testWidgets('today\'s score, feelings, standout, the AI note',
        (tester) async {
      await write('Thất vọng');
      await write('Bình yên');
      await pump(tester);
      expect(find.text(EmotionWeekScreen.title), findsOneWidget);
      expect(find.text('53'), findsOneWidget, reason: '(25 + 80) / 2');
      expect(find.textContaining('(2 bài)'), findsOneWidget);
      expect(find.text('Thất vọng'), findsOneWidget);
      expect(find.text('Bình yên'), findsOneWidget);
      await tester.scrollUntilVisible(
          find.text(EmotionWeekScreen.aiNote), 200,
          scrollable: find.byType(Scrollable).first);
      expect(find.text(EmotionWeekScreen.standoutTitle), findsOneWidget);
      expect(find.text('Buồn'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('tap another day: its own details', (tester) async {
      await write('Vui');
      await pump(tester);
      final today = DateTime.now().weekday - 1;
      final other = today == 0 ? 1 : 0;
      await tester.tap(find.bySemanticsLabel(
          EmotionWeekScreen.weekdayNames[other]));
      await tester.pump();
      expect(find.text(EmotionWeekScreen.dayEmpty), findsOneWidget);
      await tester.tap(find.bySemanticsLabel(
          EmotionWeekScreen.weekdayNames[today]));
      await tester.pump();
      expect(find.text('90'), findsOneWidget);
    });

    testWidgets('nothing written this week, and last week', (tester) async {
      await pump(tester);
      expect(find.text(EmotionWeekScreen.noEntries), findsOneWidget);
      await tester.tap(find.byTooltip('Tuần trước'));
      await tester.pump();
      expect(find.text(EmotionWeekScreen.noEntries), findsOneWidget);
      expect(find.textContaining('Tuần này ·'), findsNothing);
    });

    testWidgets('written but not analysed: says so, never a made-up score',
        (tester) async {
      await journals.create(const JournalContent(body: 'không có AI'));
      await pump(tester);
      expect(find.text(EmotionWeekScreen.dayNotAnalysed), findsOneWidget);
      expect(find.text('–'), findsOneWidget);
      await tester.scrollUntilVisible(
          find.text(EmotionWeekScreen.noAnalyses), 200,
          scrollable: find.byType(Scrollable).first);
    });

    for (final size in const [Size(320, 568), Size(844, 390)]) {
      for (final scale in const [1.0, 2.0]) {
        testWidgets('fits $size at text scale $scale', (tester) async {
          await write('Nặng nề nhưng tìm thấy sự dịu nhẹ');
          await write('Lo lắng');
          await pump(tester, size: size, scale: scale);
          expect(tester.takeException(), isNull);
        });
      }
    }
  });
}
