import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'friends_account.dart';

/// Where someone stands in the user's space.
enum SpaceState {
  /// Invited by the user; not in until they accept.
  invited,

  /// In: both agreed.
  member,
}

/// Someone in, or invited to, the user's space; a member may be restricted
/// (still in the space, but they see no new 24-hour post).
@immutable
class SpaceMember {
  const SpaceMember(this.friendId,
      {this.state = SpaceState.member, this.restricted = false});

  final String friendId;
  final SpaceState state;
  final bool restricted;

  bool get isMember => state == SpaceState.member;

  /// Can be picked to see a 24-hour post.
  bool get canSee => isMember && !restricted;
}

/// "Space của bạn": the friends on the app the user shares with. Joining
/// takes both: the user invites and the friend accepts, or the friend
/// invites and the user accepts. Only members, not restricted, can be
/// picked to see a 24-hour post. Kept on this device until the backend has
/// it (`docs/API_CONTRACT.md` has no friends yet).
class FriendSpace {
  FriendSpace({this.keep = true, List<String> incoming = sampleIncoming})
      : _incoming = ValueNotifier(List.unmodifiable(incoming));

  static final instance = FriendSpace();

  static const _key = 'social.space';
  static const _incomingKey = 'social.spaceIncoming';

  /// Friends (in the sample list) who invited the user, until a backend
  /// says who really did.
  static const sampleIncoming = ['f3', 'f4'];

  /// False in tests: nothing is written to the device.
  final bool keep;

  final _members = ValueNotifier<Map<String, SpaceMember>>(const {});
  final ValueNotifier<List<String>> _incoming;

  /// By friend id, in the order they were added; invited ones included.
  ValueListenable<Map<String, SpaceMember>> get members => _members;

  /// Friend ids of those who invited the user and are waiting for an answer.
  ValueListenable<List<String>> get incoming => _incoming;

  Future<void> restore() async {
    if (!keep) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw != null) {
        final map = (jsonDecode(raw) as Map).cast<String, Object?>();
        _members.value = {
          for (final MapEntry(:key, :value) in map.entries)
            key: switch (value) {
              // Before invitations: everyone added was in.
              bool restricted => SpaceMember(key, restricted: restricted),
              Map() => SpaceMember(key,
                  state: value['s'] == 'invited'
                      ? SpaceState.invited
                      : SpaceState.member,
                  restricted: value['r'] == true),
              _ => SpaceMember(key),
            },
        };
      }
      final incoming = prefs.getStringList(_incomingKey);
      if (incoming != null) _incoming.value = List.unmodifiable(incoming);
    } catch (_) {
      // Unreadable: an empty space.
    }
  }

  /// The people in [friends] the space knows of; someone no longer a friend
  /// on the app is left out.
  List<(AppFriend, SpaceMember)> of(List<AppFriend> friends) => [
        for (final member in _members.value.values)
          for (final friend in friends)
            if (friend.id == member.friendId) (friend, member),
      ];

  /// The friends in [friends] waiting for the user's answer.
  List<AppFriend> invitesFrom(List<AppFriend> friends) => [
        for (final id in _incoming.value)
          for (final friend in friends)
            if (friend.id == id && !_members.value.containsKey(id)) friend,
      ];

  /// Sends an invitation; they are in once they accept.
  Future<void> invite(String friendId) => _set({
        ..._members.value,
        friendId: SpaceMember(friendId, state: SpaceState.invited),
      });

  /// Takes back an invitation not answered yet.
  Future<void> cancelInvite(String friendId) {
    if (_members.value[friendId]?.state != SpaceState.invited) {
      return Future.value();
    }
    return remove(friendId);
  }

  /// The friend accepted the user's invitation. Simulated in the test
  /// version; a backend tells the app.
  Future<void> acceptedBy(String friendId) {
    if (_members.value[friendId]?.state != SpaceState.invited) {
      return Future.value();
    }
    return _set({..._members.value, friendId: SpaceMember(friendId)});
  }

  /// The user accepts a friend's invitation: both are in.
  Future<void> accept(String friendId) async {
    _setIncoming([
      for (final id in _incoming.value)
        if (id != friendId) id
    ]);
    await _set({..._members.value, friendId: SpaceMember(friendId)});
  }

  /// The user declines a friend's invitation; they are not told.
  Future<void> decline(String friendId) async => _setIncoming([
        for (final id in _incoming.value)
          if (id != friendId) id
      ]);

  Future<void> remove(String friendId) =>
      _set({..._members.value}..remove(friendId));

  Future<void> restrict(String friendId, bool restricted) {
    final member = _members.value[friendId];
    if (member == null || !member.isMember) return Future.value();
    return _set({
      ..._members.value,
      friendId: SpaceMember(friendId, restricted: restricted),
    });
  }

  /// Everyone out, e.g. on signing out of Facebook. The sample invitations
  /// come back for the next sign-in.
  Future<void> clear() async {
    _setIncoming(sampleIncoming);
    await _set(const {});
  }

  void _setIncoming(List<String> ids) {
    _incoming.value = List.unmodifiable(ids);
    if (!keep) return;
    SharedPreferences.getInstance()
        .then((prefs) => prefs.setStringList(_incomingKey, ids))
        .ignore();
  }

  Future<void> _set(Map<String, SpaceMember> members) async {
    _members.value = members;
    if (!keep) return;
    try {
      await (await SharedPreferences.getInstance()).setString(
          _key,
          jsonEncode({
            for (final member in members.values)
              member.friendId: {
                's': member.state.name,
                'r': member.restricted,
              },
          }));
    } catch (_) {
      // Kept for this run only.
    }
  }
}
