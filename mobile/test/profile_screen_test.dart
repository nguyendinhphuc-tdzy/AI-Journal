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
    testWidgets('Profile opens, toggles preferences, and returns Home at $size',
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
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Nudaeng Lover'), findsOneWidget);
      expect(tester.takeException(), isNull);

      for (final title in ['Daily Reminder', 'Sound Effects']) {
        final tile = find.widgetWithText(SwitchListTile, title);
        await tester.ensureVisible(tile);
        await tester.pumpAndSettle();
        final oldValue = tester.widget<SwitchListTile>(tile).value;
        await tester.tap(tile);
        await tester.pumpAndSettle();
        expect(tester.widget<SwitchListTile>(tile).value, !oldValue);
      }
      await tester.scrollUntilVisible(find.text('v1.0.0'), 100,
          scrollable: find.descendant(
            of: find.byType(ProfileScreen),
            matching: find.byType(Scrollable),
          ));
      await tester.pumpAndSettle();
      expect(tester.getRect(find.text('v1.0.0')).bottom,
          lessThanOrEqualTo(size.height));
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Back to Home'));
      await tester.pumpAndSettle();
      expect(tester.element(find.byType(HomeScreen)), same(originalHome));
      expect(find.byType(ProfileScreen), findsNothing);
    });
  }
}
