import 'package:ai_diary/core/theme/app_theme.dart';
import 'package:ai_diary/features/journal/data/journal_entry.dart';
import 'package:ai_diary/features/journal/data/journal_repository.dart';
import 'package:ai_diary/features/journal/journal_scope.dart';
import 'package:ai_diary/features/onboarding/data/onboarding_store.dart';
import 'package:ai_diary/features/onboarding/onboarding_flow.dart';
import 'package:ai_diary/features/onboarding/presentation/first_entry_session.dart';
import 'package:ai_diary/features/onboarding/presentation/onboarding_ready_screen.dart';
import 'package:ai_diary/features/reminders/data/reminder_service.dart';
import 'package:ai_diary/main.dart';
import 'package:ai_diary/navigation/app_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef _Ready = OnboardingReadyScreen;

class _Setup {
  _Setup(this.store, this.journals, this.completions);

  final OnboardingStore store;
  final JournalRepository journals;
  final List<void> completions;
}

/// The flow at OB11. [entry]: a saved first entry; [draft]: a kept draft.
Future<_Setup> _pump(
  WidgetTester tester, {
  bool entry = false,
  bool draft = false,
  String? nickname,
  List<String> reminders = const [],
  bool simulated = false,
  Size size = const Size(390, 844),
  double textScale = 1,
}) async {
  final journals = InMemoryJournalRepository();
  final prefs = <String, Object>{
    'onboarding.step': 'ready',
    'onboarding.reminders': reminders,
    if (nickname != null) 'onboarding.nickname': nickname,
  };
  if (entry) {
    final saved =
        await journals.create(const JournalContent(body: 'Hôm nay ổn.'));
    prefs['onboarding.firstEntryId'] = saved.id;
  }
  if (draft) {
    await journals.saveDraft(
        FirstEntrySession.draftKey,
        JournalDraft(
            fields: const {'cause': 'mưa'}, updatedAt: DateTime(2026, 10, 18)));
  }
  SharedPreferences.setMockInitialValues(prefs);
  final store = await OnboardingStore.open();
  final completions = <void>[];
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  tester.view.padding = const FakeViewPadding(top: 47, bottom: 34);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(JournalScope(
    repository: journals,
    child: MaterialApp(
      theme: AppTheme.light,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: OnboardingFlow(
        store: store,
        brandName: 'AI Diary',
        reminders: simulated ? SimulatedReminderService() : _RealReminders(),
        onComplete: () => completions.add(null),
      ),
    ),
  ));
  await tester.pump(const Duration(seconds: 2));
  return _Setup(store, journals, completions);
}

/// Stands in for a real notification service; only [simulated] is read.
class _RealReminders extends SimulatedReminderService {
  @override
  bool get simulated => false;
}

final _mascot = find.byWidgetPredicate((widget) =>
    widget is Image && widget.semanticLabel == 'Nudaeng đang đan áo len');

