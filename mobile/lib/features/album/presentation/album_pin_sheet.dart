import 'dart:async';

import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/widgets/app_delete_dialog.dart';
import '../../../core/widgets/app_ui.dart';
import '../data/album_auth.dart';
import '../data/album_pins.dart';
import '../data/album_unlocks.dart';

/// The app's [AlbumAuth]: the PIN pad in the app's sheet, over [AlbumPins].
/// After [maxTries] wrong PINs in a row the pad waits [wait] before the next
/// try (kept for the app session).
///
/// Albums locked before PINs (with the device's screen lock) have none: the
/// device confirms the owner once ([legacyCheck]), then a PIN is chosen and
/// kept, and the album opens with it from then on.
class PinAlbumAuth implements AlbumAuth {
  PinAlbumAuth(
      [this.pins = const LocalAlbumPins(), Future<bool> Function()? legacy])
      : legacyCheck = legacy ?? _deviceCheck;

  final AlbumPins pins;
  final Future<bool> Function() legacyCheck;

  static const legacyReason =
      'Album này được khóa bằng khóa màn hình của máy. Xác nhận một lần để '
      'đặt mật khẩu riêng cho album.';

  static Future<bool> _deviceCheck() async {
    try {
      // The system prompt pauses the app; that is not leaving it.
      return await AlbumUnlocks.instance.duringSystemPrompt(() =>
          LocalAuthentication().authenticate(
              localizedReason: legacyReason, persistAcrossBackgrounding: true));
    } catch (_) {
      return false;
    }
  }

  static const maxTries = 5;
  static const wait = Duration(seconds: 30);

  final _wrong = <String, int>{};
  final _waitUntil = <String, DateTime>{};

  @override
  Future<String?> choosePin(BuildContext context) =>
      showAppSheet<String>(context, builder: (_) => const AlbumPinPad.choose());

  @override
  Future<AlbumAuthResult> verify(BuildContext context, String albumId,
      {required String reason}) async {
    bool hasPin;
    try {
      hasPin = await pins.has(albumId);
    } catch (_) {
      return AlbumAuthResult.failed;
    }
    if (!hasPin) {
      if (!await legacyCheck() || !context.mounted) {
        return AlbumAuthResult.failed;
      }
      final pin = await choosePin(context);
      if (pin == null) return AlbumAuthResult.canceled;
      await setPin(albumId, pin);
      return AlbumAuthResult.success;
    }
    if (!context.mounted) return AlbumAuthResult.canceled;
    final opened = await showAppSheet<bool>(context,
        builder: (_) => AlbumPinPad.verify(
            reason: reason, check: (pin) => _check(albumId, pin)));
    return switch (opened) {
      true => AlbumAuthResult.success,
      false => AlbumAuthResult.failed,
      null => AlbumAuthResult.canceled,
    };
  }

  @override
  Future<void> setPin(String albumId, String? pin) async {
    _wrong.remove(albumId);
    _waitUntil.remove(albumId);
    await pins.set(albumId, pin);
  }

  Future<PinCheck> _check(String albumId, String pin) async {
    final until = _waitUntil[albumId];
    final now = DateTime.now();
    if (until != null && now.isBefore(until)) {
      return PinCheck.waitFor(until.difference(now));
    }
    if (await pins.check(albumId, pin)) {
      _wrong.remove(albumId);
      return PinCheck.right;
    }
    final wrong = (_wrong[albumId] ?? 0) + 1;
    if (wrong < maxTries) {
      _wrong[albumId] = wrong;
      return PinCheck.wrong;
    }
    _wrong.remove(albumId);
    _waitUntil[albumId] = now.add(wait);
    return const PinCheck.waitFor(wait);
  }
}

/// What checking an entered PIN said.
class PinCheck {
  const PinCheck._(this.ok, [this.wait]);

