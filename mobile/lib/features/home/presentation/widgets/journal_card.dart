import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class JournalCard extends StatelessWidget {
  const JournalCard({
    super.key,
    required this.child,
    this.color = AppColors.surface,
    this.width,
    this.margin = EdgeInsets.zero,
  });

  final Widget child;
  final Color color;
  final double? width;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Card(
        color: color,
        elevation: 0,
        margin: margin,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(padding: const EdgeInsets.all(20), child: child),
      ),
    );
  }
}
