import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

enum MascotState {
  idle,
  thinking,
  writing,
  happy,
  sleeping,
  walking,
  study,
  album,
  map,
}

class MascotPlaceholder extends StatelessWidget {
  const MascotPlaceholder({
    super.key,
    this.state = MascotState.idle,
    this.size = 96,
  });

  final MascotState state;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Mascot ${state.name}',
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppColors.primaryLight,
          borderRadius: BorderRadius.circular(size / 2),
          border: Border.all(color: AppColors.border),
        ),
        alignment: Alignment.center,
        child: Text(
          state.name,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
        ),
      ),
    );
  }
}
