import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Decorative lake scene. Water and fish share one repaint-only clock.
class LoginFishingScene extends StatefulWidget {
  const LoginFishingScene({super.key});

  static const artwork = 'assets/images/nudaeng-login-fishing-transparent.png';

  @override
  State<LoginFishingScene> createState() => _LoginFishingSceneState();
}

class _LoginFishingSceneState extends State<LoginFishingScene>
    with SingleTickerProviderStateMixin {
  late final _clock =
      AnimationController(vsync: this, duration: const Duration(seconds: 8));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final pause = MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.viewInsetsOf(context).bottom > 0 ||
        !TickerMode.valuesOf(context).enabled;
    if (pause) {
      _clock.stop();
    } else {
      _clock.repeat();
    }
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: IgnorePointer(
          child: RepaintBoundary(
            child: SizedBox(
              height: 184,
              width: double.infinity,
              child: Stack(children: [
                Positioned.fill(
                    child: CustomPaint(painter: _LakePainter(_clock))),
                Positioned(
                  left: 30,
                  bottom: 10,
                  width: 192,
                  height: 168,
                  child: Image.asset(LoginFishingScene.artwork,
                      fit: BoxFit.contain, cacheWidth: 576),
                ),
              ]),
            ),
          ),
        ),
      );
}

class _LakePainter extends CustomPainter {
  _LakePainter(this.clock) : super(repaint: clock);
  final Animation<double> clock;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final t = clock.value;
    final water = Path()
      ..moveTo(0, h * .70)
      ..cubicTo(w * .35, h * .43, w * .55, h * .63, w, h * .36)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(water, Paint()..color = const Color(0xFFBFDCD9));
    canvas.save();
    canvas.clipPath(water);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFE8F4EE);
    for (var i = 0; i < 9; i++) {
      final x = w * (.16 + (i % 3) * .31) + math.sin(t * math.pi * 2 + i) * 5;
      final y = h * (.59 + (i ~/ 3) * .16);
      canvas.drawArc(
          Rect.fromCenter(center: Offset(x, y), width: 38, height: 6),
          0,
          math.pi,
          false,
          stroke);
    }
    canvas.restore();
    final bank = Path()
      ..moveTo(0, h * .54)
      ..quadraticBezierTo(w * .28, h * .49, w * .48, h * .77)
      ..quadraticBezierTo(w * .18, h * .86, 0, h * .91)
      ..close();
    canvas.drawPath(bank, Paint()..color = const Color(0xFFAAC8AD));
    for (var i = 0; i < 7; i++) {
      final x = 12.0 + i * 21;
      final y = h * .77 + math.sin(i.toDouble()) * 7;
      final grass = Path()
        ..moveTo(x - 3, y)
        ..lineTo(x - 6, y - 7)
        ..moveTo(x - 3, y)
        ..lineTo(x, y - 9);
      canvas.drawPath(
          grass,
          Paint()
            ..color = const Color(0xFF668F76)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5);
    }
    // One short jump, followed by a long quiet interval.
    final jump = (t - .48) / .18;
    if (jump >= 0 && jump <= 1) {
      final x = w * (.63 + .21 * jump);
      final surface = h * .65;
      final y = surface - math.sin(jump * math.pi) * 45;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate((jump - .5) * 1.3);
      final fish = Paint()..color = const Color(0xFFCF9B67);
      canvas.drawOval(const Rect.fromLTWH(-9, -5, 18, 10), fish);
      canvas.drawPath(
          Path()
            ..moveTo(-7, 0)
            ..lineTo(-15, -6)
            ..lineTo(-15, 6)
            ..close(),
          fish);
      canvas.drawCircle(
          const Offset(4, -1), 1.1, Paint()..color = const Color(0xFF354744));
      canvas.restore();
    }
    final ripple = (t - .66) / .16;
    if (ripple >= 0 && ripple <= 1) {
      canvas.drawOval(
          Rect.fromCenter(
              center: Offset(w * .84, h * .65),
              width: 12 + 36 * ripple,
              height: 3 + 8 * ripple),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = const Color(0xFFE8F4EE).withValues(alpha: 1 - ripple));
    }
  }

  @override
  bool shouldRepaint(_LakePainter oldDelegate) => oldDelegate.clock != clock;
}
