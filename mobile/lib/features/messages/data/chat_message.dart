import 'package:flutter/foundation.dart';

import '../../social/data/app_friend.dart';

/// What a message carries: words, a 24-hour memory post, or a saved place.
enum MessageKind { text, memory, place }

/// A saved place as the sender chose to send it: a snapshot, never their
/// private notes on it.
@immutable
class SharedPlace {
  const SharedPlace({
    required this.name,
    required this.latitude,
    required this.longitude,
    this.category,
    this.note,
  });

  final String name;
  final double latitude;
  final double longitude;
  final String? category;

  /// A line the sender wrote for the friend, if any.
  final String? note;

  Map<String, Object?> toJson() => {
        'name': name,
        'latitude': latitude,
        'longitude': longitude,
        if (category != null) 'category': category,
        if (note != null) 'note': note,
      };

  static SharedPlace? fromJson(Object? json) {
    if (json is! Map) return null;
    final name = json['name'];
    final lat = json['latitude'];
    final lon = json['longitude'];
    if (name is! String || lat is! num || lon is! num) return null;
    return SharedPlace(
      name: name,
      latitude: lat.toDouble(),
      longitude: lon.toDouble(),
      category: json['category'] as String?,
      note: json['note'] as String?,
    );
  }
}

/// A 24-hour memory post, as it was shared: gone once it expires.
@immutable
class SharedMemoryCard {
  const SharedMemoryCard({
    required this.shareId,
    required this.expiresAt,
    this.title,
    this.text,
    this.placeLabel,
  });

  final String shareId;
  final DateTime expiresAt;
  final String? title;
  final String? text;
  final String? placeLabel;

  bool isActive(DateTime now) => now.isBefore(expiresAt);

  static SharedMemoryCard? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['share_id'];
    final expires = DateTime.tryParse('${json['expires_at']}');
    if (id is! String || expires == null) return null;
    return SharedMemoryCard(
      shareId: id,
      expiresAt: expires,
      title: json['title'] as String?,
      text: json['text'] as String?,
      placeLabel: json['place_label'] as String?,
    );
  }
}

/// Where a message the user wrote stands on this device.
enum SendState { sent, sending, failed }

@immutable
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.sentAt,
    this.kind = MessageKind.text,
    this.text,
    this.place,
    this.memory,
    this.clientId,
    this.state = SendState.sent,
  });

  /// The server's id; a local one (`local:…`) while sending.
  final String id;
  final String senderId;
  final DateTime sentAt;
  final MessageKind kind;
  final String? text;
  final SharedPlace? place;
  final SharedMemoryCard? memory;

  /// Made by the device for each message it sends, so a retry after a lost
  /// answer never posts it twice.
  final String? clientId;
  final SendState state;

  ChatMessage copyWith({SendState? state}) => ChatMessage(
        id: id,
        senderId: senderId,
        sentAt: sentAt,
        kind: kind,
        text: text,
        place: place,
        memory: memory,
        clientId: clientId,
        state: state ?? this.state,
      );

  /// One message from the API; null when it cannot be shown.
  static ChatMessage? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final sender = json['sender_id'];
    final at = DateTime.tryParse('${json['created_at']}');
    if (id is! String || sender is! String || at == null) return null;
    final kind = switch (json['kind']) {
      'text' => MessageKind.text,
      'memory_share' => MessageKind.memory,
      'place' => MessageKind.place,
      _ => null,
    };
    if (kind == null) return null;
    final message = ChatMessage(
      id: id,
      senderId: sender,
      sentAt: at,
      kind: kind,
      text: json['text'] as String?,
      place: SharedPlace.fromJson(json['place']),
      memory: SharedMemoryCard.fromJson(json['memory_share']),
      clientId: json['client_id'] as String?,
    );
    return switch (kind) {
      MessageKind.text when (message.text ?? '').trim().isEmpty => null,
      MessageKind.place when message.place == null => null,
      MessageKind.memory when message.memory == null => null,
      _ => message,
    };
  }
}

/// A conversation with one friend.
@immutable
class Conversation {
  const Conversation({
    required this.id,
    required this.friend,
    this.username,
    this.lastMessage,
    this.unread = 0,
    this.canSend = true,
  });

  final String id;
  final AppFriend friend;
  final String? username;
  final ChatMessage? lastMessage;
  final int unread;

  /// False once they are no longer friends (or one blocked the other): the
  /// history stays, read-only.
  final bool canSend;

  static Conversation? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final peer = json['friend'];
    if (id is! String || peer is! Map) return null;
    final friend = AppFriend.fromApi({...peer, 'status': 'accepted'});
    if (friend == null) return null;
    final username = peer['username'];
    return Conversation(
      id: id,
      friend: friend,
      username: username is String && username.isNotEmpty ? username : null,
      lastMessage: ChatMessage.fromJson(json['last_message']),
      unread: (json['unread_count'] as num?)?.toInt() ?? 0,
      canSend: json['can_send'] != false,
    );
  }
}
