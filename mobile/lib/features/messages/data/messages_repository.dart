import '../../../core/network/api_client.dart';
import '../../social/data/app_friend.dart';
import 'chat_message.dart';

/// The server has no messaging yet (its routes answer 404): nothing was
/// sent, and screens say so instead of an error.
class MessagesUnavailable implements Exception {
  const MessagesUnavailable();
}

/// Messages between friends on the app: one conversation per friend, text,
/// shared places and 24-hour memory posts. Proposal for the API in
/// `features/messages/README.md`.
abstract interface class MessagesRepository {
  /// The signed-in account, to tell its messages from the friend's.
  String get myId;

  /// Accepted friends, to send a place to.
  Future<List<AppFriend>> friends();

  /// Newest activity first.
  Future<List<Conversation>> conversations();

  /// The conversation with [friendId], made on first use.
  Future<Conversation> open(String friendId);

  /// Oldest first. With [after], only messages newer than that one.
  Future<List<ChatMessage>> messages(String conversationId, {String? after});

  /// Sends [text]; the same [clientId] again never posts it twice.
  Future<ChatMessage> send(String conversationId, String text,
      {required String clientId});

  /// Everything up to [messageId] has been seen.
  Future<void> markRead(String conversationId, String messageId);

  /// Unread messages across all conversations, for the tab's badge.
  Future<int> unreadCount();

  /// One place message to each of [friendIds].
  Future<void> sharePlace(List<String> friendIds, SharedPlace place);
}

/// The API proposed in `features/messages/README.md`, under `/api/v1`.
class RemoteMessagesRepository implements MessagesRepository {
  RemoteMessagesRepository(this.api, {required this.myId});

  final ApiClient api;
  @override
  final String myId;

  /// A route the server does not have yet answers 404 (or 405).
  Future<T> _call<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on ApiException catch (error) {
      if (error.statusCode == 404 || error.statusCode == 405) {
        throw const MessagesUnavailable();
      }
      rethrow;
    }
  }

  @override
  Future<List<AppFriend>> friends() async => List.unmodifiable(
      (await api.getList('/friends', requireAuth: true))
          .map(AppFriend.fromApi)
          .nonNulls);

  @override
  Future<List<Conversation>> conversations() => _call(() async =>
      List.unmodifiable((await api.getList('/conversations', requireAuth: true))
          .map(Conversation.fromJson)
          .nonNulls));

  @override
  Future<Conversation> open(String friendId) => _call(() async {
        final conversation = Conversation.fromJson(await api.postJson(
            '/conversations', {'friend_id': friendId},
            requireAuth: true));
        if (conversation == null) throw const FormatException('conversation');
        return conversation;
      });

  @override
  Future<List<ChatMessage>> messages(String conversationId,
      {String? after}) async {
    final query = after == null ? '' : '?after=${Uri.encodeComponent(after)}';
    final page = await api.getJson(
        '/conversations/${Uri.encodeComponent(conversationId)}/messages$query',
        requireAuth: true);
    final items = page['items'];
    return items is List
        ? List.unmodifiable(items.map(ChatMessage.fromJson).nonNulls)
        : const [];
  }

  @override
  Future<ChatMessage> send(String conversationId, String text,
      {required String clientId}) async {
    final message = ChatMessage.fromJson(await api.postJson(
        '/conversations/${Uri.encodeComponent(conversationId)}/messages',
        {'client_id': clientId, 'text': text},
        requireAuth: true));
    if (message == null) throw const FormatException('message');
    return message;
  }

  @override
  Future<void> markRead(String conversationId, String messageId) =>
      api.postJson('/conversations/${Uri.encodeComponent(conversationId)}/read',
          {'message_id': messageId},
          requireAuth: true);

  @override
  Future<int> unreadCount() => _call(() async =>
      ((await api.getJson('/messages/unread-count', requireAuth: true))['count']
                  as num?)
              ?.toInt() ??
          0);

  @override
  Future<void> sharePlace(List<String> friendIds, SharedPlace place) =>
      _call(() => api.postJson(
          '/place-shares', {'recipient_ids': friendIds, 'place': place.toJson()},
          requireAuth: true));
}