  static const right = PinCheck._(true);
  static const wrong = PinCheck._(false);
  const PinCheck.waitFor(Duration wait) : this._(false, wait);

  final bool ok;

  /// Too many wrong tries: how long until the next.
  final Duration? wait;
}

/// Four dots and a number pad, in the app's sheet. [AlbumPinPad.choose]
/// asks for a new PIN twice and closes with it; [AlbumPinPad.verify] asks
/// for the album's and closes with true once it is right.
class AlbumPinPad extends StatefulWidget {
  const AlbumPinPad.choose({super.key})
      : reason = null,
        check = null;

  const AlbumPinPad.verify(
      {super.key, required String this.reason, required this.check});

  final String? reason;
  final Future<PinCheck> Function(String pin)? check;

  static const chooseTitle = 'Đặt mật khẩu album';
  static const chooseHelp =
      'Chọn 4 chữ số. Bạn sẽ nhập mã này mỗi lần mở album.';
  static const confirmTitle = 'Nhập lại để xác nhận';
  static const confirmHelp = 'Nhập lại 4 chữ số vừa chọn.';
  static const mismatch = 'Hai lần nhập chưa khớp. Bạn đặt lại nhé.';
  static const verifyTitle = 'Nhập mật khẩu album';
  static const wrong = 'Sai mật khẩu. Bạn thử lại nhé.';
  static const checkFailed = 'Chưa kiểm tra được mật khẩu. Bạn thử lại nhé.';
  static const forgotLabel = 'Quên mật khẩu?';
  static const forgotHelp =
      'Sau này, khi bạn đăng nhập tài khoản, mật khẩu album có thể khôi phục '
      'qua email. Hiện chưa khôi phục được: nếu quên, album sẽ không mở được.';
  static const deleteLabel = 'Xóa số';

  static String waitText(int seconds) =>
      'Nhập sai nhiều lần. Thử lại sau $seconds giây.';

  @override
  State<AlbumPinPad> createState() => _AlbumPinPadState();
}

class _AlbumPinPadState extends State<AlbumPinPad> {
  var _digits = '';
  String? _first;
  String? _error;
  var _busy = false;
  var _forgot = false;
  var _waitSeconds = 0;
  Timer? _countdown;

  bool get _choosing => widget.check == null;

  @override
  void dispose() {
    _countdown?.cancel();
    super.dispose();
  }

  void _tap(String digit) {
    if (_busy || _waitSeconds > 0 || _digits.length >= AlbumPins.length) {
      return;
    }
    setState(() {
      _digits += digit;
      _error = null;
    });
    if (_digits.length == AlbumPins.length) _complete(_digits);
  }

  void _erase() {
    if (_busy || _digits.isEmpty) return;
    setState(() => _digits = _digits.substring(0, _digits.length - 1));
  }

