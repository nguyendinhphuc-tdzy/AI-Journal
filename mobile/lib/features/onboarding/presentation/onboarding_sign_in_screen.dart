import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_ui.dart';
import '../../social/data/friends_account.dart';
import '../../social/presentation/facebook_login_screen.dart';
import '../data/sign_in_service.dart';
import 'onboarding_widgets.dart';
import 'login_fishing_scene.dart';

/// OB01b: the account, right after "Bắt đầu" and before the questions.
///
/// - A mint header with the brand, "Bắt đầu nào" and Nudaeng fishing, its
///   line dropping onto a sheet of paper that holds the form.
/// - "Đăng nhập" / "Đăng ký" tabs; email and password (shown or hidden);
///   signing up asks for the password twice. "Ghi nhớ đăng nhập" and
///   "Quên mật khẩu?" when signing in. Mistakes are said under the field.
/// - Or "Tiếp tục với Google" / "Tiếp tục với Facebook". Facebook also
///   brings friends on the app (who can see 24-hour shares).
/// - "Để sau" goes on without an account. Back returns to OB01.
/// - Simulated until the backend's sign-in is merged: nothing is sent, no
///   password is kept; the screen says so.
class OnboardingSignInScreen extends StatefulWidget {
  const OnboardingSignInScreen({
    super.key,
    required this.service,
    required this.onBack,
    required this.onDone,
    this.friends,
    this.realAuth = false,
    this.onGuest,
  });

  final SignInService service;
  final bool realAuth;
  final Future<void> Function()? onGuest;

  /// Facebook friends on the app; Facebook also connects these.
  final FriendsAccount? friends;
  final VoidCallback onBack;

  /// Signed in, or "Để sau": on to OB02.
  final VoidCallback onDone;

  static const brand = 'Nhật ký AI';
  static const title = 'Bắt đầu nào';
  static const subtitle =
      'Tạo tài khoản hoặc đăng nhập để nhật ký của bạn luôn được giữ lại.';
  static const signInTab = 'Đăng nhập';
  static const signUpTab = 'Đăng ký';
  static const emailLabel = 'Email';
  static const emailHint = 'ban@email.com';
  static const passwordLabel = 'Mật khẩu';
  static const confirmLabel = 'Nhập lại mật khẩu';
  static const showPassword = 'Hiện mật khẩu';
  static const hidePassword = 'Ẩn mật khẩu';
  static const remember = 'Ghi nhớ đăng nhập';
  static const forgot = 'Quên mật khẩu?';
  static const signInLabel = 'Đăng nhập';
  static const signUpLabel = 'Tạo tài khoản';
  static const working = 'Đang đăng nhập…';
  static const or = 'hoặc';
  static const google = 'Tiếp tục với Google';
  static const facebook = 'Tiếp tục với Facebook';
  static const later = 'Để sau';
  static const backTooltip = 'Quay lại';
  static const mockNote =
      'Bản thử: chưa có tài khoản thật. Thông tin bạn nhập không được lưu hay '
      'gửi đi đâu.';

  static const emailMissing = 'Bạn nhập email nhé.';
  static const emailInvalid = 'Email chưa đúng, ví dụ: ban@email.com';
  static const passwordMissing = 'Bạn nhập mật khẩu nhé.';
  static const passwordShort = 'Mật khẩu cần ít nhất 6 ký tự.';
  static const confirmMismatch = 'Hai mật khẩu chưa giống nhau.';
  static const failed = 'Chưa đăng nhập được. Bạn thử lại nhé.';

  static const forgotTitle = 'Quên mật khẩu?';
  static const forgotBody =
      'Khi có tài khoản thật, Nhật ký AI sẽ gửi liên kết đặt lại mật khẩu về '
      'email của bạn. Bản thử chưa gửi được email.';
  static const forgotDone = 'Đã hiểu';

  static const minPassword = 6;

  @override
  State<OnboardingSignInScreen> createState() => _OnboardingSignInScreenState();
}

