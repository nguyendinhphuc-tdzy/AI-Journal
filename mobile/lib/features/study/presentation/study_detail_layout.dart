import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

/// Hand-drawn accents that echo Nudaeng's ink style. Feature-local so the
/// shared palette stays untouched.
const _doodleColors = [
  Color(0xFFE6C48E), // Nudaeng fur
  Color(0xFFA9C8BE), // soft accent
  Color(0xFFF2B5B0), // blush
];
const _ink = Color(0xFF1F201C);

/// Title card for course, framework and reading details: a dark slab with a
/// slightly wobbly, inked edge, the title and a few sparkles.
class StudyTitleCard extends StatelessWidget {
  const StudyTitleCard({super.key, required this.title, required this.color});

  final String title;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final seed = title.codeUnits.fold<int>(7, (a, b) => (a * 31 + b) & 0xFFFF);
    return CustomPaint(
      painter: _InkCardPainter(color: color, seed: seed),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 168),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 56, vertical: 40),
          child: Center(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: AppColors.surface,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InkCardPainter extends CustomPainter {
  _InkCardPainter({required this.color, required this.seed});

  final Color color;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(seed);
    final base = Path()
      ..addRRect(RRect.fromRectAndRadius(
          Offset.zero & size, const Radius.circular(18)));
    // Sample the outline and nudge each point along its normal, then join
    // the points with midpoint curves so the edge reads as one ink stroke.
    final points = <Offset>[];
    for (final metric in base.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 22) {
        final tangent = metric.getTangentForOffset(d)!;
        final normal = Offset(-tangent.vector.dy, tangent.vector.dx);
        points.add(tangent.position + normal * (random.nextDouble() * 3 - 1.5));
      }
    }
    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final current = points[i];
      final next = points[(i + 1) % points.length];
      final mid = Offset.lerp(current, next, .5)!;
      if (i == 0) {
        path.moveTo(mid.dx, mid.dy);
      } else {
        path.quadraticBezierTo(current.dx, current.dy, mid.dx, mid.dy);
      }
    }
    final first = points.first;
    final firstMid = Offset.lerp(first, points[1], .5)!;
    path
      ..quadraticBezierTo(first.dx, first.dy, firstMid.dx, firstMid.dy)
      ..close();
    canvas.drawPath(path, Paint()..color = color);

    // Four-point sparkles inside the 56 px side gutters, so even a title
    // that wraps to three lines never runs into them.
    final spots = [
      Offset(28, size.height * .58),
      Offset(40, size.height * .76),
      Offset(size.width - 32, size.height * .26),
      Offset(size.width - 26, size.height * .64),
      Offset(size.width - 42, size.height * .8),
    ];
    for (var i = 0; i < spots.length; i++) {
      _sparkle(canvas, spots[i], 6 + random.nextDouble() * 3,
          _doodleColors[(i + seed) % _doodleColors.length]);
    }
  }

  void _sparkle(Canvas canvas, Offset c, double r, Color color) {
    final path = Path()
      ..moveTo(c.dx, c.dy - r)
      ..quadraticBezierTo(c.dx, c.dy, c.dx + r, c.dy)
      ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy + r)
      ..quadraticBezierTo(c.dx, c.dy, c.dx - r, c.dy)
      ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy - r)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_InkCardPainter old) =>
      old.color != color || old.seed != seed;
}

/// Full-bleed scene under the title card: an inked ground line with Nudaeng
/// standing on it and a soft shadow trailing to the right.
class StudyGroundScene extends StatelessWidget {
  const StudyGroundScene({
    super.key,
    required this.mascot,
    required this.mascotWidth,
    required this.mascotHeight,
  });

  final Widget mascot;
  final double mascotWidth;
  final double mascotHeight;

  static const _lineFromBottom = 22.0;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: mascotHeight + _lineFromBottom + 12,
        child: LayoutBuilder(builder: (context, constraints) {
          final left = constraints.maxWidth * .62 - mascotWidth / 2;
          return Stack(clipBehavior: Clip.none, children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _GroundPainter(
                  lineFromBottom: _lineFromBottom,
                  shadowLeft: left + mascotWidth * .45,
                  shadowWidth: mascotWidth * .95,
                ),
              ),
            ),
            Positioned(
              left: left,
              // Feet sit a hair below the line so the figure reads as standing.
              bottom: _lineFromBottom - 3,
              width: mascotWidth,
              height: mascotHeight,
              child: mascot,
            ),
          ]);
        }),
      );
}

class _GroundPainter extends CustomPainter {
  _GroundPainter({
    required this.lineFromBottom,
    required this.shadowLeft,
    required this.shadowWidth,
  });

  final double lineFromBottom;
  final double shadowLeft;
  final double shadowWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height - lineFromBottom;
    final shadow = Path()
      ..addOval(Rect.fromLTWH(shadowLeft, y - 4, shadowWidth, 16));
    canvas.drawPath(shadow, Paint()..color = _ink.withValues(alpha: .1));

    final line = Path()..moveTo(0, y + 1);
    line
      ..quadraticBezierTo(size.width * .18, y + 3, size.width * .34, y)
      ..quadraticBezierTo(size.width * .52, y - 2, size.width * .7, y + 2)
      ..quadraticBezierTo(size.width * .86, y + 4, size.width, y);
    canvas.drawPath(
      line,
      Paint()
        ..color = _ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_GroundPainter old) =>
      old.shadowLeft != shadowLeft || old.shadowWidth != shadowWidth;
}

/// Uppercase eyebrow such as "SKILLS · KHÓA HỌC".
class StudyEyebrow extends StatelessWidget {
  const StudyEyebrow(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppColors.textSecondary,
              letterSpacing: 1.2,
            ),
      );
}

/// Section with an uppercase heading, e.g. "BẠN SẼ THỬ ĐIỀU GÌ".
class StudySection extends StatelessWidget {
  const StudySection({super.key, required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title.toUpperCase(),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
          ),
          const SizedBox(height: AppSpacing.md),
          ...children,
        ],
      );
}

/// A checked line for "what you will try" style lists.
class StudyCheckLine extends StatelessWidget {
  const StudyCheckLine(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.check_rounded,
                size: 20, color: AppColors.primaryDark),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text,
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge
                    ?.copyWith(color: AppColors.textSecondary)),
          ),
        ]),
      );
}

/// A numbered step for framework templates.
class StudyStepLine extends StatelessWidget {
  const StudyStepLine({super.key, required this.number, required this.text});
  final int number;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primaryDark, width: 1.5),
            ),
            child: Text('$number',
                style: Theme.of(context)
                    .textTheme
                    .labelMedium
                    ?.copyWith(color: AppColors.primaryDark)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(text,
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.copyWith(color: AppColors.textSecondary)),
            ),
          ),
        ]),
      );
}
