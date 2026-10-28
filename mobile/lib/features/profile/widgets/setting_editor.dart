import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/widgets/app_ui.dart';

/// The content of a setting's sheet (open it with `showAppSheet`): a list of
/// choices, or a text field when there are no [options]. Keeps the sheet
/// open on validation/storage failure; Cancel never writes.
class SettingEditor extends StatefulWidget {
  const SettingEditor(
      {super.key,
      required this.title,
      required this.initial,
      required this.save,
      this.options,
      this.validate,
      this.note,
      this.previewSize,
      this.onPreview});
  final String title;
  final String initial;
  final Map<String, String>? options;
  final String? Function(String)? validate;
  final Future<void> Function(String) save;
  final String? note;
  final double Function(String)? previewSize;

  /// A choice was tapped (before saving): to hear a sound, say.
  final ValueChanged<String>? onPreview;

  @override
  State<SettingEditor> createState() => _SettingEditorState();
}

class _SettingEditorState extends State<SettingEditor> {
  late String _value = widget.initial;
  bool _saving = false;
  String? _error;

  static const _fieldBorder = OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(AppRadius.input)),
    borderSide: BorderSide(color: AppColors.border),
  );

  Future<void> _save() async {
    if (_saving) return;
    final error = widget.validate?.call(_value);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.save(_value);
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Chưa lưu được. Hãy thử lại.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final options = widget.options;
    final previewSize = widget.previewSize;
    return PopScope(
      canPop: !_saving,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.title, style: AppText.sectionTitle),
          if (widget.note != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(widget.note!, style: AppText.bodySecondary),
          ],
          const SizedBox(height: AppSpacing.lg),
          if (options == null)
            TextFormField(
              initialValue: _value,
              enabled: !_saving,
              autofocus: true,
              style: AppText.body,
              onChanged: (value) => _value = value,
              decoration: const InputDecoration(
                labelText: 'Biệt danh',
                filled: true,
                fillColor: AppColors.background,
                border: _fieldBorder,
                enabledBorder: _fieldBorder,
                focusedBorder: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.all(Radius.circular(AppRadius.input)),
                  borderSide:
                      BorderSide(color: AppColors.primaryAction, width: 1.5),
                ),
              ),
            )
          else
            for (final (index, option) in options.entries.indexed) ...[
              if (index > 0) const SizedBox(height: AppSpacing.sm),
              _Choice(
                key: ValueKey('setting-option-${option.key}'),
                label: option.value,
                selected: option.key == _value,
                onTap: _saving
                    ? null
                    : () {
                        setState(() => _value = option.key);
                        widget.onPreview?.call(option.key);
                      },
              ),
            ],
          if (previewSize != null) ...[
            const SizedBox(height: AppSpacing.md),
            // How the chosen size reads, on the colour entries are written on.
            DecoratedBox(
              decoration: const BoxDecoration(
                color: AppColors.background,
                borderRadius:
                    BorderRadius.all(Radius.circular(AppRadius.input)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Text('Một chút thời gian dành cho mình.',
                    style:
                        AppText.body.copyWith(fontSize: previewSize(_value))),
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(_error!,
                style: AppText.meta
                    .copyWith(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: AppSpacing.xl),
          Row(children: [
            Expanded(
              child: AppSecondaryButton(
                  label: 'Hủy',
                  onPressed: _saving ? null : () => Navigator.pop(context)),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: AppPrimaryButton(
                  label: 'Lưu', busy: _saving, onPressed: _save),
            ),
          ]),
        ],
      ),
    );
  }
}

/// One choice: a rounded row, Primary Light with a check when selected.
class _Choice extends StatelessWidget {
  const _Choice(
      {super.key,
      required this.label,
      required this.selected,
      required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        inMutuallyExclusiveGroup: true,
        selected: selected,
        button: true,
        child: Material(
          color: selected ? AppColors.primaryLight : AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius:
                const BorderRadius.all(Radius.circular(AppRadius.input)),
            side: BorderSide(
                color: selected ? AppColors.primaryAction : AppColors.border,
                width: selected ? 1.5 : 1),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md, vertical: 12),
                child: Row(children: [
                  Expanded(child: Text(label, style: AppText.body)),
                  const SizedBox(width: AppSpacing.sm),
                  Icon(
                    selected
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 22,
                    color: selected
                        ? AppColors.primaryAction
                        : AppColors.textSecondary,
                  ),
                ]),
              ),
            ),
          ),
        ),
      );
}
