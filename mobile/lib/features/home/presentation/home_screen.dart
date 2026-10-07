import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/mascot_placeholder.dart';
import '../../journal/presentation/write_journal_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('A quiet moment for you', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Write naturally. Notice what matters.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                  ],
                ),
              ),
              const MascotPlaceholder(state: MascotState.idle, size: 72),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Daily reflection', style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'What is something you want to remember about today?',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  FilledButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const WriteJournalScreen()),
                    ),
                    child: const Text('Write'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text('Recent journals', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.md),
          const _JournalPreview(
            title: 'A calmer afternoon',
            preview: 'I finally finished something I had been thinking about all week...',
            meta: 'Today · calm',
          ),
          const SizedBox(height: AppSpacing.md),
          const _JournalPreview(
            title: 'Small things I noticed',
            preview: 'The weather felt softer today and I took a longer walk...',
            meta: 'Yesterday · reflective',
          ),
        ],
      ),
    );
  }
}

class _JournalPreview extends StatelessWidget {
  const _JournalPreview({
    required this.title,
    required this.preview,
    required this.meta,
  });

  final String title;
  final String preview;
  final String meta;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            Text(preview, maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: AppSpacing.sm),
            Text(
              meta,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
