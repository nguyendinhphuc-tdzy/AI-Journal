import 'package:ai_diary/features/journal/presentation/write_journal_screen.dart';
import 'package:ai_diary/main.dart';
import 'package:ai_diary/navigation/custom_bottom_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final tab in ['Home', 'Study', 'Album', 'Explore']) {
    testWidgets('Journal card and navigation to $tab', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(412, 915);
      tester.view.padding = const FakeViewPadding(top: 44, bottom: 34);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetPadding);
      await tester.pumpWidget(const AiDiaryApp());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reflect ➔'));
      await tester.pumpAndSettle();

      final card = find.descendant(
        of: find.byType(WriteJournalScreen),
        matching: find.byWidgetPredicate((widget) =>
            widget is DecoratedBox &&
            widget.decoration is BoxDecoration &&
            (widget.decoration as BoxDecoration).color == Colors.transparent),
      );
      final cardRect = tester.getRect(card);
      for (final child in [
        find.text('Daily Reflection'),
        find.byType(TextField),
        find.text('Finish entry'),
        find.text('✨ Go Deeper'),
      ]) {
        final rect = tester.getRect(child);
        expect(cardRect.contains(rect.topLeft), isTrue);
        expect(cardRect.contains(rect.bottomRight), isTrue);
      }
      expect(cardRect.bottom,
          lessThan(tester.getTopLeft(find.byType(CustomBottomNavigation)).dy));
      expect(find.byIcon(Icons.attach_file), findsNothing);
      expect(find.byIcon(Icons.image_outlined), findsOneWidget);
      expect(find.byIcon(Icons.mic_none_outlined), findsOneWidget);
      await tester.tap(find.text(tab));
      await tester.pumpAndSettle();
      expect(find.byType(WriteJournalScreen), findsNothing);
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        ['Home', 'Study', 'Album', 'Explore'].indexOf(tab),
      );
      expect(tester.takeException(), isNull);
    });
  }
}
