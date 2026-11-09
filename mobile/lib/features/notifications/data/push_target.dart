import 'package:flutter/foundation.dart';

/// Where a push notification leads when tapped. The push only says where to
/// look; the screen fetches the real content again with the user's session
/// (friendship, blocking and expiry are checked by the server then).
@immutable
sealed class PushTarget {
  const PushTarget();

  /// From the notification's data (`type` and an id); null for anything
  /// the app does not know.
  static PushTarget? fromData(Map<String, Object?> data) {
    String? id(String key) {
      final value = data[key];
      return value is String && value.isNotEmpty ? value : null;
    }

    return switch (data['type']) {
      'message' => switch (id('conversation_id')) {
          final c? => OpenChat(c),
          null => const OpenMessages(),
        },
      'friend_request' || 'friend_accepted' => const OpenFriends(),
      'memory_share' => switch (id('share_id')) {
          final s? => OpenMoment(s),
          null => null,
        },
      _ => null,
    };
  }
}

/// A new message: that conversation.
final class OpenChat extends PushTarget {
  const OpenChat(this.conversationId);
  final String conversationId;

  @override
  bool operator ==(Object other) =>
      other is OpenChat && other.conversationId == conversationId;
  @override
  int get hashCode => conversationId.hashCode;
}

/// A message without a conversation id: the Tin nhắn tab.
final class OpenMessages extends PushTarget {
  const OpenMessages();
  @override
  bool operator ==(Object other) => other is OpenMessages;
  @override
  int get hashCode => 1;
}

/// A friend request, or one accepted: Bạn bè.
final class OpenFriends extends PushTarget {
  const OpenFriends();
  @override
  bool operator ==(Object other) => other is OpenFriends;
  @override
  int get hashCode => 2;
}

/// A friend's 24-hour moment: on Khám phá's map.
final class OpenMoment extends PushTarget {
  const OpenMoment(this.shareId);
  final String shareId;

  @override
  bool operator ==(Object other) =>
      other is OpenMoment && other.shareId == shareId;
  @override
  int get hashCode => shareId.hashCode;
}

/// What the app says for a notification that comes while it is open.
abstract final class PushText {
  static const friends = 'Bạn có lời mời hoặc bạn bè mới';
  static const moment = 'Bạn bè vừa chia sẻ một khoảnh khắc';
  static const show = 'Xem';
}