  Future<void> _complete(String pin) async {
    if (_choosing) {
      final first = _first;
      if (first == null) {
        setState(() {
          _first = pin;
          _digits = '';
        });
      } else if (first == pin) {
        Navigator.of(context).pop(pin);
      } else {
        setState(() {
          _first = null;
          _digits = '';
          _error = AlbumPinPad.mismatch;
        });
      }
      return;
    }
    setState(() => _busy = true);
    PinCheck result;
    try {
      result = await widget.check!(pin);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _digits = '';
        _error = AlbumPinPad.checkFailed;
      });
      return;
    }
    if (!mounted) return;
    if (result.ok) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _busy = false;
      _digits = '';
      _error = AlbumPinPad.wrong;
    });
    if (result.wait case final wait?) _startWait(wait);
  }

  void _startWait(Duration wait) {
    _countdown?.cancel();
    setState(() => _waitSeconds = (wait.inMilliseconds / 1000).ceil());
    _countdown = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() => _waitSeconds--);
      if (_waitSeconds <= 0) {
        timer.cancel();
        setState(() => _error = null);
      }
    });
  }

  String get _title => !_choosing
      ? AlbumPinPad.verifyTitle
      : _first == null
          ? AlbumPinPad.chooseTitle
          : AlbumPinPad.confirmTitle;

  String get _help => !_choosing
      ? widget.reason!
      : _first == null
          ? AlbumPinPad.chooseHelp
          : AlbumPinPad.confirmHelp;

  @override
  Widget build(BuildContext context) {
    final message =
        _waitSeconds > 0 ? AlbumPinPad.waitText(_waitSeconds) : _error;
    final enabled = !_busy && _waitSeconds == 0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(_title,
              textAlign: TextAlign.center, style: AppText.sectionTitle),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(_help, textAlign: TextAlign.center, style: AppText.bodySecondary),
        const SizedBox(height: AppSpacing.lg),
        _Dots(filled: _digits.length),
        // Reserved, so the pad never jumps when a message comes or goes.
        SizedBox(
          height: 44,
          child: Center(
            child: message == null
                ? null
                : Semantics(
                    liveRegion: true,
                    child: Text(message,
                        textAlign: TextAlign.center,
                        style: AppText.meta
                            .copyWith(color: AppDeleteDialog.destructive)),
                  ),
          ),
        ),
        for (final row in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ]) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final digit in row)
                _Key(label: digit, onTap: enabled ? () => _tap(digit) : null),
            ],
          ),
          const SizedBox(height: 12),
        ],
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox.square(dimension: _Key.size + 24),
            _Key(label: '0', onTap: enabled ? () => _tap('0') : null),
            _Key(
              icon: Icons.backspace_outlined,
              label: AlbumPinPad.deleteLabel,
              plain: true,
              onTap: enabled && _digits.isNotEmpty ? _erase : null,
            ),
          ],
        ),
        if (!_choosing) ...[
          const SizedBox(height: AppSpacing.sm),
          Center(
            child: TextButton(
              onPressed: () => setState(() => _forgot = !_forgot),
              style: TextButton.styleFrom(
                  foregroundColor: AppColors.primaryAction,
                  minimumSize: const Size(48, 48),
                  textStyle: AppText.label),
              child: const Text(AlbumPinPad.forgotLabel),
            ),
          ),
          if (_forgot)
            const Text(AlbumPinPad.forgotHelp,
                textAlign: TextAlign.center, style: AppText.meta),
        ],
      ],
    );
  }
}

/// The PIN's four places: filled as digits come.
class _Dots extends StatelessWidget {
  const _Dots({required this.filled});

  final int filled;

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Đã nhập $filled trên ${AlbumPins.length} số',
        excludeSemantics: true,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < AlbumPins.length; i++)
              AnimatedContainer(
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 120),
                margin: const EdgeInsets.symmetric(horizontal: 10),
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < filled ? AppColors.primaryAction : null,
                  border: Border.all(
                      color: i < filled
                          ? AppColors.primaryAction
                          : AppColors.textSecondary,
                      width: 1.5),
                ),
              ),
          ],
        ),
      );
}

/// One round key of the pad, 64 across: a digit on Background, or an icon
/// on nothing ([plain]).
class _Key extends StatelessWidget {
  const _Key({required this.label, this.icon, this.plain = false, this.onTap});

  final String label;
  final IconData? icon;
  final bool plain;
  final VoidCallback? onTap;

  static const size = 64.0;

  @override
  Widget build(BuildContext context) {
    final icon = this.icon;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: Material(
          color: plain ? Colors.transparent : AppColors.background,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: SizedBox.square(
              dimension: size,
              child: Center(
                child: icon != null
                    ? Icon(icon,
                        color: onTap == null
                            ? AppColors.border
                            : AppColors.textPrimary)
                    : Text(label,
                        style: AppText.sectionTitle.copyWith(
                            fontSize: 26,
                            color: onTap == null
                                ? AppColors.textSecondary
                                : AppColors.textPrimary)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
