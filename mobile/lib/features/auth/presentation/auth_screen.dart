import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_colors.dart';
import '../data/auth_service.dart';

enum _AuthMethod { email, phone }

/// Real Supabase login: email/password or phone number with SMS OTP.
class AuthScreen extends StatefulWidget {
  const AuthScreen({
    super.key,
    required this.auth,
    this.onContinueAsGuest,
    this.initialError,
    this.facebookOAuthEnabled = AppConfig.facebookOAuthEnabled,
    this.startWithPhone = false,
  });

  final AuthService auth;
  final Future<void> Function()? onContinueAsGuest;
  final String? initialError;

  /// Only show this login method if the app explicitly enables OAuth.
  final bool facebookOAuthEnabled;
  /// Open the existing SMS OTP form directly from Vy's sign-in screen.
  final bool startWithPhone;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _phone = TextEditingController();
  final _otp = TextEditingController();

  _AuthMethod _method = _AuthMethod.email;
  bool _signUp = false;
  bool _otpSent = false;
  bool _busy = false;
  bool _showPassword = false;
  String? _message;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    if (widget.startWithPhone) _method = _AuthMethod.phone;
    _message = widget.initialError;
    _error = widget.initialError != null;
  }

  Future<void> _confirmGuest() async {
    if (_busy || widget.onContinueAsGuest == null) return;
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Tiếp tục không có tài khoản?'),
        content: const Text(
          'Nhật ký và tiến trình của bạn chỉ lưu trên thiết bị này. '
          'AI-Journal không đồng bộ hay sao lưu dữ liệu khách. '
          'Khi gỡ ứng dụng, dữ liệu cục bộ sẽ mất và không thể khôi phục '
          'từ tài khoản AI-Journal.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Quay lại'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Tiếp tục'),
          ),
        ],
      ),
    );
    if (!mounted || approved != true) return;
    await _perform(() async {
      await widget.onContinueAsGuest!();
      return null;
    });
  }

  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static final _phonePattern = RegExp(r'^\+[1-9]\d{7,14}$');

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _phone.dispose();
    _otp.dispose();
    super.dispose();
  }

  void _switchMethod(_AuthMethod value) {
    if (_busy) return;
    setState(() {
      _method = value;
      _otpSent = false;
      _otp.clear();
      _message = null;
      _error = false;
    });
  }

  Future<void> _perform(Future<String?> Function() task) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
      _error = false;
    });
    try {
      final message = await task();
      if (mounted) setState(() => _message = message);
    } on AuthException catch (error) {
      if (!mounted) return;
      setState(() {
        _message = error.message;
        _error = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _message = 'Không thể kết nối. Kiểm tra mạng và thử lại.';
        _error = true;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _submit() {
    if (_method == _AuthMethod.email) {
      final email = _email.text.trim();
      final password = _password.text;
      if (!_emailPattern.hasMatch(email)) {
        setState(() {
          _message = 'Vui lòng nhập email hợp lệ.';
          _error = true;
        });
        return;
      }
      if ((_signUp && password.length < 8) ||
          (!_signUp && password.isEmpty)) {
        setState(() {
          _message = _signUp
              ? 'Mật khẩu mới phải có ít nhất 8 ký tự.'
              : 'Vui lòng nhập mật khẩu.';
          _error = true;
        });
        return;
      }
      _perform(() async {
        if (_signUp) {
          final active = await widget.auth.signUpEmail(email, password);
          return active
              ? null
              : 'Kiểm tra hộp thư để xác nhận email, sau đó đăng nhập.';
        }
        await widget.auth.signInEmail(email, password);
        return null;
      });
      return;
    }

    final phone = _phone.text.trim();
    if (!_phonePattern.hasMatch(phone)) {
      setState(() {
        _message = 'Nhập số theo chuẩn quốc tế, ví dụ +84901234567.';
        _error = true;
      });
      return;
    }
    if (!_otpSent) {
      _perform(() async {
        await widget.auth.requestPhoneOtp(phone);
        if (mounted) setState(() => _otpSent = true);
        return 'Đã yêu cầu mã xác nhận. Kiểm tra tin nhắn SMS.';
      });
      return;
    }
    final otp = _otp.text.trim();
    if (!RegExp(r'^[0-9]{6}$').hasMatch(otp)) {
      setState(() {
        _message = 'Nhập mã OTP gồm 6 chữ số.';
        _error = true;
      });
      return;
    }
    _perform(() async {
      await widget.auth.verifyPhoneOtp(phone, otp);
      return null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final emailSelected = _method == _AuthMethod.email;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.auto_stories_rounded,
                      size: 60, color: AppColors.primaryDark),
                  const SizedBox(height: 14),
                  Text('AI Diary',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('Không gian riêng cho những điều bạn muốn ghi nhớ.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 30),
                  Text(_signUp ? 'Tạo tài khoản' : 'Đăng nhập',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 16),
                  SegmentedButton<_AuthMethod>(
                    segments: const [
                      ButtonSegment(value: _AuthMethod.email,
                          label: Text('Email / Gmail'),
                          icon: Icon(Icons.mail_outline)),
                      ButtonSegment(value: _AuthMethod.phone,
                          label: Text('Điện thoại'),
                          icon: Icon(Icons.phone_android)),
                    ],
                    selected: {_method},
                    onSelectionChanged: _busy
                        ? null
                        : (values) => _switchMethod(values.first),
                  ),
                  const SizedBox(height: 20),
                  if (emailSelected) ...[
                    TextField(
                      controller: _email,
                      enabled: !_busy,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(
                          labelText: 'Email', prefixIcon: Icon(Icons.alternate_email)),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _password,
                      enabled: !_busy,
                      obscureText: !_showPassword,
                      autofillHints: [
                        _signUp ? AutofillHints.newPassword : AutofillHints.password
                      ],
                      decoration: InputDecoration(
                        labelText: 'Mật khẩu (ít nhất 8 ký tự)',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          tooltip: _showPassword ? 'Ẩn mật khẩu' : 'Hiện mật khẩu',
                          onPressed: () => setState(
                              () => _showPassword = !_showPassword),
                          icon: Icon(_showPassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined),
                        ),
                      ),
                    ),
                  ] else ...[
                    TextField(
                      controller: _phone,
                      enabled: !_busy && !_otpSent,
                      keyboardType: TextInputType.phone,
                      autofillHints: const [AutofillHints.telephoneNumber],
                      decoration: const InputDecoration(
                          labelText: 'Số điện thoại (+84...)',
                          prefixIcon: Icon(Icons.phone_outlined)),
                    ),
                    if (_otpSent) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: _otp,
                        enabled: !_busy,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        decoration: const InputDecoration(
                            labelText: 'Mã OTP SMS',
                            prefixIcon: Icon(Icons.verified_user_outlined)),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _busy
                              ? null
                              : () => setState(() {
                                    _otpSent = false;
                                    _otp.clear();
                                    _message = null;
                                  }),
                          child: const Text('Nhập lại số / gửi mã mới'),
                        ),
                      ),
                    ],
                  ],
                  if (_message != null) ...[
                    const SizedBox(height: 14),
                    Text(_message!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: _error
                            ? Theme.of(context).colorScheme.error
                            : AppColors.primaryDark)),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? const SizedBox(
                            width: 22, height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(emailSelected
                            ? (_signUp ? 'Đăng ký bằng email' : 'Đăng nhập')
                            : (_otpSent ? 'Xác nhận OTP' : 'Gửi mã SMS')),
                  ),
                  if (emailSelected) ...[
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _busy ? null : () => setState(() {
                        _signUp = !_signUp;
                        _message = null;
                      }),
                      child: Text(_signUp
                          ? 'Đã có tài khoản? Đăng nhập'
                          : 'Chưa có tài khoản? Đăng ký'),
                    ),
                    if (AppConfig.googleOAuthEnabled) ...[
                      const Divider(height: 28),
                      OutlinedButton.icon(
                        onPressed: _busy ? null : () => _perform(() async {
                          await widget.auth.signInGoogle();
                          return null;
                        }),
                        icon: const Icon(Icons.login),
                        label: const Text('Tiếp tục bằng Google'),
                      ),
                    ],
                  ],
                  if (emailSelected && widget.facebookOAuthEnabled) ...[
                    const Divider(height: 28),
                    OutlinedButton.icon(
                      onPressed: _busy ? null : () => _perform(() async {
                        await widget.auth.signInFacebook();
                        return null;
                      }),
                      icon: const Icon(Icons.facebook),
                      label: const Text('Tiếp tục bằng Facebook'),
                    ),
                  ],
                  if (widget.onContinueAsGuest != null) ...[
                    const Divider(height: 32),
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _confirmGuest,
                      icon: const Icon(Icons.person_outline),
                      label: const Text('Continue without an account'),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Chế độ khách: không tạo tài khoản, không đồng bộ. '
                      'Gỡ ứng dụng sẽ mất nhật ký và tiến trình lưu cục bộ.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  const SizedBox(height: 20),
                  Text('Đăng nhập qua Supabase Auth. Nhật ký hiện lưu '
                       'riêng trên thiết bị, chưa đồng bộ cloud.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
