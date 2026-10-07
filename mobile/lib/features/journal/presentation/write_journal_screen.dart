import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/mascot_placeholder.dart';
import 'ai_reflection_screen.dart';

class WriteJournalScreen extends StatefulWidget {
  const WriteJournalScreen({super.key});

  @override
  State<WriteJournalScreen> createState() => _WriteJournalScreenState();
}

class _WriteJournalScreenState extends State<WriteJournalScreen> {
  final _controller = TextEditingController();
  String? _deeperQuestion;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _goDeeper() {
    if (_controller.text.trim().isEmpty) return;
    setState(() {
      // Sprint UI 01 uses a fake response. Replace through the feature repository later.
      _deeperQuestion = 'What part of this moment felt most different from what you expected?';
    });
  }

  void _finish() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => AiReflectionScreen(journalContent: text),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Write journal')),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'What is something you want to remember about today?',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: TextField(
                controller: _controller,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: const InputDecoration(
                  hintText: 'Start wherever you are...',
                  border: InputBorder.none,
                  filled: true,
                  fillColor: AppColors.surface,
                  contentPadding: EdgeInsets.all(AppSpacing.lg),
                ),
              ),
            ),
            if (_deeperQuestion != null) ...[
              const SizedBox(height: AppSpacing.md),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const MascotPlaceholder(state: MascotState.thinking, size: 48),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(child: Text(_deeperQuestion!)),
                ],
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _goDeeper,
                    icon: const Icon(Icons.auto_awesome_outlined),
                    label: const Text('Go Deeper'),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: FilledButton(
                    onPressed: _finish,
                    child: const Text('Finish'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
