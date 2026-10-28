import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A friend who also uses the app, as Facebook login would give them.
@immutable
class AppFriend {
  const AppFriend(this.id, this.name);

  final String id;
  final String name;

  /// Up to two letters for the avatar.
  String get initials {
    final words = name.trim().split(RegExp(r'\s+'));
    return words.length < 2
        ? words.first.characters.first.toUpperCase()
        : '${words[words.length - 2].characters.first}'
                '${words.last.characters.first}'
            .toUpperCase();
  }
}

/// Signed in: who the user's friends on the app are.
@immutable
class FriendsSession {
  const FriendsSession({required this.friends, this.sample = false});

  final List<AppFriend> friends;

  /// Made up by the mock, not real Facebook friends.
  final bool sample;
}

/// Connecting did not work (offline, the service refused).
class FriendsConnectFailed implements Exception {
  const FriendsConnectFailed();
}

/// Facebook login, for friends on the app (who sees 24-hour posts). The app
/// asks only for the public profile and friends who also use it; it never
/// posts to Facebook.
abstract interface class FriendsAccount {
  /// Null while not connected.
  ValueListenable<FriendsSession?> get session;

  /// Picks up a connection made in an earlier run.
  Future<void> restore();

  /// Throws [FriendsConnectFailed] when it could not connect.
  Future<FriendsSession> connect();

  Future<void> disconnect();
}

/// A stand-in until the backend has Facebook login (see
/// `docs/API_CONTRACT.md`): no Facebook call, no password, sample friends.
/// The connection is kept on this device so the flow can be tried again
/// after "Ngắt kết nối" in Profile.
class MockFriendsAccount implements FriendsAccount {
  MockFriendsAccount({this.delay = const Duration(milliseconds: 1200)});

  static final instance = MockFriendsAccount();

  static const _key = 'social.mockConnected';

  /// Made-up names, nobody real.
  static const sampleFriends = [
    AppFriend('f1', 'Minh Anh'),
    AppFriend('f2', 'Gia Huy'),
    AppFriend('f3', 'Thảo Nhi'),
    AppFriend('f4', 'Bảo Long'),
    AppFriend('f5', 'Khánh Linh'),
    AppFriend('f6', 'Quốc Bảo'),
    AppFriend('f7', 'Hà My'),
    AppFriend('f8', 'Tuấn Kiệt'),
  ];

  static const _session = FriendsSession(friends: sampleFriends, sample: true);

  /// How long "Đang kết nối…" shows.
  final Duration delay;

  /// The next connect fails, to see that state.
  var failNext = false;

  final _current = ValueNotifier<FriendsSession?>(null);

  @override
  ValueListenable<FriendsSession?> get session => _current;

  @override
  Future<void> restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_key) ?? false) _current.value = _session;
    } catch (_) {
      // Unreadable: not connected.
    }
  }

  /// Signs in with what was typed on the login screen. The mock checks
  /// only that both were filled in; nothing typed is kept or sent anywhere.
  @override
  Future<FriendsSession> connect() async {
    await Future<void>.delayed(delay);
    if (failNext) {
      failNext = false;
      throw const FriendsConnectFailed();
    }
    try {
      await (await SharedPreferences.getInstance()).setBool(_key, true);
    } catch (_) {
      // Connected for this run only.
    }
    return _current.value = _session;
  }

  @override
  Future<void> disconnect() async {
    _current.value = null;
    try {
      await (await SharedPreferences.getInstance()).remove(_key);
    } catch (_) {
      // Nothing kept to forget.
    }
  }
}
