import 'package:shared_preferences/shared_preferences.dart';
import 'package:ai_diary/main.dart';
import 'package:ai_diary/features/home/presentation/home_screen.dart';
import 'package:ai_diary/features/journal/presentation/write_journal_screen.dart';
import 'package:ai_diary/features/journal/presentation/ai_reflection_screen.dart';
import 'package:ai_diary/features/streak/streak_screen.dart';
import 'package:ai_diary/features/streak/streak_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // Each test is a fresh day: yesterday done, today not yet.
    StreakState.shared.reset();
  });
  for (final size in [const Size(320, 640), const Size(640, 320)]) {
    for (final action in ['Lưu nhật ký', 'Nhìn lại cùng bạn']) {
      testWidgets('$action saves, then the streak, at $size',
          (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        await tester.pumpWidget(const AiDiaryApp());
        await tester.pumpAndSettle();
        final originalHome = tester.element(find.byType(HomeScreen));
        final expectedStreak = StreakState.shared.nextCount;
        await tester.ensureVisible(find.text('Viết nhật ký'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Viết nhật ký'));
        await tester.pumpAndSettle();
        expect(find.byType(WriteJournalScreen), findsOneWidget);
        await tester.enterText(find.byType(TextField), 'A quiet moment today.');
        // Going deeper turns on once there is something written.
        await tester.pump();
        if (action != 'Lưu nhật ký') {
          // No account here: no AI question, never a made-up one.
          await tester.tap(find.text(action));
          await tester.pumpAndSettle();
          expect(find.byType(AiReflectionScreen), findsNothing);
          expect(find.text(WriteJournalScreen.deeperNeedsAccount),
              findsOneWidget);
          expect(find.byType(TextField), findsOneWidget);
          expect(
              tester.widget<TextField>(find.byType(TextField)).decoration!
                  .hintText,
              'Bắt đầu viết...');
          ScaffoldMessenger.of(tester.element(find.byType(TextField)))
              .removeCurrentSnackBar();
          await tester.pumpAndSettle();
          await tester.enterText(
              find.byType(TextField), 'School feels overwhelming.');
        }
        await tester.tap(find.text('Lưu nhật ký'));
        await tester.pumpAndSettle();
        expect(find.text('Bạn đã hoàn tất chưa?'), findsOneWidget);
        expect(find.byType(AiReflectionScreen), findsNothing);
        await tester.tap(find.text('Quay lại'));
        await tester.pumpAndSettle();
        expect(find.text('Bạn đã hoàn tất chưa?'), findsNothing);
        await tester.tap(find.text('Lưu nhật ký'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Xác nhận'));
        await tester.pumpAndSettle();
        // AI is off here (no consent, no service): no reflection, never a
        // mock one; the day's first entry still goes to the streak.
        expect(find.byType(AiReflectionScreen), findsNothing);
        expect(find.byType(StreakScreen), findsOneWidget);

        // Pushing the streak preserves the editor and its draft on Quay lại.
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(
            tester.widget<TextField>(find.byType(TextField)).controller!.text,
            action == 'Lưu nhật ký'
                ? 'A quiet moment today.'
                : 'School feels overwhelming.');
        await tester.tap(find.text('Lưu nhật ký'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Xác nhận'));
        await tester.pumpAndSettle();
        expect(find.byType(StreakScreen), findsOneWidget);
        expect(ModalRoute.of(tester.element(find.byType(StreakScreen))),
            isA<PageRouteBuilder<void>>());
        expect(find.text('Bạn đã viết nhật ký $expectedStreak ngày liên tục!'),
            findsOneWidget);
        await tester.tap(find.text('Khám phá tiếp'));
        await tester.pumpAndSettle();
        expect(tester.element(find.byType(HomeScreen)), same(originalHome));
        // Home's streak pill (back at the top of Home): short text, the
        // full words for screen readers.
        await tester.drag(find.byKey(const PageStorageKey('home-scroll')),
            const Offset(0, 2000));
        await tester.pumpAndSettle();
        expect(find.text('$expectedStreak ngày'), findsOneWidget);
        expect(
            find.byType(WriteJournalScreen, skipOffstage: false), findsNothing);
        expect(
            find.byType(AiReflectionScreen, skipOffstage: false), findsNothing);
        expect(find.byType(StreakScreen, skipOffstage: false), findsNothing);
        expect(Navigator.of(tester.element(find.byType(HomeScreen))).canPop(),
            isFalse);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('A second entry the same day goes Home without the streak',
      (tester) async {
    Future<void> writeEntry(String text) async {
      await tester.ensureVisible(find.text('Viết nhật ký'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Viết nhật ký'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), text);
      await tester.tap(find.text('Lưu nhật ký'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xác nhận'));
      await tester.pumpAndSettle();
    }

    await tester.pumpWidget(const AiDiaryApp());
    await tester.pumpAndSettle();
    final home = tester.element(find.byType(HomeScreen));
    final count = StreakState.shared.nextCount;

    await writeEntry('Buổi sáng yên.');
    expect(find.byType(StreakScreen), findsOneWidget);
    await tester.tap(find.text('Khám phá tiếp'));
    await tester.pumpAndSettle();
    expect(StreakState.shared.completedToday, isTrue);

    await writeEntry('Buổi tối cũng ổn.');
    expect(find.byType(StreakScreen, skipOffstage: false), findsNothing);
    expect(tester.element(find.byType(HomeScreen)), same(home));
    expect(find.byType(AiReflectionScreen, skipOffstage: false), findsNothing);
    expect(Navigator.of(home).canPop(), isFalse);
    // Still counted once.
    expect(StreakState.shared.value, count);
    expect(tester.takeException(), isNull);
  });
}
