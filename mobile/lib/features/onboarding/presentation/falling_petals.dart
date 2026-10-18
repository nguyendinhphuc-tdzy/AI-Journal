import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

const _petalAsset = 'assets/Deimage/nudaeng-mint-petal.png';

// The source canvas is 1254 px for a ~20 px petal; decode it small.
const _petalImage = ResizeImage(AssetImage(_petalAsset), width: 160);

/// Petals for OB01, drawn from `nudaeng-mint-petal.png`: a handful enter at
/// staggered times, fall slowly and sway. Each takes 8–12 s to cross the
/// area, then loops. While [gust] runs (0 → 1) the wind carries them off to
/// the right and up. Purely decorative: ignores input and semantics.
///
/// Callers skip this widget entirely under reduced motion.
class FallingPetals extends StatefulWidget {
  const FallingPetals({super.key, this.count = 7, this.gust})
      : assert(count >= 6 && count <= 8);

  final int count;
  final Animation<double>? gust;

  static const asset = _petalAsset;

  @override
  State<FallingPetals> createState() => _FallingPetalsState();
}

class _FallingPetalsState extends State<FallingPetals>
    with SingleTickerProviderStateMixin, _PetalImageMixin {
  final _elapsed = ValueNotifier(Duration.zero);
  late final Ticker _ticker = createTicker((value) => _elapsed.value = value);
  late final List<_Petal> _petals = _Petal.generate(widget.count);

  @override
  void initState() {
    super.initState();
    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _elapsed.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _decorative(CustomPaint(
        size: Size.infinite,
        painter: _FallPainter(
            _petals, _elapsed, widget.gust ?? kAlwaysDismissedAnimation, image),
      ));
}

/// A gust of petals blowing across the whole screen from the left, used for
/// the OB01 → OB02 transition. Paints only while [gust] is between 0 and 1.
class PetalGust extends StatefulWidget {
  const PetalGust({super.key, required this.gust, this.count = 18});

  final Animation<double> gust;
  final int count;

  static const duration = Duration(milliseconds: 1600);

  /// Share of the gust by which the OB01 petals are mostly gone; the flow
  /// switches to OB02 just before it.
  static const sweep = .4;

  @override
  State<PetalGust> createState() => _PetalGustState();
}

class _PetalGustState extends State<PetalGust> with _PetalImageMixin {
  late final List<_GustPetal> _petals = _GustPetal.generate(widget.count);

  @override
  Widget build(BuildContext context) => _decorative(CustomPaint(
        size: Size.infinite,
        painter: _GustPainter(_petals, widget.gust, image),
      ));
}

Widget _decorative(Widget child) => IgnorePointer(
      child: ExcludeSemantics(child: RepaintBoundary(child: child)),
    );

/// Loads the petal sprite once per widget.
mixin _PetalImageMixin<T extends StatefulWidget> on State<T> {
  late final _listener = ImageStreamListener(_onImage);
  ImageStream? _stream;
  ImageInfo? _info;

  ui.Image? get image => _info?.image;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final stream = _petalImage.resolve(createLocalImageConfiguration(context));
    if (stream.key == _stream?.key) return;
    _stream?.removeListener(_listener);
    _stream = stream..addListener(_listener);
  }

  void _onImage(ImageInfo info, bool _) {
    _info?.dispose();
    setState(() => _info = info);
  }

  @override
  void dispose() {
    _stream?.removeListener(_listener);
    _info?.dispose();
    super.dispose();
  }
}

/// Share of the square source canvas taken by the petal itself.
const _petalShare = .375;

void _drawPetal(
  Canvas canvas,
  ui.Image image, {
  required Offset center,
  required double size,
  required double angle,
  required double opacity,
  required bool mirrored,
}) {
  if (opacity <= 0) return;
  final side = size / _petalShare;
  canvas
    ..save()
    ..translate(center.dx, center.dy)
    ..rotate(angle);
  if (mirrored) canvas.scale(-1, 1);
  canvas
    ..drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromCenter(center: Offset.zero, width: side, height: side),
      Paint()
        ..filterQuality = FilterQuality.medium
        ..color = Color.fromRGBO(0, 0, 0, opacity.clamp(0.0, 1.0)),
    )
    ..restore();
}

class _Petal {
  const _Petal({
    required this.x,
    required this.delay,
    required this.period,
    required this.size,
    required this.sway,
    required this.drift,
    required this.swayCycles,
    required this.phase,
    required this.tilt,
    required this.mirrored,
    required this.windSpeed,
    required this.windLift,
  });

  /// Horizontal start as a fraction of the area width.
  final double x;

  /// Seconds before the petal first appears, so they never arrive together.
  final double delay;

  /// Seconds to fall from the top edge to the bottom edge.
  final double period;

  /// Visible petal length in logical px.
  final double size;
  final double sway;
  final double drift;
  final double swayCycles;
  final double phase;
  final double tilt;
  final bool mirrored;

  /// How far (in area widths) and how high (in area heights) the gust
  /// carries this petal.
  final double windSpeed;
  final double windLift;

