import 'dart:convert';

import 'package:ai_diary/core/network/api_client.dart';
import 'package:ai_diary/core/theme/app_theme.dart';
import 'package:ai_diary/features/social/presentation/real_friends_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

typedef _T = FriendsText;

/// A server with one profile and a friends list; every request is kept.
class _Server {
  _Server({this.patchStatus = 200});

  final int patchStatus;
  final calls = <String>[];
  var profile = <String, Object?>{
    'user_id': 'me',
    'display_name': 'li',
    'username': 'lili',
    'discoverable': false,
  };
  var friends = <Map<String, Object?>>[
    {'user_id': 'u1', 'status': 'accepted', 'direction': 'outgoing',
      'display_name': 'Tường Vy', 'username': 'tdzy'},
    {'user_id': 'u2', 'status': 'pending', 'direction': 'incoming',
      'display_name': 'Minh Anh', 'username': 'minhanh'},
    {'user_id': 'u3', 'status': 'pending', 'direction': 'outgoing',
      'display_name': 'Gia Huy'},
  ];

  late final api = ApiClient(
    accessTokenProvider: () async => 'token',
    client: MockClient((request) async {
      final path = request.url.path.replaceFirst(RegExp(r'^.*/api/v1'), '');
      final query = request.url.query.isEmpty ? '' : '?${request.url.query}';
      calls.add('${request.method} $path$query ${request.body}'.trim());
      http.Response json(Object body, [int status = 200]) => http.Response(
          jsonEncode(body), status,
          headers: {'content-type': 'application/json; charset=utf-8'});
      switch ('${request.method} $path') {
        case 'GET /me':
          return json(profile);
        case 'PATCH /me':
          if (patchStatus != 200) return json({}, patchStatus);
          profile = {...profile, ...jsonDecode(request.body) as Map};
          return json(profile);
        case 'GET /friends':
          return json(friends);
        case 'GET /friends/discover':
          return json([
            {'user_id': 'u9', 'display_name': 'Bảo Long', 'username': 'baolong'}
          ]);
        case 'POST /friends/requests':
          friends = [
            ...friends,
            {'user_id': 'u9', 'status': 'pending', 'direction': 'outgoing',
              'display_name': 'Bảo Long', 'username': 'baolong'},
          ];
          return json({'user_id': 'u9'}, 201);
        case 'POST /friends/u2/accept':
          friends = [
            for (final f in friends)
              f['user_id'] == 'u2' ? {...f, 'status': 'accepted'} : f
          ];
          return json({'user_id': 'u2'});
      }
      if (request.method == 'DELETE' && path.startsWith('/friends/')) {
        final id = path.substring('/friends/'.length);
        friends = [for (final f in friends) if (f['user_id'] != id) f];
        return http.Response('', 204);
      }
      return http.Response('{}', 404);
    }),
  );
}

