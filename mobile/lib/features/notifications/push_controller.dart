import 'dart:async';

import 'package:flutter/widgets.dart';

import 'data/device_registration.dart';
import 'data/push_platform.dart';
import 'data/push_target.dart';

/// Push notifications for the signed-in account: asks to show them, tells
/// the server this installation's token (again whenever it changes), and
/// hands each tapped or foreground notification to the app as a
/// [PushTarget]. Lock-screen text is the server's generic line ("Bạn có tin
/// nhắn mới"), never content.
class PushController {
  PushController({
    required this.platform,
    required this.registration,
    required this.onOpen,
    required this.onForeground,
  });

  final PushPlatform platform;
  final DeviceRegistration registration;

  /// A notification was tapped (or opened the app): go there.
  final void Function(PushTarget target) onOpen;

  /// One arrived while the app is open (the system shows nothing then).
  final void Function(PushTarget target) onForeground;

  final _subscriptions = <StreamSubscription<Object?>>[];
  var _started = false;
  String? _token;

  /// Whether the user allowed notifications (false until asked).
  bool allowed = false;

  /// Once per session; quietly does nothing where push is unavailable.
  Future<void> start() async {
    if (_started) return;
    _started = true;
    if (!await platform.start()) return;
    void open(Map<String, Object?> data) {
      final target = PushTarget.fromData(data);
      if (target != null) onOpen(target);
    }

    _subscriptions
      ..add(platform.opened.listen(open))
      ..add(platform.foreground.listen((data) {
        final target = PushTarget.fromData(data);
        if (target != null) onForeground(target);
      }))
      ..add(platform.tokenRefresh.listen(_register));
    final launch = await platform.openedAtLaunch();
    if (launch != null) open(launch);
    try {
      allowed = await platform.requestPermission();
      final token = await platform.token();
      if (token != null) await _register(token);
    } catch (_) {
      // No push this run (offline, no Play services); the app works without.
    }
  }

  Future<void> _register(String token) async {
    _token = token;
    try {
      await registration.register(token);
    } catch (_) {
      // Tried again on the next token refresh or start.
    }
  }

  /// Before signing out: this installation stops getting the account's
  /// pushes. Bounded so signing out never hangs on the network.
  Future<void> beforeSignOut() async {
    final token = _token;
    if (token == null) return;
    try {
      await registration
          .unregister(token)
          .timeout(const Duration(seconds: 4));
      _token = null;
    } catch (_) {
      // The server drops tokens that stop working or move to another
      // account on this installation.
    }
  }

  void dispose() {
    for (final s in _subscriptions) {
      s.cancel();
    }
    _subscriptions.clear();
  }
}

/// Hands [PushController] to screens (Profile signs out through it).
class PushScope extends InheritedWidget {
  const PushScope({super.key, required this.controller, required super.child});

  final PushController controller;

  static PushController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PushScope>()?.controller;

  @override
  bool updateShouldNotify(PushScope old) => old.controller != controller;
}
