import 'dart:async';

import 'package:ai_diary/core/theme/app_colors.dart';
import 'package:ai_diary/features/auth/data/auth_service.dart';
import 'package:ai_diary/features/onboarding/data/sign_in_service.dart';
import 'package:ai_diary/features/onboarding/presentation/onboarding_sign_in_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase as the sign-in screen sees it: sign-up waits for the email to
/// be confirmed, or fails with what Supabase (or the app) says.
class _Auth implements AuthService {
  Object? signUpError;
  Object? signInError;
  final changes = StreamController<String?>.broadcast(sync: true);

  @override
  String? get currentUserId => null;
  @override
  Stream<String?> get userChanges => changes.stream;
  @override
  Future<bool> signUpEmail(String email, String password) async {
    if (signUpError case final error?) throw error;
    return false; // confirmation email sent, no session yet
  }

  @override
  Future<void> signInEmail(String email, String password) async {
    if (signInError case final error?) throw error;
  }

  @override
  Future<void> requestPhoneOtp(String phone) async {}
  @override
  Future<void> verifyPhoneOtp(String phone, String otp) async {}
  @override
  Future<void> signInGoogle() async {}
  @override
  Future<void> signInFacebook() async {}
  @override
  Future<void> signOut() async {}
}

Future<void> _pump(WidgetTester tester, _Auth auth) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);
  addTearDown(auth.changes.close);
  await tester.pumpWidget(MaterialApp(
    home: OnboardingSignInScreen(
      service: SupabaseSignInAdapter(auth),
      realAuth: true,
      onBack: () {},
      onDone: () {},
    ),
  ));
  await tester.pump();
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _signUp(WidgetTester tester) async {
  await _tap(tester, find.text(OnboardingSignInScreen.signUpTab));
  final fields = find.byType(TextField);
  await tester.enterText(fields.at(0), 'vy@vidu.com');
  await tester.enterText(fields.at(1), 'mat-khau-1');
  await tester.enterText(fields.at(2), 'mat-khau-1');
  await _tap(tester, find.text(OnboardingSignInScreen.signUpLabel));
}

Future<void> _signIn(WidgetTester tester) async {
  final fields = find.byType(TextField);
  await tester.enterText(fields.at(0), 'vy@vidu.com');
  await tester.enterText(fields.at(1), 'mat-khau-1');
  // The tab says "Đăng nhập" too; the button is below it.
  await _tap(tester, find.text(OnboardingSignInScreen.signInLabel).last);
}

void main() {
  testWidgets(
      'A sent confirmation email is good news, not an error, and leads to '
      'Đăng nhập with the email kept', (tester) async {
    await _pump(tester, _Auth());
    await _signUp(tester);

    final notice = find.text(OnboardingSignInScreen.checkEmail);
    expect(notice, findsOneWidget);
    final style = tester.widget<Text>(notice).style!;
    expect(style.color, AppColors.primaryAction);
    expect(style.color,
        isNot(Theme.of(tester.element(notice)).colorScheme.error));
    expect(find.byIcon(Icons.mark_email_read_outlined), findsOneWidget);

    // On the Đăng nhập tab now: no "Nhập lại mật khẩu", email still there.
    expect(find.byType(TextField), findsNWidgets(2));
    expect(find.text('vy@vidu.com'), findsOneWidget);
    expect(find.text(OnboardingSignInScreen.signUpLabel), findsNothing);

    // Switching tab clears it.
    await _tap(tester, find.text(OnboardingSignInScreen.signUpTab));
    expect(notice, findsNothing);
  });

  for (final (name, error, shown) in [
    (
      'a Supabase error in English',
      const AuthApiException('Invalid API key', statusCode: '401'),
      OnboardingSignInScreen.failed,
    ),
    (
      'an unknown Supabase code',
      const AuthApiException('Signups not allowed for this instance',
          statusCode: '422', code: 'signup_disabled'),
      OnboardingSignInScreen.failed,
    ),
    (
      'no network',
      AuthRetryableFetchException(message: 'ClientException: Failed host'),
      OnboardingSignInScreen.offline,
    ),
    (
      "the app's own words",
      const AuthException('Không tạo được tài khoản.'),
      'Không tạo được tài khoản.',
    ),
  ]) {
    testWidgets('Sign-up shows $name in Vietnamese', (tester) async {
      await _pump(tester, _Auth()..signUpError = error);
      await _signUp(tester);
      expect(find.text(shown), findsOneWidget);
      if (error.message != shown) {
        expect(find.text(error.message), findsNothing);
      }
      expect(find.text(OnboardingSignInScreen.checkEmail), findsNothing);
    });
  }

  testWidgets('Sign-in never shows Supabase English either', (tester) async {
    await _pump(
        tester,
        _Auth()
          ..signInError =
              const AuthApiException('Invalid API key', statusCode: '401'));
    await _signIn(tester);
    expect(find.text('Invalid API key'), findsNothing);
    expect(find.text(OnboardingSignInScreen.failed), findsOneWidget);
  });
}
