import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_config.dart';

/// Auth contract allows UI tests without contacting Supabase.
abstract interface class AuthService {
  String? get currentUserId;
  Stream<String?> get userChanges;
  Future<bool> signUpEmail(String email, String password);
  Future<void> signInEmail(String email, String password);
  Future<void> requestPhoneOtp(String phone);
  Future<void> verifyPhoneOtp(String phone, String otp);
  Future<void> signInGoogle();
  Future<void> signOut();
}

class SupabaseAuthService implements AuthService {
  const SupabaseAuthService(this.client);
  final SupabaseClient client;

  @override
  String? get currentUserId => client.auth.currentSession?.user.id;

  @override
  Stream<String?> get userChanges =>
      client.auth.onAuthStateChange.map((event) => event.session?.user.id);

  @override
  Future<bool> signUpEmail(String email, String password) async {
    // The confirmation link comes back to the app (the OAuth deep link),
    // not to the project's Site URL.
    final response = await client.auth.signUp(
      email: email,
      password: password,
      emailRedirectTo: AppConfig.oauthRedirectUrl,
    );
    if (response.user == null) {
      throw const AuthException('Không tạo được tài khoản.');
    }
    return response.session != null;
  }

  @override
  Future<void> signInEmail(String email, String password) async {
    await client.auth.signInWithPassword(email: email, password: password);
  }

  @override
  Future<void> requestPhoneOtp(String phone) async {
    if (!AppConfig.phoneOtpEnabled) {
      throw const AuthException('SMS OTP chưa được cấu hình cho bản demo.');
    }
    await client.auth.signInWithOtp(phone: phone);
  }

  @override
  Future<void> verifyPhoneOtp(String phone, String otp) async {
    if (!AppConfig.phoneOtpEnabled) {
      throw const AuthException('SMS OTP chưa được bật.');
    }
    final response = await client.auth.verifyOTP(
      phone: phone, token: otp, type: OtpType.sms,
    );
    if (response.session == null) {
      throw const AuthException('Chưa xác nhận được phiên đăng nhập OTP.');
    }
  }

  @override
  Future<void> signInGoogle() async {
    if (!AppConfig.googleOAuthEnabled) {
      throw const AuthException('Google OAuth chưa được cấu hình.');
    }
    final opened = await client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: AppConfig.oauthRedirectUrl,
    );
    if (!opened) {
      throw const AuthException('Không mở được trang đăng nhập Google.');
    }
  }

  @override
  Future<void> signOut() => client.auth.signOut();
}
