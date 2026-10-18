import 'package:ai_diary/features/home/presentation/home_screen.dart';
import 'package:ai_diary/features/profile/profile_screen.dart';
import 'package:ai_diary/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
      await tester.tap(find.bySemanticsLabel('Profile avatar'));
      await tester.pumpAndSettle();
      expect(find.byType(ProfileScreen), findsOneWidget);
      expect(find.text('GENERAL'), findsOneWidget);
      expect(find.text('who says plus'), findsOneWidget);
      expect(tester.widget<Text>(find.text('who says plus')).textAlign,
          TextAlign.center);
      expect(tester.takeException(), isNull);
      final scrollable = find.descendant(
          of: find.byType(ProfileScreen), matching: find.byType(Scrollable));
      await tester.scrollUntilVisible(find.text('lock with passcode'), 150,
          scrollable: scrollable);
      expect(
          tester
              .widget<Text>(find.text('lock with passcode'))
              .style!
              .decoration,
          TextDecoration.lineThrough);
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
      await tester.scrollUntilVisible(
          find.byKey(const ValueKey('app-icon-4')), 100,
          scrollable: scrollable);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('app-icon-4')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('app-icon-4')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('selected-icon-dot')), findsOneWidget);
      expect(
          tester.getCenter(find.byKey(const ValueKey('selected-icon-dot'))).dx,
          tester.getCenter(find.byKey(const ValueKey('app-icon-4'))).dx);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('close'));
      await tester.pumpAndSettle();
      expect(tester.element(find.byType(HomeScreen)), same(originalHome));
      expect(find.byType(ProfileScreen), findsNothing);
    });
  }
}
