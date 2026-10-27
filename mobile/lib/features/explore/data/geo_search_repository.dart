import 'package:flutter/widgets.dart';

import '../../../core/network/api_client.dart';
import 'explore_places_repository.dart';
import 'place_lookup.dart';

/// Allows the live search to rank results around the map's current center.
/// Existing mocks and injected preview repositories are not affected.
abstract interface class NearbyExploreSearch {
  Future<List<ExplorePlace>> searchNear(
    String query, {
    required double latitude,
    required double longitude,
  });
}

abstract interface class NearbyPlaceLookup {
  Future<List<PlaceCandidate>> searchNear(
    String query, {
    required double latitude,
    required double longitude,
  });
}

class _GeoHit {
  const _GeoHit({
    required this.id,
    required this.label,
    required this.latitude,
    required this.longitude,
    this.address,
    this.category,
  });

  final String id;
  final String label;
  final double latitude;
  final double longitude;
  final String? address;
  final String? category;

  factory _GeoHit.fromJson(Object? raw) {
    if (raw is! Map<String, dynamic>) {
      throw const FormatException('Invalid location result');
    }
    final id = raw['external_place_id'];
    final label = raw['label'];
    final lat = raw['latitude'];
    final lon = raw['longitude'];
    if (id is! String ||
        id.isEmpty ||
        label is! String ||
        label.trim().isEmpty ||
        lat is! num ||
        lon is! num ||
        !lat.isFinite ||
        !lon.isFinite ||
        lat < -90 ||
        lat > 90 ||
        lon < -180 ||
        lon > 180) {
      throw const FormatException('Invalid location result');
    }
    return _GeoHit(
      id: id,
      label: label,
      latitude: lat.toDouble(),
      longitude: lon.toDouble(),
      address: raw['formatted_address'] is String
          ? raw['formatted_address'] as String
          : null,
      category: raw['category'] is String ? raw['category'] as String : null,
    );
  }
}

/// All address/POI requests go to FastAPI, which keeps Geoapify key private.
/// The existing ApiClient requires a fresh Supabase access token per request.
class GeoSearchGateway {
  const GeoSearchGateway(this.api);
  final ApiClient api;

  Future<List<_GeoHit>> search(
    String query, {
    double? latitude,
    double? longitude,
  }) async {
    final cleaned = query.trim();
    if (cleaned.length < 2) return const [];
    if ((latitude == null) != (longitude == null)) {
      throw ArgumentError('Latitude and longitude must be paired');
    }
    final params = <String, String>{
      'q': cleaned,
      'limit': '10',
      if (latitude != null) 'lat': latitude.toString(),
      if (longitude != null) 'lon': longitude.toString(),
    };
    final encoded = Uri(queryParameters: params).query;
    final payload = await api.getJson('/geo/search?$encoded', requireAuth: true);
    final items = payload['items'];
    if (items is! List) {
      throw const FormatException('Invalid location search response');
    }
    return items.map((value) => _GeoHit.fromJson(value)).toList();
  }
}

class RemoteExplorePlacesRepository
    implements ExplorePlacesRepository, NearbyExploreSearch {
  const RemoteExplorePlacesRepository(this.gateway);
  final GeoSearchGateway gateway;

  @override
  Future<List<ExplorePlace>> search(String query, String? category) async {
    final hits = await gateway.search(query);
    return hits.map(_toPlace).toList();
  }

  @override
  Future<List<ExplorePlace>> searchNear(
    String query, {
    required double latitude,
    required double longitude,
  }) async {
    final hits = await gateway.search(
      query,
      latitude: latitude,
      longitude: longitude,
    );
    return hits.map(_toPlace).toList();
  }

  ExplorePlace _toPlace(_GeoHit hit) => ExplorePlace(
        'geo:${hit.id}',
        hit.label,
        hit.category ?? 'Địa điểm',
        hit.latitude,
        hit.longitude,
      );
}

class RemotePlaceLookup implements PlaceLookup, NearbyPlaceLookup {
  const RemotePlaceLookup(this.gateway);
  final GeoSearchGateway gateway;

  @override
  Future<List<PlaceCandidate>> search(String query) async {
    final hits = await gateway.search(query);
    return hits.map(_toCandidate).toList();
  }

  @override
  Future<List<PlaceCandidate>> searchNear(
    String query, {
    required double latitude,
    required double longitude,
  }) async {
    final hits = await gateway.search(
      query,
      latitude: latitude,
      longitude: longitude,
    );
    return hits.map(_toCandidate).toList();
  }

  PlaceCandidate _toCandidate(_GeoHit hit) => PlaceCandidate(
        id: hit.id,
        name: hit.label,
        address: hit.address,
        latitude: hit.latitude,
        longitude: hit.longitude,
        source: PlaceSource.search,
      );

  // M02 adds real reverse geocoding. Never invent address details here.
  @override
  Future<PlaceCandidate?> nameAt(double latitude, double longitude) =>
      Future.error(const PlaceLookupUnavailable());
}

/// Inject only for real Supabase-authenticated sessions. Guest and fake auth
/// still use their explicitly labelled preview repositories.
class GeoSearchScope extends InheritedWidget {
  GeoSearchScope({super.key, required ApiClient client, required super.child})
      : gateway = GeoSearchGateway(client);

  final GeoSearchGateway gateway;

  static GeoSearchScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<GeoSearchScope>();

  RemoteExplorePlacesRepository get explore => RemoteExplorePlacesRepository(gateway);
  RemotePlaceLookup get picker => RemotePlaceLookup(gateway);

  @override
  bool updateShouldNotify(GeoSearchScope oldWidget) => oldWidget.gateway.api != gateway.api;
}
