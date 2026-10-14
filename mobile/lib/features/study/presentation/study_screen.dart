import 'package:flutter/material.dart';

import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/mascot_placeholder.dart';

class StudyScreen extends StatelessWidget {
  const StudyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const frameworks = [
      ('Daily Reflection', 'Look back on the day with one gentle prompt.'),
      ('Gratitude', 'Notice a few things that felt meaningful or good.'),
      ('Clear My Mind', 'Untangle a thought by writing it out step by step.'),
    ];

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Study & Challenges', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600)),
            MascotPlaceholder(state: MascotState.study, size: 64),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        for (final item in frameworks) ...[
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.all(AppSpacing.md),
              title: Text(item.$1),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Text(item.$2),
              ),
              trailing: const Icon(Icons.chevron_right),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        OutlinedButton.icon(
          onPressed: null,
          icon: const Icon(Icons.auto_awesome_outlined),
          label: const Text('AI Recommend Me — later sprint'),
        ),
      ],
    );
  }
}
