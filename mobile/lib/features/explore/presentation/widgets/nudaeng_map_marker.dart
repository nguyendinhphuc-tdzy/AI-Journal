import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A single static GIF frame above a pink heart pin. Native markers are bitmaps.
Future<Uint8List> createNudaengMarker() async {
  final data = await rootBundle.load('assets/images/docsach.gif');
  final codec = await ui.instantiateImageCodec(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      targetWidth: 144);
  try {
    final frame = await codec.getNextFrame();
    try {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder)..scale(2);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(2, 2, 80, 70), const Radius.circular(12)),
        Paint()..color = Colors.white,
      );
      final fitted = applyBoxFit(
          BoxFit.contain,
          Size(frame.image.width.toDouble(), frame.image.height.toDouble()),
          const Size(68, 58));
      final destination = Alignment.center
          .inscribe(fitted.destination, const Rect.fromLTWH(8, 8, 68, 58));
      canvas.drawImageRect(
          frame.image,
          Rect.fromLTWH(0, 0, frame.image.width.toDouble(),
              frame.image.height.toDouble()),
          destination,
          Paint()
            ..colorFilter = const ColorFilter.matrix([
              1,
              0,
              0,
              0,
              0,
              0,
              1,
              0,
              0,
              0,
              0,
              0,
              1,
              0,
              0,
              -4.252,
              -14.304,
              -1.444,
              20,
              0,
            ]));
      final drop = Path()
        ..moveTo(42, 116)
        ..cubicTo(34, 105, 23, 94, 23, 85)
        ..cubicTo(23, 61, 61, 61, 61, 85)
        ..cubicTo(61, 94, 50, 105, 42, 116)
        ..close();
      canvas.drawPath(drop, Paint()..color = const Color(0xFFE994AC));
      final heart = Path()
        ..moveTo(42, 94)
        ..cubicTo(17, 77, 39, 72, 42, 81)
        ..cubicTo(45, 72, 67, 77, 42, 94)
        ..close();
      canvas.drawPath(heart, Paint()..color = Colors.white);
      final picture = recorder.endRecording();
      try {
        final image = await picture.toImage(168, 236);
        try {
          final png = await image.toByteData(format: ui.ImageByteFormat.png);
          if (png == null) throw StateError('Cannot encode marker');
          return png.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes);
        } finally {
          image.dispose();
        }
      } finally {
        picture.dispose();
      }
    } finally {
      frame.image.dispose();
    }
  } finally {
    codec.dispose();
  }
}
