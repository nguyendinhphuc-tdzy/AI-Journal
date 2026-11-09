import 'dart:convert';

import 'package:ai_diary/core/network/api_client.dart';
import 'package:ai_diary/core/theme/app_theme.dart';
import 'package:ai_diary/features/messages/data/chat_message.dart';
import 'package:ai_diary/features/messages/data/messages_repository.dart';
import 'package:ai_diary/features/messages/messages_scope.dart';
import 'package:ai_diary/features/messages/presentation/chat_screen.dart';
import 'package:ai_diary/features/messages/presentation/messages_screen.dart';
import 'package:ai_diary/features/messages/presentation/messages_tab_icon.dart';
import 'package:ai_diary/features/messages/presentation/send_place_sheet.dart';
import 'package:ai_diary/features/social/data/app_friend.dart';
import 'package:ai_diary/features/sound/app_sound.dart';
import 'package:ai_diary/navigation/app_destinations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The interface sounds asked for, by file.
class _Sounds implements SoundBackend {
  final played = <String>[];
  @override
  Future<void> effect(String asset, double volume) async => played.add(asset);
  @override
  Future<void> music(String? asset, double volume) async {}
  @override
  Future<void> pauseMusic() async {}
  @override
  Future<void> preload(Iterable<String> assets) async {}
}

const _minhAnh = AppFriend('u1', 'Minh Anh');
const _giaHuy = AppFriend('u2', 'Gia Huy');

void _phone(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.reset);
}

/// [child] with [controller] above the app, as AuthGate does.
Future<void> _pump(WidgetTester tester, Widget child,
    {MessagesController? controller}) async {
  _phone(tester);
  final app = MaterialApp(theme: AppTheme.light, home: child);
  await tester.pumpWidget(controller == null
      ? app
      : MessagesScope(controller: controller, child: app));
  await tester.pumpAndSettle();
}

/// Unmounts everything and stops the controller's polling.
Future<void> _end(WidgetTester tester, MessagesController controller) async {
  await tester.pumpWidget(const SizedBox());
  controller.dispose();
}

MessagesController _controller(MessagesRepository repository) =>
    MessagesController(repository, poll: const Duration(hours: 1));

/// The API answering [routes] by "METHOD path" (any other: 404).
ApiClient _api(Map<String, Object> routes, List<String> calls) => ApiClient(
      accessTokenProvider: () async => 'token',
      client: MockClient((request) async {
        final path = request.url.path.replaceFirst(RegExp(r'^.*/api/v1'), '');
        final key = '${request.method} $path';
        calls.add(request.body.isEmpty ? key : '$key ${request.body}');
        final body = routes[key];
        return body == null
            ? http.Response('{"detail":"Not Found"}', 404)
            : http.Response(jsonEncode(body), 200,
                headers: {'content-type': 'application/json; charset=utf-8'});
      }),
    );

