import 'dart:async';
import 'dart:math' as math;

import 'package:ai_diary/core/theme/app_theme.dart';
import 'package:ai_diary/features/explore/data/place_lookup.dart';
import 'package:ai_diary/features/explore/presentation/map_style.dart';
import 'package:ai_diary/features/explore/presentation/place_picker_screen.dart';
import 'package:ai_diary/features/explore/presentation/widgets/map_overlay_parts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

typedef _E05 = PlacePickerScreen;

const _cafe = PlaceCandidate(
  id: 'g-1',
  name: 'Cà phê Hẻm',
  address: '12 Lê Lợi, Quận 1',
  latitude: 10.776,
  longitude: 106.701,
  source: PlaceSource.search,
);

class _Lookup implements PlaceLookup {
  List<PlaceCandidate> results = const [_cafe];
  bool searchFails = false;
  Object? nameError = const PlaceLookupUnavailable();
  PlaceCandidate? named;
  Completer<void>? nameGate;
  final queries = <String>[];
  final namedAt = <(double, double)>[];

  @override
  Future<List<PlaceCandidate>> search(String query) async {
    queries.add(query);
    if (searchFails) throw StateError('offline');
    return results;
  }

  @override
  Future<PlaceCandidate?> nameAt(double latitude, double longitude) async {
    namedAt.add((latitude, longitude));
    await nameGate?.future;
    if (nameError case final error?) throw error;
    return named;
  }
}

class _Location implements DeviceLocation {
  _Location(this.fix);
  DeviceFix fix;
  var asked = 0;

  @override
  bool get supported => true;

  @override
  Future<DeviceFix> current() async {
    asked++;
    return fix;
  }
}

/// A host page with "Mở" opening E05; [result] gets what it returned.
Future<List<PlaceCandidate?>> _pump(
  WidgetTester tester, {
  PlaceLookup? lookup,
  DeviceLocation location = const NoDeviceLocation(),
  PlaceCandidate? initial,
}) async {
  final returned = <PlaceCandidate?>[];
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.light,
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: FilledButton(
            onPressed: () async => returned.add(await Navigator.of(context)
                .push<PlaceCandidate>(MaterialPageRoute(
                    builder: (_) => PlacePickerScreen(
                        initial: initial,
                        lookup: lookup ?? _Lookup(),
                        location: location)))),
            child: const Text('Mở'),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('Mở'));
  await tester.pumpAndSettle();
  return returned;
}

Finder get _confirm => find.widgetWithText(FilledButton, _E05.confirmLabel);
Finder get _search => find.widgetWithText(TextField, _E05.searchHint);

bool _enabled(WidgetTester tester) =>
    tester.widget<FilledButton>(_confirm).onPressed != null;

