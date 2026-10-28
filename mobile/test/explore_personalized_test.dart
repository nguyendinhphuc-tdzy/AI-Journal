import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:ai_diary/features/explore/data/place_lookup.dart';
import 'package:ai_diary/features/explore/presentation/explore_screen.dart';
import 'package:ai_diary/features/explore/presentation/widgets/map_marker_art.dart';
import 'package:ai_diary/features/explore/presentation/widgets/places_sheet.dart';
import 'package:ai_diary/features/explore/presentation/map_style.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:ai_diary/features/explore/presentation/widgets/map_overlay_parts.dart';
import 'package:ai_diary/features/explore/presentation/widgets/nudaeng_map_marker.dart';
import 'package:ai_diary/features/explore/presentation/widgets/place_pick_overlay.dart';
import 'package:ai_diary/features/explore/presentation/widgets/place_sheets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The land colour of a map style.
String _background(String style) {
  final layers = (jsonDecode(style) as Map)['layers'] as List;
  return ((layers.first as Map)['paint'] as Map)['background-color'] as String;
}

/// The save form: from "+ Lưu một nơi" (the pin at the middle, then "Chọn
/// vị trí này"), or [atPin] from the dropped pin's card.
Future<void> _openForm(WidgetTester tester, {bool atPin = false}) async {
  if (atPin) {
    await tester.tap(find.text(ExploreScreen.saveHereLabel));
  } else {
    await tester.tap(find.byTooltip(ExploreScreen.saveLabel));
    await tester.pumpAndSettle();
    expect(find.text(PlacePickText.hint), findsOneWidget);
    await tester.tap(find.text(PlacePickText.confirm));
  }
  await tester.pumpAndSettle();
}

/// Opens the save form, names the place, picks [mood] and saves.
Future<void> _save(WidgetTester tester, String name,
    {PlaceMood? mood, bool atPin = false}) async {
  await _openForm(tester, atPin: atPin);
  await tester.enterText(find.byType(TextField).at(1), name);
  // Done typing: the sheet no longer keeps the name field in view.
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pump();
  if (mood != null) {
    final tile = find.bySemanticsLabel('Nudaeng ${mood.label}');
    await tester.ensureVisible(tile);
    await tester.tap(tile);
  }
  final save = find.text(PlaceSheetText.saveLabel);
  await tester.ensureVisible(save);
  await tester.pumpAndSettle();
  await tester.tap(save);
  await tester.pumpAndSettle();
}

class _Location implements DeviceLocation {
  _Location(this.fix);
  final DeviceFix fix;
  var asked = 0;

  @override
  bool get supported => true;

  @override
  Future<DeviceFix> current() async {
    asked++;
    return fix;
  }
}

SavedPlace _at(String id, double lat, double lng) => SavedPlace(
    id: id,
    name: id,
    category: 'Food',
    note: '',
    latitude: lat,
    longitude: lng);

