import 'dart:async';
import 'dart:convert';

import '../../auth/data/auth_service.dart';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum SignInMethod { email, google, facebook }

/// Who is signed in, and how.
@immutable
class SignedInUser {
  const SignedInUser({required this.method, this.email});

  final SignInMethod method;
  final String? email;
}

/// Signing in could not be done; [message] says why, in the app's words.
class SignInFailed implements Exception {
  const SignInFailed(this.message);

  final String message;
}

/// The app's account. Named as the backend's (`AuthService` on
/// feat/map-m01-real-search, Supabase), so the real one replaces the mock
/// without touching the screens.
abstract interface class SignInService {
  /// Null while signed out.
  ValueListenable<SignedInUser?> get user;

  /// True when signed in at once (no email to confirm first).
  Future<bool> signUpEmail(String email, String password);
  Future<void> signInEmail(String email, String password);
  Future<void> signInGoogle();

  /// After Facebook's own login and consent.
  Future<void> signInFacebook();
  Future<void> signOut();
}

/// Until the backend is merged: nothing is sent anywhere and no password is
/// kept, only that someone signed in, how, and with which email.
class MockSignInService implements SignInService {
  MockSignInService({this.delay = const Duration(milliseconds: 900)});

  static final instance = MockSignInService();

  static const _key = 'auth.mockUser';

  /// How long "Đang đăng nhập…" shows.
  final Duration delay;

  final _user = ValueNotifier<SignedInUser?>(null);

  @override
  ValueListenable<SignedInUser?> get user => _user;

  Future<void> restore() async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(_key);
      if (raw == null) return;
      final json = (jsonDecode(raw) as Map).cast<String, Object?>();
      final method = SignInMethod.values.asNameMap()[json['method']];
      if (method == null) return;
      _user.value =
          SignedInUser(method: method, email: json['email'] as String?);
    } catch (_) {
      // Unreadable: signed out.
    }
  }

  Future<void> _signIn(SignInMethod method, [String? email]) async {
    await Future<void>.delayed(delay);
    final user = SignedInUser(method: method, email: email);
    try {
      await (await SharedPreferences.getInstance())
          .setString(_key, jsonEncode({'method': method.name, 'email': email}));
    } catch (_) {
      // Signed in for this run only.
    }
    _user.value = user;
  }

  @override
  Future<bool> signUpEmail(String email, String password) async {
    await _signIn(SignInMethod.email, email);
    return true;
  }

  @override
  Future<void> signInEmail(String email, String password) =>
      _signIn(SignInMethod.email, email);

  @override
  Future<void> signInGoogle() => _signIn(SignInMethod.google);

  @override
  Future<void> signInFacebook() => _signIn(SignInMethod.facebook);

  @override
  Future<void> signOut() async {
    _user.value = null;
    try {
      await (await SharedPreferences.getInstance()).remove(_key);
    } catch (_) {
      // Nothing kept to forget.
    }
  }
}

/// Real Supabase adapter for Vy's existing sign-in layout.
/// The AuthGate listens to the same Supabase session and switches routes.
class SupabaseSignInAdapter implements SignInService {
  SupabaseSignInAdapter(this.auth);
  final AuthService auth;
  final ValueNotifier<SignedInUser?> _user = ValueNotifier(null);

  @override
  ValueListenable<SignedInUser?> get user => _user;

  @override
  Future<bool> signUpEmail(String email, String password) async {
    final active = await auth.signUpEmail(email, password);
    if (active) _user.value = SignedInUser(method: SignInMethod.email, email: email);
    return active;
  }

  @override
  Future<void> signInEmail(String email, String password) async {
    await auth.signInEmail(email, password);
    _user.value = SignedInUser(method: SignInMethod.email, email: email);
  }

  void Function()? _cancelOAuthWait;

  /// Stop waiting locally. The external provider could still finish a login
  /// if its browser tab remains open; callers must not claim it was revoked.
  void cancelOAuthWait() => _cancelOAuthWait?.call();

  /// Listen before opening the browser. Race its launch, the callback and
  /// local cancellation as a single operation so the spinner can ALWAYS stop,
  /// even when an external browser launch Future never resolves.
  Future<void> _awaitOAuth(Future<void> Function() openBrowser) async {
    if (_cancelOAuthWait != null) {
      throw const SignInFailed('Đang chờ một lần đăng nhập khác.');
    }
    final event = Completer<Object?>();
    _cancelOAuthWait = () {
      if (!event.isCompleted) event.complete(false);
    };
    final subscription = auth.userChanges.listen(
      (id) {
        if (id != null && !event.isCompleted) event.complete(true);
      },
      onError: (Object error, StackTrace stack) {
        if (!event.isCompleted) event.complete(error);
      },
    );
    try {
      final launchAndCallback = () async {
        await openBrowser();
        if (auth.currentUserId != null) return true;
        return event.future;
      }();
      // The callback might arrive while the native browser is still opening;
      // likewise Cancel must not have to wait for the browser Future.
      final result = await Future.any<Object?>([
        launchAndCallback,
        event.future,
      ]).timeout(
        const Duration(minutes: 2),
        onTimeout: () => const SignInFailed(
          'Không nhận được phiên đăng nhập. Quay lại ứng dụng rồi thử lại.',
        ),
      );
      if (result == true && auth.currentUserId != null) return;
      if (result is SignInFailed) throw result;
      if (result == false) {
        throw const SignInFailed(
          'Đã dừng chờ. Hãy đóng trang đăng nhập bên ngoài nếu còn mở.',
        );
      }
      throw const SignInFailed(
        'Đăng nhập không hoàn tất. Kiểm tra tài khoản rồi thử lại.',
      );
    } finally {
      _cancelOAuthWait = null;
      // Not awaited: cancelling a listener of a broadcast auth stream may
      // only complete when the stream closes, which would keep the caller
      // waiting (spinner, "Dừng chờ đăng nhập") after the wait had ended.
      unawaited(subscription.cancel());
    }
  }

  @override
  Future<void> signInGoogle() => _awaitOAuth(auth.signInGoogle);

  @override
  Future<void> signInFacebook() => _awaitOAuth(auth.signInFacebook);

  @override
  Future<void> signOut() => auth.signOut();
}
