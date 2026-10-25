import 'package:ai_diary/main.dart';
import 'package:ai_diary/features/explore/presentation/explore_screen.dart';
import 'package:ai_diary/features/explore/presentation/widgets/share_dialog.dart';
import 'dart:math' as math;
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:ai_diary/features/explore/presentation/widgets/nudaeng_map_marker.dart';
import 'package:ai_diary/features/explore/presentation/widgets/place_sheets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Explore uses the dark map style for the nighttime vibe',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: ExploreScreen(clock: () => DateTime(2026, 10, 24, 22)),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('Vibe ban đêm'), findsOneWidget);
    expect(
      tester.widget<MapLibreMap>(find.byType(MapLibreMap)).styleString,
      'https://tiles.openfreemap.org/styles/dark',
    );
  });

  testWidgets('Explore keeps the default light style after 5 AM',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: ExploreScreen(clock: () => DateTime(2026, 10, 24, 5)),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('Vibe ban ngày'), findsOneWidget);
    expect(
      tester.widget<MapLibreMap>(find.byType(MapLibreMap)).styleString,
      'https://tiles.openfreemap.org/styles/liberty',
    );
  });

  testWidgets('Nudaeng GIF can be rasterized into a native map marker',
      (tester) async {
    final icon = await tester.runAsync(createNudaengMarker);
    expect(icon, isNotNull);
    expect(icon, isNotEmpty);
  });
  testWidgets('Explore saves a form entry as a local map pin', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ExploreScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Save a new place'));
    await tester.pumpAndSettle();
    expect(find.text('Save a new place'), findsOneWidget);
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(1), 'Tiệm bánh cô Hai');
    await tester.tap(find.text('Study'));
    await tester.tap(find.text('Yên tĩnh'));
    await tester.enterText(fields.at(2), 'Một buổi chiều thật bình yên.');
    await tester.tap(find.bySemanticsLabel('Mood Loved it'));
    final save = find.text('Lưu & Ghim lên bản đồ');
    await tester.ensureVisible(save);
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(find.text('Đã lưu cho bạn'), findsOneWidget);
    await tester.tap(find.byTooltip('Filter places'));
    await tester.pumpAndSettle();
    await tester.tap(find.byWidgetPredicate((widget) =>
        widget is CheckedPopupMenuItem<String> && widget.value == 'Yên tĩnh'));
    await tester.pumpAndSettle();
    expect(
        find.textContaining('Đang xem: Yên tĩnh · 2 địa điểm'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Anonymous community switch enables healing pins',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ExploreScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Cộng đồng ẩn danh'), findsOneWidget);
    final toggle = find.byType(Switch);
    expect(tester.widget<Switch>(toggle).value, isFalse);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(tester.widget<Switch>(toggle).value, isTrue);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Anonymous place sharing makes the new community pin visible',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ExploreScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Save a new place'));
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(1), 'Một góc để thở');
    await tester.enterText(fields.at(2), 'Bạn không hề cô đơn đâu.');
    final anonymousToggle = find.descendant(
      of: find.byType(SwitchListTile),
      matching: find.byType(Switch),
    );
    await tester.ensureVisible(anonymousToggle);
    await tester.pumpAndSettle();
    await tester.tap(anonymousToggle);
    await tester.pumpAndSettle();
    expect(tester.widget<Switch>(anonymousToggle).value, isTrue);

    final save = find.text('Lưu & Ghim lên bản đồ');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(find.text('Đã thả trạm ẩn danh'), findsOneWidget);
    final communityToggle = find.byType(Switch).first;
    expect(tester.widget<Switch>(communityToggle).value, isTrue);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Saved place details include its note and mock share action',
      (tester) async {
    const place = SavedPlace(
      id: 'saved:1',
      name: 'Tiệm bánh cô Hai',
      category: 'Food',
      moodTag: 'Vui vẻ',
      note: 'Bánh thơm và rất yên tĩnh.',
      latitude: 10.8,
      longitude: 106.6,
      moodAsset: 'assets/images/like.gif',
      moodLabel: 'Loved it',
    );
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showSavedPlaceSheet(context, place),
            child: const Text('Open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Bánh thơm và rất yên tĩnh.'), findsOneWidget);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Share'));
    await tester.pumpAndSettle();
    expect(find.text('Share is a mock in this version.'), findsOneWidget);
  });
  testWidgets('Nudaeng Post chooses a friend and inbox accepts a place',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Column(children: [
            ElevatedButton(
              onPressed: () =>
                  showShareFriendsSheet(context, placeName: 'Tiệm bánh cô Hai'),
              child: const Text('Post'),
            ),
            ElevatedButton(
              onPressed: () => showInboxSheet(context),
              child: const Text('Inbox'),
            ),
          ]),
        ),
      ),
    ));
    await tester.tap(find.text('Post'));
    await tester.pumpAndSettle();
    expect(find.text('Gửi qua Nudaeng Post'), findsOneWidget);
    expect(
        tester
            .widget<ElevatedButton>(
                find.widgetWithText(ElevatedButton, 'Gửi thư'))
            .onPressed,
        isNull);
    await tester.tap(find.text('Tường Vy'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gửi thư'));
    await tester.pumpAndSettle();
    expect(find.text('Gửi qua Nudaeng Post'), findsNothing);
    await tester.tap(find.text('Inbox'));
    await tester.pumpAndSettle();
    expect(find.text('Hòm thư của bạn'), findsOneWidget);
    await tester.tap(find.text('Mở & Lưu vào bản đồ'));
    await tester.pumpAndSettle();
    expect(find.text('Hòm thư của bạn'), findsNothing);
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
      await tester.tap(find.text('Kỷ niệm'));
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
          widget is CheckedPopupMenuItem<String> &&
          widget.value == 'Xả stress'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Đang xem: Xả stress · 0 địa điểm'),
          findsOneWidget);
      await tester.tap(find.byTooltip('Filter places'));
      await tester.pumpAndSettle();
      await tester.tap(find.byWidgetPredicate((widget) =>
          widget is CheckedPopupMenuItem<String> && widget.value == 'Tất cả'));
      await tester.pumpAndSettle();
      expect(find.byType(MapLibreMap), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, 'Quiet');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(find.byType(ListTile), findsOneWidget);
      expect(find.text('Quiet corner'), findsOneWidget);
      await tester.tap(find.text('Quiet corner'));
      await tester.pumpAndSettle();
      expect(find.text('Study Cafe · Demo only'), findsOneWidget);
      expect(
          tester
              .widget<TextField>(find.byType(TextField).first)
              .controller!
              .text,
          isEmpty);
      await tester.tap(find.byTooltip('Close place details'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'no matching place');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(find.text('No places found'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, '');
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