void main() {
  test('Messages from the API: each kind, and what cannot be shown is left out',
      () {
    final text = ChatMessage.fromJson({
      'id': 'm1',
      'sender_id': 'u1',
      'kind': 'text',
      'text': 'Chào bạn',
      'created_at': '2026-10-30T07:00:00Z',
      'client_id': 'c1',
    })!;
    expect(text.text, 'Chào bạn');
    expect(text.clientId, 'c1');
    final place = ChatMessage.fromJson({
      'id': 'm2',
      'sender_id': 'u1',
      'kind': 'place',
      'place': {'name': 'Tiệm bánh', 'latitude': 10.7, 'longitude': 106.7},
      'created_at': '2026-10-30T07:00:00Z',
    })!;
    expect(place.place!.name, 'Tiệm bánh');
    final memory = ChatMessage.fromJson({
      'id': 'm3',
      'sender_id': 'u1',
      'kind': 'memory_share',
      'memory_share': {
        'share_id': 's1',
        'title': 'Buồn ngủ',
        'expires_at': '2026-10-31T07:00:00Z',
      },
      'created_at': '2026-10-30T07:00:00Z',
    })!;
    expect(memory.memory!.isActive(DateTime.utc(2026, 10, 31, 6)), isTrue);
    expect(memory.memory!.isActive(DateTime.utc(2026, 10, 31, 8)), isFalse);
    for (final bad in [
      {'id': 'm4', 'sender_id': 'u1', 'kind': 'text', 'text': '  ',
        'created_at': '2026-10-30T07:00:00Z'},
      {'id': 'm5', 'sender_id': 'u1', 'kind': 'place',
        'created_at': '2026-10-30T07:00:00Z'},
      {'id': 'm6', 'sender_id': 'u1', 'kind': 'sticker', 'text': 'x',
        'created_at': '2026-10-30T07:00:00Z'},
      {'id': 'm7', 'kind': 'text', 'text': 'x'},
    ]) {
      expect(ChatMessage.fromJson(bad), isNull, reason: '$bad');
    }
    final conversation = Conversation.fromJson({
      'id': 'c1',
      'friend': {'user_id': 'u1', 'display_name': 'Minh Anh', 'username': 'ma'},
      'unread_count': 2,
      'can_send': false,
    })!;
    expect(conversation.friend.name, 'Minh Anh');
    expect(conversation.username, 'ma');
    expect(conversation.unread, 2);
    expect(conversation.canSend, isFalse, reason: 'no longer friends');
  });

  test('The server without messaging: said as unavailable, nothing invented',
      () async {
    final calls = <String>[];
    final repository =
        RemoteMessagesRepository(_api(const {}, calls), myId: 'me');
    await expectLater(
        repository.conversations(), throwsA(isA<MessagesUnavailable>()));
    await expectLater(
        repository.unreadCount(), throwsA(isA<MessagesUnavailable>()));
    await expectLater(repository.open('u1'), throwsA(isA<MessagesUnavailable>()));
    await expectLater(
        repository.sharePlace(['u1'],
            const SharedPlace(name: 'X', latitude: 1, longitude: 2)),
        throwsA(isA<MessagesUnavailable>()));
  });

  test('The API as proposed: paths and bodies', () async {
    final calls = <String>[];
    final repository = RemoteMessagesRepository(
        _api({
          'GET /conversations': [
            {
              'id': 'c1',
              'friend': {'user_id': 'u1', 'display_name': 'Minh Anh'},
              'unread_count': 1,
            }
          ],
          'GET /conversations/c1/messages': {'items': []},
          'POST /conversations/c1/messages': {
            'id': 'm9',
            'sender_id': 'me',
            'kind': 'text',
            'text': 'Chào',
            'client_id': 'k1',
            'created_at': '2026-10-30T07:00:00Z',
          },
          'POST /conversations/c1/read': {'unread_count': 0},
          'GET /messages/unread-count': {'count': 3},
          'POST /place-shares': {'conversation_ids': ['c1']},
        }, calls),
        myId: 'me');
    expect((await repository.conversations()).single.unread, 1);
    expect(await repository.messages('c1'), isEmpty);
    expect((await repository.send('c1', 'Chào', clientId: 'k1')).id, 'm9');
    await repository.markRead('c1', 'm9');
    expect(await repository.unreadCount(), 3);
    await repository.sharePlace(['u1'],
        const SharedPlace(name: 'Tiệm bánh', latitude: 10.7, longitude: 106.7));
    expect(calls, [
      'GET /conversations',
      'GET /conversations/c1/messages',
      'POST /conversations/c1/messages {"client_id":"k1","text":"Chào"}',
      'POST /conversations/c1/read {"message_id":"m9"}',
      'GET /messages/unread-count',
      'POST /place-shares {"recipient_ids":["u1"],"place":'
          '{"name":"Tiệm bánh","latitude":10.7,"longitude":106.7}}',
    ]);
  });

  testWidgets('The fifth tab is "Tin nhắn"', (tester) async {
    expect(appDestinations, hasLength(5));
    expect(appDestinations.last.label, 'Tin nhắn');
  });

  testWidgets('Guests: the tab says messages need an account', (tester) async {
    await _pump(tester, const MessagesScreen());
    expect(find.text(MessagesText.needsAccount), findsOneWidget);
    expect(find.text(MessagesText.newMessage), findsNothing);
  });

  testWidgets('Signed in, server not ready: said plainly', (tester) async {
    final controller = _controller(
        RemoteMessagesRepository(_api(const {}, []), myId: 'me'));
    await _pump(tester, const MessagesScreen(), controller: controller);
    expect(find.text(MessagesText.unavailable), findsOneWidget);
    expect(find.text(MessagesText.newMessage), findsNothing);
    await _end(tester, controller);
  });

  testWidgets(
      'New message to a friend; they answer; the unread count on the tab',
      (tester) async {
    final repository = MockMessagesRepository([_minhAnh, _giaHuy]);
    final controller = _controller(repository);
    await _pump(tester, const MessagesScreen(), controller: controller);
    expect(find.text(MessagesText.empty), findsOneWidget);

    await tester.tap(find.text(MessagesText.newMessage));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('message-to-u1')));
    await tester.pumpAndSettle();
    expect(find.byType(ChatScreen), findsOneWidget);
    expect(find.text(ChatText.empty), findsOneWidget);
    await tester.enterText(find.byType(TextField), '  Đi cà phê không?  ');
    await tester.pump();
    await tester.tap(find.byTooltip(ChatText.sendTooltip));
    await tester.pumpAndSettle();
    expect(find.text('Đi cà phê không?'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty);

    // Back on the list: the conversation, newest first.
    await tester.tap(find.byTooltip(ChatText.backTooltip));
    await tester.pumpAndSettle();
    expect(find.text('Minh Anh'), findsOneWidget);
    expect(find.text('Bạn: Đi cà phê không?'), findsOneWidget);

    // They answer: the poll counts it, the row and the tab show it.
    repository.reply('u1', 'Đi luôn!');
    await controller.refresh();
    await tester.pumpAndSettle();
    expect(controller.unread, 1);
    expect(find.text('Đi luôn!'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    await tester.pumpWidget(MessagesScope(
        controller: controller,
        child: const MaterialApp(home: Scaffold(body: MessagesTabIcon()))));
    expect(find.byType(Badge), findsOneWidget);

    // Opened: read, and the count goes back to none.
    await _pump(tester, const MessagesScreen(), controller: controller);
    await tester.tap(find.text('Minh Anh'));
    await tester.pumpAndSettle();
    expect(find.text('Đi luôn!'), findsOneWidget);
    expect(controller.unread, 0);
    await _end(tester, controller);
  });

  testWidgets('A failed send stays, marked, and goes once on retry',
      (tester) async {
    final repository = MockMessagesRepository([_minhAnh])..failNext = true;
    final conversation = await repository.open('u1');
    await _pump(tester,
        ChatScreen(repository: repository, conversation: conversation));
    await tester.enterText(find.byType(TextField), 'Alo');
    await tester.pump();
    await tester.tap(find.byTooltip(ChatText.sendTooltip));
    await tester.pumpAndSettle();
    expect(find.text(ChatText.failed), findsOneWidget);
    expect(await repository.messages(conversation.id), isEmpty);
    await tester.tap(find.text('Alo'));
    await tester.pumpAndSettle();
    expect(find.text(ChatText.failed), findsNothing);
    expect(await repository.messages(conversation.id), hasLength(1));
    expect(find.text('Alo'), findsOneWidget);
  });

  testWidgets('New messages arrive while the conversation is open',
      (tester) async {
    final repository = MockMessagesRepository([_minhAnh]);
    final conversation = await repository.open('u1');
    await _pump(
        tester,
        ChatScreen(
            repository: repository,
            conversation: conversation,
            poll: const Duration(seconds: 5)));
    repository.reply('u1', 'Bạn ơi');
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.text('Bạn ơi'), findsOneWidget);
  });

  testWidgets('No longer friends: the history stays, read-only',
      (tester) async {
    final repository = MockMessagesRepository([_minhAnh]);
    repository.reply('u1', 'Hẹn gặp lại');
    repository.ended.add('u1');
    final conversation = await repository.open('u1');
    expect(conversation.canSend, isFalse);
    await _pump(tester,
        ChatScreen(repository: repository, conversation: conversation));
    expect(find.text('Hẹn gặp lại'), findsOneWidget);
    expect(find.text(ChatText.readOnly), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('Place cards show; 24-hour moments stay out of the chat',
      (tester) async {
    final repository = MockMessagesRepository([_minhAnh]);
    final conversation = await repository.open('u1');
    final messages = await repository.messages(conversation.id);
    expect(messages, isEmpty);
    final now = DateTime.now();
    final chat = _FixedMessages(repository, [
      ChatMessage(
          id: 'p',
          senderId: 'u1',
          sentAt: now,
          kind: MessageKind.place,
          place: const SharedPlace(
              name: 'Tiệm bánh cô Hai',
              category: 'Ăn uống',
              latitude: 10.77,
              longitude: 106.70)),
      ChatMessage(
          id: 'a',
          senderId: 'u1',
          sentAt: now,
          kind: MessageKind.memory,
          memory: SharedMemoryCard(
              shareId: 's1',
              title: 'Buồn ngủ',
              expiresAt: now.add(const Duration(hours: 3)))),
      ChatMessage(
          id: 'e',
          senderId: 'u1',
          sentAt: now,
          kind: MessageKind.memory,
          memory: SharedMemoryCard(
              shareId: 's0',
              title: 'Bí mật cũ',
              expiresAt: now.subtract(const Duration(minutes: 1)))),
    ]);
    await _pump(tester, ChatScreen(repository: chat, conversation: conversation));
    expect(find.text('Tiệm bánh cô Hai'), findsOneWidget);
    expect(find.text('Ăn uống'), findsOneWidget);
    // 24-hour moments are not chat messages (they are on the map and in
    // Khoảnh khắc): older ones the server put here are left out...
    expect(find.text('Buồn ngủ'), findsNothing);
    expect(find.text('Bí mật cũ'), findsNothing);
    expect(find.text(ChatText.memoryExpired), findsNothing);
    // ...but read, so the tab's count is not stuck on them.
    expect(chat.readUpTo, 'e');
  });

  testWidgets('Send a place: pick friends; each gets it as a message',
      (tester) async {
    final repository = MockMessagesRepository([_minhAnh, _giaHuy]);
    List<String>? sent;
    await _pump(
        tester,
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async => sent = await sendPlaceToFriends(
                  context,
                  repository,
                  const SharedPlace(
                      name: 'Tiệm bánh', latitude: 10.7, longitude: 106.7)),
              child: const Text('Mở'),
            ),
          ),
        ));
    await tester.tap(find.text('Mở'));
    await tester.pumpAndSettle();
    expect(find.text(SendPlaceText.help), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('send-place-to-u2')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(SendPlaceText.send));
    await tester.pumpAndSettle();
    expect(sent, ['Gia Huy']);
    final list = await repository.conversations();
    expect(list.single.friend.id, 'u2');
    expect(list.single.lastMessage!.place!.name, 'Tiệm bánh');
  });

  testWidgets('Send a place without messaging on the server: says so',
      (tester) async {
    final calls = <String>[];
    final repository = RemoteMessagesRepository(
        _api({
          'GET /friends': [
            {'user_id': 'u1', 'status': 'accepted', 'display_name': 'Minh Anh'}
          ],
        }, calls),
        myId: 'me');
    Object? error;
    await _pump(
        tester,
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                try {
                  await sendPlaceToFriends(context, repository,
                      const SharedPlace(name: 'X', latitude: 1, longitude: 2));
                } catch (e) {
                  error = e;
                }
              },
              child: const Text('Mở'),
            ),
          ),
        ));
    await tester.tap(find.text('Mở'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('send-place-to-u1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(SendPlaceText.send));
    await tester.pumpAndSettle();
    expect(error, isA<SendPlaceFailed>());
    expect((error! as SendPlaceFailed).message, SendPlaceText.unavailable);
  });
  test('Recall, delete one, delete a chat: the API paths', () async {
    final calls = <String>[];
    final repository = RemoteMessagesRepository(
        _api({
          'POST /conversations/c1/messages/m1/recall': {
            'id': 'm1',
            'sender_id': 'me',
            'kind': 'text',
            'text': null,
            'recalled': true,
            'created_at': '2026-10-30T07:00:00Z',
          },
          'DELETE /conversations/c1/messages/m2': <String, Object>{},
          'DELETE /conversations/c1': <String, Object>{},
        }, calls),
        myId: 'me');
    final recalled = await repository.recall('c1', 'm1');
    expect(recalled.recalled, isTrue);
    expect(recalled.text, isNull);
    await repository.hide('c1', 'm2');
    await repository.deleteConversation('c1');
    expect(calls, [
      'POST /conversations/c1/messages/m1/recall {}',
      'DELETE /conversations/c1/messages/m2',
      'DELETE /conversations/c1',
    ]);
  });

  testWidgets('Hold a message: recall mine for both; delete one for me',
      (tester) async {
    final repository = MockMessagesRepository([_minhAnh]);
    final conversation = await repository.open('u1');
    repository.reply('u1', 'Chào Li');
    await repository.send(conversation.id, 'Nhắn nhầm', clientId: 'k1');
    await _pump(tester,
        ChatScreen(repository: repository, conversation: conversation));

    await tester.longPress(find.text('Nhắn nhầm'));
    await tester.pumpAndSettle();
    expect(find.text(ChatText.copy), findsOneWidget);
    await tester.tap(find.text(ChatText.recall));
    await tester.pumpAndSettle();
    expect(find.text(ChatText.recallTitle), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, ChatText.recall));
    await tester.pumpAndSettle();
    expect(find.text('Nhắn nhầm'), findsNothing);
    expect(find.text(ChatText.recalled), findsOneWidget);

    // Their message: no recall, only delete for me.
    await tester.longPress(find.text('Chào Li'));
    await tester.pumpAndSettle();
    expect(find.text(ChatText.recall), findsNothing);
    await tester.tap(find.text(ChatText.hide));
    await tester.pumpAndSettle();
    expect(find.text('Chào Li'), findsNothing);
    expect(await repository.messages(conversation.id), hasLength(1),
        reason: 'only the recalled one is left for me');
  });

  testWidgets('Swipe a conversation away: asked first, then gone for me',
      (tester) async {
    final repository = MockMessagesRepository([_minhAnh]);
    repository.reply('u1', 'Alo');
    final controller = _controller(repository);
    await _pump(tester, const MessagesScreen(), controller: controller);
    expect(find.text('Minh Anh'), findsOneWidget);
    await tester.drag(find.text('Minh Anh'), const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(find.text(MessagesText.deleteTitle('Minh Anh')), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, MessagesText.deleteLabel));
    await tester.pumpAndSettle();
    expect(find.text('Minh Anh'), findsNothing);
    expect(await repository.conversations(), isEmpty);
    // A new message brings it back, from there on.
    repository.reply('u1', 'Còn đó không?');
    final list = await repository.conversations();
    expect(list.single.lastMessage!.text, 'Còn đó không?');
    expect(await repository.messages(list.single.id), hasLength(1));
    await _end(tester, controller);
  });

  group('Sounds', () {
    late _Sounds sounds;
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      sounds = _Sounds();
      AppSound.backend = sounds;
      await AppSound.instance.refresh();
    });
    tearDown(() => AppSound.backend = null);

    test('A new message chimes once; not for what was there at start',
        () async {
      var now = DateTime(2026, 10, 30, 9);
      final repository = MockMessagesRepository([_minhAnh]);
      repository.reply('u1', 'Tin cũ');
      final controller = MessagesController(repository,
          poll: const Duration(hours: 1), clock: () => now);
      addTearDown(controller.dispose);
      await controller.refresh();
      expect(controller.unread, 1);
      expect(sounds.played, isEmpty, reason: 'already there');
      repository.reply('u1', 'Tin mới');
      await controller.refresh();
      expect(sounds.played, ['message_in.wav']);
      // The open conversation noticed it too: one chime, not two.
      controller.chime();
      expect(sounds.played, hasLength(1));
      now = now.add(MessagesController.chimeGap);
      repository.reply('u1', 'Tin nữa');
      await controller.refresh();
      expect(sounds.played, ['message_in.wav', 'message_in.wav']);
      await controller.refresh();
      expect(sounds.played, hasLength(2), reason: 'nothing new');
    });

    testWidgets('Sending pops; a message arriving in the open chat chimes',
        (tester) async {
      final repository = MockMessagesRepository([_minhAnh]);
      final conversation = await repository.open('u1');
      var chimes = 0;
      await _pump(
          tester,
          ChatScreen(
              repository: repository,
              conversation: conversation,
              onIncoming: () => chimes++));
      await tester.enterText(find.byType(TextField), 'Alo');
      await tester.pump();
      await tester.tap(find.byTooltip(ChatText.sendTooltip));
      await tester.pumpAndSettle();
      expect(sounds.played, ['message_out.wav']);
      expect(chimes, 0, reason: 'my own message');
      repository.reply('u1', 'Nghe nè');
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(chimes, 1);
      expect(find.text('Hôm nay'), findsOneWidget, reason: 'a day line');
    });
  });
}

