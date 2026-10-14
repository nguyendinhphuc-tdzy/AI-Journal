import 'dart:math' as math;

import 'package:ai_diary/features/home/presentation/home_screen.dart';
import 'package:ai_diary/features/home/presentation/widgets/journal_card.dart';
import 'package:ai_diary/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final size in [
    const Size(412, 915),
    const Size(320, 640),
    const Size(640, 320),
  ]) {
    testWidgets('Home stays fixed and covers background mascot at $size',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      tester.view.padding = const FakeViewPadding(top: 44, bottom: 34);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetPadding);

      await tester.pumpWidget(const AiDiaryApp());
      await tester.pumpAndSettle();
      final home = find.byType(HomeScreen);
      expect(find.descendant(of: home, matching: find.byType(Scrollable)),
          findsNothing);

      final week = find.descendant(
        of: home,
        matching: find.byWidgetPredicate((widget) =>
            widget is Positioned &&
            widget.bottom == 0 &&
            widget.height != null),
      );
      final mascot = find.descendant(
        of: home,
        matching: find.byWidgetPredicate((widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName ==
                'assets/images/laixe.gif'),
      );
      final homeRect = tester.getRect(home);
      final weekRect = tester.getRect(week);
      final mascotRect = tester.getRect(mascot);
      final cardRect = tester.getRect(find.byType(JournalCard));
      final background = find.descendant(
        of: home,
        matching: find.byWidgetPredicate((widget) =>
            widget is DecoratedBox &&
            widget.decoration is BoxDecoration &&
            (widget.decoration as BoxDecoration).image != null),
      );
      expect(tester.getRect(background), homeRect);
      expect(
        tester.getTopLeft(find.byType(CircleAvatar)).dy,
        greaterThanOrEqualTo(44 + 20),
      );
      expect(
        weekRect.bottom,
        lessThanOrEqualTo(
            tester.getTopLeft(find.byType(NavigationBar)).dy + 0.01),
      );

      // Source image is 1536x2752, centered and painted with BoxFit.cover.
      final backgroundScale =
          math.max(homeRect.width / 1536, homeRect.height / 2752);
      final paintedHeight = 2752 * backgroundScale;
      final bakedHeadTop = homeRect.top +
          (homeRect.height - paintedHeight) / 2 +
          paintedHeight * 0.76;
      expect(weekRect.top, lessThan(bakedHeadTop));
      expect(weekRect.bottom, closeTo(homeRect.bottom, 0.01));
      expect(mascotRect.bottom, closeTo(weekRect.top + 12, 0.01));
      expect(cardRect.bottom, lessThanOrEqualTo(mascotRect.top + 0.01));
      if (size.height == 915) {
        expect(mascotRect.size, const Size(200, 200));
      }

      await tester.drag(home, const Offset(0, -150));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.getRect(week), weekRect);
      expect(tester.getRect(mascot), mascotRect);
      expect(tester.getRect(find.byType(JournalCard)), cardRect);
      expect(tester.takeException(), isNull);
    });
  }
}
