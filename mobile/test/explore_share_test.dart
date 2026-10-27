import 'package:ai_diary/main.dart';
import 'package:ai_diary/features/album/data/memory.dart';
import 'package:ai_diary/features/album/data/memory_share.dart';
import 'package:ai_diary/features/album/presentation/album_routes.dart';
import 'package:ai_diary/features/explore/presentation/explore_screen.dart';
import 'dart:math' as math;
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:ai_diary/features/explore/presentation/widgets/map_overlay_parts.dart';
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
    testWidgets('A post shared from Album opens Explore with its pin at $size',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(const AiDiaryApp());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kỷ niệm'));
      await tester.pumpAndSettle();
      // What A10 does once the service accepted a post: the album routes
      // close and the library hands the post to the shell.
      final expiresAt = DateTime(2026, 10, 21, 14, 5);
      AlbumRoutes.published.value = SharedMemoryPost(
        id: 'post-1',
        payload: const SharePayload(
          albumId: 'a',
          memoryId: 'm',
          audience: ShareAudience(id: 'friends', label: 'Bạn bè'),
          place: MemoryPlace(
              label: 'Hồ Xuân Hương', latitude: 11.94, longitude: 108.44),
          title: 'Chiều ở Đà Lạt',
          text: 'Ly ca cao nóng.',
        ),
        publishedAt: expiresAt.subtract(const Duration(hours: 24)),
        expiresAt: expiresAt.add(const Duration(days: 3650)),
      );
      await tester.pumpAndSettle();
      expect(AlbumRoutes.published.value, isNull);
      expect(
          tester
              .widget<NavigationBar>(find.byType(NavigationBar))
              .selectedIndex,
          3);
      expect(find.byType(ExploreScreen), findsOneWidget);
      expect(
          tester
              .widget<ExploreScreen>(find.byType(ExploreScreen))
              .highlight!
              .id,
          'post-1');
      // Its card is open: what was shared and until when.
      expect(find.text('Chiều ở Đà Lạt'), findsOneWidget);
      expect(find.textContaining('Ly ca cao nóng.'), findsOneWidget);
      expect(
          find.textContaining('Hồ Xuân Hương · Hết hạn lúc'), findsOneWidget);
      expect(find.byType(MapLibreMap), findsOneWidget);
      await tester.tap(find.byTooltip(ExploreScreen.closePostTooltip));
      await tester.pumpAndSettle();
      expect(find.text('Chiều ở Đà Lạt'), findsNothing);
      // Taken off the map in Album (A12 or A11): E01 drops the pin.
      AlbumRoutes.unshared.value = const ShareRemoval(postId: 'post-1');
      await tester.pumpAndSettle();
      expect(AlbumRoutes.unshared.value, isNull);
      expect(tester.widget<ExploreScreen>(find.byType(ExploreScreen)).highlight,
          isNull);
      // A mood chip keeps that mood; tapped again, every mood is back.
      final calm = find.widgetWithText(MapMoodChip, 'Yên tĩnh');
      await tester.ensureVisible(calm);
      await tester.tap(calm);
      await tester.pumpAndSettle();
      expect(find.textContaining('Đang xem: Yên tĩnh · 1 địa điểm'),
          findsOneWidget);
      await tester.tap(calm);
      await tester.pumpAndSettle();
      expect(find.textContaining('Đang xem:'), findsNothing);
      expect(find.byType(MapLibreMap), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Quiet');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(find.byType(ListTile), findsOneWidget);
      expect(find.text('Quiet corner'), findsOneWidget);
      await tester.tap(find.text('Quiet corner'));
      await tester.pumpAndSettle();
      expect(find.text('Study Cafe · ${ExploreScreen.sample}'), findsOneWidget);
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
          isEmpty);
      await tester.tap(find.byTooltip(ExploreScreen.closePlaceTooltip));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'no matching place');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(find.text(ExploreScreen.noResults), findsOneWidget);
      await tester.enterText(find.byType(TextField), '');
      await tester.pump(const Duration(milliseconds: 400));
      tester.widget<MapLibreMap>(find.byType(MapLibreMap)).onMapLongClick!(
          const math.Point(10, 10), const LatLng(10.8, 106.6));
      await tester.pumpAndSettle();
      expect(find.text(ExploreScreen.draftTitle), findsOneWidget);
      await tester.tap(find.byTooltip(ExploreScreen.removeDraftTooltip));
      await tester.pumpAndSettle();
      expect(find.text(ExploreScreen.draftTitle), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
