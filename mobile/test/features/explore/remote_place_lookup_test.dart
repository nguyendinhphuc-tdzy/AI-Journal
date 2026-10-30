import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:ai_diary/core/network/api_client.dart';
import 'package:ai_diary/features/explore/data/place_lookup.dart';

void main() {
  test('authenticated search returns real candidates, never sample', () async {
    final requests = <http.Request>[];
    final httpClient = MockClient((request) async {
      requests.add(request);
      return http.Response(jsonEncode({
        'items': [{
          'provider': 'geoapify',
          'external_place_id': 'geo-1',
          'label': 'Bưu điện Trung tâm',
          'formatted_address': 'Quận 1',
          'latitude': 10.7769,
          'longitude': 106.7009,
        }]
      }), 200, headers: {'content-type': 'application/json; charset=utf-8'});
    });
    final api = ApiClient(client: httpClient,
      accessTokenProvider: () async => 'test-access-token');
    final lookup = RemotePlaceLookup(api);
    final results = await lookup.search('Bưu điện');
    expect(results, hasLength(1));
    expect(results.first.sample, false);
    expect(results.first.id, 'geo-1');
    expect(results.first.name, 'Bưu điện Trung tâm');
    expect(requests.single.url.path, endsWith('/geo/search'));
    expect(requests.single.headers['Authorization'], 'Bearer test-access-token');
    api.close();
  });

  test('reverse null is unnamed, not provider failure', () async {
    final httpClient = MockClient((request) async => http.Response('null', 200));
    final api = ApiClient(client: httpClient,
      accessTokenProvider: () async => 'test-access-token');
    expect(await RemotePlaceLookup(api).nameAt(10.77, 106.7), isNull);
    api.close();
  });

  test('missing JWT fails closed without sending HTTP', () async {
    var called = false;
    final httpClient = MockClient((request) async {
      called = true;
      return http.Response('{}', 200);
    });
    final api = ApiClient(client: httpClient);
    await expectLater(RemotePlaceLookup(api).search('Hanoi'),
        throwsA(isA<PlaceLookupUnavailable>()));
    expect(called, false);
    api.close();
  });

  test('network failure is surfaced as unavailable', () async {
    final httpClient = MockClient((request) async => http.Response('{}', 503));
    final api = ApiClient(client: httpClient,
      accessTokenProvider: () async => 'test-access-token');
    await expectLater(RemotePlaceLookup(api).nameAt(10.77, 106.7),
        throwsA(isA<PlaceLookupUnavailable>()));
    api.close();
  });

  test('nearby Vietnamese POIs are fetched through JWT backend, not direct Geoapify', () async {
    final requests = <http.Request>[];
    final httpClient = MockClient((request) async {
      requests.add(request);
      return http.Response(jsonEncode({'items': [{
        'provider': 'geoapify',
        'external_place_id': 'hcm-cafe',
        'label': 'Quán cà phê Sài Gòn',
        'formatted_address': 'Quận 1, TP.HCM',
        'categories': ['catering.cafe'],
        'latitude': 10.7769,
        'longitude': 106.7009,
      }]}), 200, headers: {'content-type': 'application/json'});
    });
    final api = ApiClient(client: httpClient,
        accessTokenProvider: () async => 'test-access-token');
    final result = await RemotePlaceLookup(api).nearby(
        10.7769, 106.7009, category: 'cafe', name: 'Cà phê');
    expect(result, hasLength(1));
    expect(result.single.name, 'Quán cà phê Sài Gòn');
    expect(result.single.address, 'Quận 1, TP.HCM');
    expect(result.single.category, 'catering.cafe');
    expect(requests.single.url.path, endsWith('/geo/places'));
    expect(requests.single.url.queryParameters['category'], 'cafe');
    expect(requests.single.url.queryParameters['q'], 'Cà phê');
    expect(requests.single.headers['Authorization'], 'Bearer test-access-token');
    api.close();
  });

  test('POI browsing fails closed without authenticated session', () async {
    var sent = false;
    final api = ApiClient(client: MockClient((request) async {
      sent = true;
      return http.Response('{"items":[]}', 200);
    }));
    await expectLater(RemotePlaceLookup(api).nearby(10.77, 106.7),
        throwsA(isA<PlaceLookupUnavailable>()));
    expect(sent, false);
    api.close();
  });

}