/// [repository] with these messages in every conversation (cards).
class _FixedMessages implements MessagesRepository {
  _FixedMessages(this.repository, this.fixed);

  final MessagesRepository repository;
  final List<ChatMessage> fixed;

  @override
  String get myId => repository.myId;
  @override
  Future<List<AppFriend>> friends() => repository.friends();
  @override
  Future<List<Conversation>> conversations() => repository.conversations();
  @override
  Future<Conversation> open(String friendId) => repository.open(friendId);
  @override
  Future<List<ChatMessage>> messages(String conversationId,
          {String? after}) async =>
      after == null ? fixed : const [];
  @override
  Future<ChatMessage> send(String conversationId, String text,
          {required String clientId}) =>
      repository.send(conversationId, text, clientId: clientId);
  String? readUpTo;

  @override
  Future<void> markRead(String conversationId, String messageId) async =>
      readUpTo = messageId;
  @override
  Future<int> unreadCount() async => 0;
  @override
  Future<void> sharePlace(List<String> friendIds, SharedPlace place) =>
      repository.sharePlace(friendIds, place);
  @override
  Future<void> deleteConversation(String conversationId) =>
      repository.deleteConversation(conversationId);
  @override
  Future<ChatMessage> recall(String conversationId, String messageId) =>
      repository.recall(conversationId, messageId);
  @override
  Future<void> hide(String conversationId, String messageId) =>
      repository.hide(conversationId, messageId);
}
