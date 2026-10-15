import 'package:ai_diary/features/home/presentation/home_screen.dart';
import 'package:ai_diary/features/home/presentation/widgets/journal_card.dart';
import 'package:ai_diary/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final size in [
    const Size(412, 915),
    const Size(320, 640),
    const Size(640, 320)
  ]) {
    testWidgets('Home scrolls under a fixed top bar at $size', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      tester.view.padding = const FakeViewPadding(top: 44, bottom: 34);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetPadding);
      await tester.pumpWidget(const AiDiaryApp());
      await tester.pumpAndSettle();
      final home = find.byType(HomeScreen);
      final scroll = find.byKey(const PageStorageKey('home-scroll'));
      final topBar = find.byKey(const ValueKey('home-sticky-top-bar'));
      final panel = find.byKey(const ValueKey('this-week-panel'));
      final background = find.descendant(
          of: home,
          matching: find.byWidgetPredicate((widget) =>
              widget is Image &&
              widget.image is AssetImage &&
              (widget.image as AssetImage).assetName ==
                  'assets/images/background_homescreen.png'));
      expect(tester.getRect(background), tester.getRect(home));
      final topBarRect = tester.getRect(topBar);
      final navRect = tester.getRect(find.byType(NavigationBar));
      final panelTop = tester.getTopLeft(panel).dy;
      final mascot = find.bySemanticsLabel('Nudaeng, idle');
      expect(tester.getRect(find.byType(JournalCard)).bottom,
          lessThanOrEqualTo(tester.getTopLeft(mascot).dy));
      expect(topBarRect.top, greaterThanOrEqualTo(44));
      await tester.drag(scroll, const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(panel).dy, lessThan(panelTop));
      expect(tester.getRect(topBar), topBarRect);
      expect(tester.getRect(find.byType(NavigationBar)), navRect);
      expect(
          tester
              .widget<Opacity>(find.byKey(const ValueKey('home-header-fade')))
              .opacity,
          0);
      expect(tester.takeException(), isNull);
    });
  }
}
