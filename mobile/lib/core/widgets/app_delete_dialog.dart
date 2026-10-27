import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text.dart';

/// The app's one "delete?" dialog, for anything that goes for good (a
/// journal entry, a memory, an album, a post taken off the map).
///
/// A Surface dialog (modal radius, 35 % dim) with Nudaeng crumbling away,
/// a centered title and body, an optional [preview] of what goes, then
/// "Giữ lại" on light grey and the action in a deep brick red: 48-high pills
/// without outlines.
///
/// [onConfirm] runs in the dialog: a spinner in place of the action,
/// "Giữ lại", Back and the barrier off, repeated taps ignored. Success
/// closes it with true; only then do callers remove anything from screen. A
/// failure stays, says why ([describeError], else [failed]) and offers
/// "Thử lại". No undo is offered.
class AppDeleteDialog extends StatefulWidget {
  const AppDeleteDialog({
    super.key,
    required this.title,
    required this.body,
    required this.confirmLabel,
    required this.onConfirm,
    this.preview,
    this.failed = genericFailed,
    this.describeError,
  });

  final String title;
  final String body;
  final String confirmLabel;
  final Future<void> Function() onConfirm;

  /// What goes, under the body (e.g. [AppDeletePreview]).
  final Widget? preview;

  /// Said when [onConfirm] fails and [describeError] has nothing better.
  final String failed;

  /// A message for this error, or null to say [failed].
  final String? Function(Object error)? describeError;

  static const cancelLabel = 'Giữ lại';
  static const retryLabel = 'Thử lại';
  static const genericFailed = 'Chưa xóa được. Bạn thử lại nhé.';

  /// Transparent, so it sits on Surface without a box.
  static const art = 'assets/images/nudaeng-delete-transparent.png';

  /// Deep brick red for the destructive action: 5.9:1 with a Surface label.
  static const destructive = Color(0xFFA6453A);
  static const _keepFill = Color(0xFFE9ECE8);

  /// Shows the dialog [builder] makes (an [AppDeleteDialog], or a widget
  /// that builds one). True once its action succeeded; false when kept.
  static Future<bool> present(
    BuildContext context, {
    required WidgetBuilder builder,
    bool useRootNavigator = false,
  }) async =>
      await showDialog<bool>(
        context: context,
        useRootNavigator: useRootNavigator,
        barrierColor: Colors.black.withValues(alpha: .35),
        builder: builder,
      ) ??
      false;

  @override
  State<AppDeleteDialog> createState() => _AppDeleteDialogState();
}

class _AppDeleteDialogState extends State<AppDeleteDialog> {
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
        _error = widget.describeError?.call(error) ?? widget.failed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const destructive = AppDeleteDialog.destructive;
    final preview = widget.preview;
    return PopScope(
      canPop: !_busy,
      child: Dialog(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.modal)),
        insetPadding: const EdgeInsets.all(AppSpacing.lg),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(
                  child: Image(
                    image: AssetImage(AppDeleteDialog.art),
                    width: 128,
                    excludeFromSemantics: true,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Semantics(
                  header: true,
                  child: Text(widget.title,
                      textAlign: TextAlign.center, style: AppText.sectionTitle),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(widget.body,
                    textAlign: TextAlign.center, style: AppText.bodySecondary),
                if (preview != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  preview,
                ],
                if (_error case final error?) ...[
                  const SizedBox(height: 12),
                  Semantics(
                    liveRegion: true,
                    child: Text(error,
                        textAlign: TextAlign.center,
                        style: AppText.meta.copyWith(color: destructive)),
                  ),
                ],
                const SizedBox(height: AppSpacing.xl),
                Row(children: [
                  Expanded(
                    child: TextButton(
                      onPressed:
                          _busy ? null : () => Navigator.of(context).pop(false),
                      style: _pill(
                          fill: AppDeleteDialog._keepFill,
                          label: AppColors.textPrimary),
                      child: const Text(AppDeleteDialog.cancelLabel,
                          textAlign: TextAlign.center),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      // Repeated taps while it runs do nothing.
                      onPressed: _confirm,
                      style: _pill(fill: destructive, label: AppColors.surface),
                      child: _busy
                          ? Semantics(
                              label: widget.confirmLabel,
                              child: const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2.2, color: AppColors.surface),
                              ),
                            )
                          : Text(
                              _error == null
                                  ? widget.confirmLabel
                                  : AppDeleteDialog.retryLabel,
                              textAlign: TextAlign.center),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 48 high, pill-shaped, no outline; disabled keeps its colours faded.
  static ButtonStyle _pill({required Color fill, required Color label}) =>
      ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.disabled)
                ? fill.withValues(alpha: .6)
                : fill),
        foregroundColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.disabled)
                ? label.withValues(alpha: .6)
                : label),
        minimumSize: const WidgetStatePropertyAll(Size(0, 48)),
        padding:
            const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 12)),
        shape: const WidgetStatePropertyAll(StadiumBorder()),
        textStyle: const WidgetStatePropertyAll(AppText.label),
      );
}

/// What a delete takes, on a soft mint strip: an optional line above (e.g.
/// when it was written) and its name, on one line.
class AppDeletePreview extends StatelessWidget {
  const AppDeletePreview({super.key, required this.title, this.meta});

  final String title;
  final String? meta;

  @override
  Widget build(BuildContext context) {
    final meta = this.meta;
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.input),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (meta != null) ...[
            Text(meta, style: AppText.meta),
            const SizedBox(height: 2),
          ],
          Text(title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.label),
        ],
      ),
    );
  }
}
