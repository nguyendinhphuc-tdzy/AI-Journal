import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'place_mood.dart';

/// A place the user saved on the map (E02).
class SavedPlace {
  const SavedPlace({
    required this.id,
    required this.name,
    required this.category,
    this.mood,
    required this.note,
    required this.latitude,
    required this.longitude,
  });

  final String id;
  final String name;
  final String category;

  /// Null when saved without a Nudaeng.
  final PlaceMood? mood;
  final String note;
  final double latitude;
  final double longitude;

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'category': category,
        'mood': mood?.name,
        'note': note,
        'latitude': latitude,
        'longitude': longitude,
      };

  static SavedPlace fromJson(Map<String, Object?> json) {
    final mood = json['mood'];
    return SavedPlace(
      id: json['id'] as String,
      name: json['name'] as String,
      category: json['category'] as String,
      mood: mood is String ? PlaceMood.values.asNameMap()[mood] : null,
      note: json['note'] as String? ?? '',
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
    );
  }
}

/// An anonymous community stop (mock: only on this device).
class CommunityStop {
  const CommunityStop({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.message,
  });

  final String id;
  final double latitude;
  final double longitude;
  final String message;

  Map<String, Object?> toJson() => {
        'id': id,
        'latitude': latitude,
        'longitude': longitude,
        'message': message,
      };

  static CommunityStop fromJson(Map<String, Object?> json) => CommunityStop(
        id: json['id'] as String,
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        message: json['message'] as String,
      );
}

/// Where the map's places are kept between runs. Null from a load: nothing
/// kept yet (the samples show).
abstract interface class SavedPlacesStore {
  Future<List<SavedPlace>?> places();
  Future<void> keepPlaces(List<SavedPlace> places);
  Future<List<CommunityStop>?> stops();
  Future<void> keepStops(List<CommunityStop> stops);
}

/// On this device, via shared_preferences, until saved places have a
/// backend (B09 has no mood or category fields yet).
class LocalSavedPlacesStore implements SavedPlacesStore {
  const LocalSavedPlacesStore({this.userId});

  /// Null is for the standalone demo only; signed-in users get scoped data.
  final String? userId;
  static const placesKey = 'explore.savedPlaces';
  static const stopsKey = 'explore.communityStops';

  String _key(String key) => userId == null ? key : 'users.$userId.$key';

  static Future<List<T>?> _read<T>(
      String key, T Function(Map<String, Object?>) parse) async {
    final raw = (await SharedPreferences.getInstance()).getString(key);
    if (raw == null) return null;
    return [
      for (final item in jsonDecode(raw) as List)
        parse((item as Map).cast<String, Object?>()),
    ];
  }

  static Future<void> _write(String key, List<Object?> items) async {
    final ok = await (await SharedPreferences.getInstance())
        .setString(key, jsonEncode(items));
    if (!ok) throw StateError('Could not keep $key');
  }

  @override
  Future<List<SavedPlace>?> places() => _read(_key(placesKey), SavedPlace.fromJson);

  @override
  Future<void> keepPlaces(List<SavedPlace> places) =>
      _write(_key(placesKey), [for (final place in places) place.toJson()]);

  @override
  Future<List<CommunityStop>?> stops() =>
      _read(stopsKey, CommunityStop.fromJson);

  @override
  Future<void> keepStops(List<CommunityStop> stops) =>
      _write(_key(stopsKey), [for (final stop in stops) stop.toJson()]);
}

/// In memory only, for tests.
class InMemorySavedPlacesStore implements SavedPlacesStore {
  List<SavedPlace>? kept;
  List<CommunityStop>? keptStops;

  @override
  Future<List<SavedPlace>?> places() async => kept;

  @override
  Future<void> keepPlaces(List<SavedPlace> places) async =>
      kept = List.of(places);

  @override
  Future<List<CommunityStop>?> stops() async => keptStops;

  @override
  Future<void> keepStops(List<CommunityStop> stops) async =>
      keptStops = List.of(stops);
}
