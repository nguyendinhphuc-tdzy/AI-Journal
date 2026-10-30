import 'dart:async';

import 'package:flutter/widgets.dart';

import 'data/messages_repository.dart';

/// The signed-in account's messages: the repository, and the unread count
/// on the "Tin nhắn" tab, asked again every [poll] while the app is in
/// front (no push notifications yet).
class MessagesController extends ChangeNotifier with WidgetsBindingObserver {
  MessagesController(this.repository,
      {this.poll = const Duration(seconds: 30)});

  final MessagesRepository repository;
  final Duration poll;

  int _unread = 0;
  bool _available = true;
  Timer? _timer;
  bool _started = false;

  int get unread => _unread;

  /// False once the server answered that it has no messaging yet.
  bool get available => _available;

  /// Counts now and keeps counting while the app is in front.
  void start() {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    _resume();
  }

  void _resume() {
    _timer?.cancel();
    _timer = Timer.periodic(poll, (_) => refresh());
    refresh();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _resume();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _timer?.cancel();
    }
  }

  Future<void> refresh() async {
    try {
      final count = await repository.unreadCount();
      _set(count, true);
    } on MessagesUnavailable {
      _set(0, false);
    } catch (_) {
      // Offline: keep the last count.
    }
  }

  /// A conversation was read on screen: count again at once.
  void seen() => refresh();

  void _set(int unread, bool available) {
    if (unread == _unread && available == _available) return;
    _unread = unread;
    _available = available;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    if (_started) WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}

/// Hands [MessagesController] to the screens; none for guests, who have no
/// friends on the app.
class MessagesScope extends InheritedNotifier<MessagesController> {
  const MessagesScope(
      {super.key, required MessagesController controller, required super.child})
      : super(notifier: controller);

  static MessagesController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<MessagesScope>()?.notifier;
}
