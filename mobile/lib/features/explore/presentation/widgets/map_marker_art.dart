import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/saved_places.dart';

/// Saved places close together on screen, drawn as one pin with their
/// number until the map is zoomed in far enough to tell them apart.
class PlaceCluster {
  PlaceCluster(SavedPlace first) : places = [first];

  final List<SavedPlace> places;

  LatLng get centre => LatLng(
        places.map((p) => p.latitude).reduce((a, b) => a + b) / places.length,
        places.map((p) => p.longitude).reduce((a, b) => a + b) / places.length,
      );
}

/// Groups [places] that would be within [radius] logical pixels of each
/// other at [zoom]; [keep] (the chosen place) is never grouped.
List<PlaceCluster> clusterPlaces(List<SavedPlace> places, double zoom,
    {double radius = 56, String? keep}) {
  // Web Mercator, in logical pixels at this zoom (256 per tile).
  final scale = 256 * math.pow(2, zoom) / (2 * math.pi);
  math.Point<double> at(SavedPlace p) {
    final lat = p.latitude * math.pi / 180;
    return math.Point(
      scale * (p.longitude * math.pi / 180),
      scale * math.log(math.tan(math.pi / 4 + lat / 2)),
    );
  }

  final clusters = <PlaceCluster>[];
  final anchors = <math.Point<double>>[];
  for (final place in places) {
    final point = at(place);
    var joined = false;
    if (place.id != keep) {
      for (var i = 0; i < clusters.length; i++) {
        if (clusters[i].places.first.id == keep) continue;
        if (anchors[i].distanceTo(point) <= radius) {
          clusters[i].places.add(place);
          joined = true;
          break;
        }
      }
    }
    if (!joined) {
      clusters.add(PlaceCluster(place));
      anchors.add(point);
    }
  }
  return clusters;
}

Future<Uint8List> _draw(Size size, void Function(Canvas canvas) paint) async {
  final recorder = ui.PictureRecorder();
  paint(Canvas(recorder));
  final picture = recorder.endRecording();
  try {
    final image =
        await picture.toImage(size.width.toInt(), size.height.toInt());
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
}

/// A teal circle with the number of places in it (99+ above that).
Future<Uint8List> createClusterMarker(int count) =>
    _draw(const Size(160, 160), (canvas) {
      const centre = Offset(80, 80);
      canvas.drawCircle(
          centre.translate(0, 4), 64, Paint()..color = const Color(0x33201F1C));
      canvas.drawCircle(centre, 64, Paint()..color = Colors.white);
      canvas.drawCircle(centre, 54, Paint()..color = AppColors.primaryAction);
      final text = TextPainter(
        text: TextSpan(
          text: count > 99 ? '99+' : '$count',
          style: const TextStyle(
              color: Colors.white, fontSize: 52, fontWeight: FontWeight.w700),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(canvas, centre - Offset(text.width / 2, text.height / 2));
    });

/// A pin just dropped (not saved): a teal drop with a white dot, its tip at
/// the bottom centre.
Future<Uint8List> createDropMarker() => _draw(const Size(120, 160), (canvas) {
      const w = 120.0, h = 156.0, r = w / 2;
      final drop = Path()
        ..moveTo(w / 2, h)
        ..cubicTo(w * .28, h * .74, 0, h * .6, 0, r)
        ..arcToPoint(const Offset(w, r), radius: const Radius.circular(r))
        ..cubicTo(w, h * .6, w * .72, h * .74, w / 2, h)
        ..close();
      canvas.drawPath(drop, Paint()..color = AppColors.primaryAction);
      canvas.drawCircle(
          const Offset(w / 2, r), r * .38, Paint()..color = Colors.white);
    });

/// A soft teal ring that spreads once around a new pin.
Future<Uint8List> createRingMarker() => _draw(const Size(200, 200), (canvas) {
      const centre = Offset(100, 100);
      canvas.drawCircle(centre, 90,
          Paint()..color = AppColors.primaryAction.withValues(alpha: .18));
      canvas.drawCircle(
          centre,
          90,
          Paint()
            ..color = AppColors.primaryAction
            ..style = PaintingStyle.stroke
            ..strokeWidth = 8);
    });

/// The pin frame and Nudaeng's art for map markers.
abstract final class PinArt {
  static const frame = 'assets/images/map-markers/pin-frame.png';

  /// Drawn this wide (px), so the chosen pin stays sharp when enlarged.
  static const width = 240.0;

  /// How big pins show: a place among others, and the chosen one (large
  /// enough to see Nudaeng blink and wave).
  static const size = .5;
  static const chosenSize = .85;

  /// Neutral Nudaeng, and the blink-and-wave frames (01 is the still one).
  static const neutral = 'assets/images/map-markers/nudaeng-frame-01.png';
  static List<String> get waveFrames => [
        for (var i = 1; i <= 6; i++)
          'assets/images/map-markers/nudaeng-frame-0$i.png',
      ];

  /// Blink, then wave: which frame (1-based) for how long, about 1.8 s.
  static const wave = [
    (1, 350),
    (2, 100),
    (1, 150),
    (3, 100),
    (4, 130),
    (5, 130),
    (4, 130),
    (5, 130),
    (3, 100),
    (6, 480),
  ];

  /// In the frame's square canvas: the window's centre and radius, and the
  /// pin's tip (the point on the coordinate).
  static const window = Offset(.4996, .4406);
  static const windowRadius = .2703;
  static const tip = .934;

  /// What part of an image goes in the window (fractions): the mood art's
  /// head and upper body; the wave frames' whole upper dog, raised paw too.
  static const moodCrop = Rect.fromLTWH(.19, .05, .62, .62);
  static const waveCrop = Rect.fromLTWH(.06, 0, .88, .88);
}

final _decoded = <String, Future<ui.Image>>{};

Future<ui.Image> _image(String asset, int width) =>
    _decoded.putIfAbsent('$asset@$width', () async {
      final data = await rootBundle.load(asset);
      final codec = await ui.instantiateImageCodec(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
          targetWidth: width);
      final frame = await codec.getNextFrame();
      codec.dispose();
      return frame.image;
    });

/// A pin: [art] (the [crop] of it) in the frame's round window on mint,
/// the frame over it. Cut at the tip, so anchoring the image at its bottom
/// puts the tip on the place.
Future<Uint8List> createPinMarker(String art,
    {Rect crop = PinArt.moodCrop, double width = PinArt.width}) async {
  final pixels = (width * 2).round();
  final frame = await _image(PinArt.frame, pixels);
  final picture = await _image(art, pixels);
  final height = (width * PinArt.tip).roundToDouble();
  return _draw(Size(width, height), (canvas) {
    final centre = Offset(PinArt.window.dx * width, PinArt.window.dy * width);
    // A little wider than the window, so nothing shows under the ring.
    final radius = PinArt.windowRadius * width * 1.04;
    final circle = Rect.fromCircle(center: centre, radius: radius);
    canvas.save();
    canvas.clipPath(Path()..addOval(circle));
    canvas.drawRect(circle, Paint()..color = AppColors.primaryLight);
    final w = picture.width.toDouble(), h = picture.height.toDouble();
    canvas.drawImageRect(
        picture,
        Rect.fromLTWH(
            crop.left * w, crop.top * h, crop.width * w, crop.height * h),
        circle,
        Paint()..filterQuality = FilterQuality.medium);
    canvas.restore();
    canvas.drawImageRect(
        frame,
        Rect.fromLTWH(0, 0, frame.width.toDouble(), frame.height.toDouble()),
        Rect.fromLTWH(0, 0, width, width),
        Paint()..filterQuality = FilterQuality.medium);
  });
}