class _OnboardingSignInScreenState extends State<OnboardingSignInScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  var _signUp = false;
  var _hidden = true;
  var _remember = true;
  var _busy = false;
  String? _emailError;
  String? _passwordError;
  String? _confirmError;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  static final _emailShape = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  void _switchTab(bool signUp) {
    if (_busy || signUp == _signUp) return;
    setState(() {
      _signUp = signUp;
      _passwordError = null;
      _confirmError = null;
      _error = null;
    });
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    final password = _password.text;
    setState(() {
      _emailError = email.isEmpty
          ? OnboardingSignInScreen.emailMissing
          : _emailShape.hasMatch(email)
              ? null
              : OnboardingSignInScreen.emailInvalid;
      _passwordError = password.isEmpty
          ? OnboardingSignInScreen.passwordMissing
          : _signUp && password.length < OnboardingSignInScreen.minPassword
              ? OnboardingSignInScreen.passwordShort
              : null;
      _confirmError = _signUp && _confirm.text != password
          ? OnboardingSignInScreen.confirmMismatch
          : null;
      _error = null;
    });
    if (_emailError != null ||
        _passwordError != null ||
        _confirmError != null) {
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    if (_signUp) {
      await _signUpReal(email, password);
    } else {
      await _run(() => widget.service.signInEmail(email, password));
    }
  }

  Future<void> _signUpReal(String email, String password) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final active = await widget.service.signUpEmail(email, password);
      if (!mounted) return;
      if (active) {
        widget.onDone();
      } else {
        setState(() => _error = 'Kiểm tra email xác nhận tài khoản, sau đó đăng nhập.');
      }
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } on SignInFailed catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = e is Exception ? e.toString() : OnboardingSignInScreen.failed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _facebook() async {
    if (_busy) return;
    final friends = widget.friends;
    if (!widget.realAuth && friends != null) {
      // Facebook's login and consent, which also brings friends on the app.
      final connected = await openFacebookLogin(context, friends);
      if (!connected || !mounted) return;
    }
    await _run(widget.service.signInFacebook);
  }

  /// Runs a sign-in with the button busy; on to OB02 once it worked.
  Future<void> _run(Future<Object?> Function() signIn) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await signIn();
      // Nothing typed is kept once signed in.
      _password.clear();
      _confirm.clear();
      if (mounted) widget.onDone();
    } on SignInFailed catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = OnboardingSignInScreen.failed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _forgot() => showAppSheet<void>(
        context,
        builder: (sheet) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(OnboardingSignInScreen.forgotTitle, style: _Text.sheet),
            const SizedBox(height: AppSpacing.sm),
            const Text(OnboardingSignInScreen.forgotBody, style: _Text.body),
            const SizedBox(height: AppSpacing.lg),
            OnboardingCta(
                label: OnboardingSignInScreen.forgotDone,
                onPressed: () => Navigator.pop(sheet)),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.background,
        body: OnboardingStagger(
          child: SafeArea(
            bottom: false,
            child: LayoutBuilder(
              builder: (context, box) => SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: box.maxHeight),
                  // The paper runs to the bottom on a tall screen.
                  child: IntrinsicHeight(
                    child: Column(children: [
                      _header(context),
                      Expanded(child: _card(context)),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

  /// An open, calm scene above the paper form; never overlaps its fields.
  Widget _header(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 24, 0),
            child: Row(children: [
              if (!widget.realAuth)
                IconButton(
                  onPressed: _busy ? null : widget.onBack,
                  tooltip: OnboardingSignInScreen.backTooltip,
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
              const Flexible(
                  child:
                      Text(OnboardingSignInScreen.brand, style: _Text.brand)),
            ]),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 8, 24, 0),
            child: StaggerItem(
              order: 0,
              child: Text(OnboardingSignInScreen.title, style: _Text.title),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 8, 24, 0),
            child: StaggerItem(
              order: 1,
              child:
                  Text(OnboardingSignInScreen.subtitle, style: _Text.subtitle),
            ),
          ),
          const StaggerItem(order: 2, child: LoginFishingScene()),
        ],
      );

  /// The paper holding the form.
  Widget _card(BuildContext context) => StaggerItem(
        order: 3,
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: AppColors.textPrimary.withValues(alpha: .08),
                blurRadius: 24,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          padding: EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg + MediaQuery.paddingOf(context).bottom),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Tabs(signUp: _signUp, onChanged: _switchTab),
                  const SizedBox(height: AppSpacing.lg),
                  _label(OnboardingSignInScreen.emailLabel),
                  TextField(
                    controller: _email,
                    enabled: !_busy,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autocorrect: false,
                    autofillHints: const [AutofillHints.email],
                    style: _Text.input,
                    cursorColor: AppColors.primaryAction,
                    onChanged: (_) {
                      if (_emailError != null) {
                        setState(() => _emailError = null);
                      }
                    },
                    decoration: _field(
                        hint: OnboardingSignInScreen.emailHint,
                        error: _emailError),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _label(OnboardingSignInScreen.passwordLabel),
                  _passwordField(_password, _passwordError, last: !_signUp,
                      onChanged: () {
                    if (_passwordError != null) {
                      setState(() => _passwordError = null);
                    }
                  }),
                  if (_signUp) ...[
                    const SizedBox(height: AppSpacing.md),
                    _label(OnboardingSignInScreen.confirmLabel),
                    _passwordField(_confirm, _confirmError, last: true,
                        onChanged: () {
                      if (_confirmError != null) {
                        setState(() => _confirmError = null);
                      }
                    }),
                  ] else ...[
                    const SizedBox(height: AppSpacing.xs),
                    // Side by side when they fit; "Quên mật khẩu?" goes under
                    // on a narrow screen or with large text.
                    Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          InkWell(
                            borderRadius:
                                BorderRadius.circular(AppRadius.small),
                            onTap: _busy
                                ? null
                                : () => setState(() => _remember = !_remember),
                            child:
                                Row(mainAxisSize: MainAxisSize.min, children: [
                              Checkbox(
                                value: _remember,
                                onChanged: _busy
                                    ? null
                                    : (on) => setState(() => _remember = on!),
                                activeColor: AppColors.primaryAction,
                                visualDensity: VisualDensity.compact,
                              ),
                              const Flexible(
                                child: Text(OnboardingSignInScreen.remember,
                                    style: _Text.small),
                              ),
                            ]),
                          ),
                          TextButton(
                            onPressed: _busy ? null : _forgot,
                            style: TextButton.styleFrom(
                                foregroundColor: AppColors.primaryAction,
                                minimumSize: const Size(48, 44)),
                            child: const Text(OnboardingSignInScreen.forgot,
                                style: _Text.link),
                          ),
                        ]),
                  ],
                  if (_error case final error?) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Semantics(
                      liveRegion: true,
                      child: Text(error,
                          style: _Text.small.copyWith(
                              color: Theme.of(context).colorScheme.error)),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  OnboardingCta(
                    label: _busy
                        ? OnboardingSignInScreen.working
                        : _signUp
                            ? OnboardingSignInScreen.signUpLabel
                            : OnboardingSignInScreen.signInLabel,
                    onPressed: _busy ? null : _submit,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const _Or(),
                  const SizedBox(height: AppSpacing.lg),
                  _ProviderButton(
                    label: OnboardingSignInScreen.google,
                    icon: const CustomPaint(
                        size: Size.square(20), painter: _GoogleMark()),
                    onPressed:
                        _busy ? null : () => _run(widget.service.signInGoogle),
                  ),
                  const SizedBox(height: 12),
                  _ProviderButton(
                    label: OnboardingSignInScreen.facebook,
                    icon: const Icon(Icons.facebook_rounded,
                        size: 22, color: facebookBlue),
                    onPressed: _busy ? null : _facebook,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  OnboardingTextAction(
                    label: OnboardingSignInScreen.later,
                    onPressed: () async {
                      if (_busy) return;
                      if (widget.onGuest != null) {
                        await widget.onGuest!();
                      } else {
                        widget.onDone();
                      }
                    },
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  if (!widget.realAuth)
                    const Text(OnboardingSignInScreen.mockNote,
                        textAlign: TextAlign.center, style: _Text.note),
                ],
              ),
            ),
          ),
        ),
      );

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: ExcludeSemantics(child: Text(text, style: _Text.label)),
      );

  Widget _passwordField(TextEditingController controller, String? error,
          {required bool last, required VoidCallback onChanged}) =>
      TextField(
        controller: controller,
        enabled: !_busy,
        obscureText: _hidden,
        autocorrect: false,
        enableSuggestions: false,
        textInputAction: last ? TextInputAction.done : TextInputAction.next,
        onSubmitted: last ? (_) => _submit() : null,
        style: _Text.input,
        cursorColor: AppColors.primaryAction,
        onChanged: (_) => onChanged(),
        decoration: _field(error: error).copyWith(
          suffixIcon: IconButton(
            tooltip: _hidden
                ? OnboardingSignInScreen.showPassword
                : OnboardingSignInScreen.hidePassword,
            onPressed: () => setState(() => _hidden = !_hidden),
            icon: Icon(
                _hidden
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: AppColors.textSecondary),
          ),
        ),
      );

  static InputDecoration _field({String? hint, String? error}) {
    OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: BorderSide(color: color, width: width),
        );
    return InputDecoration(
      hintText: hint,
      hintStyle: _Text.hint,
      errorText: error,
      errorMaxLines: 2,
      filled: true,
      fillColor: AppColors.background,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 14),
      enabledBorder: border(AppColors.border, 1),
      disabledBorder: border(AppColors.border, 1),
      focusedBorder: border(AppColors.primaryAction, 2),
      errorBorder: border(const Color(0xFFB3261E), 1),
      focusedErrorBorder: border(const Color(0xFFB3261E), 2),
    );
  }
}

