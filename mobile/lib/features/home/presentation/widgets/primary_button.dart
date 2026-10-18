import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class PrimaryButton extends StatelessWidget {
  const PrimaryButton(
      {super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primaryAction,
        foregroundColor: AppColors.surface,
        minimumSize: const Size.fromHeight(54),
      ),
      onPressed: onPressed,
      child: Text(label),
    );
  }
}
