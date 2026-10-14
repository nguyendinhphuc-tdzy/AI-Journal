import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class JournalCard extends StatelessWidget {
  const JournalCard(
      {super.key, required this.child, this.color = AppColors.surface});

  final Widget child;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(padding: const EdgeInsets.all(20), child: child),
    );
  }
}
