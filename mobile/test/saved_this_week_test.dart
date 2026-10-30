import 'package:ai_diary/core/data/app_data.dart';
import 'package:ai_diary/features/home/presentation/home_screen.dart';
import 'package:ai_diary/features/journal/ai_reflection_screen.dart';
import 'package:ai_diary/main.dart';
import 'package:ai_diary/core/widgets/app_ui.dart';
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
      await tester.tap(find.text('Lưu'));
      await tester.pump();
      expect(find.text('Đã lưu. Xem lại ở mục Đã lưu trên Trang chủ.'),
          findsOneWidget);
      expect(savedThisWeekItems.value.length, 2);
      expect(savedThisWeekItems.value.first['type'], 'quote');
      await tester.tap(find.text('Đã lưu'));
      expect(savedThisWeekItems.value.length, 2);
      Navigator.of(tester.element(find.byType(AIReflectionScreen))).pop();
      await tester.pumpAndSettle();
      expect(tester.element(find.byType(HomeScreen)), same(home));
      // Let the save snackbar dismiss before interacting with the bottom panel.
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      final navigationPosition = tester.getTopLeft(find.byType(NavigationBar));
      final list = find.byKey(const PageStorageKey('home-scroll'));
      // Home scrolls as one page (header included, as on the other tabs);
      // the bottom bar stays put.
      expect(find.byType(AppPageHeader), findsOneWidget);
      final card = find.byKey(const ValueKey('home-reflection'));
      final cardPosition = tester.getTopLeft(card);
      await tester.drag(list, const Offset(0, -120));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(card).dy, lessThan(cardPosition.dy));
      expect(tester.getTopLeft(find.byType(NavigationBar)), navigationPosition);
      await tester.scrollUntilVisible(
        find.text(
            'Hãy làm những gì bạn có thể, bằng những gì bạn có, ngay tại nơi bạn đang đứng.'),
        150,
        scrollable:
            find.descendant(of: list, matching: find.byType(Scrollable)),
      );
      expect(
          find.text(
              'Hãy làm những gì bạn có thể, bằng những gì bạn có, ngay tại nơi bạn đang đứng.'),
          findsOneWidget);
      expect(tester.getTopLeft(find.byType(NavigationBar)), navigationPosition);
      // Home keeps the newest; the older insight is one tap away.
      expect(find.text('An existing insight.'), findsNothing);
      final all = find.byKey(const ValueKey('home-saved-all'));
      await tester.scrollUntilVisible(all, 150,
          scrollable:
              find.descendant(of: list, matching: find.byType(Scrollable)));
      await tester.pumpAndSettle();
      expect(find.text('Xem tất cả (2)'), findsOneWidget);
      await tester.tap(all);
      await tester.pumpAndSettle();
      expect(find.byType(SavedItemsScreen), findsOneWidget);
      await tester.scrollUntilVisible(find.text('An existing insight.'), 150,
          scrollable: find
              .descendant(
                  of: find.byType(SavedItemsScreen),
                  matching: find.byType(Scrollable))
              .first);
      expect(find.text('An existing insight.'), findsOneWidget);
      await tester.tap(find.byTooltip('Đóng'));
      await tester.pumpAndSettle();
      final unsave = find.byTooltip('Bỏ lưu trích dẫn');
      await Scrollable.ensureVisible(tester.element(unsave), alignment: 0.5);
      await tester.pumpAndSettle();
      await tester.tap(unsave);
      await tester.pumpAndSettle();
      expect(savedThisWeekItems.value.length, 1);
      expect(savedThisWeekItems.value.single['type'], 'insight');
      expect(
          find.text(
              'Hãy làm những gì bạn có thể, bằng những gì bạn có, ngay tại nơi bạn đang đứng.'),
          findsNothing);
      expect(find.text('Đã bỏ lưu trích dẫn'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 7));
    });
  }
}
