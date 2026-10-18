import 'package:ai_diary/core/data/app_data.dart';
import 'package:ai_diary/features/home/presentation/home_screen.dart';
import 'package:ai_diary/features/journal/ai_reflection_screen.dart';
import 'package:ai_diary/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final size in [const Size(320, 640), const Size(640, 320)]) {
    testWidgets('Saved quote updates scrolling Home at $size', (tester) async {
      final originalItems = savedThisWeekItems.value;
      savedThisWeekItems.value = [
        {'type': 'insight', 'content': 'An existing insight.'},
      ];
      addTearDown(() => savedThisWeekItems.value = originalItems);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(const AiDiaryApp());
      await tester.pumpAndSettle();
      final home = tester.element(find.byType(HomeScreen));
      Navigator.of(home).push(MaterialPageRoute<void>(
        builder: (_) => const AIReflectionScreen(journalContent: 'My draft'),
      ));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pump();
      expect(find.text('Saved to This Week!'), findsOneWidget);
      expect(savedThisWeekItems.value.length, 2);
      expect(savedThisWeekItems.value.first['type'], 'quote');
      await tester.tap(find.text('Saved'));
      expect(savedThisWeekItems.value.length, 2);
      Navigator.of(tester.element(find.byType(AIReflectionScreen))).pop();
      await tester.pumpAndSettle();
      expect(tester.element(find.byType(HomeScreen)), same(home));
      // Let the save snackbar dismiss before interacting with the bottom panel.
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      final navigationPosition = tester.getTopLeft(find.byType(NavigationBar));
      final list = find.byKey(const PageStorageKey('home-scroll'));
      final topBar = find.byKey(const ValueKey('home-sticky-top-bar'));
      final topBarPosition = tester.getTopLeft(topBar);
      final panel = find.byKey(const ValueKey('this-week-panel'));
      final panelPosition = tester.getTopLeft(panel);
      final controller = tester.widget<SingleChildScrollView>(list).controller!;
      final fade = find.byKey(const ValueKey('home-header-fade'));
      expect(tester.widget<Opacity>(fade).opacity, 1);
      controller.jumpTo(75);
      await tester.pump();
      expect(tester.widget<Opacity>(fade).opacity, 0.5);
      expect(tester.getTopLeft(topBar), topBarPosition);
      controller.jumpTo(150);
      await tester.pump();
      expect(tester.widget<Opacity>(fade).opacity, 0);
      controller.jumpTo(0);
      await tester.pump();
      expect(tester.widget<Opacity>(fade).opacity, 1);
      await tester.drag(list, const Offset(0, -600));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(topBar), topBarPosition);
      expect(tester.getTopLeft(panel).dy, lessThan(panelPosition.dy));
      await tester.scrollUntilVisible(
        find.text('Do what you can, with what you have, where you are.'),
        150,
        scrollable:
            find.descendant(of: list, matching: find.byType(Scrollable)),
      );
      expect(find.text('Do what you can, with what you have, where you are.'),
          findsOneWidget);
      expect(tester.getTopLeft(find.byType(NavigationBar)), navigationPosition);
      await tester.scrollUntilVisible(
        find.text('An existing insight.'),
        150,
        scrollable:
            find.descendant(of: list, matching: find.byType(Scrollable)),
      );
      expect(find.text('An existing insight.'), findsOneWidget);
      final unsave = find.byTooltip('Unsave quote');
      await Scrollable.ensureVisible(tester.element(unsave), alignment: 0.5);
      await tester.pumpAndSettle();
      await tester.tap(unsave);
      await tester.pumpAndSettle();
      expect(savedThisWeekItems.value.length, 1);
      expect(savedThisWeekItems.value.single['type'], 'insight');
      expect(find.text('Do what you can, with what you have, where you are.'),
          findsNothing);
      expect(find.text('Quote removed from This Week'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 7));
    });
  }
}
