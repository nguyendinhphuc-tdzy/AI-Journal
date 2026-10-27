import 'dart:convert';

import 'package:ai_diary/core/network/api_client.dart';
import 'package:ai_diary/features/explore/data/geo_search_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.Response _reply(Object value, [int status = 200]) => http.Response.bytes(
      utf8.encode(jsonEncode(value)),
      status,
      headers: const {'content-type': 'application/json; charset=utf-8'},
    );

void main() {
  test('searches Vietnamese POI and addresses near map center with JWT', () async {
    final requests = <http.Request>[];
    final client = ApiClient(
      client: MockClient((request) async {
        requests.add(request);
        return _reply({
          'items': [
            {
              'external_place_id': 'poi-1',
              'label': 'Cà phê Sách',
              'category': 'catering.cafe',
              'formatted_address': 'Quận 1, Thành phố Hồ Chí Minh',
              'latitude': 10.77,
              'longitude': 106.7,
            },
          ],
        });
      }),
      accessTokenProvider: () async => 'user-jwt',
    );
    final gateway = GeoSearchGateway(client);
    final explore = RemoteExplorePlacesRepository(gateway);
    final picker = RemotePlaceLookup(gateway);

    final found = await explore.searchNear(
      'cà phê',
      latitude: 10.8231,
      longitude: 106.6297,
    );
    expect(found, hasLength(1));
    expect(found.single.label, 'Cà phê Sách');
    expect(found.single.id, 'geo:poi-1');

    final candidates = await picker.searchNear(
      'cà phê',
      latitude: 10.8231,
      longitude: 106.6297,
    );
    expect(candidates.single.name, 'Cà phê Sách');
    expect(candidates.single.address, contains('Hồ Chí Minh'));
    expect(candidates.single.sample, isFalse);
    expect(requests, hasLength(2));
    for (final request in requests) {
      expect(request.headers['Authorization'], 'Bearer user-jwt');
      expect(request.url.path, endsWith('/geo/search'));
      expect(request.url.queryParameters['q'], 'cà phê');
      expect(request.url.queryParameters['lat'], '10.8231');
      expect(request.url.queryParameters['lon'], '106.6297');
      expect(request.url.queryParameters['limit'], '10');
      expect(request.url.queryParameters.containsKey('apiKey'), isFalse);
    }
    client.close();
  });

  test('blank query never makes an HTTP request', () async {
    final client = ApiClient(
      client: MockClient((request) async {
        fail('No request expected');
      }),
      accessTokenProvider: () async => 'jwt',
    );
    expect(await GeoSearchGateway(client).search(' '), isEmpty);
    client.close();
  });

  test('missing session fails closed before a network request', () async {
    final client = ApiClient(
      client: MockClient((request) async {
        fail('No unauthenticated network request allowed');
      }),
      accessTokenProvider: () async => null,
    );
    await expectLater(
      GeoSearchGateway(client).search('Cà phê', latitude: 10.8, longitude: 106.7),
      throwsA(isA<MissingAccessTokenException>()),
    );
    client.close();
  });

  test('provider errors propagate without fabricated sample results', () async {
    final client = ApiClient(
      client: MockClient((_) async => _reply({'detail': 'unavailable'}, 503)),
      accessTokenProvider: () async => 'jwt',
    );
    await expectLater(
      GeoSearchGateway(client).search('Cà phê', latitude: 10.8, longitude: 106.7),
      throwsA(isA<ApiException>()),
    );
    client.close();
  });

  test('invalid provider coordinates are rejected', () async {
    final client = ApiClient(
      client: MockClient((_) async => _reply({
        'items': [
          {
            'external_place_id': 'invalid',
            'label': 'Invalid',
            'latitude': 120,
            'longitude': 106.7,
          }
        ]
      })),
      accessTokenProvider: () async => 'jwt',
    );
    await expectLater(
      GeoSearchGateway(client).search('Invalid'),
      throwsFormatException,
    );
    client.close();
  });
}
