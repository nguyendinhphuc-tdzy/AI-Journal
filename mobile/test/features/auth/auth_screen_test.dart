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
  }
  @override
  Future<void> verifyPhoneOtp(String phone, String otp) async {
    lastOtp = otp;
  }
  @override
  Future<void> signInGoogle() async {}
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
    await tester.pumpWidget(MaterialApp(home: AuthScreen(auth: auth)));
    await tester.tap(find.text('Điện thoại'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '+84901234567');
    await tester.tap(find.text('Gửi mã SMS'));
    await tester.pumpAndSettle();
    expect(auth.lastPhone, '+84901234567');
    await tester.enterText(find.byType(TextField).last, '123456');
    await tester.tap(find.text('Xác nhận OTP'));
    await tester.pumpAndSettle();
    expect(auth.lastOtp, '123456');
  });
}
