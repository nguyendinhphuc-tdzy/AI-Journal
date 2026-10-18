import 'package:ai_diary/main.dart';
import 'package:ai_diary/features/explore/presentation/explore_screen.dart';
import 'package:ai_diary/features/explore/presentation/widgets/share_dialog.dart';
import 'dart:math' as math;
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:ai_diary/features/explore/presentation/widgets/nudaeng_map_marker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Nudaeng GIF can be rasterized into a native map marker',
      (tester) async {
    final icon = await tester.runAsync(createNudaengMarker);
    expect(icon, isNotNull);
    expect(icon, isNotEmpty);
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
      expect(find.byType(MapLibreMap), findsOneWidget);
      await tester.tap(find.byTooltip('Filter places'));
      await tester.pumpAndSettle();
      await tester.tap(find.byWidgetPredicate((widget) =>
          widget is CheckedPopupMenuItem<String> && widget.value == 'Food'));
      await tester.pumpAndSettle();
      expect(find.byType(ListTile), findsOneWidget);
      await tester.tap(find.byTooltip('Filter places'));
      await tester.pumpAndSettle();
      await tester.tap(find.byWidgetPredicate((widget) =>
          widget is CheckedPopupMenuItem<String> && widget.value == 'Food'));
      await tester.pumpAndSettle();
      expect(find.byType(MapLibreMap), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Quiet');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(find.byType(ListTile), findsOneWidget);
      expect(find.text('Quiet corner'), findsOneWidget);
      await tester.tap(find.text('Quiet corner'));
      await tester.pumpAndSettle();
      expect(find.text('Study Cafe · Demo only'), findsOneWidget);
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
          isEmpty);
      await tester.tap(find.byTooltip('Close place details'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'no matching place');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(find.text('No places found'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '');
      await tester.pump(const Duration(milliseconds: 400));
      tester.widget<MapLibreMap>(find.byType(MapLibreMap)).onMapLongClick!(
          const math.Point(10, 10), const LatLng(10.8, 106.6));
      await tester.pumpAndSettle();
      expect(find.text('Temporary pin'), findsOneWidget);
      await tester.tap(find.byTooltip('Remove temporary pin'));
      await tester.pumpAndSettle();
      expect(find.text('Temporary pin'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