/// "Đăng nhập" | "Đăng ký": the chosen one raised on Surface.
class _Tabs extends StatelessWidget {
  const _Tabs({required this.signUp, required this.onChanged});

  final bool signUp;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(children: [
        AnimatedAlign(
          alignment: signUp ? Alignment.centerRight : Alignment.centerLeft,
          duration: reduced ? Duration.zero : const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          child: FractionallySizedBox(
            widthFactor: .5,
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.textPrimary.withValues(alpha: .08),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),
        ),
        Row(children: [
          for (final (value, label) in [
            (false, OnboardingSignInScreen.signInTab),
            (true, OnboardingSignInScreen.signUpTab),
          ])
            Expanded(
              child: Semantics(
                button: true,
                selected: signUp == value,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => onChanged(value),
                  child: SizedBox(
                    height: 44,
                    child: Center(
                      child: Text(label,
                          style: _Text.tab.copyWith(
                              color: signUp == value
                                  ? AppColors.textPrimary
                                  : AppColors.textSecondary)),
                    ),
                  ),
                ),
              ),
            ),
        ]),
      ]),
    );
  }
}

class _Or extends StatelessWidget {
  const _Or();

  @override
  Widget build(BuildContext context) => const Row(children: [
        Expanded(child: Divider(color: AppColors.border)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Text(OnboardingSignInScreen.or, style: _Text.small),
        ),
        Expanded(child: Divider(color: AppColors.border)),
      ]);
}