Future<void> _tapMap(WidgetTester tester, LatLng at) async {
  tester.widget<MapLibreMap>(find.byType(MapLibreMap)).onMapClick!(
      const math.Point(10, 10), at);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('The same light map as Explore', (tester) async {
    await _pump(tester);
    expect(tester.widget<MapLibreMap>(find.byType(MapLibreMap)).styleString,
        ExploreMapStyle.day);
  });

  testWidgets('Looks and works as Explore: zoom, its pin, its buttons',
      (tester) async {
    await _pump(tester);
    expect(find.byType(MapCenterPin), findsOneWidget);
    expect(find.byType(MapZoomButtons), findsOneWidget);
    await tester.tap(find.byTooltip(MapZoomButtons.zoomInTooltip));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final map = tester.widget<MapLibreMap>(find.byType(MapLibreMap));
    expect(map.zoomGesturesEnabled, isTrue);
    expect(map.minMaxZoomPreference.maxZoom, 19);
  });

  testWidgets('Map, search, centre pin and panel; nothing chosen yet',
      (tester) async {
    await _pump(tester);
    expect(find.byType(MapLibreMap), findsOneWidget);
    expect(_search, findsOneWidget);
    expect(find.byTooltip(_E05.backTooltip), findsOneWidget);
    expect(find.text(_E05.nothingYet), findsOneWidget);
    expect(find.text(_E05.howTo), findsOneWidget);
    expect(_enabled(tester), isFalse);
    // No mascot here, and no "my location" without a location service.
    expect(find.byType(Image), findsNothing);
    expect(find.byTooltip(_E05.myLocation), findsNothing);
  });

  testWidgets('Search (debounced) → result → confirm returns it',
      (tester) async {
    final lookup = _Lookup();
    final returned = await _pump(tester, lookup: lookup);
    await tester.enterText(_search, 'cà');
    await tester.enterText(_search, 'cà phê');
    await tester.pump(_E05.debounce);
    await tester.pumpAndSettle();
    expect(lookup.queries, ['cà phê']);
    await tester.tap(find.text('Cà phê Hẻm'));
    await tester.pumpAndSettle();
    // The candidate: name, address, coordinates; no lookup for a named place.
    expect(find.text('Cà phê Hẻm'), findsOneWidget);
    expect(find.textContaining('12 Lê Lợi, Quận 1'), findsOneWidget);
    expect(find.textContaining('10.77600, 106.70100'), findsOneWidget);
    expect(lookup.namedAt, isEmpty);
    await tester.tap(_confirm);
    await tester.pumpAndSettle();
    final place = returned.single!;
    expect(place.id, 'g-1');
    expect(place.name, 'Cà phê Hẻm');
    expect(place.address, '12 Lê Lợi, Quận 1');
    expect(place.latitude, 10.776);
    expect(place.source, PlaceSource.search);
  });

  testWidgets('Search failure and no results say so; Retry searches again',
      (tester) async {
    final lookup = _Lookup()..searchFails = true;
    await _pump(tester, lookup: lookup);
    await tester.enterText(_search, 'xyz');
    await tester.pump(_E05.debounce);
    await tester.pumpAndSettle();
    expect(find.text(_E05.searchFailed), findsOneWidget);
    lookup
      ..searchFails = false
      ..results = const [];
    await tester.tap(find.widgetWithText(TextButton, _E05.retryLabel));
    await tester.pumpAndSettle();
    expect(find.text(_E05.noResults), findsOneWidget);
  });

  testWidgets('A pin: looked up; failure is not "no place"; a name may be set',
      (tester) async {
    final lookup = _Lookup()..nameGate = Completer();
    final returned = await _pump(tester, lookup: lookup);
    tester.widget<MapLibreMap>(find.byType(MapLibreMap)).onMapClick!(
        const math.Point(10, 10), const LatLng(10.8, 106.65));
    await tester.pump();
    expect(find.text(_E05.naming), findsOneWidget);
    expect(_enabled(tester), isFalse);
    lookup.nameGate!.complete();
    await tester.pumpAndSettle();
    final (lat, lng) = lookup.namedAt.single;
    expect(lat, closeTo(10.8, 1e-9));
    expect(lng, closeTo(106.65, 1e-9));
    // Coordinates are there; only the name is missing.
    expect(find.text(_E05.unnamed), findsOneWidget);
    expect(find.textContaining('10.80000, 106.65000'), findsOneWidget);
    expect(find.text(_E05.lookupFailed), findsOneWidget);
    expect(find.text(_E05.nothingYet), findsNothing);
    expect(_enabled(tester), isTrue);
    await tester.enterText(
        find.widgetWithText(TextField, _E05.nameLabel), '  Nhà bà ngoại ');
    await tester.tap(_confirm);
    await tester.pumpAndSettle();
    final place = returned.single!;
    expect(place.name, 'Nhà bà ngoại');
    expect(place.source, PlaceSource.pin);
    expect(place.id, isNull);
  });

  testWidgets('A pin with nothing named there; used as coordinates',
      (tester) async {
    final lookup = _Lookup()..nameError = null;
    final returned = await _pump(tester, lookup: lookup);
    await _tapMap(tester, const LatLng(10.8, 106.65));
    expect(find.text(_E05.lookupEmpty), findsOneWidget);
    await tester.tap(_confirm);
    await tester.pumpAndSettle();
    expect(returned.single!.named, isFalse);
  });

  testWidgets('A pin the service names', (tester) async {
    final lookup = _Lookup()
      ..nameError = null
      ..named = const PlaceCandidate(
          name: 'Công viên Tao Đàn',
          address: 'Quận 1',
          latitude: 10.8,
          longitude: 106.65,
          source: PlaceSource.pin);
    final returned = await _pump(tester, lookup: lookup);
    await _tapMap(tester, const LatLng(10.8, 106.65));
    expect(find.text('Công viên Tao Đàn'), findsOneWidget);
    expect(find.widgetWithText(TextField, _E05.nameLabel), findsNothing);
    await tester.tap(_confirm);
    await tester.pumpAndSettle();
    expect(returned.single!.name, 'Công viên Tao Đàn');
    expect(returned.single!.latitude, 10.8);
  });

  testWidgets('Back returns nothing; the starting place is shown',
      (tester) async {
    final returned = await _pump(tester, initial: _cafe);
    expect(find.text('Cà phê Hẻm'), findsOneWidget);
    expect(_enabled(tester), isTrue);
    await _tapMap(tester, const LatLng(10.8, 106.65));
    await tester.tap(find.byTooltip(_E05.backTooltip));
    await tester.pumpAndSettle();
    expect(returned.single, isNull);
  });

  testWidgets('My location: asked only on tap, then still needs confirm',
      (tester) async {
    final location = _Location(const DeviceFixFound(10.79, 106.68));
    final returned = await _pump(tester, location: location);
    expect(location.asked, 0);
    await tester.tap(find.byTooltip(_E05.myLocation));
    await tester.pumpAndSettle();
    expect(location.asked, 1);
    expect(find.textContaining('10.79000, 106.68000'), findsOneWidget);
    // Not taken as the place until confirmed.
    expect(returned, isEmpty);
    await tester.tap(_confirm);
    await tester.pumpAndSettle();
    expect(returned.single!.source, PlaceSource.device);
  });

  testWidgets('My location denied: says so; picking by hand still works',
      (tester) async {
    final location = _Location(const DeviceFixDenied());
    await _pump(tester, location: location);
    await tester.tap(find.byTooltip(_E05.myLocation));
    await tester.pumpAndSettle();
    expect(find.text(_E05.locationDenied), findsOneWidget);
    expect(_enabled(tester), isFalse);
    await _tapMap(tester, const LatLng(10.8, 106.65));
    expect(find.text(_E05.locationDenied), findsNothing);
    expect(_enabled(tester), isTrue);
  });
}
