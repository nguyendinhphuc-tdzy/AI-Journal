import 'package:ai_diary/core/theme/app_theme.dart';
import 'package:ai_diary/features/onboarding/data/onboarding_scope.dart';
import 'package:ai_diary/features/onboarding/data/onboarding_store.dart';
import 'package:ai_diary/features/onboarding/presentation/onboarding_reminder_screen.dart';
import 'package:ai_diary/features/profile/profile_screen.dart';
import 'package:ai_diary/features/reminders/data/reminder_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Finder get _row => find.byKey(const ValueKey('setting-item-daily reminders'));

Finder _switch(ReminderSlot slot) =>
    find.byType(Switch).at(ReminderSlot.values.indexOf(slot));

Future<OnboardingStore> _pump(
    WidgetTester tester, SimulatedReminderService reminders) async {
  SharedPreferences.setMockInitialValues({});
  final store = await OnboardingStore.open(userId: 'u1');
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(412, 915);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(OnboardingScope(
    store: store,
    child: MaterialApp(
        theme: AppTheme.light, home: ProfileScreen(reminders: reminders)),
  ));
  await tester.pumpAndSettle();
  return store;
}

/// OB10's Nudaeng keeps moving: fixed pumps, long enough for a page
/// transition, instead of settling.
Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  test('Profile says which reminders are set, or that they are off', () {
    expect(ProfileScreen.remindersValue({}), 'Tắt');
    expect(
        ProfileScreen.remindersValue({
          ReminderSlot.evening: const ReminderTime(21, 15),
          ReminderSlot.morning: const ReminderTime(7, 30),
        }),
        '07:30 · 21:15');
  });

  testWidgets('Off at first; set the evening one; it is scheduled and shown',
      (tester) async {
    final reminders = SimulatedReminderService();
    final store = await _pump(tester, reminders);
    expect(find.descendant(of: _row, matching: find.text('Tắt')),
        findsOneWidget);

    await _tap(tester, _row);
    expect(find.text(OnboardingReminderScreen.title), findsOneWidget);
    await _tap(tester, _switch(ReminderSlot.evening));
    await _tap(tester, find.text(OnboardingReminderScreen.saveLabel));

    expect(reminders.prompts, 1, reason: 'asked on save, once');
    expect(reminders.scheduled.keys, [ReminderSlot.evening]);
    expect(store.reminders, {ReminderSlot.evening: const ReminderTime(21, 0)});
    // Back on Hồ sơ, with what is set.
    expect(find.text(OnboardingReminderScreen.title), findsNothing);
    expect(find.descendant(of: _row, matching: find.text('21:00')),
        findsOneWidget);
  });

  testWidgets('Turning both off cancels them; "Để sau" changes nothing',
      (tester) async {
    final reminders =
        SimulatedReminderService(status: NotificationPermission.granted);
    final store = await _pump(tester, reminders);
    await store.saveReminders({ReminderSlot.morning: const ReminderTime(8, 0)});
    await reminders.scheduleDaily(
        ReminderSlot.morning, const ReminderTime(8, 0));

    // Evening on too, then "Để sau": nothing applied.
    await _tap(tester, _row);
    await _tap(tester, _switch(ReminderSlot.evening));
    await _tap(tester, find.text(OnboardingReminderScreen.laterLabel));
    expect(store.reminders.keys, [ReminderSlot.morning]);
    expect(reminders.scheduled.keys, [ReminderSlot.morning]);

    // Both off: "Tiếp tục không nhắc" removes it.
    await _tap(tester, _row);
    await _tap(tester, _switch(ReminderSlot.morning));
    await _tap(tester, find.text(OnboardingReminderScreen.withoutLabel));
    expect(store.reminders, isEmpty);
    expect(reminders.scheduled, isEmpty);
    expect(find.descendant(of: _row, matching: find.text('Tắt')),
        findsOneWidget);
  });
}
