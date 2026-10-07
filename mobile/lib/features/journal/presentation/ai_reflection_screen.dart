import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/mascot_placeholder.dart';

class AiReflectionScreen extends StatelessWidget {
  const AiReflectionScreen({super.key, required this.journalContent});

  final String journalContent;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('A reflection for you')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          const Center(
            child: MascotPlaceholder(state: MascotState.happy, size: 110),
          ),
          const SizedBox(height: AppSpacing.xl),
          _ReflectionCard(
            title: 'What I noticed',
            body: 'You seem to feel more relaxed after finishing something you had been carrying for a while.',
          ),
          const SizedBox(height: AppSpacing.md),
          _ReflectionCard(
            title: 'Something to think about',
            body: 'What helped you move from thinking about it to actually finishing it?',
          ),
          const SizedBox(height: AppSpacing.xl),
          FilledButton(
            onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
            child: const Text('Done'),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'UI sprint note: this reflection is mocked until the AI endpoint is integrated.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
        ],
      ),
    );
  }
}

class _ReflectionCard extends StatelessWidget {
  const _ReflectionCard({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            Text(body),
          ],
        ),
      ),
    );
  }
}
