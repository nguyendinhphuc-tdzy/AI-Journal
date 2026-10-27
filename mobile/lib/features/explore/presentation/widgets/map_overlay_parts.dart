import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text.dart';

/// The soft shadow under everything that floats over the map, so Surface
/// reads on the light and the night style alike.
const mapOverlayShadow = [
  BoxShadow(color: Color(0x1F1F201C), blurRadius: 16, offset: Offset(0, 4)),
];

/// Surface floating over the map: [radius] corners, a hairline border and
/// [mapOverlayShadow]. Taps ripple inside its shape.
class MapFloatingSurface extends StatelessWidget {
  const MapFloatingSurface({
    super.key,
    required this.child,
    this.radius = 20,
    this.color = AppColors.surface,
  });

  final Widget child;
  final double radius;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final shape = BorderRadius.circular(radius);
    return DecoratedBox(
      decoration:
          BoxDecoration(borderRadius: shape, boxShadow: mapOverlayShadow),
      child: Material(
        color: color,
        shape: RoundedRectangleBorder(
            borderRadius: shape,
            side: const BorderSide(color: AppColors.border)),
        clipBehavior: Clip.antiAlias,
        child: child,
      ),
    );
  }
}

/// A mood to keep on the map, as Journal's chips: Primary Light with an
/// outline when chosen, Surface otherwise, 40 high.
class MapMoodChip extends StatelessWidget {
  const MapMoodChip(
      {super.key,
      required this.label,
      required this.selected,
      required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        selected: selected,
        child: DecoratedBox(
          decoration: const ShapeDecoration(
              shape: StadiumBorder(), shadows: mapOverlayShadow),
          child: Material(
            color: selected ? AppColors.primaryLight : AppColors.surface,
            shape: StadiumBorder(
                side: BorderSide(
                    color:
                        selected ? AppColors.primaryAction : AppColors.border)),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 40),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Center(
                    widthFactor: 1,
                    child: Text(label,
                        style: AppText.meta.copyWith(
                            color: selected
                                ? AppColors.primaryAction
                                : AppColors.textPrimary,
                            fontWeight: selected ? FontWeight.w600 : null)),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}

/// A card over the map for one thing (a place, a pin, a shared post): an
/// icon in a Primary Light circle, its title and details, and a close button.
class MapInfoCard extends StatelessWidget {
  const MapInfoCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.closeTooltip,
    required this.onClose,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String closeTooltip;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => MapFloatingSurface(
        radius: 24,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.md, AppSpacing.md, AppSpacing.xs, AppSpacing.md),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                  color: AppColors.primaryLight, shape: BoxShape.circle),
              child: Icon(icon, color: AppColors.primaryAction),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.label),
                  const SizedBox(height: 2),
                  Text(subtitle, style: AppText.meta),
                ],
              ),
            ),
            IconButton(
              tooltip: closeTooltip,
              onPressed: onClose,
              icon: const Icon(Icons.close_rounded,
                  color: AppColors.textSecondary),
            ),
          ]),
        ),
      );
}
