import 'dart:async';
import 'dart:convert';

import 'package:ai_diary/core/network/api_client.dart';
import 'package:ai_diary/features/notifications/data/device_registration.dart';
import 'package:ai_diary/features/notifications/data/push_platform.dart';
import 'package:ai_diary/features/notifications/data/push_target.dart';
import 'package:ai_diary/features/notifications/push_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Firebase as the controller sees it, driven by the test.
class _FakePlatform implements PushPlatform {
  _FakePlatform({this.available = true, this.allow = true, this.launch});

  final bool available;
  final bool allow;
  final Map<String, Object?>? launch;
  var asked = 0;
  String? current = 'token-${'a' * 40}';

  final refresh = StreamController<String>.broadcast();
  final taps = StreamController<Map<String, Object?>>.broadcast();
  final arrivals = StreamController<Map<String, Object?>>.broadcast();

  @override
  Future<bool> start() async => available;
  @override
  Future<bool> requestPermission() async {
    asked++;
    return allow;
  }

  @override
  Future<String?> token() async => current;
  @override
  Stream<String> get tokenRefresh => refresh.stream;
  @override
  Future<Map<String, Object?>?> openedAtLaunch() async => launch;
  @override
  Stream<Map<String, Object?>> get opened => taps.stream;
  @override
  Stream<Map<String, Object?>> get foreground => arrivals.stream;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('What a notification opens, by its type', () {
    expect(PushTarget.fromData({'type': 'message', 'conversation_id': 'c1'}),
        const OpenChat('c1'));
    expect(PushTarget.fromData({'type': 'message'}), const OpenMessages());
    expect(PushTarget.fromData({'type': 'friend_request', 'sender_id': 'u'}),
        const OpenFriends());
    expect(PushTarget.fromData({'type': 'friend_accepted', 'friend_id': 'u'}),
        const OpenFriends());
    expect(PushTarget.fromData({'type': 'memory_share', 'share_id': 's1'}),
        const OpenMoment('s1'));
    expect(PushTarget.fromData({'type': 'memory_share'}), isNull);
    expect(PushTarget.fromData({'type': 'promo'}), isNull);
    expect(PushTarget.fromData({}), isNull);
  });

  group('PushController', () {
    late List<String> calls;
    late ApiClient api;
    late List<PushTarget> opened, arrived;

    setUp(() {
      calls = [];
      opened = [];
      arrived = [];
      api = ApiClient(
        accessTokenProvider: () async => 'session',
        client: MockClient((request) async {
          final path = request.url.path.replaceFirst(RegExp(r'^.*/api/v1'), '');
          calls.add('${request.method} $path ${request.body}');
          return http.Response(
              request.method == 'POST' ? '{"registered": true}' : '',
              request.method == 'POST' ? 200 : 204,
              headers: {'content-type': 'application/json'});
        }),
      );
    });
    tearDown(() => api.close());

    PushController controller(_FakePlatform platform) => PushController(
          platform: platform,
          registration: DeviceRegistration(api),
          onOpen: opened.add,
          onForeground: arrived.add,
        );

    test('Signed in: asks once, registers the token with one installation id',
        () async {
      final platform = _FakePlatform();
      final push = controller(platform);
      addTearDown(push.dispose);
      await push.start();
      await push.start();
      expect(platform.asked, 1);
      expect(push.allowed, isTrue);
      expect(calls, hasLength(1));
      final first = jsonDecode(calls.single.split(' ').skip(2).join(' '))
          as Map<String, dynamic>;
      expect(calls.single, startsWith('POST /devices '));
      expect(first['token'], platform.current);
      expect(first['platform'], 'android');
      expect((first['installation_id'] as String).length, 32);

      // The token rotates: the same installation tells the server again.
      platform.refresh.add('token-${'b' * 40}');
      await pumpEventQueue();
      final second = jsonDecode(calls.last.split(' ').skip(2).join(' '))
          as Map<String, dynamic>;
      expect(second['token'], 'token-${'b' * 40}');
      expect(second['installation_id'], first['installation_id']);
    });

    test('Taps open their screen; ones while open are only said', () async {
      final platform = _FakePlatform(
          launch: {'type': 'message', 'conversation_id': 'c1'});
      final push = controller(platform);
      addTearDown(push.dispose);
      await push.start();
      expect(opened, [const OpenChat('c1')], reason: 'opened the app');
      platform.taps.add({'type': 'friend_request', 'sender_id': 'u2'});
      platform.arrivals.add({'type': 'memory_share', 'share_id': 's9'});
      platform.taps.add({'type': 'unknown'});
      await pumpEventQueue();
      expect(opened, [const OpenChat('c1'), const OpenFriends()]);
      expect(arrived, [const OpenMoment('s9')]);
    });

    test('Notifications refused: said as not allowed, the app goes on',
        () async {
      final push = controller(_FakePlatform(allow: false));
      addTearDown(push.dispose);
      await push.start();
      expect(push.allowed, isFalse);
      // The token is still known to the server (no notification shows until
      // the user allows them in Settings).
      expect(calls.single, startsWith('POST /devices '));
    });

    test('Signing out stops the token; no push where there is none', () async {
      final platform = _FakePlatform();
      final push = controller(platform);
      addTearDown(push.dispose);
      await push.start();
      await push.beforeSignOut();
      expect(calls.last, 'DELETE /devices {"token":"${platform.current}"}');

      calls.clear();
      final none = controller(_FakePlatform(available: false));
      addTearDown(none.dispose);
      await none.start();
      await none.beforeSignOut();
      expect(calls, isEmpty, reason: 'no Firebase: nothing asked or sent');
    });
  });
}
