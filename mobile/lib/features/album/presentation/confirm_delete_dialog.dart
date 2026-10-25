import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../data/album.dart';
import '../data/album_deletion.dart';
import 'album_form_parts.dart';

/// A11 (and A12's "Gỡ khỏi bản đồ"): a Surface dialog that names what goes
/// and what happens, with "Hủy" and a destructive action in the theme's
/// error colour (as A03's "Xóa album"), never the primary teal.
///
/// - The action runs in the dialog: a spinner in its place, "Hủy", Back and
///   the barrier off. Success closes it with true; only then do callers
///   remove anything from screen. A failure keeps the dialog, says why
///   ([DeletionFailure.message], or [failed]) and offers "Thử lại".
/// - No undo is offered, no celebration.
class ConfirmDeleteDialog extends StatefulWidget {
  const ConfirmDeleteDialog({
    super.key,
    required this.title,
    required this.body,
    required this.confirmLabel,
    required this.onConfirm,
    this.failed = genericFailed,
  });

  final String title;
  final String body;
  final String confirmLabel;
  final Future<void> Function() onConfirm;

  /// Said when [onConfirm] fails with anything but a [DeletionFailure].
  final String failed;

  static const cancelLabel = 'Hủy';
  static const retryLabel = 'Thử lại';
  static const genericFailed = 'Chưa làm được. Bạn thử lại nhé.';

  static const memoryTitle = 'Xóa kỷ niệm';
  static const albumTitle = 'Xóa album';
  static const noUndo = 'Không thể hoàn tác.';

  static String memoryBody({String? title, required Album album}) {
    final what = title == null || title.trim().isEmpty
        ? 'Kỷ niệm này'
        : 'Kỷ niệm "${title.trim()}"';
    return '$what sẽ bị xóa khỏi album "${_albumName(album)}", gồm ảnh, ghi '
        'chú và địa điểm. Nếu kỷ niệm đang được chia sẻ, bài chia sẻ sẽ được '
        'gỡ khỏi bản đồ. $noUndo';
  }

  static String albumBody(Album album, int memories) {
    final name = '"${_albumName(album)}"';
    return memories == 0
        ? 'Album $name sẽ bị xóa. Album chưa có kỷ niệm nào. $noUndo'
        : 'Album $name và $memories kỷ niệm trong đó sẽ bị xóa, gồm ảnh, ghi '
            'chú và địa điểm. Các bài chia sẻ từ album này sẽ được gỡ khỏi '
            'bản đồ. $noUndo';
  }

  /// A locked album that hides its name is not named here either.
  static String _albumName(Album album) =>
      album.locked && album.hideNameWhenLocked ? 'Album đã khóa' : album.name;

  /// True once [onConfirm] succeeded; false when canceled.
  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String body,
    required String confirmLabel,
    required Future<void> Function() onConfirm,
    String failed = genericFailed,
  }) async =>
      await showDialog<bool>(
        context: context,
        useRootNavigator: true,
        barrierColor: Colors.black.withValues(alpha: .35),
        builder: (_) => ConfirmDeleteDialog(
          title: title,
          body: body,
          confirmLabel: confirmLabel,
          onConfirm: onConfirm,
          failed: failed,
        ),
      ) ??
      false;

  @override
  State<ConfirmDeleteDialog> createState() => _ConfirmDeleteDialogState();
}

class _ConfirmDeleteDialogState extends State<ConfirmDeleteDialog> {
  var _busy = false;
  String? _error;

  Future<void> _confirm() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onConfirm();
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error is DeletionFailure ? error.message : widget.failed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PopScope(
      canPop: !_busy,
      child: Dialog(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        insetPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg, vertical: AppSpacing.lg),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  header: true,
                  child: Text(widget.title, style: AlbumFormText.title),
                ),
                const SizedBox(height: 12),
                Text(widget.body, style: AlbumFormText.body),
                if (_error case final error?) ...[
                  const SizedBox(height: AppSpacing.md),
                  AlbumFormMessage(error),
                ],
                const SizedBox(height: AppSpacing.lg),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    TextButton(
                      onPressed:
                          _busy ? null : () => Navigator.of(context).pop(false),
                      style: TextButton.styleFrom(
                          foregroundColor: AppColors.textPrimary,
                          minimumSize: const Size(48, 48),
                          textStyle: AlbumFormText.section),
                      child: const Text(ConfirmDeleteDialog.cancelLabel),
                    ),
                    FilledButton(
                      // Repeated taps while it runs do nothing.
                      onPressed: _confirm,
                      style: FilledButton.styleFrom(
                        backgroundColor: scheme.error,
                        foregroundColor: scheme.onError,
                        minimumSize: const Size(120, 48),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24)),
                        textStyle: AlbumFormText.section,
                      ),
                      child: _busy
                          ? Semantics(
                              label: widget.confirmLabel,
                              child: SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2.2, color: scheme.onError),
                              ),
                            )
                          : Text(_error == null
                              ? widget.confirmLabel
                              : ConfirmDeleteDialog.retryLabel),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