  /// Fixed seed: the scene looks the same on every launch and in tests.
  static List<_Petal> generate(int count) {
    final random = math.Random(11);
    double between(double min, double max) =>
        min + random.nextDouble() * (max - min);
    final slots = List.generate(count, (i) => i)..shuffle(random);
    return [
      for (var i = 0; i < count; i++)
        _Petal(
          x: (slots[i] + between(.2, .8)) / count,
          delay: i * 1.3 + between(0, .6),
          period: between(8, 12),
          size: between(14, 20),
          sway: between(8, 16),
          drift: between(-24, 12),
          swayCycles: between(1.5, 2.5),
          phase: between(0, math.pi * 2),
          tilt: between(-.6, .6),
          mirrored: random.nextBool(),
          windSpeed: between(1.2, 1.8),
          windLift: between(.15, .45),
        ),
    ];
  }
}

class _FallPainter extends CustomPainter {
  _FallPainter(this.petals, this.elapsed, this.gust, this.image)
      : super(repaint: Listenable.merge([elapsed, gust]));

  final List<_Petal> petals;
  final ValueListenable<Duration> elapsed;
  final Animation<double> gust;
  final ui.Image? image;

  @override
  void paint(Canvas canvas, Size size) {
    final image = this.image;
    if (image == null) return;
    final seconds =
        elapsed.value.inMicroseconds / Duration.microsecondsPerSecond;
    // The wind builds up fast, so petals lean, then race away before OB01
    // fades out.
    final wind = Curves.easeInQuad
        .transform((gust.value / PetalGust.sweep).clamp(0.0, 1.0));
    for (final petal in petals) {
      final local = seconds - petal.delay;
      if (local < 0) continue;
      final progress = (local % petal.period) / petal.period;
      final wave = math.pi * 2 * progress * petal.swayCycles + petal.phase;
      final x = petal.x * size.width +
          petal.drift * progress +
          petal.sway * math.sin(wave) +
          wind * petal.windSpeed * size.width;
      final y = -petal.size +
          (size.height + petal.size * 2) * progress -
          wind * petal.windLift * size.height;
      final fade = math.min(
        (progress / .12).clamp(0.0, 1.0),
        ((1 - progress) / .15).clamp(0.0, 1.0),
      );
      _drawPetal(
        canvas,
        image,
        center: Offset(x, y),
        size: petal.size,
        angle: petal.tilt + .45 * math.sin(wave + .6) + wind * math.pi * 4,
        opacity: fade,
        mirrored: petal.mirrored,
      );
    }
  }

  @override
  bool shouldRepaint(_FallPainter old) =>
      old.petals != petals ||
      old.elapsed != elapsed ||
      old.gust != gust ||
      old.image != image;
}

class _GustPetal {
  const _GustPetal({
    required this.start,
    required this.y,
    required this.lift,
    required this.loop,
    required this.size,
    required this.spin,
    required this.mirrored,
  });

  /// Share of the gust before this petal enters from the left edge.
  final double start;

  /// Entry height as a share of the screen height.
  final double y;

  /// How far the wind lifts it while crossing, in screen heights.
  final double lift;

  /// Amplitude of the curl along the path, in logical px.
  final double loop;
  final double size;

  /// Turns over the crossing; negative spins the other way.
  final double spin;
  final bool mirrored;

  /// Each petal takes this share of the gust (~800 ms) to cross the
  /// screen; entries spread over the rest, so petals keep crossing OB02.
  static const travel = .5;

  static List<_GustPetal> generate(int count) {
    final random = math.Random(23);
    double between(double min, double max) =>
        min + random.nextDouble() * (max - min);
    return [
      for (var i = 0; i < count; i++)
        _GustPetal(
          start: i / count * (1 - travel),
          y: between(.2, .95),
          lift: between(.08, .3),
          loop: between(10, 36),
          size: between(14, 22),
          spin: between(1, 2.5) * (random.nextBool() ? 1 : -1),
          mirrored: random.nextBool(),
        ),
    ];
  }
}

class _GustPainter extends CustomPainter {
  _GustPainter(this.petals, this.gust, this.image) : super(repaint: gust);

  final List<_GustPetal> petals;
  final Animation<double> gust;
  final ui.Image? image;

  @override
  void paint(Canvas canvas, Size size) {
    final image = this.image;
    final g = gust.value;
    if (image == null || g <= 0 || g >= 1) return;
    for (final petal in petals) {
      final local = (g - petal.start) / _GustPetal.travel;
      if (local <= 0 || local >= 1) continue;
      final t = Curves.easeInOutSine.transform(local);
      final x = -40 + (size.width + 80) * t;
      final y = petal.y * size.height -
          petal.lift * size.height * t +
          petal.loop * math.sin(t * math.pi * 3);
      final fade = math.min(local / .12, (1 - local) / .12);
      _drawPetal(
        canvas,
        image,
        center: Offset(x, y),
        size: petal.size,
        angle: petal.spin * math.pi * 2 * t,
        opacity: fade,
        mirrored: petal.mirrored,
      );
    }
  }

  @override
  bool shouldRepaint(_GustPainter old) =>
      old.petals != petals || old.gust != gust || old.image != image;
}
