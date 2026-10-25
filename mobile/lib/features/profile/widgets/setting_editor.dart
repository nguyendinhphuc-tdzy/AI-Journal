import 'package:flutter/material.dart';

/// Keeps the dialog open on validation/storage failure; Cancel never writes.
class SettingEditor extends StatefulWidget {
  const SettingEditor(
      {super.key,
      required this.title,
      required this.initial,
      required this.save,
      this.options,
      this.validate,
      this.note,
      this.previewSize});
  final String title;
  final String initial;
  final Map<String, String>? options;
  final String? Function(String)? validate;
  final Future<void> Function(String) save;
  final String? note;
  final double Function(String)? previewSize;

  @override
  State<SettingEditor> createState() => _SettingEditorState();
}

class _SettingEditorState extends State<SettingEditor> {
  late String _value = widget.initial;
  bool _saving = false;
  String? _error;

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
  Widget build(BuildContext context) => PopScope(
        canPop: !_saving,
        child: AlertDialog(
          title: Text(widget.title),
          content: SingleChildScrollView(
              child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.note != null) ...[
                Text(widget.note!),
                const SizedBox(height: 16)
              ],
              if (widget.options == null)
                TextFormField(
                  initialValue: _value,
                  enabled: !_saving,
                  autofocus: true,
                  onChanged: (value) => _value = value,
                  decoration: const InputDecoration(labelText: 'Biệt danh'),
                )
              else
                DropdownButtonFormField<String>(
                  initialValue: _value,
                  isExpanded: true,
                  items: [
                    for (final option in widget.options!.entries)
                      DropdownMenuItem(
                          value: option.key,
                          child: Text(option.value,
                              overflow: TextOverflow.ellipsis))
                  ],
                  onChanged: _saving
                      ? null
                      : (value) => setState(() => _value = value!),
                ),
              if (widget.previewSize != null) ...[
                const SizedBox(height: 20),
                Text('Một chút thời gian dành cho mình.',
                    style: TextStyle(fontSize: widget.previewSize!(_value))),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error))
              ],
            ],
          )),
          actions: [
            TextButton(
                onPressed: _saving ? null : () => Navigator.pop(context),
                child: const Text('Hủy')),
            FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(_saving ? 'Đang lưu…' : 'Lưu')),
          ],
        ),
      );
}
