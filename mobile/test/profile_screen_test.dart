import 'package:ai_diary/core/theme/app_theme.dart';
import 'package:ai_diary/features/home/presentation/home_screen.dart';
import 'package:ai_diary/features/profile/profile_screen.dart';
import 'package:ai_diary/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ai_diary/features/onboarding/data/onboarding_store.dart';
import 'package:ai_diary/features/onboarding/data/journal_goal.dart';
import 'package:ai_diary/features/onboarding/data/journaling_experience.dart';
import 'package:ai_diary/features/reminders/data/reminder_service.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
      'Home settings read saved onboarding answers without changing them',
      (tester) async {
    final store = await OnboardingStore.open();
    await store.saveNickname('Trâm');
    await store.saveGoal(JournalGoal.sortThoughts);
    await store.saveExperience(JournalingExperience.occasional);
    await store.saveAiChoice(enabled: false);
    await store.saveReminders({
      ReminderSlot.morning: const ReminderTime(7, 30),
      ReminderSlot.evening: const ReminderTime(21, 15),
    });
    await store.complete();
    await tester.pumpWidget(const AiDiaryApp());
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Ảnh đại diện hồ sơ'));
    await tester.pumpAndSettle();
    expect(find.text('Trâm'), findsOneWidget);
    expect(find.text(JournalGoal.sortThoughts.label), findsOneWidget);
    // Writing experience and the AI choice are onboarding answers only.
    expect(find.text(JournalingExperience.occasional.label), findsNothing);
    final scrollable = find.descendant(
        of: find.byType(ProfileScreen), matching: find.byType(Scrollable));
    await tester.scrollUntilVisible(find.text('Biểu tượng ứng dụng'), 100,
        scrollable: scrollable);
    expect(find.text('Đã chọn không dùng AI'), findsNothing);
    // Settings that open nothing yet are not listed.
    for (final gone in [
      'Gói Nudaeng Plus',
      'Nhắc nhở mỗi ngày',
      'Ngôn ngữ',
      'Bảo mật',
      'Thông tin',
      'Biểu tượng đặc biệt',
    ]) {
      expect(find.text(gone, skipOffstage: false), findsNothing);
    }
    await tester.tap(find.byTooltip('Đóng'));
    await tester.pumpAndSettle();
    expect(store.completed, isTrue);
    expect(store.nickname, 'Trâm');
    expect(store.aiEnabled, isFalse);
    expect(store.reminders, hasLength(2));
  });

  testWidgets('Skipped onboarding answers have explicit empty states',
      (tester) async {
    final store = await OnboardingStore.open();
    await store.saveExperience(JournalingExperience.unknown);
    await tester.pumpWidget(const MaterialApp(home: ProfileScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Chưa đặt biệt danh'), findsOneWidget);
    expect(find.text('Chưa chọn mục tiêu'), findsOneWidget);
    for (final removed in [
      'Trải nghiệm viết nhật ký',
      'AI Chiêm nghiệm',
      'Nền giấy',
    ]) {
      expect(find.text(removed), findsNothing);
    }

    expect(store.aiEnabled, isNull);
    expect(store.completed, isFalse);
  });

  testWidgets('Lists stop at their ends: no stretch, no bounce',
      (tester) async {
    await tester.pumpWidget(const AiDiaryApp());
    await tester.pumpAndSettle();
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.scrollBehavior, isA<AppScrollBehavior>());
    final context = tester.element(find.byType(HomeScreen));
    expect(app.scrollBehavior!.getScrollPhysics(context),
        isA<ClampingScrollPhysics>());
    expect(find.byType(StretchingOverscrollIndicator), findsNothing);
    expect(find.byType(GlowingOverscrollIndicator), findsNothing);
  });

  for (final size in [
    const Size(412, 915),
    const Size(320, 640),
    const Size(640, 320),
  ]) {
    testWidgets('Profile opens, previews settings, and returns Home at $size',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(const AiDiaryApp());
      await tester.pumpAndSettle();
      final originalHome = tester.element(find.byType(HomeScreen));
      await tester.tap(find.bySemanticsLabel('Ảnh đại diện hồ sơ'));
      await tester.pumpAndSettle();
      expect(find.byType(ProfileScreen), findsOneWidget);
      expect(find.text('Hồ sơ'), findsOneWidget);
      expect(find.text('Cài đặt chung'), findsOneWidget);
      // Left-aligned rows in a card, as elsewhere in the app: every name
      // starts at one edge, after its icon, in the left half.
      final nameLeft = tester.getTopLeft(find.text('Bạn bè gọi bạn là gì?')).dx;
      expect(
          nameLeft, lessThan(tester.getCenter(find.byType(ProfileScreen)).dx));
      expect(tester.getTopLeft(find.text('Chọn con đường truyền cảm hứng')).dx,
          closeTo(nameLeft, .01));
      expect(tester.takeException(), isNull);
      final scrollable = find.descendant(
          of: find.byType(ProfileScreen), matching: find.byType(Scrollable));
      await tester.scrollUntilVisible(
          find.byKey(const ValueKey('app-icon-1')), 150,
          scrollable: scrollable);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('app-icon-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('app-icon-1')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('selected-icon-dot')), findsOneWidget);
      expect(
          tester.getCenter(find.byKey(const ValueKey('selected-icon-dot'))).dx,
          tester.getCenter(find.byKey(const ValueKey('app-icon-1'))).dx);
      // Three Nudaeng icons, named for screen readers; no fourth.
      expect(find.byKey(const ValueKey('app-icon-2')), findsOneWidget);
      expect(find.byKey(const ValueKey('app-icon-3')), findsNothing);
      expect(find.bySemanticsLabel('Nudaeng bình yên'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Đóng'));
      await tester.pumpAndSettle();
      expect(tester.element(find.byType(HomeScreen)), same(originalHome));
      expect(find.byType(ProfileScreen), findsNothing);
    });
  }
}
