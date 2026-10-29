import 'package:ai_diary/core/theme/app_theme.dart';
import 'package:ai_diary/features/journal/data/api_ai_service.dart';
import 'package:ai_diary/features/onboarding/data/onboarding_scope.dart';
import 'package:ai_diary/features/onboarding/data/onboarding_store.dart';
import 'package:ai_diary/features/profile/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_ai.dart';

Finder get _row => find.byKey(const ValueKey('setting-item-ai replies'));

Future<OnboardingStore> _pump(WidgetTester tester, {required bool ai}) async {
  SharedPreferences.setMockInitialValues({
    // "Chỉ viết nhật ký" in an older onboarding: AI is still on in the app.
    'account.u1.onboarding.ai': 'off',
  });
  final store = await OnboardingStore.open(userId: 'u1');
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(412, 915);
  addTearDown(tester.view.reset);
  final app = OnboardingScope(
    store: store,
    child: MaterialApp(theme: AppTheme.light, home: const ProfileScreen()),
  );
  await tester.pumpWidget(
      ai ? AiRemoteScope(service: FakeAi().service, child: app) : app);
  await tester.pumpAndSettle();
  return store;
}

void main() {
  testWidgets('Signed in: "Phản hồi AI", on, turned off and back on',
      (tester) async {
    final store = await _pump(tester, ai: true);
    expect(store.aiInApp, isTrue);
    expect(find.text('Phản hồi AI'), findsOneWidget);
    expect(find.descendant(of: _row, matching: find.text('Bật')),
        findsOneWidget);

    await tester.tap(_row);
    await tester.pumpAndSettle();
    expect(find.text(ProfileScreen.aiRepliesNote), findsOneWidget,
        reason: 'says what is sent before the choice');
    await tester.tap(find.text('Tắt').last);
    await tester.pump();
    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();
    expect(store.aiInApp, isFalse);
    expect(find.descendant(of: _row, matching: find.text('Tắt')),
        findsOneWidget);

    await tester.tap(_row);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bật').last);
    await tester.pump();
    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();
    expect(store.aiInApp, isTrue);
  });

  testWidgets('Without AI (guest): no "Phản hồi AI" to set', (tester) async {
    await _pump(tester, ai: false);
    expect(find.text('Phản hồi AI'), findsNothing);
  });
}
