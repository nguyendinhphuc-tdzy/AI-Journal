import 'explore_places_repository.dart';
import '../../../core/network/api_client.dart';
import 'package:flutter/widgets.dart';

/// How a place was chosen in E05.
enum PlaceSource { search, pin, device }

/// A place the user can pick in E05: a search result, a pin dropped on the
/// map, or the device's location. Pins may have no name.
class PlaceCandidate {
  const PlaceCandidate({
    this.id,
    this.name,
    this.address,
    required this.latitude,
    required this.longitude,
    required this.source,
    this.sample = false,
  });

  /// The search provider's id, when there is one.
  final String? id;
  final String? name;
  final String? address;
  final double latitude;
  final double longitude;
  final PlaceSource source;

  /// A demo place from the mock search, not a real address.
  final bool sample;

  bool get named => (name ?? '').trim().isNotEmpty;

  String get coordinates =>
      '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}';

  PlaceCandidate copyWith({String? name, String? address}) => PlaceCandidate(
        id: id,
        name: name ?? this.name,
        address: address ?? this.address,
        latitude: latitude,
        longitude: longitude,
        source: source,
        sample: sample,
      );
}

/// The name lookup could not run (no service, offline). Different from
/// "nothing is named here" (null).
class PlaceLookupUnavailable implements Exception {
  const PlaceLookupUnavailable();
}

/// Search by name and name a point. A real version goes through FastAPI
/// (`GET /api/v1/geo/search`, not merged yet); there is no reverse lookup in
/// the API contract.
abstract interface class PlaceLookup {
  Future<List<PlaceCandidate>> search(String query);

  /// The name and address at a point; null when nothing is named there.
  /// Throws [PlaceLookupUnavailable] when the lookup cannot run.
  Future<PlaceCandidate?> nameAt(double latitude, double longitude);
}

/// Explore's demo places for search; no reverse lookup.
class MockPlaceLookup implements PlaceLookup {
  const MockPlaceLookup([this.places = const MockExplorePlacesRepository()]);

  final ExplorePlacesRepository places;

  @override
  Future<List<PlaceCandidate>> search(String query) async => [
        for (final place in await places.search(query, null))
          PlaceCandidate(
            id: place.id,
            name: place.label,
            latitude: place.latitude,
            longitude: place.longitude,
            source: PlaceSource.search,
            sample: true,
          ),
      ];

  @override
  Future<PlaceCandidate?> nameAt(double latitude, double longitude) =>
      Future.error(const PlaceLookupUnavailable());
}

/// Real authenticated FastAPI place search and reverse lookup.
class RemotePlaceLookup implements PlaceLookup {
  const RemotePlaceLookup(this.client);
  final ApiClient client;

  PlaceCandidate _candidate(Map<String, dynamic> raw,
      PlaceSource source) {
    final lat = raw['latitude'];
    final lon = raw['longitude'];
    final label = raw['label'];
    if (lat is! num || lon is! num || !lat.isFinite || !lon.isFinite ||
        lat < -90 || lat > 90 || lon < -180 || lon > 180 ||
        label is! String || label.trim().isEmpty) {
      throw const FormatException('Invalid place lookup data');
    }
    return PlaceCandidate(
      id: raw['external_place_id'] is String
          ? raw['external_place_id'] as String : null,
      name: label,
      address: raw['formatted_address'] is String
          ? raw['formatted_address'] as String : null,
      latitude: lat.toDouble(),
      longitude: lon.toDouble(),
      source: source,
    );
  }

  @override
  Future<List<PlaceCandidate>> search(String query) async {
    final normalized = query.trim();
    if (normalized.length < 2) return const [];
    try {
      final result = await client.getJson(
        '/geo/search?q=${Uri.encodeQueryComponent(normalized)}',
        requireAuth: true,
      );
      final items = result['items'];
      if (items is! List) throw const FormatException('Invalid place results');
      return items.map((raw) {
        if (raw is! Map<String, dynamic>) {
          throw const FormatException('Invalid place result');
        }
        return _candidate(raw, PlaceSource.search);
      }).toList();
    } catch (_) {
      throw const PlaceLookupUnavailable();
    }
  }

  @override
  Future<PlaceCandidate?> nameAt(double latitude, double longitude) async {
    if (!latitude.isFinite || !longitude.isFinite ||
        latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) {
      throw const PlaceLookupUnavailable();
    }
    try {
      final raw = await client.getOptionalJson(
        '/geo/reverse?lat=$latitude&lon=$longitude',
        requireAuth: true,
      );
      if (raw == null) return null;
      return _candidate(raw, PlaceSource.pin);
    } catch (_) {
      throw const PlaceLookupUnavailable();
    }
  }
}

/// Provided only for an authenticated cloud session. Guest stays on mock.
class PlaceLookupScope extends InheritedWidget {
  const PlaceLookupScope({super.key, required this.lookup,
      required super.child});
  final PlaceLookup lookup;

  static PlaceLookup? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PlaceLookupScope>()?.lookup;

  @override
  bool updateShouldNotify(PlaceLookupScope oldWidget) =>
      oldWidget.lookup != lookup;
}

/// The device's location, asked only when the user taps "Vị trí của tôi".
abstract interface class DeviceLocation {
  /// False hides "Vị trí của tôi".
  bool get supported;

  /// Asks for permission if needed, then the current position.
  Future<DeviceFix> current();
}

sealed class DeviceFix {
  const DeviceFix();
}

class DeviceFixFound extends DeviceFix {
  const DeviceFixFound(this.latitude, this.longitude);
  final double latitude;
  final double longitude;
}

class DeviceFixDenied extends DeviceFix {
  const DeviceFixDenied();
}

class DeviceFixFailed extends DeviceFix {
  const DeviceFixFailed();
}

/// No location plugin in the app yet: "Vị trí của tôi" is not offered.
class NoDeviceLocation implements DeviceLocation {
  const NoDeviceLocation();

  @override
  bool get supported => false;

  @override
  Future<DeviceFix> current() async => const DeviceFixFailed();
}
