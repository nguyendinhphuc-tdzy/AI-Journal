import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ai_diary/core/network/api_client.dart';

void main() {
  test('adds a fresh bearer token to GET and POST calls', () async {
    var current = 'first';
    final requests = <http.Request>[];
    final client = ApiClient(
      accessTokenProvider: () async => current,
      client: MockClient((request) async {
        requests.add(request);
        return http.Response('{"ok":true}', 200);
      }),
    );
    await client.getJson('/journals');
    current = 'refreshed';
    await client.postJson('/journals', {'content': 'A private journal'});
    expect(requests[0].headers['authorization'], 'Bearer first');
    expect(requests[1].headers['authorization'], 'Bearer refreshed');
    expect(requests[1].headers['content-type'], contains('application/json'));
    client.close();
  });

  test('does not log backend response body in an exception', () async {
    final client = ApiClient(client: MockClient(
      (_) async => http.Response('a private journal body', 401),
    ));
    await expectLater(
      client.getJson('/journals'),
      throwsA(predicate((error) =>
          error is ApiException &&
          error.statusCode == 401 &&
          !error.toString().contains('private journal body'))),
    );
    client.close();
  });

  test('does not send bearer for guest session', () async {
    final client = ApiClient(
      accessTokenProvider: () async => null,
      client: MockClient((request) async {
        expect(request.headers.containsKey('authorization'), isFalse);
        return http.Response('{"ok":true}', 200);
      }),
    );
    await client.getJson('/prompts/daily');
    client.close();
  });
}
