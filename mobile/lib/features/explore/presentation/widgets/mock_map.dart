import 'package:flutter/material.dart';

/// Offline map illustration with normalized mock coordinates, not geographic data.
class MockMap extends StatelessWidget {
  const MockMap({super.key, this.child});
  final Widget? child;
  @override
  Widget build(BuildContext context) => CustomPaint(
      painter: const _MapPainter(), child: child ?? const SizedBox.expand());
}

class _MapPainter extends CustomPainter {
  const _MapPainter();
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
        Offset.zero & size, Paint()..color = const Color(0xFFF0EEE5));
    final park = Paint()..color = const Color(0xFFD5E6CF);
    for (final rect in [
      const Rect.fromLTWH(.06, .12, .26, .22),
      const Rect.fromLTWH(.60, .52, .32, .28)
    ]) {
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(rect.left * size.width, rect.top * size.height,
                  rect.width * size.width, rect.height * size.height),
              const Radius.circular(24)),
          park);
    }
    final river = Path()
      ..moveTo(size.width * .85, -20)
      ..cubicTo(size.width * .1, size.height * .3, size.width * 1.2,
          size.height * .55, size.width * .42, size.height + 20);
    canvas.drawPath(
        river,
        Paint()
          ..color = const Color(0xFFB8DDE2)
          ..style = PaintingStyle.stroke
          ..strokeWidth = size.width * .13);
    final road = Paint()
      ..color = Colors.white
      ..strokeWidth = 11;
    for (var i = 1; i < 6; i++) {
      canvas.drawLine(Offset(0, size.height * i / 6),
          Offset(size.width, size.height * i / 6 - 35), road);
    }
    for (var i = 1; i < 4; i++) {
      canvas.drawLine(Offset(size.width * i / 4, 0),
          Offset(size.width * i / 4 - 45, size.height), road);
    }
  }

  @override
  bool shouldRepaint(covariant _MapPainter oldDelegate) => false;
}

class HeartMapPin extends StatelessWidget {
  const HeartMapPin({super.key});
  @override
  Widget build(BuildContext context) => const SizedBox(
      width: 46,
      height: 48,
      child: Stack(alignment: Alignment.topCenter, children: [
        Icon(Icons.location_on, size: 46, color: Color(0xFFE994AC)),
        Positioned(
            top: 10,
            child: Icon(Icons.favorite, size: 17, color: Colors.white)),
      ]));
}