Future<void> _open(WidgetTester tester, _Server server) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 1400);
  addTearDown(tester.view.reset);
  addTearDown(server.api.close);
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.light,
    home: RealFriendsScreen(auth: null, api: server.api),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Requests first, then friends, then requests sent',
      (tester) async {
    final server = _Server();
    await _open(tester, server);
    expect(find.text(_T.summary(1, 1)), findsOneWidget);
    expect(find.text(_T.incomingTitle(1)), findsOneWidget);
    expect(find.text(_T.friendsTitle(1)), findsOneWidget);
    expect(find.text(_T.outgoingTitle(1)), findsOneWidget);
    final incoming = tester.getTopLeft(find.text('Minh Anh')).dy;
    final friend = tester.getTopLeft(find.text('Tường Vy')).dy;
    final sent = tester.getTopLeft(find.text('Gia Huy')).dy;
    expect(incoming < friend && friend < sent, isTrue);
    expect(find.text('@lili'), findsOneWidget, reason: 'the profile card');
    expect(find.text(_T.hidden), findsOneWidget);
  });

  testWidgets('Accept a request: they move to friends', (tester) async {
    final server = _Server();
    await _open(tester, server);
    await tester.tap(find.text(_T.accept));
    await tester.pumpAndSettle();
    expect(server.calls, contains('POST /friends/u2/accept {}'));
    expect(find.text(_T.friendsTitle(2)), findsOneWidget);
    expect(find.text(_T.accept), findsNothing);
    expect(find.text(_T.accepted), findsOneWidget);
  });

  testWidgets('Search: too short, then people; "Kết bạn" turns into "Đã gửi"',
      (tester) async {
    final server = _Server();
    await _open(tester, server);
    await tester.enterText(find.byType(TextField), 'ba');
    await tester.pump();
    expect(find.text(_T.searchShort), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'bao');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(server.calls, contains('GET /friends/discover?q=bao'));
    expect(find.text('Bảo Long'), findsOneWidget);
    await tester.tap(find.text(_T.addFriend));
    await tester.pumpAndSettle();
    expect(server.calls.where((c) => c.startsWith('POST /friends/requests')),
        hasLength(1));
    expect(find.text(_T.requested), findsOneWidget);
    expect(find.text(_T.addFriend), findsNothing);
  });

  testWidgets('Search finding only friends says so, not "nobody"',
      (tester) async {
    final server = _Server();
    server.friends = [
      ...server.friends,
      {'user_id': 'u9', 'status': 'accepted', 'direction': 'outgoing',
        'display_name': 'Bảo Long'},
    ];
    await _open(tester, server);
    await tester.enterText(find.byType(TextField), 'bao');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text(_T.searchKnown), findsOneWidget);
    expect(find.text(_T.searchNone), findsNothing);
  });

  testWidgets('Unfriend asks first; "Giữ lại" keeps them', (tester) async {
    final server = _Server();
    await _open(tester, server);
    await tester.tap(find.byTooltip(_T.moreTooltip('Tường Vy')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(_T.unfriend).last);
    await tester.pumpAndSettle();
    expect(find.text(_T.unfriendTitle('Tường Vy')), findsOneWidget);
    await tester.tap(find.text('Giữ lại'));
    await tester.pumpAndSettle();
    expect(server.calls.where((c) => c.startsWith('DELETE')), isEmpty);
    await tester.tap(find.byTooltip(_T.moreTooltip('Tường Vy')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(_T.unfriend).last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, _T.unfriend));
    await tester.pumpAndSettle();
    expect(server.calls, contains('DELETE /friends/u1'));
    expect(find.text(_T.friendsTitle(0)), findsOneWidget);
  });

  testWidgets(
      'Profile: name, @username and "tìm thấy" saved together; nothing lost',
      (tester) async {
    final server = _Server();
    await _open(tester, server);
    await tester.tap(find.text(_T.edit));
    await tester.pumpAndSettle();
    // The search box is a field too: the sheet's are name, then @username.
    final username = find.byType(TextField).at(2);
    await tester.enterText(username, 'Li Li!');
    await tester.tap(find.byType(Switch));
    await tester.pump();
    await tester.tap(find.text(_T.save));
    await tester.pumpAndSettle();
    expect(find.text(_T.usernameInvalid), findsOneWidget);
    expect(server.calls.where((c) => c.startsWith('PATCH')), isEmpty);
    await tester.enterText(username, '@LiLi_2');
    await tester.pump();
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue,
        reason: 'the switch kept what was chosen');
    await tester.tap(find.text(_T.save));
    await tester.pumpAndSettle();
    final patch = server.calls.singleWhere((c) => c.startsWith('PATCH'));
    expect(jsonDecode(patch.substring('PATCH /me '.length)), {
      'display_name': 'li',
      'username': 'lili_2',
      'discoverable': true,
    });
    expect(find.text(_T.saved), findsOneWidget);
    expect(find.text('@lili_2'), findsOneWidget);
    expect(find.text(_T.visible), findsOneWidget);
  });

  testWidgets('Profile: a username already taken is said under the field',
      (tester) async {
    final server = _Server(patchStatus: 409);
    await _open(tester, server);
    await tester.tap(find.text(_T.edit));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(2), 'tdzy');
    await tester.tap(find.text(_T.save));
    await tester.pumpAndSettle();
    expect(find.text(_T.usernameTaken), findsOneWidget);
    expect(find.text(_T.editTitle), findsOneWidget, reason: 'still open');
  });
}
