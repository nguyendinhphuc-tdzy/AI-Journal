import 'dart:async';

import 'package:ai_diary/features/auth/data/auth_service.dart';
import 'package:ai_diary/features/auth/data/guest_mode_store.dart';
import 'package:ai_diary/features/onboarding/data/onboarding_store.dart';
import 'package:ai_diary/features/onboarding/onboarding_flow.dart';
import 'package:ai_diary/features/auth/presentation/auth_screen.dart';
import 'package:ai_diary/features/home/presentation/home_screen.dart';
import 'package:ai_diary/features/journal/presentation/write_journal_screen.dart';
import 'package:ai_diary/features/profile/profile_screen.dart';
import 'package:ai_diary/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAuth implements AuthService {
  final changes = StreamController<String?>.broadcast();
  String? currentId;

  @override
  String? get currentUserId => currentId;
  @override
  Stream<String?> get userChanges => changes.stream;
  @override
  Future<bool> signUpEmail(String email, String password) async => true;
  @override
  Future<void> signInEmail(String email, String password) async {}
  @override
  Future<void> requestPhoneOtp(String phone) async {}
  @override
  Future<void> verifyPhoneOtp(String phone, String code) async {}
  @override
  Future<void> signInGoogle() async {}
  @override
  Future<void> signOut() async {
    currentId = null;
    changes.add(null);
  }

  void signIn(String userId) {
    currentId = userId;
    changes.add(userId);
  }
}

void main() {
  testWidgets('Auth gates routes and logout returns to login',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final auth = _FakeAuth();
    addTearDown(auth.changes.close);
    final onboarding = await OnboardingStore.open(userId: 'account-a');
    await onboarding.complete();
    await tester.pumpWidget(AiDiaryApp(auth: auth));
    await tester.pumpAndSettle();
    expect(find.byType(AuthScreen), findsOneWidget);

    auth.signIn('account-a');
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);

    // Routes pushed above the Navigator still inherit the auth scope.
    final context = tester.element(find.byType(HomeScreen));
    Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => const ProfileScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Đăng xuất'), findsOneWidget);

    await tester.tap(find.text('Đăng xuất'));
    await tester.pumpAndSettle();
    expect(find.byType(AuthScreen), findsOneWidget);
    expect(find.byType(WriteJournalScreen), findsNothing);
  });
  testWidgets('Guest choice opens OB01 with no Supabase account and resumes',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final auth = _FakeAuth();
    addTearDown(auth.changes.close);
    await tester.pumpWidget(AiDiaryApp(auth: auth));
    await tester.pumpAndSettle();

    expect(find.text('Continue without an account'), findsOneWidget);
    await tester.tap(find.text('Continue without an account'));
    await tester.pumpAndSettle();
    expect(find.text('Tiếp tục không có tài khoản?'), findsOneWidget);
    await tester.tap(find.text('Tiếp tục'));
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingFlow), findsOneWidget);
    expect(auth.currentUserId, isNull);
    expect((await GuestModeStore.open()).isActive, isTrue);

    final onboarding =
        await OnboardingStore.open(userId: GuestModeStore.userId);
    await onboarding.saveNickname('Khách');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(AiDiaryApp(auth: auth));
    await tester.pumpAndSettle();

    expect(find.byType(OnboardingFlow), findsOneWidget);
    expect((await OnboardingStore.open(userId: GuestModeStore.userId)).nickname,
        'Khách');
    expect(auth.currentUserId, isNull);
  });

  testWidgets('A new authenticated account enters onboarding automatically',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final auth = _FakeAuth();
    addTearDown(auth.changes.close);
    await tester.pumpWidget(AiDiaryApp(auth: auth));
    await tester.pumpAndSettle();
    auth.signIn('new-account');
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingFlow), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
  });

}
