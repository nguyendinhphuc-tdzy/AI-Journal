import 'package:flutter/widgets.dart';

/// A friend on the app: an accepted friendship between two accounts
/// (`GET /friends`), found by @username.
@immutable
class AppFriend {
  const AppFriend(this.id, this.name);

  /// From one item of `GET /friends`; null unless the friendship is accepted.
  static AppFriend? fromApi(Object? item) {
    if (item is! Map || item['status'] != 'accepted') return null;
    final id = item['user_id'];
    if (id is! String || id.isEmpty) return null;
    final name = item['display_name'];
    final username = item['username'];
    return AppFriend(
        id,
        name is String && name.trim().isNotEmpty
            ? name.trim()
            : username is String && username.isNotEmpty
                ? '@$username'
                : 'Người dùng AI-Journal');
  }

  final String id;
  final String name;

  /// Up to two letters for the avatar.
  String get initials {
    final words = name.replaceFirst('@', '').trim().split(RegExp(r'\s+'));
    return words.length < 2
        ? words.first.characters.first.toUpperCase()
        : '${words[words.length - 2].characters.first}'
                '${words.last.characters.first}'
            .toUpperCase();
  }
}
