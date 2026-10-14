import 'package:ai_diary/main.dart';
import 'package:ai_diary/features/home/presentation/home_screen.dart';
import 'package:ai_diary/features/journal/presentation/write_journal_screen.dart';
import 'package:ai_diary/features/journal/presentation/ai_reflection_screen.dart';
import 'package:ai_diary/features/streak/streak_screen.dart';
import 'package:ai_diary/features/streak/streak_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final size in [const Size(320, 640), const Size(640, 320)]) {
    for (final action in ['Finish', '✨ Go Deeper']) {
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
        await tester.tap(find.text('Reflect ➔'));
        await tester.pumpAndSettle();
        expect(find.byType(WriteJournalScreen), findsOneWidget);
        await tester.enterText(find.byType(TextField), 'A quiet moment today.');
        await tester.tap(find.text(action));
        await tester.pumpAndSettle();
        expect(
            tester
                .widget<AiReflectionScreen>(find.byType(AiReflectionScreen))
                .journalContent,
            'A quiet moment today.');

        // Pushing reflection preserves the editor and its draft on Back.
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(
            tester.widget<TextField>(find.byType(TextField)).controller!.text,
            'A quiet moment today.');
        await tester.tap(find.text(action));
        await tester.pumpAndSettle();
        await tester.pump(const Duration(seconds: 3));
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();
        expect(find.byType(StreakScreen), findsOneWidget);
        expect(ModalRoute.of(tester.element(find.byType(StreakScreen))),
            isA<PageRouteBuilder<void>>());
        expect(find.text('$expectedStreak day streak'), findsOneWidget);
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();
        expect(tester.element(find.byType(HomeScreen)), same(originalHome));
        expect(find.text('$expectedStreak day streak'), findsOneWidget);
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
