import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text.dart';
import '../../../../core/widgets/app_ui.dart';
import 'map_overlay_parts.dart';

abstract final class PlacePickText {
  static const hint = 'Di chuyển bản đồ để chọn vị trí';
  static const cancel = 'Huỷ';
  static const confirm = 'Chọn vị trí này';
}

/// Choosing where a new place goes: a pin fixed at the middle of the map
/// (its tip exactly on the map's centre), a hint above and "Huỷ" / "Chọn
/// vị trí này" below. The user moves the map under the pin; while the map
/// moves the pin lifts a little, and sets down when it stops.
class PlacePickOverlay extends StatelessWidget {
  const PlacePickOverlay({
    super.key,
    required this.moving,
    required this.onCancel,
    required this.onConfirm,
  });

  /// The map is being moved.
  final bool moving;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return Stack(fit: StackFit.expand, children: [
      MapCenterPin(moving: moving),
      SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.md, 12, AppSpacing.md, AppSpacing.md),
          child: Column(children: [
            MapFloatingSurface(
              radius: 20,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md, vertical: 12),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.open_with_rounded,
                      size: 20, color: AppColors.primaryAction),
                  const SizedBox(width: AppSpacing.sm),
                  Flexible(
                    child: Semantics(
                      liveRegion: true,
                      child:
                          const Text(PlacePickText.hint, style: AppText.label),
                    ),
                  ),
                ]),
              ),
            ),
            const Spacer(),
            MapFloatingSurface(
              radius: 28,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  Expanded(
                    child: AppSecondaryButton(
                        label: PlacePickText.cancel,
                        compact: true,
                        onPressed: onCancel),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: AppPrimaryButton(
                        label: PlacePickText.confirm,
                        icon: Icons.check_rounded,
                        compact: true,
                        onPressed: onConfirm),
                  ),
                ]),
              ),
            ),
          ]),
        ),
      ),
    ]);
  }
}
