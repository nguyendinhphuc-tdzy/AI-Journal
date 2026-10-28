import 'dart:convert';

import 'package:ai_diary/core/network/api_client.dart';
import 'package:ai_diary/features/explore/data/remote_saved_places_repository.dart';
import 'package:ai_diary/features/explore/presentation/widgets/place_sheets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.Response _reply(Object value, [int status = 200]) => http.Response.bytes(
  utf8.encode(jsonEncode(value)),
  status,
  headers: const {'content-type': 'application/json; charset=utf-8'},
);

const _draft = PlaceDraft(
  name: 'Cà phê sách',
  category: 'Chill',
  note: 'Mùi cà phê dễ chịu',
  mood: PlaceMood.peaceful,
  isAnonymousShare: false,
);

Map<String, dynamic> _place(int id) => {
  'id': id, 'label': 'Cà phê sách', 'latitude': 10.77,
  'longitude': 106.69, 'provider': 'manual', 'external_place_id': null,
  'address_text': null, 'created_at': '2026-10-28T00:00:00Z',
  'updated_at': '2026-10-28T00:00:00Z',
};

void main() {
  test('create private pin and encrypted-transport note, list via cursor, delete', () async {
    final requests = <http.Request>[];
    final api = ApiClient(
      accessTokenProvider: () async => 'owner-jwt',
      client: MockClient((request) async {
        requests.add(request);
        final path = request.url.path;
        if (request.method == 'DELETE') return http.Response('', 204);
        if (request.method == 'POST' && path.endsWith('/places')) {
          return _reply(_place(12), 201);
        }
        if (request.method == 'POST' && path.endsWith('/notes')) {
          return _reply({'id': 51, 'content': 'saved'}, 201);
        }
        if (path.endsWith('/notes')) {
          return _reply({'items': [{'content':
            'AIJOURNAL_PLACE_V1:${jsonEncode({
              'category': 'Chill', 'mood': 'peaceful',
              'note': 'Mùi cà phê dễ chịu',
            })}'
          }], 'next_cursor': null});
        }
        if (request.url.queryParameters['cursor'] == 'after-page-1') {
          return _reply({'items': [_place(12)], 'next_cursor': null});
        }
        return _reply({'items': [_place(8)], 'next_cursor': 'after-page-1'});
      }),
    );
    final repo = RemoteSavedPlacesRepository(api);
    final created = await repo.create(_draft, latitude: 10.77, longitude: 106.69);
    expect(created.id, 'saved:12');
    expect(created.note, 'Mùi cà phê dễ chịu');
    final listed = await repo.all();
    expect(listed.map((p) => p.id), ['saved:8', 'saved:12']);
    await repo.delete(created.id);
    expect(requests.last.method, 'DELETE');
    for (final request in requests) {
      expect(request.headers['authorization'], 'Bearer owner-jwt');
      expect(request.url.queryParameters.containsKey('apiKey'), isFalse);
    }
    final noteRequest = requests.firstWhere((r) =>
        r.method == 'POST' && r.url.path.endsWith('/notes'));
    expect(noteRequest.body, contains('AIJOURNAL_PLACE_V1:'));
    api.close();
  });

  test('no JWT: fail before any private request', () async {
    var calls = 0;
    final api = ApiClient(
      accessTokenProvider: () async => null,
      client: MockClient((_) async { calls++; return _reply({}); }),
    );
    await expectLater(
      RemoteSavedPlacesRepository(api).all(),
      throwsA(isA<MissingAccessTokenException>()),
    );
    expect(calls, 0);
    api.close();
  });

  test('note failure reports partial persistence to avoid duplicate retry', () async {
    final api = ApiClient(
      accessTokenProvider: () async => 'jwt',
      client: MockClient((request) async {
        if (request.url.path.endsWith('/notes')) {
          return _reply({'detail': 'unavailable'}, 503);
        }
        return _reply(_place(12), 201);
      }),
    );
    await expectLater(
      RemoteSavedPlacesRepository(api).create(
        _draft, latitude: 10.77, longitude: 106.69,
      ),
      throwsA(isA<PartiallySavedPlace>()),
    );
    api.close();
  });
}
