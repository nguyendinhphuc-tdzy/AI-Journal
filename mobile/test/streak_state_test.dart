import 'package:ai_diary/features/streak/streak_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Completing a day notifies once and repeat completion is idempotent',
      () {
    final state = StreakState(now: () => DateTime(2026, 10, 11));
    addTearDown(state.dispose);
    var notifications = 0;
    state.addListener(() => notifications++);
    expect(state.value, 2);
    expect(state.nextCount, 3);
    state.completeToday();
    state.completeToday();
    expect(state.value, 3);
    expect(state.nextCount, 3);
    expect(notifications, 1);
  });

  test('Consecutive day increments, missed day restarts the streak', () {
    var now = DateTime(2026, 10, 11);
    final state = StreakState(now: () => now);
    addTearDown(state.dispose);
    state.completeToday();
    now = DateTime(2026, 10, 12);
    expect(state.nextCount, 4);
    state.completeToday();
    now = DateTime(2026, 10, 14);
    expect(state.nextCount, 1);
    state.completeToday();
    expect(state.value, 1);
  });
}
