import 'dart:async';

import 'package:flutter/widgets.dart';

/// Locked albums opened in this session. In memory only, never stored; all
/// albums lock again when the app goes to the background.
///
/// A04, or A03 after changing the lock, may call [unlock] only after the
/// device's own authentication succeeded in the current foreground session.
class AlbumUnlocks extends ChangeNotifier with WidgetsBindingObserver {
  AlbumUnlocks._() {
    WidgetsBinding.instance.addObserver(this);
  }

  static final instance = AlbumUnlocks._();

  final _ids = <String>{};
  AppLifecycleState _lifecycle =
      WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed;
  int _revision = 0;

  /// System authentication prompts currently on screen.
  int _systemPrompts = 0;
  Completer<void>? _resumed;

  bool get foreground => _lifecycle == AppLifecycleState.resumed;
  int get revision => _revision;

  bool isUnlocked(String albumId) => _ids.contains(albumId);

  void unlock(String albumId) {
    if (!foreground) return;
    if (_ids.add(albumId)) notifyListeners();
  }

  /// Locks one album again, e.g. once the screen that just locked it is gone.
  void lock(String albumId) {
    if (_ids.remove(albumId)) notifyListeners();
  }

  void lockAll() {
    _revision++;
    _ids.clear();
    notifyListeners();
  }

  /// Runs [prompt], a screen of the operating system's own (the PIN prompt,
  /// the photo picker). On Android it is a separate activity, so the app is
  /// paused while it shows: that is the system screen in front, not the user
  /// leaving, and must not lock everything (or the save that asked for it
  /// would be refused, or the album being edited would lock behind it).
  /// Returns once the app is in front again (or after [settle]), so callers
  /// can check [foreground] right away.
  Future<T> duringSystemPrompt<T>(Future<T> Function() prompt,
      {Duration settle = const Duration(seconds: 2)}) async {
    _systemPrompts++;
    try {
      final result = await prompt();
      if (!foreground) {
        _resumed ??= Completer<void>();
        await _resumed!.future.timeout(settle, onTimeout: () {});
      }
      return result;
    } finally {
      _systemPrompts--;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycle = state;
    if (state == AppLifecycleState.resumed) {
      _resumed?.complete();
      _resumed = null;
    }
    if (state == AppLifecycleState.detached ||
        (_systemPrompts == 0 &&
            (state == AppLifecycleState.paused ||
                state == AppLifecycleState.hidden))) {
      lockAll();
    } else {
      // Inactive native overlays hide private UI without discarding the task.
      notifyListeners();
    }
  }
}
