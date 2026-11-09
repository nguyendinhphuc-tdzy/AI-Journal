import 'package:ai_diary/core/data/app_data.dart';
import 'package:ai_diary/core/theme/app_theme.dart';
import 'package:ai_diary/features/auth/data/guest_mode_store.dart';
import 'package:ai_diary/features/home/presentation/home_screen.dart';
import 'package:ai_diary/features/journal/data/api_ai_service.dart';
import 'package:ai_diary/features/journal/data/cloud_ai_api.dart';
import 'package:ai_diary/features/journal/data/journal_repository.dart';
import 'package:ai_diary/features/journal/data/saved_quotes.dart';
import 'package:ai_diary/features/journal/journal_scope.dart';
import 'package:ai_diary/features/onboarding/data/onboarding_scope.dart';
import 'package:ai_diary/features/onboarding/data/onboarding_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_ai.dart';

const _a = '11111111-0000-0000-0000-00000000000a';
const _b = '11111111-0000-0000-0000-00000000000b';

Map<String, Object?> _serverQuote(String id, String text) => {
      'id': id,
      'text': text,
      'author': 'Tác giả',
      'source': null,
      'saved_at': '2026-10-29T08:00:00Z',
    };

/// Home for [user] (an account with [ai], or a guest without).
Future<void> _home(WidgetTester tester, String user, {FakeAi? ai}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(412, 915);
  addTearDown(tester.view.reset);
  final onboarding = await OnboardingStore.open(userId: user);
  final home = OnboardingScope(
    // A new account: a new Home, as AuthGate keys a session by its user.
    key: ValueKey(user),
    store: onboarding,
    child: JournalScope(
      repository: InMemoryJournalRepository(),
      child: MaterialApp(theme: AppTheme.light, home: const HomeScreen()),
    ),
  );
  await tester.pumpWidget(
      ai == null ? home : AiRemoteScope(service: ai.service, child: home));
  await tester.pumpAndSettle();
}

Future<void> _toSaved(WidgetTester tester) async {
  await tester.scrollUntilVisible(find.text(HomeScreen.savedTitle), 200,
      scrollable: find
          .descendant(
              of: find.byKey(const PageStorageKey('home-scroll')),
              matching: find.byType(Scrollable))
          .first);
  await tester.pumpAndSettle();
}

