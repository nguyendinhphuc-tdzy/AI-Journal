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
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final size in [const Size(320, 640), const Size(640, 320)]) {
    for (final action in ['Hoàn tất', '✨ Suy ngẫm sâu hơn']) {
      testWidgets('$action follows full reflection flow at $size',
          (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        await tester.pumpWidget(const AiDiaryApp());
        await tester.pumpAndSettle();
        final originalHome = tester.element(find.byType(HomeScreen));
        final expectedStreak = StreakState.shared.nextCount;
        await tester.tap(find.text('Cùng suy ngẫm ➔'));
        await tester.pumpAndSettle();
        expect(find.byType(WriteJournalScreen), findsOneWidget);
        await tester.enterText(find.byType(TextField), 'A quiet moment today.');
        if (action != 'Hoàn tất') {
          await tester.tap(find.text(action));
          await tester.pumpAndSettle();
          expect(find.byType(AiReflectionScreen), findsNothing);
          expect(find.text('A quiet moment today.'), findsOneWidget);
          expect(find.byType(TextField), findsOneWidget);
          await tester.enterText(
              find.byType(TextField), 'School feels overwhelming.');
        }
        await tester.tap(find.text('Hoàn tất'));
        await tester.pumpAndSettle();
        expect(find.text('Bạn đã hoàn tất chưa?'), findsOneWidget);
        expect(find.byType(AiReflectionScreen), findsNothing);
        await tester.tap(find.text('Quay lại'));
        await tester.pumpAndSettle();
        expect(find.text('Bạn đã hoàn tất chưa?'), findsNothing);
        await tester.tap(find.text('Hoàn tất'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Xác nhận'));
        await tester.pumpAndSettle();
        expect(
            tester
                .widget<AiReflectionScreen>(find.byType(AiReflectionScreen))
                .journalContent,
            action == 'Hoàn tất'
                ? 'A quiet moment today.'
                : 'A quiet moment today.\n\nSchool feels overwhelming.');

        // Pushing reflection preserves the editor and its draft on Quay lại.
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(
            tester.widget<TextField>(find.byType(TextField)).controller!.text,
            action == 'Hoàn tất'
                ? 'A quiet moment today.'
                : 'School feels overwhelming.');
        await tester.tap(find.text('Hoàn tất'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Xác nhận'));
        await tester.pumpAndSettle();
        await tester.pump(const Duration(seconds: 7));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Tiếp tục'));
        await tester.pumpAndSettle();
        expect(find.byType(StreakScreen), findsOneWidget);
        expect(ModalRoute.of(tester.element(find.byType(StreakScreen))),
            isA<PageRouteBuilder<void>>());
        expect(
            find.text('Chuỗi $expectedStreak ngày liên tiếp'), findsOneWidget);
        await tester.tap(find.text('Tiếp tục'));
        await tester.pumpAndSettle();
        expect(tester.element(find.byType(HomeScreen)), same(originalHome));
        expect(find.text('$expectedStreak ngày liên tiếp'), findsOneWidget);
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
}
