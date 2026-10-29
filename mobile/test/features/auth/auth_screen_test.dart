import 'dart:async';

import 'package:ai_diary/features/auth/data/auth_service.dart';
import 'package:ai_diary/features/auth/presentation/auth_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAuth implements AuthService {
  final controller = StreamController<String?>.broadcast();
  String? lastEmail;
  String? lastPhone;
  String? lastOtp;
  int signupCalls = 0;
  int facebookCalls = 0;
  int otpRequests = 0;

  @override
  String? get currentUserId => null;
  @override
  Stream<String?> get userChanges => controller.stream;
  @override
  Future<bool> signUpEmail(String email, String password) async {
    lastEmail = email;
    signupCalls++;
    return false;
  }
  @override
  Future<void> signInEmail(String email, String password) async {
    lastEmail = email;
  }
  @override
  Future<void> requestPhoneOtp(String phone) async {
    lastPhone = phone;
    otpRequests++;
  }
  @override
  Future<void> verifyPhoneOtp(String phone, String otp) async {
    lastOtp = otp;
  }
  @override
  Future<void> signInGoogle() async {}
  @override
  Future<void> signInFacebook() async { facebookCalls++; }
  @override
  Future<void> signOut() async {}
}

void main() {
  testWidgets('Invalid email is rejected without contacting auth',
      (tester) async {
    final auth = _FakeAuth();
    addTearDown(auth.controller.close);
    await tester.pumpWidget(MaterialApp(home: AuthScreen(auth: auth)));
    await tester.tap(find.widgetWithText(FilledButton, 'Đăng nhập'));
    await tester.pump();
    expect(auth.lastEmail, isNull);
    expect(find.text('Vui lòng nhập email hợp lệ.'), findsOneWidget);
  });

  testWidgets('Email signup waits for confirmation when no session exists',
      (tester) async {
    final auth = _FakeAuth();
    addTearDown(auth.controller.close);
    await tester.pumpWidget(MaterialApp(home: AuthScreen(auth: auth)));
    await tester.tap(find.text('Chưa có tài khoản? Đăng ký'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'vy@gmail.com');
    await tester.enterText(find.byType(TextField).at(1), 'Password123');
    await tester.tap(find.text('Đăng ký bằng email'));
    await tester.pumpAndSettle();
    expect(auth.lastEmail, 'vy@gmail.com');
    expect(auth.signupCalls, 1);
    expect(find.textContaining('Kiểm tra hộp thư'), findsOneWidget);
  });

  testWidgets('Phone OTP sends a request and verifies six digits',
      (tester) async {
    final auth = _FakeAuth();
    addTearDown(auth.controller.close);
    await tester.pumpWidget(MaterialApp(
      home: AuthScreen(auth: auth, phoneOtpEnabled: true),
    ));
    await tester.tap(find.text('Điện thoại'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '+84901234567');
    await tester.tap(find.text('Gửi mã SMS'));
    await tester.pumpAndSettle();
    expect(auth.lastPhone, '+84901234567');
    await tester.enterText(find.byType(TextField).last, '123456');
    // At the default 800x600 widget test viewport, OTP adds a field and
    // pushes the submit button below the fold. Scroll before tapping.
    await tester.ensureVisible(find.text('Xác nhận OTP'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xác nhận OTP'));
    await tester.pumpAndSettle();
    expect(auth.lastOtp, '123456');
  });
  testWidgets('Facebook button is absent until OAuth is enabled',
      (tester) async {
    final auth = _FakeAuth();
    addTearDown(auth.controller.close);
    await tester.pumpWidget(MaterialApp(home: AuthScreen(auth: auth)));
    expect(find.text('Tiếp tục bằng Facebook'), findsNothing);
    expect(auth.facebookCalls, 0);
  });

  testWidgets('Facebook button invokes the AuthService once when enabled',
      (tester) async {
    final auth = _FakeAuth();
    addTearDown(auth.controller.close);
    await tester.pumpWidget(MaterialApp(
      home: AuthScreen(auth: auth, facebookOAuthEnabled: true),
    ));
    final facebookButton = find.text('Tiếp tục bằng Facebook');
    expect(facebookButton, findsOneWidget);
    await tester.ensureVisible(facebookButton);
    await tester.pumpAndSettle();
    await tester.tap(facebookButton);
    // The screen now waits up to 2 minutes for the OAuth callback, with a
    // spinner (it never settles meanwhile): one frame shows the call.
    await tester.pump();
    expect(auth.facebookCalls, 1);
    expect(find.text('Dừng chờ đăng nhập'), findsOneWidget);
    // Let that wait run out, so no timer outlives the test.
    await tester.pump(const Duration(minutes: 2, seconds: 1));
    await tester.pump();
    expect(auth.facebookCalls, 1, reason: 'called once');
  });

  testWidgets('Phone OTP is hidden when no SMS provider is configured',
      (tester) async {
    final auth = _FakeAuth();
    addTearDown(auth.controller.close);
    await tester.pumpWidget(MaterialApp(home: AuthScreen(auth: auth)));
    expect(find.text('Điện thoại'), findsNothing);
    expect(find.text('Gửi mã SMS'), findsNothing);
    expect(auth.otpRequests, 0);
  });

  testWidgets('Resend SMS is rate limited on the client', (tester) async {
    final auth = _FakeAuth();
    addTearDown(auth.controller.close);
    await tester.pumpWidget(MaterialApp(
      home: AuthScreen(auth: auth, phoneOtpEnabled: true,
          startWithPhone: true),
    ));
    await tester.enterText(find.byType(TextField).first, '+84901234567');
    await tester.ensureVisible(find.text('Gửi mã SMS'));
    await tester.tap(find.text('Gửi mã SMS'));
    await tester.pumpAndSettle();
    expect(auth.otpRequests, 1);
    final resend = find.text('Gửi lại mã OTP');
    await tester.ensureVisible(resend);
    await tester.tap(resend);
    await tester.pumpAndSettle();
    expect(auth.otpRequests, 1);
    expect(find.textContaining('giây trước khi yêu cầu mã mới'),
        findsOneWidget);
  });

  testWidgets('Cancel Facebook wait hides spinner and shows an error',
      (tester) async {
    final auth = _FakeAuth();
    addTearDown(auth.controller.close);
    await tester.pumpWidget(MaterialApp(
      home: AuthScreen(auth: auth, facebookOAuthEnabled: true),
    ));
    final facebook = find.text('Tiếp tục bằng Facebook');
    await tester.ensureVisible(facebook);
    await tester.tap(facebook);
    await tester.pump();
    expect(find.text('Dừng chờ đăng nhập'), findsOneWidget);

    await tester.tap(find.text('Dừng chờ đăng nhập'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 25));

    expect(find.text('Dừng chờ đăng nhập'), findsNothing);
    expect(find.textContaining('Đã dừng chờ'), findsOneWidget);
    expect(find.text('Tiếp tục bằng Facebook'), findsOneWidget);
  });


}
