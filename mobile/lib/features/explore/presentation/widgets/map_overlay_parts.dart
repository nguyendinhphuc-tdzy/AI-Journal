import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text.dart';

/// The soft shadow under everything that floats over the map, so Surface
/// reads over it.
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

/// A filter over the map (what places are for, a mood), as Journal's chips:
/// Primary Light with an outline when chosen, Surface otherwise, 40 high.
/// [leading] and [trailing] sit either side of the label.
class MapMoodChip extends StatelessWidget {
  const MapMoodChip(
      {super.key,
      required this.label,
      required this.selected,
      required this.onTap,
      this.leading,
      this.trailing});

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget? leading;
  final Widget? trailing;

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
                  padding: EdgeInsets.only(
                      left: leading != null ? 8 : 14,
                      right: trailing != null ? 8 : 14),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    if (leading case final leading?) ...[
                      leading,
                      const SizedBox(width: 6),
                    ],
                    Text(label,
                        style: AppText.meta.copyWith(
                            color: selected
                                ? AppColors.primaryAction
                                : AppColors.textPrimary,
                            fontWeight: selected ? FontWeight.w600 : null)),
                    if (trailing case final trailing?) ...[
                      const SizedBox(width: 2),
                      trailing,
                    ],
                  ]),
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
    this.action,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String closeTooltip;
  final VoidCallback onClose;

  /// What can be done with it, under the details (e.g. "Lưu nơi này").
  final Widget? action;

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
                  if (action case final action?) ...[
                    const SizedBox(height: AppSpacing.sm),
                    action,
                  ],
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

/// A round 52 button floating over the map (back, "Vị trí của tôi"); a
/// small spinner in its place while [busy].
class MapCircleButton extends StatelessWidget {
  const MapCircleButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.busy = false,
    this.color = AppColors.textPrimary,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool busy;
  final Color color;

  @override
  Widget build(BuildContext context) => MapFloatingSurface(
        radius: 26,
        child: SizedBox.square(
          dimension: 52,
          child: busy
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : IconButton(
                  tooltip: tooltip,
                  onPressed: onPressed,
                  icon: Icon(icon, color: color),
                ),
        ),
      );
}

/// "Phóng to" over "Thu nhỏ", one step a tap (pinching works too).
class MapZoomButtons extends StatelessWidget {
  const MapZoomButtons(
      {super.key, required this.onZoomIn, required this.onZoomOut});

  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;

  static const zoomInTooltip = 'Phóng to';
  static const zoomOutTooltip = 'Thu nhỏ';

  @override
  Widget build(BuildContext context) => MapFloatingSurface(
        radius: 26,
        child: SizedBox(
          width: 52,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            IconButton(
              tooltip: zoomInTooltip,
              onPressed: onZoomIn,
              icon: const Icon(Icons.add_rounded, color: AppColors.textPrimary),
            ),
            Container(width: 28, height: 1, color: AppColors.border),
            IconButton(
              tooltip: zoomOutTooltip,
              onPressed: onZoomOut,
              icon: const Icon(Icons.remove_rounded,
                  color: AppColors.textPrimary),
            ),
          ]),
        ),
      );
}

/// The pin fixed at the middle of a map, its tip exactly on the centre: a
/// teal drop with a white dot and its shadow. It lifts while the map
/// [moving] and sets down when it stops; [faded] until a place is chosen.
/// It never takes a touch.
class MapCenterPin extends StatelessWidget {
  const MapCenterPin({super.key, this.moving = false, this.faded = false});

  final bool moving;
  final bool faded;

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    final lift = moving && !reduced ? 10.0 : 0.0;
    const duration = Duration(milliseconds: 160);
    return IgnorePointer(
      child: Center(
        child: SizedBox(
          width: 0,
          height: 0,
          child: OverflowBox(
            maxWidth: 80,
            maxHeight: 120,
            child: AnimatedOpacity(
              opacity: faded ? .55 : 1,
              duration: reduced ? Duration.zero : duration,
              child: SizedBox(
                width: 80,
                height: 120,
                child: Stack(clipBehavior: Clip.none, children: [
                  // Its shadow on the map, smaller while lifted.
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 56,
                    child: Center(
                      child: AnimatedContainer(
                        duration: duration,
                        width: lift > 0 ? 10 : 16,
                        height: 5,
                        decoration: BoxDecoration(
                          color: AppColors.textPrimary.withValues(alpha: .25),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  AnimatedPositioned(
                    duration: duration,
                    curve: Curves.easeOut,
                    left: 18,
                    // The tip is at the box's middle (60) when set down.
                    top: 60 - 52 - lift,
                    child: const CustomPaint(
                        size: Size(44, 52), painter: _PinPainter()),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A teal drop with a white dot; its tip at the bottom centre.
class _PinPainter extends CustomPainter {
  const _PinPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final r = w / 2;
    final drop = Path()
      ..moveTo(w / 2, h)
      ..cubicTo(w * .28, h * .74, 0, h * .6, 0, r)
      ..arcToPoint(Offset(w, r), radius: Radius.circular(r))
      ..cubicTo(w, h * .6, w * .72, h * .74, w / 2, h)
      ..close();
    canvas.drawShadow(drop, AppColors.textPrimary, 3, false);
    canvas.drawPath(drop, Paint()..color = AppColors.primaryAction);
    canvas.drawCircle(Offset(w / 2, r), r * .38, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_PinPainter old) => false;
}
