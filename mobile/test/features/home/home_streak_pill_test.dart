import 'package:ai_diary/core/network/api_client.dart';
import 'package:ai_diary/core/theme/app_theme.dart';
import 'package:ai_diary/features/home/presentation/home_screen.dart';
import 'package:ai_diary/features/journal/data/journal_repository.dart';
import 'package:ai_diary/features/journal/journal_scope.dart';
import 'package:ai_diary/features/streak/streak_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

Finder get _pill => find.byIcon(Icons.local_fire_department_outlined);

/// Home with [streak] answering /streak (an account), or none (a guest).
Future<int> _pump(WidgetTester tester, {http.Response? streak}) async {
  var requests = 0;
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(412, 915);
  addTearDown(tester.view.reset);
  final home = JournalScope(
    repository: InMemoryJournalRepository(),
    child: MaterialApp(theme: AppTheme.light, home: const HomeScreen()),
  );
  if (streak == null) {
    await tester.pumpWidget(home);
  } else {
    final client = ApiClient(
      accessTokenProvider: () async => 'token',
      client: MockClient((request) async {
        if (request.url.path.endsWith('/streak')) requests++;
        return streak;
      }),
    );
    addTearDown(client.close);
    await tester.pumpWidget(StreakApiScope(client: client, child: home));
  }
  await tester.pumpAndSettle();
  return requests;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    StreakState.shared.reset();
  });

  testWidgets('An account: the server\'s count, read once on opening Home',
      (tester) async {
    final requests = await _pump(tester,
        streak: http.Response(
            '{"current_streak":5,"today_completed":true}', 200));
    expect(requests, 1);
    expect(find.text('5 ngày'), findsOneWidget);
    expect(find.bySemanticsLabel('Chuỗi 5 ngày liên tiếp'), findsOneWidget);
    expect(StreakState.shared.completedToday, isTrue);
  });

  testWidgets('An account whose streak cannot be read: no pill, no 0',
      (tester) async {
    await _pump(tester, streak: http.Response('{"detail":"down"}', 503));
    expect(_pill, findsNothing);
    expect(find.text('0 ngày'), findsNothing);
  });

  testWidgets('A malformed answer is not shown either', (tester) async {
    await _pump(tester,
        streak: http.Response('{"current_streak":"5"}', 200));
    expect(_pill, findsNothing);
  });

  testWidgets('A guest (no server streak): no pill, as on the streak screen',
      (tester) async {
    StreakState.shared.reset(count: 3);
    await _pump(tester);
    expect(_pill, findsNothing);
    expect(find.text('3 ngày'), findsNothing);
  });
}