/// "Tiếp tục với …": Surface, a hairline, the provider's mark.
class _ProviderButton extends StatelessWidget {
  const _ProviderButton(
      {required this.label, required this.icon, required this.onPressed});

  final String label;
  final Widget icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(color: AppColors.border),
          minimumSize: const Size.fromHeight(52),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
          textStyle: OnboardingCta.labelStyle,
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          icon,
          const SizedBox(width: 12),
          Flexible(child: Text(label, textAlign: TextAlign.center)),
        ]),
      );
}

/// Google's "G" (google-color.svg), drawn from its own paths on a 24 grid.
class _GoogleMark extends CustomPainter {
  const _GoogleMark();

  static const _parts = [
    (
      Color(0xFF4285F4),
      'M23 12.245c0-.905-.075-1.565-.236-2.25h-10.54v4.083h6.186c-.124 '
          '1.014-.797 2.542-2.294 3.569l-.021.136 3.332 2.53.23.022C21.779 '
          '18.417 23 15.593 23 12.245z'
    ),
    (
      Color(0xFF34A853),
      'M12.225 23c3.03 0 5.574-.978 7.433-2.665l-3.542-2.688c-.948.648-2.22 '
          '1.1-3.891 1.1a6.745 6.745 0 01-6.386-4.572l-.132.011-3.465 '
          '2.628-.045.124C4.043 20.531 7.835 23 12.225 23z'
    ),
    (
      Color(0xFFFBBC05),
      'M5.84 14.175A6.65 6.65 0 015.463 12c0-.758.138-1.491.361-2.175l-.006'
          '-.147-3.508-2.67-.115.054A10.831 10.831 0 001 12c0 1.772.436 '
          '3.447 1.197 4.938l3.642-2.763z'
    ),
    (
      Color(0xFFEB4335),
      'M12.225 5.253c2.108 0 3.529.892 4.34 1.638l3.167-3.031C17.787 2.088 '
          '15.255 1 12.225 1 7.834 1 4.043 3.469 2.197 7.062l3.63 '
          '2.763a6.77 6.77 0 016.398-4.572z'
    ),
  ];

