import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../data/album_theme.dart';

/// Folder-style cover from the wireframe: back panel with a tab, a sheet of
/// paper, the front panel, and the theme's Nudaeng pose on a taped photo
/// card. [locked] shows a generic cover with a lock, never the theme or
/// anything from the album.
class AlbumCover extends StatelessWidget {
  const AlbumCover({super.key, required this.themeId, required this.locked});

  final String themeId;
  final bool locked;

  /// Width : height of the cover art.
  static const aspectRatio = 1.28;

  @override
  Widget build(BuildContext context) =>
      _CoverArt(themeId: themeId, locked: locked);
}

/// The same cover, small, for the theme pickers (A02, A03). A type of its own
/// so a screen's one real cover stays easy to tell apart.
class AlbumCoverThumbnail extends StatelessWidget {
  const AlbumCoverThumbnail({super.key, required this.themeId});

  final String themeId;

  @override
  Widget build(BuildContext context) =>
      _CoverArt(themeId: themeId, locked: false);
}

class _CoverArt extends StatelessWidget {
  const _CoverArt({required this.themeId, required this.locked});

  final String themeId;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final theme = locked ? AlbumTheme.classic : AlbumTheme.of(themeId);
    final pose = theme.pose;
    return AspectRatio(
      aspectRatio: AlbumCover.aspectRatio,
      child: LayoutBuilder(builder: (context, box) {
        final w = box.maxWidth;
        final h = box.maxHeight;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _FolderPainter(tape: pose == null ? theme.tape : null),
              ),
            ),
            if (locked)
              const Align(
                alignment: Alignment(0, .45),
                child: Icon(Icons.lock_outline_rounded,
                    size: 28, color: AppColors.primaryAction),
              )
            else if (pose != null)
              Positioned(
                left: w * .27,
                top: h * .3,
                width: w * .46,
                height: h * .62,
                child: _PhotoCard(pose: pose, tape: theme.tape),
              ),
          ],
        );
      }),
    );
  }
}

/// The pose on a small sheet of photo paper, slightly turned, taped on.
class _PhotoCard extends StatelessWidget {
  const _PhotoCard({required this.pose, required this.tape});

  final String pose;
  final Color tape;

  @override
  Widget build(BuildContext context) => Transform.rotate(
        angle: -.05,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.textPrimary.withValues(alpha: .12),
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Image.asset(pose,
                      fit: BoxFit.contain,
                      excludeFromSemantics: true,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink()),
                ),
              ),
            ),
            Positioned(
              top: -4,
              left: 0,
              right: 0,
              child: Center(
                child: FractionallySizedBox(
                  widthFactor: .5,
                  child: Container(
                    height: 8,
                    color: tape.withValues(alpha: .45),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
}

class _FolderPainter extends CustomPainter {
  const _FolderPainter({this.tape});

  /// Washi tape on the front panel; none when a photo card carries it.
  final Color? tape;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final radius = Radius.circular(w * .07);

    // Back panel with its tab.
    final back = Path()
      ..addRRect(RRect.fromRectAndCorners(
        Rect.fromLTWH(0, h * .12, w, h * .88),
        topRight: radius,
        bottomLeft: radius,
        bottomRight: radius,
      ))
      ..addRRect(RRect.fromRectAndCorners(
        Rect.fromLTWH(0, 0, w * .42, h * .2),
        topLeft: radius,
        topRight: radius,
      ));
    canvas.drawPath(back, Paint()..color = AppColors.primary);

    // A sheet of paper tucked inside.
    final paper = RRect.fromRectAndRadius(
        Rect.fromLTWH(w * .08, h * .2, w * .84, h * .5),
        Radius.circular(w * .03));
    canvas.drawRRect(paper, Paint()..color = AppColors.surface);
    final ruled = Paint()
      ..color = AppColors.border
      ..strokeWidth = 1;
    for (var i = 1; i <= 2; i++) {
      final y = h * .2 + h * .12 * i;
      canvas.drawLine(Offset(w * .16, y), Offset(w * .84, y), ruled);
    }

    // Front panel, lighter.
    final front =
        RRect.fromRectAndRadius(Rect.fromLTWH(0, h * .36, w, h * .64), radius);
    canvas.drawRRect(front, Paint()..color = AppColors.softAccent);

    final tape = this.tape;
    if (tape == null) return;
    final strip = Rect.fromCenter(
        center: Offset(w * .74, h * .38), width: w * .26, height: h * .1);
    canvas.save();
    canvas.translate(strip.center.dx, strip.center.dy);
    canvas.rotate(-.12);
    canvas.translate(-strip.center.dx, -strip.center.dy);
    canvas.drawRect(strip, Paint()..color = tape.withValues(alpha: .28));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_FolderPainter oldDelegate) => oldDelegate.tape != tape;
}
