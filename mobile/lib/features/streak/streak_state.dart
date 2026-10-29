import 'package:flutter/widgets.dart';

import '../../core/network/api_client.dart';

/// Session state; authenticated streaks are hydrated from /streak.
class StreakState extends ValueNotifier<int> {
  StreakState({int initialCount = 0, DateTime Function()? now})
      : _now = now ?? DateTime.now,
        super(initialCount) {
    _lastCompletedDay = _today.subtract(const Duration(days: 1));
  }

  static final shared = StreakState();
  final DateTime Function() _now;
  late DateTime _lastCompletedDay;

  DateTime get _today {
    final now = _now();
    return DateTime.utc(now.year, now.month, now.day);
  }

  /// Whether today already counts: its first entry was celebrated. The
  /// streak screen shows for that entry only, not for later ones.
  bool get completedToday => !_lastCompletedDay.isBefore(_today);

  int get nextCount {
    final gap = _today.difference(_lastCompletedDay).inDays;
    if (gap <= 0) return value;
    return gap == 1 ? value + 1 : 1;
  }

  void completeToday() {
    final updatedCount = nextCount;
    _lastCompletedDay = _today;
    value = updatedCount;
  }

  /// Back to the starting state (yesterday done), for tests sharing [shared].
  /// Do not carry a user's mock streak across a real auth identity switch.
  void resetForNewLocalSession() => reset();

  /// The server alone records streak completions. Hydration is read-only.
  void applyServerSnapshot({required int currentStreak, required bool todayCompleted}) {
    if (currentStreak < 0) throw ArgumentError.value(currentStreak);
    _lastCompletedDay = todayCompleted
        ? _today
        : _today.subtract(const Duration(days: 1));
    value = currentStreak;
  }

  @visibleForTesting
  void reset({int count = 0}) {
    _lastCompletedDay = _today.subtract(const Duration(days: 1));
    value = count;
  }
}

/// Only a verified account has server streak access; guests never call /streak.
class StreakApiScope extends InheritedWidget {
  const StreakApiScope({super.key, required this.client, required super.child});

  final ApiClient client;

  static StreakApiScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<StreakApiScope>();

  @override
  bool updateShouldNotify(StreakApiScope oldWidget) => client != oldWidget.client;
}
