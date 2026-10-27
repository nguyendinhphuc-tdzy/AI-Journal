import 'dart:convert';

import 'package:ai_diary/features/explore/presentation/explore_screen.dart';
import 'package:ai_diary/features/explore/presentation/map_style.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:ai_diary/features/explore/presentation/widgets/map_overlay_parts.dart';
import 'package:ai_diary/features/explore/presentation/widgets/nudaeng_map_marker.dart';
import 'package:ai_diary/features/explore/presentation/widgets/place_sheets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The land colour of a map style.
String _background(String style) {
  final layers = (jsonDecode(style) as Map)['layers'] as List;
  return ((layers.first as Map)['paint'] as Map)['background-color'] as String;
}

void main() {
  testWidgets('At night the vibe changes, the map stays light', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: ExploreScreen(clock: () => DateTime(2026, 10, 24, 22)),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('Vibe ban đêm'), findsOneWidget);
    final style =
        tester.widget<MapLibreMap>(find.byType(MapLibreMap)).styleString;
    // The map stays light at night: only the greeting changes.
    expect(style, ExploreMapStyle.day);
    expect(_background(style), '#EEF4F1');
  });

  testWidgets('Explore keeps the default light style after 5 AM',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: ExploreScreen(clock: () => DateTime(2026, 10, 24, 5)),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('Vibe ban ngày'), findsOneWidget);
    final style =
        tester.widget<MapLibreMap>(find.byType(MapLibreMap)).styleString;
    expect(style, ExploreMapStyle.day);
    // The app's Background token.
    expect(_background(style), '#EEF4F1');
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
    await tester.tap(find.byTooltip(ExploreScreen.saveLabel));
    await tester.pumpAndSettle();
    expect(find.text(PlaceSheetText.addTitle), findsOneWidget);
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(1), 'Tiệm bánh cô Hai');
    await tester.tap(find.text('Học tập'));
    await tester.tap(find.descendant(
        of: find.byType(BottomSheet), matching: find.text('Yên tĩnh')));
    await tester.enterText(fields.at(2), 'Một buổi chiều thật bình yên.');
    await tester.tap(find.bySemanticsLabel('Nudaeng Thích lắm'));
    final save = find.text(PlaceSheetText.saveLabel);
    await tester.ensureVisible(save);
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(find.text('Đã lưu cho bạn'), findsOneWidget);
    await tester.tap(find.widgetWithText(MapMoodChip, 'Yên tĩnh'));
    await tester.pumpAndSettle();
    expect(
        find.textContaining('Đang xem: Yên tĩnh · 2 địa điểm'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Anonymous community switch enables healing pins',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ExploreScreen()));
    await tester.pumpAndSettle();
    expect(find.text(ExploreScreen.communityLabel), findsOneWidget);
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
    await tester.tap(find.byTooltip(ExploreScreen.saveLabel));
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

    final save = find.text(PlaceSheetText.saveLabel);
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
    await tester.tap(find.text(PlaceSheetText.shareLabel));
    await tester.pumpAndSettle();
    expect(find.text(PlaceSheetText.shareMock), findsOneWidget);
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
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, PlaceSheetText.sendLabel))
            .onPressed,
        isNull);
    await tester.tap(find.text('Tường Vy'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(PlaceSheetText.sendLabel));
    await tester.pumpAndSettle();
    expect(find.text('Gửi qua Nudaeng Post'), findsNothing);
    await tester.tap(find.text('Inbox'));
    await tester.pumpAndSettle();
    expect(find.text('Hòm thư của bạn'), findsOneWidget);
    await tester.tap(find.text(PlaceSheetText.openLabel));
    await tester.pumpAndSettle();
    expect(find.text('Hòm thư của bạn'), findsNothing);
  });
}
