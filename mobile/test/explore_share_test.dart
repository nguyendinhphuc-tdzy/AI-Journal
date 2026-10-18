import 'package:ai_diary/main.dart';
import 'package:ai_diary/features/explore/presentation/explore_screen.dart';
import 'package:ai_diary/features/explore/presentation/widgets/share_dialog.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:ai_diary/features/explore/presentation/widgets/nudaeng_map_marker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Nudaeng GIF can be rasterized into a native map marker',
      (tester) async {
    final icon = await tester.runAsync(createNudaengMarker);
    expect(icon, isA<BytesMapBitmap>());
    expect((icon! as BytesMapBitmap).byteData, isNotEmpty);
  });
  for (final size in [const Size(320, 640), const Size(640, 320)]) {
    testWidgets('Album Share opens Explore and dismisses mock dialog at $size',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(const AiDiaryApp());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Album'));
      await tester.pumpAndSettle();
      final share = find.widgetWithText(ElevatedButton, 'Share');
      await tester.ensureVisible(share);
      await tester.pumpAndSettle();
      await tester.tap(share);
      await tester.pumpAndSettle();
      expect(find.byType(ShareDialog), findsOneWidget);
      expect(
          tester
              .widget<NavigationBar>(find.byType(NavigationBar))
              .selectedIndex,
          3);
      final description = find.descendant(
          of: find.byType(ShareDialog), matching: find.byType(TextField));
      await tester.ensureVisible(description);
      await tester.enterText(description, 'A lovely meal.');
      tester.view.viewInsets = const FakeViewPadding(bottom: 120);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      final confirm = find.descendant(
          of: find.byType(ShareDialog),
          matching: find.widgetWithText(ElevatedButton, 'Share'));
      await tester.ensureVisible(confirm);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(confirm);
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      expect(find.byType(ShareDialog), findsNothing);
      expect(find.byType(ExploreScreen), findsOneWidget);
      expect(
          tester.widget<GoogleMap>(find.byType(GoogleMap)).markers.length, 3);
      await tester.tap(find.byTooltip('Filter places'));
      await tester.pumpAndSettle();
      await tester.tap(find.byWidgetPredicate((widget) =>
          widget is CheckedPopupMenuItem<String> && widget.value == 'Food'));
      await tester.pumpAndSettle();
      expect(
          tester.widget<GoogleMap>(find.byType(GoogleMap)).markers.length, 1);
      await tester.tap(find.byTooltip('Filter places'));
      await tester.pumpAndSettle();
      await tester.tap(find.byWidgetPredicate((widget) =>
          widget is CheckedPopupMenuItem<String> && widget.value == 'Food'));
      await tester.pumpAndSettle();
      expect(
          tester.widget<GoogleMap>(find.byType(GoogleMap)).markers.length, 3);
      await tester.enterText(find.byType(TextField), 'Quiet');
      await tester.pumpAndSettle();
      expect(
          tester.widget<GoogleMap>(find.byType(GoogleMap)).markers.length, 1);
      await tester.enterText(find.byType(TextField), 'no matching place');
      await tester.pumpAndSettle();
      expect(find.text('No places found'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
