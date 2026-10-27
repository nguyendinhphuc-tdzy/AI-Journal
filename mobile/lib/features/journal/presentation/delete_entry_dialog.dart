import 'package:flutter/material.dart';

import '../../../core/widgets/app_delete_dialog.dart';
import '../data/journal_entry.dart';
import 'journal_list_screen.dart';

/// Asks before an entry goes: the app's [AppDeleteDialog], with the entry
/// (when it was written and its first line) on the preview strip. The
/// delete runs in the dialog; a failure stays and offers "Thử lại".
class DeleteEntryDialog extends StatelessWidget {
  const DeleteEntryDialog(
      {super.key, required this.entry, required this.onConfirm});

  final JournalEntry entry;
  final Future<void> Function() onConfirm;

  static const title = 'Xóa bài viết?';
  static const body = 'Bài viết sẽ bị xóa vĩnh viễn\nvà không thể khôi phục.';
  static const cancelLabel = AppDeleteDialog.cancelLabel;
  static const confirmLabel = 'Xóa bài viết';
  static const retryLabel = AppDeleteDialog.retryLabel;
  static const failed = 'Chưa xóa được bài viết. Bạn thử lại nhé.';

  /// True once [onConfirm] succeeded; false when kept.
  static Future<bool> show(
    BuildContext context, {
    required JournalEntry entry,
    required Future<void> Function() onConfirm,
  }) =>
      AppDeleteDialog.present(context,
          builder: (_) =>
              DeleteEntryDialog(entry: entry, onConfirm: onConfirm));

  @override
  Widget build(BuildContext context) {
    final at = entry.createdAt.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    final (first, _) = JournalListScreen.summary(entry);
    return AppDeleteDialog(
      title: title,
      body: body,
      confirmLabel: confirmLabel,
      failed: failed,
      onConfirm: onConfirm,
      preview: AppDeletePreview(
        meta: '${two(at.day)}/${two(at.month)}/${at.year} · '
            '${two(at.hour)}:${two(at.minute)}',
        title: first.isEmpty ? 'Bài viết không có nội dung' : first,
      ),
    );
  }
}