void main() {
  late List<Map<String, dynamic>> shared;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    shared = savedThisWeekItems.value;
    savedThisWeekItems.value = [];
  });
  tearDown(() => savedThisWeekItems.value = shared);

  testWidgets('An account: the server\'s quotes, with ones kept here before',
      (tester) async {
    final ai = FakeAi();
    ai.serverQuotes.add(_serverQuote('q-1', 'Từ tài khoản.'));
    await (await SavedQuotes.open(userId: _a)).save('Chỉ trên máy.', 'B');
    await _home(tester, _a, ai: ai);
    await _toSaved(tester);
    // Home shows the newest; "Xem tất cả" has both.
    expect(find.text('Chỉ trên máy.'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('home-saved-all')));
    await tester.pumpAndSettle();
    expect(find.text('Từ tài khoản.'), findsOneWidget);
    expect(find.text('Chỉ trên máy.'), findsOneWidget);
    expect(ai.requests, contains('GET /saved-quotes?limit=100&offset=0'));
    expect(
        ai.serverQuotes.map((q) => q['text']), isNot(contains('Chỉ trên máy.')),
        reason: 'one kept here before is never sent up by itself');
    expect((await SavedQuotes.open(userId: _a)).all().map((q) => q.text),
        containsAll(['Từ tài khoản.', 'Chỉ trên máy.']));
    // Other saved items are left as they are.
    savedThisWeekItems.value = [
      {'type': 'insight', 'content': 'Một phân tích đã lưu.', 'title': 'T'},
    ];
    await tester.pumpAndSettle();
    final all = savedShown(
        (await SavedQuotes.open(userId: _a)).all(), savedThisWeekItems.value);
    expect(all.where((i) => i['type'] == 'insight'), hasLength(1));
  });

  testWidgets(
      'Saved on the quote screen: on Home at once; let go on Home: '
      'gone from the server', (tester) async {
    final ai = FakeAi();
    await _home(tester, _a, ai: ai);
    await (await SavedQuotes.open(userId: _a, cloud: CloudAiApi(ai.client)))
        .save('Câu vừa lưu.', 'Tác giả');
    await tester.pumpAndSettle();
    await _toSaved(tester);
    expect(find.text('Câu vừa lưu.'), findsOneWidget);
    expect(ai.serverQuotes.single['text'], 'Câu vừa lưu.');

    await tester.tap(find.byTooltip('Bỏ lưu trích dẫn').first);
    await tester.pumpAndSettle();
    expect(ai.serverQuotes, isEmpty);
    expect(find.text('Câu vừa lưu.'), findsNothing);
    expect(find.text('Đã bỏ lưu trích dẫn'), findsOneWidget);
  });

  testWidgets('Letting go fails (network): it stays, and the reader is told',
      (tester) async {
    final ai = FakeAi();
    ai.serverQuotes.add(_serverQuote('q-1', 'Vẫn còn.'));
    await _home(tester, _a, ai: ai);
    await _toSaved(tester);
    ai
      ..failPath = '/saved-quotes/q-1'
      ..failStatus = 503;
    await tester.tap(find.byTooltip('Bỏ lưu trích dẫn').first);
    await tester.pumpAndSettle();
    expect(find.text('Vẫn còn.'), findsOneWidget);
    expect(find.text('Chưa bỏ lưu được. Bạn thử lại nhé.'), findsOneWidget);
    expect(ai.serverQuotes, hasLength(1));
  });

  test('Saving fails (network): nothing is kept, so nothing is promised',
      () async {
    final ai = FakeAi()
      ..failPath = '/saved-quotes'
      ..failStatus = 503;
    final quotes =
        await SavedQuotes.open(userId: _a, cloud: CloudAiApi(ai.client));
    await expectLater(quotes.save('Câu.', 'Tác giả'), throwsA(anything));
    expect(quotes.all(), isEmpty);
  });

  testWidgets('Offline on opening Home: the copy kept here shows',
      (tester) async {
    final ai = FakeAi()
      ..failPath = '/saved-quotes'
      ..failStatus = 503;
    await (await SavedQuotes.open(userId: _a)).save('Đã có từ trước.', 'A');
    await _home(tester, _a, ai: ai);
    await _toSaved(tester);
    expect(find.text('Đã có từ trước.'), findsOneWidget);
  });

  testWidgets(
      'Gone from the server (let go on another phone): gone here; '
      'letting it go again is fine', (tester) async {
    final ai = FakeAi();
    final quotes =
        await SavedQuotes.open(userId: _a, cloud: CloudAiApi(ai.client));
    await quotes.save('Đã bỏ ở máy khác.', 'A');
    ai.serverQuotes.clear();
    await _home(tester, _a, ai: ai);
    expect(find.text('Đã bỏ ở máy khác.', skipOffstage: false), findsNothing);
    expect(quotes.all(), isEmpty);
    // A stale copy let go: the server's 404 counts as done.
    await quotes.save('Lại.', 'A');
    ai.serverQuotes.clear();
    await quotes.remove('Lại.');
    expect(quotes.all(), isEmpty);
  });

  testWidgets('Another account (sign out, sign in): only its own quotes',
      (tester) async {
    final ai = FakeAi();
    ai.serverQuotes.add(_serverQuote('q-a', 'Của A.'));
    await _home(tester, _a, ai: ai);
    await _toSaved(tester);
    expect(find.text('Của A.'), findsOneWidget);

    // B signs in on the same phone: A's server is not B's.
    final forB = FakeAi()..serverQuotes.add(_serverQuote('q-b', 'Của B.'));
    await tester.pumpWidget(const SizedBox());
    await _home(tester, _b, ai: forB);
    await _toSaved(tester);
    expect(find.text('Của B.'), findsOneWidget);
    expect(find.text('Của A.', skipOffstage: false), findsNothing);
    expect((await SavedQuotes.open(userId: _b)).all().map((q) => q.text),
        ['Của B.']);
  });

  testWidgets('A guest: on the device only; leaving guest mode discards them',
      (tester) async {
    await (await SavedQuotes.open(userId: GuestModeStore.userId))
        .save('Của khách.', 'A');
    await _home(tester, GuestModeStore.userId);
    await _toSaved(tester);
    expect(find.text('Của khách.'), findsOneWidget);

    await (await GuestModeStore.open()).leaveAndDiscard();
    expect(
        (await SavedQuotes.open(userId: GuestModeStore.userId)).all(), isEmpty);
  });
}