void main() {
  test('Close places group at a distance and come apart zoomed in', () {
    final places = [
      _at('a', 10.7757, 106.6929),
      _at('b', 10.7759, 106.6931),
      _at('c', 10.8200, 106.7500),
    ];
    final far = clusterPlaces(places, 12);
    expect([for (final c in far) c.places.length], [2, 1]);
    final near = clusterPlaces(places, 19);
    expect(near, hasLength(3));
    // The chosen one is never inside a group.
    final kept = clusterPlaces(places, 12, keep: 'a');
    expect(
        kept.firstWhere((c) => c.places.first.id == 'a').places, hasLength(1));
  });

  setUp(() {
    clearUnsavedPlace();
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Saved at the pin, kept on the device, there after a restart',
      (tester) async {
    final store = InMemorySavedPlacesStore();
    await tester
        .pumpWidget(MaterialApp(home: ExploreScreen(savedPlacesStore: store)));
    await tester.pumpAndSettle();
    tester.widget<MapLibreMap>(find.byType(MapLibreMap)).onMapClick!(
        const math.Point(10, 10), const LatLng(10.81, 106.71));
    await tester.pumpAndSettle();
    await _openForm(tester, atPin: true);
    expect(find.text(PlaceSheetText.addHelpPinned), findsOneWidget);
    await tester.tap(find.byTooltip(PlaceSheetText.closeTooltip));
    await tester.pumpAndSettle();
    await _save(tester, 'Cà phê Cách Mạng', mood: PlaceMood.tired, atPin: true);
    expect(find.text(ExploreScreen.saved), findsOneWidget);
    final kept = store.kept!.singleWhere((p) => p.name == 'Cà phê Cách Mạng');
    // Where the pin was, not the map centre.
    expect(kept.latitude, closeTo(10.81, 1e-9));
    expect(kept.longitude, closeTo(106.71, 1e-9));
    expect(kept.mood, PlaceMood.tired);
    expect(store.kept, hasLength(4), reason: 'the samples are kept too');

    // A new run: it is still there, and the search finds it without accents.
    await tester.pumpWidget(const SizedBox());
    await tester
        .pumpWidget(MaterialApp(home: ExploreScreen(savedPlacesStore: store)));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'cach mang');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('Cà phê Cách Mạng'), findsOneWidget);
    expect(find.text('Ăn uống · ${ExploreScreen.savedResult}'), findsOneWidget);
    await tester.tap(find.text('Cà phê Cách Mạng'));
    await tester.pumpAndSettle();
    // Chosen: its card in "Những nơi của bạn", open with its actions.
    expect(find.text(PlaceSheetText.shareLabel), findsOneWidget);
    expect(find.text('Ăn uống · Mệt mỏi'), findsOneWidget);
  });

  testWidgets('Choosing a spot: the pin at the middle, Huỷ goes back',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ExploreScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(ExploreScreen.saveLabel));
    await tester.pumpAndSettle();
    expect(find.text(PlacePickText.hint), findsOneWidget);
    expect(find.text(PlacesSheetText.title), findsNothing, reason: 'aside');
    await tester.tap(find.text(PlacePickText.cancel));
    await tester.pumpAndSettle();
    expect(find.text(PlacePickText.hint), findsNothing);
    expect(find.text(PlaceSheetText.addTitle), findsNothing);
    expect(find.text(PlacesSheetText.title), findsOneWidget);
  });

  testWidgets('Nothing saved: a small Nudaeng invites the first place',
      (tester) async {
    final store = InMemorySavedPlacesStore()..kept = [];
    await tester
        .pumpWidget(MaterialApp(home: ExploreScreen(savedPlacesStore: store)));
    await tester.pumpAndSettle();
    final drag = find.text(PlacesSheetText.title);
    await tester.drag(drag, const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(find.text(PlacesSheetText.emptyTitle), findsOneWidget);
    final add = find.descendant(
        of: find.byType(DraggableScrollableSheet),
        matching: find.text(PlacesSheetText.addLabel));
    await tester.ensureVisible(add);
    await tester.pumpAndSettle();
    await tester.tap(add);
    await tester.pumpAndSettle();
    expect(find.text(PlacePickText.hint), findsOneWidget);
  });

  testWidgets('Vị trí của tôi: asked only on tap; refused says how to allow',
      (tester) async {
    final location = _Location(const DeviceFixDenied());
    await tester
        .pumpWidget(MaterialApp(home: ExploreScreen(location: location)));
    await tester.pumpAndSettle();
    expect(location.asked, 0, reason: 'never on opening the map');
    await tester.tap(find.byTooltip(ExploreScreen.locateTooltip));
    await tester.pumpAndSettle();
    expect(location.asked, 1);
    expect(find.text(ExploreScreen.locationDenied), findsOneWidget);
    expect(
        tester.widget<MapLibreMap>(find.byType(MapLibreMap)).myLocationEnabled,
        isFalse);
  });

  testWidgets('Vị trí của tôi found: the blue dot comes on', (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: ExploreScreen(
            location: _Location(const DeviceFixFound(10.78, 106.70)))));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(ExploreScreen.locateTooltip));
    await tester.pumpAndSettle();
    expect(
        tester.widget<MapLibreMap>(find.byType(MapLibreMap)).myLocationEnabled,
        isTrue);
  });

  test('Places and stops are kept on the device and read back', () async {
    const store = LocalSavedPlacesStore();
    expect(await store.places(), isNull, reason: 'nothing kept yet');
    await store.keepPlaces(const [
      SavedPlace(
          id: 'saved:1',
          name: 'Góc nhỏ',
          category: 'Study',
          mood: PlaceMood.reflective,
          note: 'Yên.',
          latitude: 10.8,
          longitude: 106.7),
      SavedPlace(
          id: 'saved:2',
          name: 'Không Nudaeng',
          category: 'Food',
          note: '',
          latitude: 10.7,
          longitude: 106.6),
    ]);
    await store.keepStops(const [
      CommunityStop(
          id: 'a', latitude: 10.7, longitude: 106.6, message: 'Ổn mà'),
    ]);
    final places = (await store.places())!;
    expect([
      for (final p in places) (p.name, p.mood, p.category)
    ], [
      ('Góc nhỏ', PlaceMood.reflective, 'Study'),
      ('Không Nudaeng', null, 'Food'),
    ]);
    expect((await store.stops())!.single.message, 'Ổn mà');
  });

  testWidgets('A filter that would hide the new place is dropped',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ExploreScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(MapMoodChip, 'Học tập'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Đang xem: Học tập'), findsOneWidget);
    // Saved as food: the study filter would hide it.
    await _save(tester, 'Quán mới');
    expect(find.text(ExploreScreen.savedShown), findsOneWidget);
    expect(find.textContaining('Đang xem:'), findsNothing);
  });

  testWidgets('A place that fits the filter keeps it', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ExploreScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(MapMoodChip, 'Ăn uống'));
    await tester.pumpAndSettle();
    await _save(tester, 'Quán mới');
    expect(find.text(ExploreScreen.saved), findsOneWidget);
    expect(
        find.textContaining('Đang xem: Ăn uống · 2 địa điểm'), findsOneWidget);
  });

  testWidgets('Zoom by hand: buttons, and pinching is on', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ExploreScreen()));
    await tester.pumpAndSettle();
    expect(find.byTooltip(ExploreScreen.zoomInTooltip), findsOneWidget);
    expect(find.byTooltip(ExploreScreen.zoomOutTooltip), findsOneWidget);
    await tester.tap(find.byTooltip(ExploreScreen.zoomInTooltip));
    await tester.tap(find.byTooltip(ExploreScreen.zoomOutTooltip));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final map = tester.widget<MapLibreMap>(find.byType(MapLibreMap));
    expect(map.zoomGesturesEnabled, isTrue);
  });

  testWidgets('One light map at any hour; no day or night label',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ExploreScreen()));
    await tester.pumpAndSettle();
    expect(find.textContaining('Vibe'), findsNothing);
    expect(find.text(ExploreScreen.pinHint), findsOneWidget);
    final style =
        tester.widget<MapLibreMap>(find.byType(MapLibreMap)).styleString;
    expect(style, ExploreMapStyle.day);
    // Ivory land.
    expect(_background(style), '#F7F4EC');
  });

  testWidgets('Nudaeng GIF can be rasterized into a native map marker',
      (tester) async {
    final icon = await tester.runAsync(createNudaengMarker);
    expect(icon, isNotNull);
    expect(icon, isNotEmpty);
    final mood = await tester.runAsync(() => createNudaengMarker(
        PlaceMood.happy.asset, const Color(0xFFE994AC), false));
    expect(mood, isNotEmpty);
    // A pin: Nudaeng in the frame, cut at the tip (its bottom edge).
    final pin = await tester.runAsync(() async {
      final png = await createPinMarker(PlaceMood.happy.asset);
      final codec = await ui.instantiateImageCodec(png);
      return (await codec.getNextFrame()).image;
    });
    expect(pin!.width, PinArt.width);
    expect(pin.height, (PinArt.width * PinArt.tip).round());
    for (final frame in [PinArt.neutral, ...PinArt.waveFrames]) {
      expect(
          await tester
              .runAsync(() => createPinMarker(frame, crop: PinArt.waveCrop)),
          isNotEmpty);
    }
    expect(PinArt.wave.fold(0, (sum, step) => sum + step.$2), 1800);
  });
  testWidgets('Explore saves a form entry as a local map pin', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ExploreScreen()));
    await tester.pumpAndSettle();
    await _openForm(tester);
    expect(find.text(PlaceSheetText.addTitle), findsOneWidget);
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(1), 'Tiệm bánh cô Hai');
    final sheet = find.byType(BottomSheet);
    await tester
        .tap(find.descendant(of: sheet, matching: find.text('Học tập')));
    await tester.enterText(fields.at(2), 'Một buổi chiều thật bình yên.');
    final calm = find.bySemanticsLabel('Nudaeng Bình yên');
    await tester.ensureVisible(calm);
    await tester.tap(calm);
    final save = find.text(PlaceSheetText.saveLabel);
    await tester.ensureVisible(save);
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(find.text(ExploreScreen.saved), findsOneWidget);
    // Study places: the sample one and this one.
    await tester.tap(find.widgetWithText(MapMoodChip, 'Học tập'));
    await tester.pumpAndSettle();
    expect(
        find.textContaining('Đang xem: Học tập · 2 địa điểm'), findsOneWidget);
    // And felt peaceful there: both.
    await tester.tap(find.byKey(const ValueKey('mood-filter')));
    await tester.pumpAndSettle();
    expect(find.text(PlaceSheetText.filterTitle), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Nudaeng Bình yên'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Đang xem: Học tập · Bình yên · 2 địa điểm'),
        findsOneWidget);
    // Only the mood, any place: still those two (the café is happy).
    await tester.tap(find.widgetWithText(MapMoodChip, 'Học tập'));
    await tester.pumpAndSettle();
    expect(
        find.textContaining('Đang xem: Bình yên · 2 địa điểm'), findsOneWidget);
    await tester.tap(find.widgetWithText(MapMoodChip, ExploreScreen.allFilter));
    await tester.pumpAndSettle();
    expect(find.textContaining('Đang xem:'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'Save sheet: six Nudaeng in view, none chosen; tap again unchooses',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ExploreScreen()));
    await tester.pumpAndSettle();
    await _openForm(tester);
    expect(find.text(PlaceSheetText.categoryLabel), findsOneWidget);
    expect(find.text(PlaceSheetText.moodLabel), findsOneWidget);
    expect(find.text(PlaceSheetText.moodHelp), findsOneWidget);
    // The old mood chips are gone.
    expect(find.text('Cần chữa lành'), findsNothing);
    final tiles = [
      for (final mood in PlaceMood.values)
        find.bySemanticsLabel('Nudaeng ${mood.label}')
    ];
    for (final tile in tiles) {
      expect(tile, findsOneWidget);
    }
    // Three to a row, two rows.
    final first = tester.getRect(tiles[0]);
    expect(tester.getRect(tiles[2]).top, first.top);
    expect(tester.getRect(tiles[3]).top, greaterThan(first.bottom));
    bool chosen(PlaceMood mood) =>
        tester
            .widget<Semantics>(find.byWidgetPredicate((w) =>
                w is Semantics &&
                w.properties.label == 'Nudaeng ${mood.label}'))
            .properties
            .selected ==
        true;
    expect(PlaceMood.values.where(chosen), isEmpty, reason: 'nothing assumed');
    await tester.ensureVisible(tiles[4]);
    await tester.tap(tiles[4]);
    await tester.pump();
    expect(chosen(PlaceMood.anxious), isTrue);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    await tester.tap(tiles[4]);
    await tester.pump();
    expect(chosen(PlaceMood.anxious), isFalse);
  });

  testWidgets('Save sheet closes without saving and keeps what was typed',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ExploreScreen()));
    await tester.pumpAndSettle();
    await _openForm(tester);
    await tester.enterText(find.byType(TextField).at(1), 'Góc nhỏ');
    await tester.tap(find.byTooltip(PlaceSheetText.closeTooltip));
    await tester.pumpAndSettle();
    expect(find.text(PlaceSheetText.addTitle), findsNothing);
    expect(find.text(ExploreScreen.saved), findsNothing);
    await _openForm(tester);
    expect(find.text('Góc nhỏ'), findsOneWidget, reason: 'carried on');
    // Back closes it too.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text(PlaceSheetText.addTitle), findsNothing);
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
    await _openForm(tester);

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
      mood: PlaceMood.happy,
      note: 'Bánh thơm và rất yên tĩnh.',
      latitude: 10.8,
      longitude: 106.6,
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
    expect(find.text('Ăn uống'), findsOneWidget);
    expect(find.text('Vui vẻ'), findsOneWidget);
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
