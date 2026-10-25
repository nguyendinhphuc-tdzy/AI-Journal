import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../album_scope.dart';
import '../data/album_auth.dart';
import '../data/album_unlocks.dart';
import 'album_cover.dart';
import 'album_form_parts.dart';
import 'nudaeng_album_key.dart';

/// A04. Only generic artwork/copy is allowed here, even on failed auth.
class AlbumUnlockScreen extends StatefulWidget {
  const AlbumUnlockScreen(
      {super.key, required this.albumId, required this.onUnlocked});
  final String albumId;
  final VoidCallback onUnlocked;
  static const description = 'Mở khóa để xem album này';

  @override
  State<AlbumUnlockScreen> createState() => _AlbumUnlockScreenState();
}

class _AlbumUnlockScreenState extends State<AlbumUnlockScreen> {
  final _session = AlbumUnlocks.instance;
  bool _busy = false;
  bool _success = false;
  bool _animationComplete = false;
  bool _opening = false;
  int? _successRevision;
  String? _message;

  @override
  void initState() {
    super.initState();
    _session.addListener(_sessionChanged);
  }

  void _sessionChanged() {
    if (_success && _successRevision != _session.revision) {
      setState(() {
        _success = false;
        _animationComplete = false;
        _message = 'Phiên mở khóa đã kết thúc. Hãy xác thực lại.';
      });
    }
    if (_success && _animationComplete && _session.foreground && !_opening) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _animationFinished();
      });
    }
  }

  Future<void> _authenticate() async {
    if (_busy || _success || !_session.foreground) return;
    final auth = AlbumScope.authOf(context);
    setState(() {
      _busy = true;
      _message = null;
    });
    AlbumAuthResult result;
    try {
      result = await auth.authenticate('Xác thực để mở album');
    } catch (_) {
      result = AlbumAuthResult.failed;
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (result == AlbumAuthResult.success && _session.foreground) {
        _success = true;
        _successRevision = _session.revision;
      } else {
        _message = switch (result) {
          AlbumAuthResult.canceled => 'Đã hủy xác thực. Album vẫn được khóa.',
          AlbumAuthResult.notSetUp =>
            'Hãy thiết lập khóa màn hình hoặc sinh trắc học trong cài đặt thiết bị.',
          AlbumAuthResult.notSupported =>
            'Thiết bị chưa hỗ trợ xác thực mở khóa.',
          _ => 'Chưa mở khóa được. Bạn có thể thử lại hoặc hủy.',
        };
      }
    });
  }

  void _animationFinished() {
    _animationComplete = true;
    if (!_success ||
        _opening ||
        !_session.foreground ||
        _successRevision != _session.revision) {
      return;
    }
    _opening = true;
    _session.unlock(widget.albumId);
    widget.onUnlocked();
  }

  @override
  void dispose() {
    _session.removeListener(_sessionChanged);
    super.dispose();
  }

  String get _status => _success
      ? 'Xác thực thành công. Đang mở album…'
      : _busy
          ? 'Đang xác thực…'
          : _message ?? 'Album đang được khóa.';

  IconData get _statusIcon => _success
      ? Icons.lock_open_rounded
      : _message != null
          ? Icons.info_outline_rounded
          : Icons.lock_outline_rounded;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          surfaceTintColor: Colors.transparent,
          // Generic on purpose: no album name or cover before unlocking.
          title: const Text('Album đã khóa', style: AlbumFormText.title),
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.lg),
                children: [
                  _Scene(success: _success, onKeyPutAway: _animationFinished),
                  const SizedBox(height: AppSpacing.xl),
                  Semantics(
                    header: true,
                    child: const Text(AlbumUnlockScreen.description,
                        textAlign: TextAlign.center, style: _Text.title),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  const Text(
                    'Nhập mã PIN của máy, hoặc dùng vân tay, khuôn mặt.',
                    textAlign: TextAlign.center,
                    style: _Text.body,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  // The state in words and an icon, never only the mascot.
                  Center(
                    child: Semantics(
                      liveRegion: true,
                      child: AnimatedContainer(
                        duration: MediaQuery.disableAnimationsOf(context)
                            ? Duration.zero
                            : const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: _success
                              ? AppColors.primaryLight
                              : AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: _success
                                  ? AppColors.primary
                                  : AppColors.border),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          if (_busy)
                            const SizedBox.square(
                              dimension: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.primaryAction),
                            )
                          else
                            Icon(_statusIcon,
                                size: 18, color: AppColors.textPrimary),
                          const SizedBox(width: AppSpacing.sm),
                          Flexible(
                            child: Text(_status,
                                textAlign: TextAlign.center,
                                style: AlbumFormText.bodyStrong),
                          ),
                        ]),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  AlbumPrimaryButton(
                    label: _message == null ? 'Mở khóa' : 'Thử lại',
                    onPressed: _busy || _success ? null : _authenticate,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  TextButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      minimumSize: const Size.fromHeight(48),
                      textStyle: AlbumFormText.section,
                    ),
                    child: const Text('Hủy'),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  const Text(AlbumLockCard.notEncrypted,
                      textAlign: TextAlign.center, style: AlbumFormText.note),
                ],
              ),
            ),
          ),
        ),
      );
}

/// The generic locked cover with Nudaeng (96) beside it, key in paw; after a
/// confirmed unlock the key goes into the pouch once (1 s).
class _Scene extends StatelessWidget {
  const _Scene({required this.success, required this.onKeyPutAway});

  final bool success;
  final VoidCallback onKeyPutAway;

  static const coverWidth = 168.0;
  static const nudaeng = 96.0;

  @override
  Widget build(BuildContext context) => Center(
        child: Container(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: SizedBox(
            width: coverWidth + nudaeng * .62,
            height: coverWidth / AlbumCover.aspectRatio + nudaeng * .3,
            child: Stack(clipBehavior: Clip.none, children: [
              const Positioned(
                left: 0,
                top: 0,
                width: coverWidth,
                child: AlbumCover(themeId: 'classic', locked: true),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                width: nudaeng,
                height: nudaeng,
                child: NudaengAlbumKey(
                  authSucceeded: success,
                  onCompleted: onKeyPutAway,
                  semanticLabel: success
                      ? 'Nudaeng cất chìa khóa vào túi'
                      : 'Nudaeng cầm chìa khóa',
                ),
              ),
            ]),
          ),
        ),
      );
}

abstract final class _Text {
  static const title = TextStyle(
    fontFamily: 'Nunito',
    fontSize: 24,
    fontWeight: FontWeight.w700,
    height: 1.3,
    color: AppColors.textPrimary,
  );
  static const body = TextStyle(
    fontFamily: 'BeVietnamPro',
    fontSize: 16,
    height: 1.5,
    color: AppColors.textPrimary,
  );
}