void main() {
  testWidgets('Copy, paper card, nothing of the pledge', (tester) async {
    await _pump(tester);
    expect(find.text(_Ready.title), findsOneWidget);
    expect(find.text(_Ready.invitation), findsOneWidget);
    expect(find.text('Bước 9/9'), findsOneWidget);
    expect(find.text(_Ready.enterLabel), findsOneWidget);
    expect(find.byType(Checkbox), findsNothing);
    expect(
        find.textContaining(
            RegExp('SIGNED|chữ ký|cam kết|7 ngày', caseSensitive: false)),
        findsNothing);
  });

  // The test font is much wider than the real ones, so a taller screen
  // stands in for the room Nudaeng gets on a phone.
  testWidgets('Nudaeng below the content, above the CTA', (tester) async {
    await _pump(tester,
        entry: true, reminders: ['evening@21:00'], size: const Size(390, 1300));
    expect(_mascot, findsOneWidget);
    final mascot = tester.getRect(_mascot);
    expect(mascot.top,
        greaterThan(tester.getRect(find.text(_Ready.entrySaved)).bottom));
    expect(
        mascot.bottom, lessThan(tester.getRect(find.byType(FilledButton)).top));
  });

  testWidgets('Nickname only as a greeting', (tester) async {
    await _pump(tester, nickname: 'Vy');
    expect(find.text(_Ready.greeting('Vy')), findsOneWidget);
    expect(find.text(_Ready.title), findsOneWidget);
  });

  testWidgets('No nickname: no greeting line', (tester) async {
    await _pump(tester);
    expect(find.textContaining('ơi,'), findsNothing);
  });

  group('Summary follows the real state', () {
    testWidgets('entry saved', (tester) async {
      await _pump(tester, entry: true);
      expect(find.text(_Ready.entrySaved), findsOneWidget);
      expect(find.text(_Ready.draftKept), findsNothing);
      expect(find.text(_Ready.noEntry), findsNothing);
    });

    testWidgets('draft only', (tester) async {
      await _pump(tester, draft: true);
      expect(find.text(_Ready.draftKept), findsOneWidget);
      expect(find.text(_Ready.entrySaved), findsNothing);
      expect(find.text(_Ready.noEntry), findsNothing);
    });

    testWidgets('writing skipped', (tester) async {
      await _pump(tester);
      expect(find.text(_Ready.noEntry), findsOneWidget);
      expect(find.text(_Ready.entrySaved), findsNothing);
      expect(find.text(_Ready.draftKept), findsNothing);
    });

    testWidgets('reminders scheduled: the actual slots and times',
        (tester) async {
      await _pump(tester, reminders: ['morning@07:30', 'evening@21:00']);
      expect(
          find.text('Lời nhắc buổi sáng lúc 07:30 và buổi tối lúc 21:00 '
              'đã được bật.'),
          findsOneWidget);
      expect(find.text(_Ready.remindersLater), findsNothing);
      expect(find.text(_Ready.simulatedNote), findsNothing);
    });

    testWidgets('one reminder', (tester) async {
      await _pump(tester, reminders: ['evening@22:15']);
      expect(find.text('Lời nhắc buổi tối lúc 22:15 đã được bật.'),
          findsOneWidget);
    });

    testWidgets('simulated reminders are labelled so', (tester) async {
      await _pump(tester, reminders: ['morning@08:00'], simulated: true);
      expect(find.text(_Ready.simulatedNote), findsOneWidget);
    });

    testWidgets('reminders skipped or refused: nothing claimed',
        (tester) async {
      await _pump(tester);
      expect(find.text(_Ready.remindersLater), findsOneWidget);
      expect(find.textContaining('đã được bật'), findsNothing);
    });
  });

  testWidgets('Enter: saved as done, then Home; answers and entry kept',
      (tester) async {
    final setup = await _pump(tester, entry: true, nickname: 'Vy', reminders: [
      'evening@21:00',
    ]);
    final entryId = setup.store.firstEntryId;
    await tester.tap(find.text(_Ready.enterLabel));
    await tester.pump();
    expect(setup.store.completed, isTrue);
    expect(setup.completions, hasLength(1));
    expect(setup.store.nickname, 'Vy');
    expect(setup.store.reminders,
        {ReminderSlot.evening: const ReminderTime(21, 0)});
    expect(await setup.journals.entry(entryId!), isNotNull);
  });

  testWidgets('App: Home replaces onboarding, and stays on next launch',
      (tester) async {
    SharedPreferences.setMockInitialValues({'onboarding.step': 'ready'});
    final store = await OnboardingStore.open();
    final journals = InMemoryJournalRepository();
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(AiDiaryApp(journals: journals, onboarding: store));
    await tester.pump(const Duration(seconds: 2));
    await tester.tap(find.text(_Ready.enterLabel));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(AppShell), findsOneWidget);
    expect(find.byType(OnboardingFlow), findsNothing);

    await tester.pumpWidget(const SizedBox());
    final relaunched = await OnboardingStore.open();
    await tester
        .pumpWidget(AiDiaryApp(journals: journals, onboarding: relaunched));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(AppShell), findsOneWidget);
  });

  testWidgets('Draft is kept when entering', (tester) async {
    final setup = await _pump(tester, draft: true);
    await tester.tap(find.text(_Ready.enterLabel));
    await tester.pump();
    expect(await setup.journals.draft(FirstEntrySession.draftKey), isNotNull);
  });

  testWidgets('Back returns to OB10', (tester) async {
    final setup = await _pump(tester);
    await tester.tap(find.byTooltip('Quay lại'));
    await tester.pump();
    expect(setup.store.step, OnboardingStep.reminder);
  });

  group('Saving "done" fails', () {
    Future<List<bool>> pumpScreen(WidgetTester tester,
        {required List<bool> results}) async {
      SharedPreferences.setMockInitialValues({});
      final calls = <bool>[];
      final session = FirstEntrySession(
          journals: InMemoryJournalRepository(),
          store: await OnboardingStore.open());
      addTearDown(session.dispose);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: OnboardingReadyScreen(
          nickname: null,
          session: session,
          reminders: const {},
          remindersSimulated: false,
          onBack: () {},
          onEnter: () async {
            final ok = results[calls.length];
            calls.add(ok);
            return ok;
          },
        ),
      ));
      await tester.pump(const Duration(seconds: 2));
      return calls;
    }

    testWidgets('stays, says so, retry works', (tester) async {
      final calls = await pumpScreen(tester, results: [false, true]);
      await tester.tap(find.text(_Ready.enterLabel));
      await tester.pump();
      expect(find.text(_Ready.enterFailed), findsOneWidget);
      expect(find.text(_Ready.title), findsOneWidget);
      expect(find.text(_Ready.retryLabel), findsOneWidget);

      await tester.tap(find.text(_Ready.retryLabel));
      await tester.pump();
      expect(calls, [false, true]);
    });

    testWidgets('repeated taps while saving ask once', (tester) async {
      final calls = await pumpScreen(tester, results: [true, true]);
      await tester.tap(find.text(_Ready.enterLabel));
      await tester.tap(find.text(_Ready.enterLabel));
      await tester.pump();
      expect(calls, hasLength(1));
    });
  });

  for (final (size, scale) in [
    (const Size(360, 640), 1.0),
    (const Size(390, 844), 1.0),
    (const Size(390, 844), 1.6),
  ]) {
    testWidgets('lays out without overflow: $size × $scale', (tester) async {
      await _pump(tester,
          entry: true,
          draft: true,
          nickname: 'Một biệt danh khá dài',
          reminders: ['morning@08:00', 'evening@21:00'],
          simulated: true,
          size: size,
          textScale: scale);
      expect(tester.takeException(), isNull);
      expect(find.text(_Ready.enterLabel), findsOneWidget);
    });
  }
}
