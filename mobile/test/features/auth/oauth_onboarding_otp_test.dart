import 'dart:async';

import 'package:ai_diary/features/auth/data/auth_service.dart';
import 'package:ai_diary/features/auth/presentation/auth_screen.dart';
import 'package:ai_diary/features/onboarding/data/sign_in_service.dart';
import 'package:ai_diary/features/onboarding/presentation/onboarding_sign_in_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAuth implements AuthService {
  final changes = StreamController<String?>.broadcast(sync: true);
  String? signedIn;
  int googleCalls = 0;
  int facebookCalls = 0;
  String? otpPhone;
  String? otpCode;

  @override
  String? get currentUserId => signedIn;
  @override
  Stream<String?> get userChanges => changes.stream;
  void succeed(String id) {
    signedIn = id;
    changes.add(id);
  }

  @override
  Future<bool> signUpEmail(String email, String password) async => false;
  @override
  Future<void> signInEmail(String email, String password) async {}
  @override
  Future<void> signInGoogle() async { googleCalls++; }
  @override
  Future<void> signInFacebook() async { facebookCalls++; }
  @override
  Future<void> requestPhoneOtp(String phone) async { otpPhone = phone; }
  @override
  Future<void> verifyPhoneOtp(String phone, String code) async {
    otpPhone = phone;
    otpCode = code;
  }
  @override
  Future<void> signOut() async {}
}

void main() {
  test('OAuth browser open is not success until a real session arrives',
      () async {
    final auth = _FakeAuth();
    addTearDown(auth.changes.close);
    final adapter = SupabaseSignInAdapter(auth);
    var done = false;
    final future = adapter.signInGoogle().then((_) => done = true);
    await Future<void>.delayed(Duration.zero);
    expect(auth.googleCalls, 1);
    expect(done, isFalse);
    auth.succeed('real-user');
    await future;
    expect(done, isTrue);
  });

  test('OAuth callback stream errors propagate instead of silently succeeding',
      () async {
    final auth = _FakeAuth();
    addTearDown(auth.changes.close);
    final adapter = SupabaseSignInAdapter(auth);
    final future = adapter.signInFacebook();
    await Future<void>.delayed(Duration.zero);
    final failure = expectLater(future, throwsA(isA<StateError>()));
    auth.changes.addError(StateError('oauth callback failure'));
    await failure;
  });

  testWidgets('real sign-in exposes configured OTP and hides disabled Facebook',
      (tester) async {
    final auth = _FakeAuth();
    addTearDown(auth.changes.close);
    await tester.pumpWidget(MaterialApp(
      home: OnboardingSignInScreen(
        service: SupabaseSignInAdapter(auth),
        realAuth: true,
        phoneOtpEnabled: true,
        facebookOAuthEnabled: false,
        onBack: () {},
        onDone: () {},
      ),
    ));
    expect(find.text(OnboardingSignInScreen.facebook), findsNothing);
    final otp = find.text(OnboardingSignInScreen.phone);
    expect(otp, findsOneWidget);
    await tester.ensureVisible(otp);
    await tester.pumpAndSettle();
    await tester.tap(otp);
    await tester.pumpAndSettle();
    expect(find.byType(AuthScreen), findsOneWidget);
    expect(find.text('Điện thoại'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, '+84901234567');
    await tester.ensureVisible(find.text('Gửi mã SMS'));
    await tester.tap(find.text('Gửi mã SMS'));
    await tester.pumpAndSettle();
    expect(auth.otpPhone, '+84901234567');
    await tester.enterText(find.byType(TextField).last, '123456');
    await tester.ensureVisible(find.text('Xác nhận OTP'));
    await tester.tap(find.text('Xác nhận OTP'));
    await tester.pumpAndSettle();
    expect(auth.otpCode, '123456');
  });
}