  static final _paths = [for (final (_, d) in _parts) _svgPath(d)];

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24, size.height / 24);
    for (final (i, (colour, _)) in _parts.indexed) {
      canvas.drawPath(_paths[i], Paint()..color = colour);
    }
  }

  @override
  bool shouldRepaint(_GoogleMark old) => false;

  /// The SVG path commands these use: M C c H h V v L l A a Z.
  static Path _svgPath(String d) {
    final tokens = RegExp(r'[A-Za-z]|-?(?:\d+\.?\d*|\.\d+)')
        .allMatches(d)
        .map((m) => m[0]!)
        .toList();
    final path = Path();
    var i = 0;
    var command = '';
    var x = 0.0, y = 0.0;
    double next() => double.parse(tokens[i++]);
    // Arc flags may run together ("01"): one digit each.
    bool flag() {
      final token = tokens[i];
      if (token.length > 1) {
        tokens[i] = token.substring(1);
        return token[0] == '1';
      }
      i++;
      return token == '1';
    }

    while (i < tokens.length) {
      if (RegExp(r'^[A-Za-z]$').hasMatch(tokens[i])) command = tokens[i++];
      switch (command) {
        case 'M':
          x = next();
          y = next();
          path.moveTo(x, y);
          command = 'L';
        case 'L':
          x = next();
          y = next();
          path.lineTo(x, y);
        case 'l':
          final dx = next(), dy = next();
          path.relativeLineTo(dx, dy);
          x += dx;
          y += dy;
        case 'H':
          x = next();
          path.lineTo(x, y);
        case 'h':
          final dx = next();
          path.relativeLineTo(dx, 0);
          x += dx;
        case 'V':
          y = next();
          path.lineTo(x, y);
        case 'v':
          final dy = next();
          path.relativeLineTo(0, dy);
          y += dy;
        case 'C':
          final x1 = next(), y1 = next(), x2 = next(), y2 = next();
          x = next();
          y = next();
          path.cubicTo(x1, y1, x2, y2, x, y);
        case 'c':
          final x1 = next(), y1 = next(), x2 = next(), y2 = next();
          final dx = next(), dy = next();
          path.relativeCubicTo(x1, y1, x2, y2, dx, dy);
          x += dx;
          y += dy;
        case 'A' || 'a':
          final rx = next(), ry = next(), rotation = next();
          final large = flag(), sweep = flag();
          final ex = next(), ey = next();
          final relative = command == 'a';
          final end = relative ? Offset(x + ex, y + ey) : Offset(ex, ey);
          path.arcToPoint(end,
              radius: Radius.elliptical(rx, ry),
              rotation: rotation,
              largeArc: large,
              clockwise: sweep);
          x = end.dx;
          y = end.dy;
        case 'Z' || 'z':
          path.close();
        default:
          i++;
      }
    }
    return path;
  }
}

abstract final class _Text {
  static const brand = TextStyle(
    fontFamily: 'Nunito',
    fontSize: 18,
    fontWeight: FontWeight.w700,
    height: 1.3,
    color: AppColors.primaryAction,
  );
  static const title = TextStyle(
    fontFamily: 'Nunito',
    fontSize: 30,
    fontWeight: FontWeight.w700,
    height: 1.2,
    color: AppColors.textPrimary,
  );
  static const subtitle = TextStyle(
    fontFamily: 'BeVietnamPro',
    fontSize: 15,
    height: 1.45,
    color: AppColors.textSecondary,
  );
  static const sheet = TextStyle(
    fontFamily: 'Nunito',
    fontSize: 22,
    fontWeight: FontWeight.w700,
    height: 1.3,
    color: AppColors.textPrimary,
  );
  static const tab = TextStyle(
    fontFamily: 'BeVietnamPro',
    fontSize: 15,
    fontWeight: FontWeight.w600,
    height: 1.4,
  );
  static const label = TextStyle(
    fontFamily: 'BeVietnamPro',
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 20 / 14,
    color: AppColors.textPrimary,
  );
  static const input = TextStyle(
    fontFamily: 'BeVietnamPro',
    fontSize: 16,
    height: 1.4,
    color: AppColors.textPrimary,
  );
  static const hint = TextStyle(
    fontFamily: 'BeVietnamPro',
    fontSize: 16,
    height: 1.4,
    color: AppColors.textSecondary,
  );
  static const body = TextStyle(
    fontFamily: 'BeVietnamPro',
    fontSize: 15,
    height: 1.5,
    color: AppColors.textSecondary,
  );
  static const small = TextStyle(
    fontFamily: 'BeVietnamPro',
    fontSize: 14,
    height: 20 / 14,
    color: AppColors.textSecondary,
  );
  static const link = TextStyle(
    fontFamily: 'BeVietnamPro',
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 20 / 14,
  );
  static const note = TextStyle(
    fontFamily: 'BeVietnamPro',
    fontSize: 12,
    height: 1.4,
    color: AppColors.textSecondary,
  );
}
