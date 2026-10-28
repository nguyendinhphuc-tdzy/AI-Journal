import 'dart:async';

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

  test('private GET refreshes once on 401 without repeating forever', () async {
    var refreshes = 0;
    final seen = <String?>[];
    final client = ApiClient(
      accessTokenProvider: () async => 'expired',
      accessTokenRefresher: () async {
        refreshes++;
        return 'renewed';
      },
      client: MockClient((request) async {
        seen.add(request.headers['authorization']);
        return request.headers['authorization'] == 'Bearer renewed'
            ? http.Response('{"ok":true}', 200)
            : http.Response('{"detail":"expired"}', 401);
      }),
    );
    expect((await client.getJson('/journals', requireAuth: true))['ok'], true);
    expect(refreshes, 1);
    expect(seen, ['Bearer expired', 'Bearer renewed']);
    client.close();
  });

  test('401 after refresh fails closed and is not retried repeatedly', () async {
    var requests = 0;
    var refreshes = 0;
    final client = ApiClient(
      accessTokenProvider: () async => 'expired',
      accessTokenRefresher: () async {
        refreshes++;
        return 'still-expired';
      },
      client: MockClient((request) async {
        requests++;
        return http.Response('private backend details', 401);
      }),
    );
    await expectLater(
        client.postJson('/journals', {'content': 'Private'}, requireAuth: true),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 401)));
    expect(requests, 2);
    expect(refreshes, 1);
    client.close();
  });

  test('timeout is bounded; a write is never retried', () async {
    var calls = 0;
    final client = ApiClient(
      requestTimeout: const Duration(milliseconds: 5),
      client: MockClient((request) async {
        calls++;
        await Future<void>.delayed(const Duration(milliseconds: 30));
        return http.Response('{"ok":true}', 200);
      }),
    );
    await expectLater(
      client.postJson('/journals', {'content': 'A private entry'}),
      throwsA(isA<ApiTimeoutException>()),
    );
    expect(calls, 1);
    client.close();
  });

  test('AI requests use a separate longer inference timeout', () async {
    final client = ApiClient(
      requestTimeout: const Duration(milliseconds: 5),
      aiRequestTimeout: const Duration(milliseconds: 120),
      client: MockClient((request) async {
        await Future<void>.delayed(const Duration(milliseconds: 30));
        return http.Response('{"ok":true}', 200);
      }),
    );
    expect((await client.postJson('/ai/reflection', {'content': 'note'}))['ok'], true);
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
