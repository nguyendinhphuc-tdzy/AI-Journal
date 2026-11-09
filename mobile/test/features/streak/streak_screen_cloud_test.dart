import 'package:ai_diary/core/network/api_client.dart';
import 'package:ai_diary/features/streak/streak_screen.dart';
import 'package:ai_diary/features/streak/streak_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  setUp(() => StreakState.shared.reset());

  Future<void> showStreak(WidgetTester tester, http.Response response) async {
    final client = ApiClient(
      accessTokenProvider: () async => 'test-token',
      client: MockClient((_) async => response),
    );
    addTearDown(client.close);
    await tester.pumpWidget(StreakApiScope(
      client: client,
      child: const MaterialApp(home: StreakScreen()),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('a server count of zero does not become a local streak',
      (tester) async {
    await showStreak(tester,
        http.Response('{"current_streak":0,"today_completed":false}', 200));
    expect(StreakState.shared.value, 0);
    expect(StreakState.shared.completedToday, isFalse);
    expect(find.textContaining('ngày liên tục'), findsNothing);
  });

  testWidgets('a failed streak request does not invent a number',
      (tester) async {
    await showStreak(tester, http.Response('{"detail":"offline"}', 503));
    expect(StreakState.shared.value, 0);
    expect(find.textContaining('ngày liên tục'), findsNothing);
  });
}
