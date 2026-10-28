import 'dart:async';

import 'package:ai_diary/features/auth/data/auth_service.dart';
import 'package:ai_diary/features/auth/data/guest_mode_store.dart';
import 'package:ai_diary/features/auth/presentation/auth_gate.dart';
import 'package:ai_diary/features/onboarding/data/onboarding_store.dart';
import 'package:ai_diary/features/onboarding/onboarding_flow.dart';
import 'package:ai_diary/core/widgets/app_delete_dialog.dart';
import 'package:ai_diary/features/onboarding/presentation/onboarding_sign_in_screen.dart';
import 'package:ai_diary/features/home/presentation/home_screen.dart';
import 'package:ai_diary/features/journal/presentation/write_journal_screen.dart';
import 'package:ai_diary/features/profile/profile_screen.dart';
import 'package:ai_diary/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;
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
  /// What the next email sign-in throws, if anything.
  Object? signInError;
  @override
  Future<void> signInEmail(String email, String password) async {
    if (signInError case final error?) throw error;
  }
  @override
  Future<void> requestPhoneOtp(String phone) async {}
  @override
  Future<void> verifyPhoneOtp(String phone, String code) async {}
  @override
  Future<void> signInGoogle() async {}
  @override
  Future<void> signInFacebook() async {}
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

typedef _I = OnboardingSignInScreen;

/// A phone screen; the gate's sign-in is the onboarding one.
void _phone(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.reset);
}

/// Past a route change; what follows may keep moving (petals): no settling.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump();
}

Future<void> _tapLater(WidgetTester tester) async {
  await tester.ensureVisible(find.text(_I.later));
  await tester.pump();
  await tester.tap(find.text(_I.later));
  await _settle(tester);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Auth gates routes and logout returns to login',
      (tester) async {
    _phone(tester);
    final auth = _FakeAuth();
    addTearDown(auth.changes.close);
    final onboarding = await OnboardingStore.open(userId: 'account-a');
    await onboarding.complete();
    await tester.pumpWidget(AiDiaryApp(auth: auth));
    await _settle(tester);
    expect(find.byType(OnboardingSignInScreen), findsOneWidget);
    // A real sign-in: no stand-in note, no back, nothing that does nothing.
    expect(find.text(_I.mockNote), findsNothing);
    expect(find.byTooltip(_I.backTooltip), findsNothing);
    expect(find.text(_I.remember), findsNothing);
    expect(find.text(_I.forgot), findsNothing);

    auth.signIn('account-a');
    await _settle(tester);
    expect(find.byType(HomeScreen), findsOneWidget);

    // Routes pushed above the Navigator still inherit the auth scope.
    final context = tester.element(find.byType(HomeScreen));
    Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => const ProfileScreen()));
    await _settle(tester);
    final signOut = find.text(ProfileScreen.signOutLabel);
    await tester.ensureVisible(signOut);
    await tester.pump();
    await tester.tap(signOut);
    await _settle(tester);
    expect(find.byType(OnboardingSignInScreen), findsOneWidget);
    expect(find.byType(WriteJournalScreen), findsNothing);
  });

  testWidgets('A wrong password is said in Vietnamese', (tester) async {
    _phone(tester);
    final auth = _FakeAuth()
      ..signInError = const AuthException('Invalid login credentials',
          statusCode: '400', code: 'invalid_credentials');
    addTearDown(auth.changes.close);
    await tester.pumpWidget(AiDiaryApp(auth: auth));
    await _settle(tester);
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'ban@email.com');
    await tester.enterText(fields.at(1), 'bimat1');
    final signIn = find.text(_I.signInLabel).last;
    await tester.ensureVisible(signIn);
    await tester.pump();
    await tester.tap(signIn);
    await _settle(tester);
    expect(find.text(_I.wrongCredentials), findsOneWidget);
    expect(find.text('Invalid login credentials'), findsNothing);
    expect(auth.currentUserId, isNull);
  });

  testWidgets('Guest choice opens OB01 with no Supabase account and resumes',
      (tester) async {
    _phone(tester);
    final auth = _FakeAuth();
    addTearDown(auth.changes.close);
    await tester.pumpWidget(AiDiaryApp(auth: auth));
    await _settle(tester);

    await _tapLater(tester);
    expect(find.byType(OnboardingFlow), findsOneWidget);
    expect(auth.currentUserId, isNull);
    expect((await GuestModeStore.open()).isActive, isTrue);

    final onboarding =
        await OnboardingStore.open(userId: GuestModeStore.userId);
    await onboarding.saveNickname('Khách');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(AiDiaryApp(auth: auth));
    await _settle(tester);

    expect(find.byType(OnboardingFlow), findsOneWidget);
    expect((await OnboardingStore.open(userId: GuestModeStore.userId)).nickname,
        'Khách');
    expect(auth.currentUserId, isNull);
  });

  testWidgets('A guest is warned before Đăng xuất deletes their data',
      (tester) async {
    _phone(tester);
    var leaves = 0;
    await tester.pumpWidget(GuestScope(
      onLeaveGuest: () async => leaves++,
      child: const MaterialApp(home: ProfileScreen()),
    ));
    await _settle(tester);

    final signOut = find.text(ProfileScreen.signOutLabel);
    Future<void> tapSignOut() async {
      await tester.ensureVisible(signOut);
      await tester.pump();
      await tester.tap(signOut);
      await _settle(tester);
    }

    await tapSignOut();
    expect(find.text(ProfileScreen.guestSignOutTitle), findsOneWidget);
    await tester.tap(find.text(AppDeleteDialog.cancelLabel));
    await _settle(tester);
    expect(leaves, 0, reason: 'Giữ lại keeps everything');
    expect(find.text(ProfileScreen.guestSignOutTitle), findsNothing);

    await tapSignOut();
    await tester.tap(find.text(ProfileScreen.guestSignOutConfirm));
    await _settle(tester);
    expect(leaves, 1);
  });

  testWidgets('A new authenticated account enters onboarding automatically',
      (tester) async {
    _phone(tester);
    final auth = _FakeAuth();
    addTearDown(auth.changes.close);
    await tester.pumpWidget(AiDiaryApp(auth: auth));
    await _settle(tester);
    auth.signIn('new-account');
    await _settle(tester);
    expect(find.byType(OnboardingFlow), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
  });
}
