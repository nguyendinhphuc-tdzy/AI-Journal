import 'package:flutter/material.dart';

import '../../../core/widgets/app_delete_dialog.dart';
import '../data/album.dart';
import '../data/album_deletion.dart';

/// A11 (and A12's "Gỡ khỏi bản đồ"): the app's [AppDeleteDialog] (Nudaeng,
/// "Giữ lại" and the action in brick red), naming what goes and what
/// happens.
///
/// - The action runs in the dialog: a spinner in its place, "Giữ lại", Back
///   and the barrier off. Success closes it with true; only then do callers
///   remove anything from screen. A failure keeps the dialog, says why
///   ([DeletionFailure.message], or [failed]) and offers "Thử lại".
/// - No undo is offered, no celebration.
class ConfirmDeleteDialog extends StatelessWidget {
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

  static const cancelLabel = AppDeleteDialog.cancelLabel;
  static const retryLabel = AppDeleteDialog.retryLabel;
  static const genericFailed = 'Chưa làm được. Bạn thử lại nhé.';

  static const memoryTitle = 'Xóa kỷ niệm';
  static const albumTitle = 'Xóa album';

  /// The dialog's titles; [memoryTitle] and [albumTitle] are its actions.
  static const memoryQuestion = 'Xóa kỷ niệm?';
  static const albumQuestion = 'Xóa album?';
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

  /// True once [onConfirm] succeeded; false when kept.
  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String body,
    required String confirmLabel,
    required Future<void> Function() onConfirm,
    String failed = genericFailed,
  }) =>
      AppDeleteDialog.present(
        context,
        useRootNavigator: true,
        builder: (_) => ConfirmDeleteDialog(
          title: title,
          body: body,
          confirmLabel: confirmLabel,
          onConfirm: onConfirm,
          failed: failed,
        ),
      );

  @override
  Widget build(BuildContext context) => AppDeleteDialog(
        title: title,
        body: body,
        confirmLabel: confirmLabel,
        onConfirm: onConfirm,
        failed: failed,
        describeError: (error) =>
            error is DeletionFailure ? error.message : null,
      );
}
