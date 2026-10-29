import 'package:ai_diary/features/streak/streak_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Completing a day notifies once and repeat completion is idempotent',
      () {
    final state = StreakState(now: () => DateTime(2026, 10, 11));
    addTearDown(state.dispose);
    var notifications = 0;
    state.addListener(() => notifications++);
    expect(state.value, 0);
    expect(state.nextCount, 1);
    expect(state.completedToday, isFalse);
    state.completeToday();
    state.completeToday();
    expect(state.value, 1);
    expect(state.nextCount, 1);
    expect(state.completedToday, isTrue);
    expect(notifications, 1);
  });

  test('server streak snapshot never fabricates historical days', () {
    final state = StreakState(now: () => DateTime(2026, 10, 29));
    addTearDown(state.dispose);
    expect(state.value, 0);
    state.applyServerSnapshot(currentStreak: 8, todayCompleted: true);
    expect(state.value, 8);
    expect(state.completedToday, isTrue);
    expect(state.nextCount, 8);
    state.applyServerSnapshot(currentStreak: 3, todayCompleted: false);
    expect(state.value, 3);
    expect(state.completedToday, isFalse);
    expect(state.nextCount, 4);
  });

  test('Consecutive day increments, missed day restarts the streak', () {
    var now = DateTime(2026, 10, 11);
    final state = StreakState(now: () => now);
    addTearDown(state.dispose);
    state.completeToday();
    now = DateTime(2026, 10, 12);
    expect(state.nextCount, 2);
    state.completeToday();
    now = DateTime(2026, 10, 14);
    expect(state.nextCount, 1);
    state.completeToday();
    expect(state.value, 1);
  });
}
