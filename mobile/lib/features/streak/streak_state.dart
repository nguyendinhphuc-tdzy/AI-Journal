import 'package:flutter/foundation.dart';

/// Session-only mock state. Replace the initial count/date with backend data.
class StreakState extends ValueNotifier<int> {
  StreakState({int initialCount = 2, DateTime Function()? now})
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
}
