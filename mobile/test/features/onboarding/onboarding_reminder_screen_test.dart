import 'package:ai_diary/core/theme/app_theme.dart';
import 'package:ai_diary/features/journal/data/journal_repository.dart';
import 'package:ai_diary/features/journal/journal_scope.dart';
import 'package:ai_diary/features/onboarding/data/onboarding_store.dart';
import 'package:ai_diary/features/onboarding/onboarding_flow.dart';
import 'package:ai_diary/features/onboarding/presentation/onboarding_reminder_screen.dart';
import 'package:ai_diary/features/reminders/data/reminder_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 18/10/2026 09:30, local.
final _now = DateTime(2026, 10, 18, 9, 30);

Future<OnboardingStore> _pump(
  WidgetTester tester,
  SimulatedReminderService service, {
  Size size = const Size(390, 844),
  double textScale = 1,
  Map<String, Object> prefs = const {},
}) async {
  SharedPreferences.setMockInitialValues(
      {'onboarding.step': 'reminder', ...prefs});
  final store = await OnboardingStore.open();
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  tester.view.padding = const FakeViewPadding(top: 47, bottom: 34);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(JournalScope(
    repository: InMemoryJournalRepository(),
    child: MaterialApp(
      theme: AppTheme.light,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: OnboardingFlow(
          store: store, brandName: 'AI Diary', reminders: service),
    ),
  ));
  await tester.pump(const Duration(seconds: 2));
  return store;
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

Finder _switch(ReminderSlot slot) =>
    find.byType(Switch).at(ReminderSlot.values.indexOf(slot));

final _mascot = find.byWidgetPredicate((widget) =>
    widget is Image && widget.semanticLabel == 'Nudaeng cầm bóng bay');

Future<void> _toggle(WidgetTester tester, ReminderSlot slot) async {
  await tester.ensureVisible(_switch(slot));
  await tester.tap(_switch(slot));
  await _settle(tester);
}

Future<void> _tapText(WidgetTester tester, String text) async {
  await tester.tap(find.text(text));
  await _settle(tester);
}

SimulatedReminderService _service({
  NotificationPermission status = NotificationPermission.notDetermined,
  NotificationPermission answer = NotificationPermission.granted,
  Set<ReminderSlot>? failing,
}) =>
    SimulatedReminderService(
        status: status, answer: answer, failing: failing, clock: () => _now);

void main() {
  group('ReminderTime', () {
    test('daily start: today if still ahead, otherwise tomorrow', () {
      expect(const ReminderTime(21, 0).nextAfter(_now),
          DateTime(2026, 10, 18, 21));
      expect(
          const ReminderTime(8, 0).nextAfter(_now), DateTime(2026, 10, 19, 8));
      expect(const ReminderTime(9, 30).nextAfter(_now),
          DateTime(2026, 10, 19, 9, 30),
          reason: 'the exact minute has passed');
      expect(const ReminderTime(8, 0).nextAfter(DateTime(2026, 12, 31, 23)),
          DateTime(2027, 1, 1, 8));
    });

    test('label and parse round-trip', () {
      expect(const ReminderTime(8, 5).label, '08:05');
      expect(ReminderTime.tryParse('21:00'), const ReminderTime(21, 0));
      expect(ReminderTime.tryParse('24:00'), isNull);
      expect(ReminderTime.tryParse('8'), isNull);
    });

    test('slot ids are stable', () {
      expect(ReminderSlot.morning.id, 1001);
      expect(ReminderSlot.evening.id, 1002);
    });
  });

  testWidgets('defaults: both off at 08:00 and 21:00, continue without',
      (tester) async {
    final service = _service();
    await _pump(tester, service);
    expect(find.text(OnboardingReminderScreen.title), findsOneWidget);
    expect(find.text(OnboardingReminderScreen.helper), findsOneWidget);
    expect(find.text('Buổi sáng'), findsOneWidget);
    expect(find.text('Buổi tối'), findsOneWidget);
    expect(find.text('08:00'), findsOneWidget);
    expect(find.text('21:00'), findsOneWidget);
    expect(find.text('Bước 8/9'), findsOneWidget);
    for (final slot in ReminderSlot.values) {
      expect(tester.widget<Switch>(_switch(slot)).value, isFalse);
    }
    expect(find.text(OnboardingReminderScreen.withoutLabel), findsOneWidget);
    expect(find.text(OnboardingReminderScreen.laterLabel), findsNothing);
  });

  // Real fonts fit Nudaeng and the balloons on 390×844 (checked on rendered
  // shots); the test font is much wider, so a taller screen stands in.
  testWidgets('Nudaeng with balloons: whole, below the cards, or hidden',
      (tester) async {
    await _pump(tester, _service(), size: const Size(390, 1300));
    expect(_mascot, findsOneWidget);
    final cards = tester.getRect(find.text('Buổi tối'));
    final mascot = tester.getRect(_mascot);
    expect(mascot.top, greaterThan(cards.bottom),
        reason: 'the balloons never draw over the content');
    expect(mascot.bottom,
        lessThan(tester.getRect(find.byType(FilledButton)).top));
  });

  testWidgets('no room for the balloons: Nudaeng hides, never shrinks',
      (tester) async {
    await _pump(tester, _service(), size: const Size(390, 700));
    expect(_mascot, findsNothing);
  });

  testWidgets('toggles only change the draft; no prompt until saving',
      (tester) async {
    final service = _service();
    await _pump(tester, service);
    await _toggle(tester, ReminderSlot.evening);
    expect(find.text(OnboardingReminderScreen.saveLabel), findsOneWidget);
    expect(find.text(OnboardingReminderScreen.laterLabel), findsOneWidget);
    await _toggle(tester, ReminderSlot.evening);
    expect(find.text(OnboardingReminderScreen.withoutLabel), findsOneWidget);
    expect(service.prompts, 0);
    expect(service.scheduled, isEmpty);
  });

  testWidgets('save: asks once, schedules the chosen slot from its next time',
      (tester) async {
    final service = _service();
    final store = await _pump(tester, service);
    await _toggle(tester, ReminderSlot.morning);
    await _tapText(tester, OnboardingReminderScreen.saveLabel);

    expect(service.prompts, 1);
    expect(service.scheduled.keys, [ReminderSlot.morning]);
    final morning = service.scheduled[ReminderSlot.morning]!;
    expect(morning.time, const ReminderTime(8, 0));
    expect(morning.firstAt, DateTime(2026, 10, 19, 8));
    expect(store.reminders, {ReminderSlot.morning: const ReminderTime(8, 0)});
    expect(store.step, OnboardingStep.ready);
    expect(find.text(OnboardingReminderScreen.simulatedNote), findsOneWidget,
        reason: 'the stand-in says no real notification will come');
  });

  testWidgets('time picker changes the draft only', (tester) async {
    final service = _service();
    final store = await _pump(tester, service);
    await _tapText(tester, '21:00');
    expect(find.text('Giờ nhắc buổi tối'), findsOneWidget);
    // Opens ready to type, with the dial one tap away.
    expect(find.byIcon(Icons.access_time), findsOneWidget);
    final fields = find.byType(TextField);
    await tester.enterText(fields.first, '22');
    await tester.enterText(fields.last, '15');
    await _tapText(tester, 'Chọn');

    expect(find.text('22:15'), findsOneWidget);
    expect(tester.widget<Switch>(_switch(ReminderSlot.evening)).value, isFalse);
    expect(service.prompts, 0);
    expect(service.scheduled, isEmpty);

    await _toggle(tester, ReminderSlot.evening);
    await _tapText(tester, OnboardingReminderScreen.saveLabel);
    expect(store.reminders, {ReminderSlot.evening: const ReminderTime(22, 15)});
  });

  testWidgets('"Để sau" applies nothing', (tester) async {
    final service = _service();
    final store = await _pump(tester, service);
    await _toggle(tester, ReminderSlot.morning);
    await _tapText(tester, OnboardingReminderScreen.laterLabel);
    expect(service.prompts, 0);
    expect(service.scheduled, isEmpty);
    expect(store.reminders, isEmpty);
    expect(store.step, OnboardingStep.ready);
  });

  testWidgets('both off: continues without and removes saved reminders',
      (tester) async {
    final service = _service(status: NotificationPermission.granted);
    await service.scheduleDaily(
        ReminderSlot.evening, const ReminderTime(21, 0));
    final store = await _pump(tester, service, prefs: {
      'onboarding.reminders': <String>['evening@21:00']
    });
    expect(tester.widget<Switch>(_switch(ReminderSlot.evening)).value, isTrue,
        reason: 'the draft starts from what was saved');
    await _toggle(tester, ReminderSlot.evening);
    await _tapText(tester, OnboardingReminderScreen.withoutLabel);
    expect(service.scheduled, isEmpty);
    expect(store.reminders, isEmpty);
    expect(store.step, OnboardingStep.ready);
  });

  testWidgets('denied before: no prompt again, offers Settings',
      (tester) async {
    final service = _service(status: NotificationPermission.denied);
    final store = await _pump(tester, service);
    await _toggle(tester, ReminderSlot.morning);
    await _tapText(tester, OnboardingReminderScreen.saveLabel);

    expect(service.prompts, 0);
    expect(find.text(OnboardingReminderScreen.blocked), findsOneWidget);
    expect(find.text(OnboardingReminderScreen.settingsLabel), findsOneWidget);
    await _tapText(tester, OnboardingReminderScreen.settingsLabel);
    expect(service.settingsOpened, 1);
    expect(find.textContaining(OnboardingReminderScreen.settingsFailed),
        findsOneWidget,
        reason: 'the stand-in cannot open Settings and says so');

    await _tapText(tester, OnboardingReminderScreen.continueLabel);
    expect(store.reminders, isEmpty);
    expect(store.step, OnboardingStep.ready);
  });

  testWidgets('prompt refused: message; saving again does not ask again',
      (tester) async {
    final service = _service(answer: NotificationPermission.denied);
    await _pump(tester, service);
    await _toggle(tester, ReminderSlot.evening);
    await _tapText(tester, OnboardingReminderScreen.saveLabel);
    expect(service.prompts, 1);
    expect(find.text(OnboardingReminderScreen.blocked), findsOneWidget);

    // An edit clears the message; saving again only re-checks.
    await _toggle(tester, ReminderSlot.morning);
    expect(find.text(OnboardingReminderScreen.blocked), findsNothing);
    await _tapText(tester, OnboardingReminderScreen.saveLabel);
    expect(service.prompts, 1);
    expect(find.text(OnboardingReminderScreen.blocked), findsOneWidget);
  });

  testWidgets('unavailable: message, no Settings action', (tester) async {
    final service = _service(status: NotificationPermission.unavailable);
    final store = await _pump(tester, service);
    await _toggle(tester, ReminderSlot.morning);
    await _tapText(tester, OnboardingReminderScreen.saveLabel);
    expect(find.text(OnboardingReminderScreen.blocked), findsOneWidget);
    expect(find.text(OnboardingReminderScreen.settingsLabel), findsNothing);
    await _tapText(tester, OnboardingReminderScreen.continueLabel);
    expect(store.step, OnboardingStep.ready);
  });

  testWidgets('partial failure: names the slot; retry or continue',
      (tester) async {
    final service = _service(failing: {ReminderSlot.evening});
    final store = await _pump(tester, service);
    await _toggle(tester, ReminderSlot.morning);
    await _toggle(tester, ReminderSlot.evening);
    await _tapText(tester, OnboardingReminderScreen.saveLabel);

    expect(find.textContaining('Chưa tạo được lời nhắc buổi tối.'),
        findsOneWidget);
    expect(find.textContaining('Lời nhắc buổi sáng lúc 08:00 đã được đặt.'),
        findsOneWidget);
    expect(store.step, OnboardingStep.reminder);

    service.failing.clear();
    await _tapText(tester, OnboardingReminderScreen.retryLabel);
    expect(service.scheduled.keys,
        unorderedEquals([ReminderSlot.morning, ReminderSlot.evening]));
    expect(store.reminders.length, 2);
    expect(store.step, OnboardingStep.ready);
  });

  testWidgets('partial failure: continue records only what was scheduled',
      (tester) async {
    final service = _service(failing: {ReminderSlot.morning});
    final store = await _pump(tester, service);
    await _toggle(tester, ReminderSlot.morning);
    await _toggle(tester, ReminderSlot.evening);
    await _tapText(tester, OnboardingReminderScreen.saveLabel);
    await _tapText(tester, OnboardingReminderScreen.continueLabel);
    expect(store.reminders, {ReminderSlot.evening: const ReminderTime(21, 0)});
    expect(store.step, OnboardingStep.ready);
  });

  testWidgets('Back keeps the draft, unapplied', (tester) async {
    final service = _service();
    final store = await _pump(tester, service);
    await _toggle(tester, ReminderSlot.evening);
    await tester.tap(find.byTooltip('Quay lại'));
    await _settle(tester);
    expect(store.step, OnboardingStep.firstEntry,
        reason: 'no first entry was saved');
    await tester.tap(find.text('Để mình viết sau'));
    await _settle(tester);
    expect(store.step, OnboardingStep.reminder);
    expect(tester.widget<Switch>(_switch(ReminderSlot.evening)).value, isTrue);
    expect(service.scheduled, isEmpty);
    expect(store.reminders, isEmpty);
  });

  for (final (name, size, scale) in [
    ('360 wide', const Size(360, 800), 1.0),
    ('430 wide', const Size(430, 932), 1.0),
    ('large text', const Size(390, 844), 1.6),
  ]) {
    testWidgets('lays out without overflow: $name', (tester) async {
      await _pump(tester, _service(), size: size, textScale: scale);
      await _toggle(tester, ReminderSlot.morning);
      expect(tester.takeException(), isNull);
      expect(find.text(OnboardingReminderScreen.saveLabel), findsOneWidget);
    });
  }
}