/// Conversations kept in memory for the run (tests): [friends] write back
/// only when [reply] is called.
class MockMessagesRepository implements MessagesRepository {
  MockMessagesRepository(this._friends,
      {this.myId = 'me', DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  final List<AppFriend> _friends;
  @override
  final String myId;
  final DateTime Function() _clock;

  /// The next [send] fails, to see that state.
  var failNext = false;

  /// Friend ids who are no longer friends: their conversation is read-only.
  final ended = <String>{};

  final _byFriend = <String, String>{};
  final _messages = <String, List<ChatMessage>>{};
  final _read = <String, int>{};
  var _next = 0;

  String _conversationFor(String friendId) {
    final id = _byFriend.putIfAbsent(friendId, () => 'c-$friendId');
    _messages.putIfAbsent(id, () => []);
    return id;
  }

  Conversation _conversation(String id) {
    final friendId =
        _byFriend.entries.firstWhere((entry) => entry.value == id).key;
    final friend = _friends.firstWhere((f) => f.id == friendId,
        orElse: () => AppFriend(friendId, 'Người dùng AI-Journal'));
    final list = _messages[id] ?? const <ChatMessage>[];
    final seen = _read[id] ?? 0;
    return Conversation(
      id: id,
      friend: friend,
      lastMessage: list.isEmpty ? null : list.last,
      unread: list.skip(seen).where((m) => m.senderId != myId).length,
      canSend: !ended.contains(friendId) &&
          _friends.any((f) => f.id == friendId),
    );
  }

  ChatMessage _add(String conversationId, ChatMessage Function(String id) of) {
    final message = of('m${_next++}');
    _messages[conversationId]!.add(message);
    return message;
  }

  /// [friendId] writes [text] to the user.
  ChatMessage reply(String friendId, String text) =>
      _add(_conversationFor(friendId),
          (id) => ChatMessage(id: id, senderId: friendId, sentAt: _clock(), text: text));

  @override
  Future<List<AppFriend>> friends() async => List.unmodifiable(
      _friends.where((f) => !ended.contains(f.id)));

  @override
  Future<List<Conversation>> conversations() async {
    final list = [
      for (final id in _byFriend.values)
        if (_messages[id]!.isNotEmpty) _conversation(id)
    ]..sort((a, b) => b.lastMessage!.sentAt.compareTo(a.lastMessage!.sentAt));
    return list;
  }

  @override
  Future<Conversation> open(String friendId) async =>
      _conversation(_conversationFor(friendId));

  @override
  Future<List<ChatMessage>> messages(String conversationId,
      {String? after}) async {
    final list = _messages[conversationId] ?? const <ChatMessage>[];
    if (after == null) return List.unmodifiable(list);
    final at = list.indexWhere((m) => m.id == after);
    return List.unmodifiable(at < 0 ? list : list.skip(at + 1));
  }

  @override
  Future<ChatMessage> send(String conversationId, String text,
      {required String clientId}) async {
    if (failNext) {
      failNext = false;
      throw const ApiException(503);
    }
    if (!_conversation(conversationId).canSend) throw const ApiException(403);
    final list = _messages[conversationId]!;
    for (final m in list) {
      if (m.clientId == clientId) return m;
    }
    return _add(
        conversationId,
        (id) => ChatMessage(
            id: id,
            senderId: myId,
            sentAt: _clock(),
            text: text,
            clientId: clientId));
  }

  @override
  Future<void> markRead(String conversationId, String messageId) async {
    final list = _messages[conversationId] ?? const <ChatMessage>[];
    final at = list.indexWhere((m) => m.id == messageId);
    if (at >= 0) _read[conversationId] = at + 1;
  }

  @override
  Future<int> unreadCount() async =>
      (await conversations()).fold<int>(0, (sum, c) => sum + c.unread);

  @override
  Future<void> sharePlace(List<String> friendIds, SharedPlace place) async {
    for (final friendId in friendIds) {
      _add(
          _conversationFor(friendId),
          (id) => ChatMessage(
              id: id,
              senderId: myId,
              sentAt: _clock(),
              kind: MessageKind.place,
              place: place));
    }
  }
}
