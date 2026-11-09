import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/home_scene_settings.dart';

/// The top of Home: a large Vietnamese street with Nudaeng riding through
/// it, and Home's [content] (greeting, prompt, actions) over the sky
/// (docs/design/nudaeng-street/DESIGN_V2.md).
///
/// - Street: the v2 panorama (breakfast stall → flowered house and kiosk →
///   corner shop), three screen widths wide, kept at its proportions and
///   set on the bottom of the hero; the sky colour fills above it. The
///   camera pans on without stopping, one hero width every [widthTime]:
///   each pass of the street is followed by the next, the end of one
///   blending into the start of the other over [seam] (both ends are walls
///   under greenery), so there is no cut, flash or pause.
/// - Plain: sky and a road band only.
/// - Nudaeng faces right, riding left to right: the 12 side poses loop
///   glide → foot down → push back → foot up → glide ([riderFrames], timed
///   by [riderDurations]). The frames were aligned on the wheels
///   (`tool/align_nudaeng_side_frames.py`), so the scooter and wheels stay
///   put while the legs move; the wheels sit on the road at 92 % of the
///   panorama, a small contact shadow under each. The scooter does not
///   bob. The poses are still drafts: the pushing foot does not reach the
///   road and the body size varies a little between frames.
/// - The hero is at least 1.6 × its width tall and grows when the content
///   needs more room (large text), so text never covers the shops.
/// - Effects fall over the whole scene, under the content, mostly over the
///   street: few and faint around the prompt. Each one also relights the
///   scenery ([grades]): rain cooler and greyer on a wet road, snow cold and
///   silvery, leaves warm and creamy. Text, buttons and the navigation bar
///   keep their colours.
/// - Reduced motion: no effect, the camera holds where it is (the light and
///   the raincoat stay). Off screen or in the background everything pauses
///   and later resumes from there.
class HomeSceneHero extends StatefulWidget {
  const HomeSceneHero({
    super.key,
    required this.content,
    this.scene = HomeScene.street,
    this.effect = SceneEffect.none,
  });

  final Widget content;
  final HomeScene scene;
  final SceneEffect effect;

  // Hand-drawn repaint of v2 (`tool/build_handdrawn_panorama.py`): same
  // layout, so the snow overlay and the loop seam still fit.
  static const panoramaAsset = 'assets/images/nudaeng-vietnam-panorama-v3.jpg';
  // Full 1881 × 836 transparent canvas, painted for this panorama's awnings.
  // Keep it inside the same camera transform; never crop its transparent sky.
  static const snowOverlayAsset =
      'assets/images/nudaeng-vietnam-snow-overlay.png';

  /// The kick cycle, frame 1 a glide (also the still pose).
  static final riderFrames = [
    for (var i = 1; i <= 12; i++)
      'assets/images/nudaeng-ride-${i.toString().padLeft(2, '0')}.png',
  ];

  /// Same kick timing and wheelbase; short raincoat, hood and visible legs.
  static final rainRiderFrames = [
    for (var i = 1; i <= 12; i++)
      'assets/images/nudaeng-rain-ride-${i.toString().padLeft(2, '0')}.png',
  ];

  /// Glides held, the kick quick: about 1.9 s a cycle.
  static const riderDurations = [
    Duration(milliseconds: 360), // glide
    Duration(milliseconds: 110), // foot lifts
    Duration(milliseconds: 110), // foot goes down
    Duration(milliseconds: 120), // foot at the road
    Duration(milliseconds: 110), // push back
    Duration(milliseconds: 140), // push, leg out
    Duration(milliseconds: 110), // foot comes back
    Duration(milliseconds: 110),
    Duration(milliseconds: 110), // foot up
    Duration(milliseconds: 220), // glide
    Duration(milliseconds: 140), // glide, blink
    Duration(milliseconds: 260), // glide
  ];

  /// The frames' shared canvas (px) and wheel anchors on it, as measured by
  /// `tool/export_nudaeng_ride_frames.py`. Every frame draws Nudaeng at one
  /// size on one scooter (`tool/normalize_nudaeng_ride_frames.py`).
  static const riderCanvas = Size(480, 534);
  static const rearHubX = 56.4;
  static const frontHubX = 422.1;
  static const riderRoadY = 516.0;

  /// Hub to road on the frames (px).
  static const wheelRadius = 37.0;
  // Extra transparent headroom for the hood, not a change to world scale.
  static const rainRiderCanvas = Size(480, 574);
  static const rainRiderRoadY = 556.0;

  /// The frame at [seconds] into the loop.
  static int riderFrameAt(double seconds) {
    final cycle =
        riderDurations.fold(0, (total, step) => total + step.inMicroseconds);
    var t = (seconds * Duration.microsecondsPerSecond).round() % cycle;
    for (var i = 0; i < riderDurations.length; i++) {
      t -= riderDurations[i].inMicroseconds;
      if (t < 0) return i;
    }
    return 0;
  }

  /// The panorama's own sky at its top edge, continued above it.
  static const sky = Color(0xFFAFDED8);

  /// The road for the plain scene, as on the panorama.
  static const road = Color(0xFFCBC5B9);

  /// How each effect lights the scenery (panorama, sky, plain road), never
  /// the UI: a colour matrix, rows R, G, B, A, offsets in 0–255.
  static const grades = <SceneEffect, List<double>>{
    // Cooler, greyer, a little less vivid.
    SceneEffect.rain: [
      .86, .07, .02, 0, 0, //
      .03, .88, .04, 0, 2,
      .03, .07, .88, 0, 5,
      0, 0, 0, 1, 0,
    ],
    // Cold and silvery: colours muted, the yellows down, a little lighter.
    SceneEffect.snow: [
      .6069, .3025, .0305, 0, 18, //
      .0918, .8370, .0312, 0, 18,
      .0938, .3154, .5708, 0, 22,
      0, 0, 0, 1, 0,
    ],
    // Warm late light: cream and soft yellow.
    SceneEffect.leaves: [
      .9839, .0601, .0061, 0, 20, //
      .0167, .9577, .0057, 0, 2,
      .0153, .0515, .8332, 0, 0,
      0, 0, 0, 1, 0,
    ],
  };

  /// [color] as [grades] shows it under [effect].
  static Color graded(Color color, SceneEffect effect) {
    final m = grades[effect];
    if (m == null) return color;
    double channel(int row) =>
        ((m[row] * color.r + m[row + 1] * color.g + m[row + 2] * color.b) *
                255 +
            m[row + 4]) /
        255;
    return Color.from(
        alpha: color.a,
        red: channel(0).clamp(0, 1),
        green: channel(5).clamp(0, 1),
        blue: channel(10).clamp(0, 1));
  }

  /// The sky above the panorama, matching its graded top edge.
  static Color skyFor(SceneEffect effect) => graded(sky, effect);
  static final rainSky = skyFor(SceneEffect.rain);

  /// The plain scene's road; under rain darker, as if wet.
  static Color roadFor(SceneEffect effect) =>
      effect == SceneEffect.rain ? rainRoad : graded(road, effect);
  static const rainRoad = Color(0xFFB3BEC0);

  /// How much an effect shows at [y], against the rooftops' line: none over
  /// the prompt (for the quiet two thirds of the particles, a faint few
  /// otherwise), fully from just above the roofs down.
  static double streetShare(double y, double rooftops) =>
      ((y - rooftops + 30) / 90).clamp(0.0, 1.0);

  static String semanticLabel(HomeScene scene) => switch (scene) {
        HomeScene.street => 'Nudaeng đang chạy xe qua phố',
        HomeScene.plain => 'Nudaeng đang chạy xe',
      };

  static const panoramaAspect = 1881 / 836;

  /// Panorama width, in hero widths: three street sections.
  static const panoramaWidths = 3.0;

  /// Least hero height, in hero widths.
  static const heightFactor = 1.6;

  /// Share of the panorama from the rooftops down: content stays above it.
  static const buildingsShare = .72;

  /// Share of the panorama below the road line the wheels are on.
  static const groundShare = .08;

  /// Distance between the wheels, in hero widths: sets Nudaeng's size
  /// against the street.
  static const wheelbaseFactor = .213;

  /// Where the middle between the wheels is, in hero widths.
  static const riderCentre = .48;

  /// Height of the content sheet's curved top drawn over the bottom: its
  /// middle rises this high, its sides a quarter of it.
  static const lip = 24.0;

  /// Time for the camera to pan one hero width.
  static const widthTime = Duration(seconds: 15);

  /// How much one pass of the street overlaps the next, in hero widths:
  /// the end fades into the start there.
  static const seam = .25;

  /// From one pass of the street to the next, in hero widths.
  static const lap = panoramaWidths - seam;

  /// From standing to full speed when the scene starts or resumes.
  static const rampUp = Duration(milliseconds: 800);

  static double panoramaHeight(double width) =>
      width * panoramaWidths / panoramaAspect;

  /// How far the camera has panned after [seconds] of travel, in hero
  /// widths; it never turns back.
  static double cameraAt(double seconds) =>
      seconds * Duration.microsecondsPerSecond / widthTime.inMicroseconds;

  /// Whether the scene moves by itself. On in the app; off under widget
  /// tests, where motion that never ends would keep `pumpAndSettle` from
  /// settling on every screen above Home. Tests of this widget turn it on.
  @visibleForTesting
  static bool autoplay = WidgetsBinding.instance is WidgetsFlutterBinding;

  @override
  State<HomeSceneHero> createState() => _HomeSceneHeroState();
}

class _HomeSceneHeroState extends State<HomeSceneHero>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final Ticker _ticker = createTicker(_tick);

  /// Seconds of travel (eased in after each start); kept while paused.
  final _travel = ValueNotifier(0.0);

  /// Seconds the effect has been falling; kept while paused.
  final _time = ValueNotifier(0.0);

  Duration _last = Duration.zero;

  /// 0 → 1 over [HomeSceneHero.rampUp] after each start.
  double _pace = 0;

  var _reduced = false;
  var _visible = true;
  var _foreground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final state = WidgetsBinding.instance.lifecycleState;
    _foreground = state == null || state == AppLifecycleState.resumed;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MediaQuery.disableAnimationsOf(context);
    // False on a hidden tab or under another screen.
    _visible = TickerMode.valuesOf(context).enabled;
    _sync();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _sync();
  }

  /// Moves only while it can be seen and motion is wanted; stopping keeps
  /// the position, so it resumes from there (easing in again).
  void _sync() {
    // Nudaeng rides in every scene, so the clock always runs when it can.
    final run = HomeSceneHero.autoplay && !_reduced && _visible && _foreground;
    if (run && !_ticker.isActive) {
      _last = Duration.zero;
      _pace = 0;
      _ticker.start();
    } else if (!run && _ticker.isActive) {
      _ticker.stop();
    }
  }

  void _tick(Duration elapsed) {
    final dt =
        (elapsed - _last).inMicroseconds / Duration.microsecondsPerSecond;
    _last = elapsed;
    final ramp =
        HomeSceneHero.rampUp.inMicroseconds / Duration.microsecondsPerSecond;
    // Average pace over this frame, so the travel is exact for any dt.
    final from = _pace;
    _pace = math.min(1, _pace + dt / ramp);
    final rampTime = from >= 1 ? 0.0 : math.min(dt, (1 - from) * ramp);
    _travel.value += rampTime * (from + _pace) / 2 + (dt - rampTime);
    _time.value += dt;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    _travel.dispose();
    _time.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final street = widget.scene == HomeScene.street;
    // Reduced motion removes falling particles, not the selected outfit/light.
    final weather = widget.effect;
    final raining = weather == SceneEffect.rain;
    final effect = _reduced ? SceneEffect.none : widget.effect;
    return LayoutBuilder(builder: (context, box) {
      final width = box.maxWidth;
      final panorama = HomeSceneHero.panoramaHeight(width);
      final ground = panorama * HomeSceneHero.groundShare;
      final canvas =
          raining ? HomeSceneHero.rainRiderCanvas : HomeSceneHero.riderCanvas;
      final roadY =
          raining ? HomeSceneHero.rainRiderRoadY : HomeSceneHero.riderRoadY;
      // Logical px per frame px.
      final unit = width *
          HomeSceneHero.wheelbaseFactor /
          (HomeSceneHero.frontHubX - HomeSceneHero.rearHubX);
      final riderLeft = width * HomeSceneHero.riderCentre -
          unit * (HomeSceneHero.rearHubX + HomeSceneHero.frontHubX) / 2;
      final shadow = (width: 34 * unit, height: 5 * unit);
      return ConstrainedBox(
        constraints:
            BoxConstraints(minHeight: width * HomeSceneHero.heightFactor),
        child: Stack(children: [
          Positioned.fill(
            child: ColoredBox(
              key: const ValueKey('home-scene-sky'),
              color: HomeSceneHero.skyFor(weather),
            ),
          ),
          // The scene: one label, decorative parts excluded.
          Positioned.fill(
            child: Semantics(
              label: HomeSceneHero.semanticLabel(widget.scene),
              image: true,
              excludeSemantics: true,
              child: ClipRect(
                child: Stack(children: [
                  if (street)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: panorama,
                      child: RepaintBoundary(
                        child: _Street(
                            travel: _travel,
                            width: width,
                            height: panorama,
                            weather: weather),
                      ),
                    )
                  else
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: ground * 2,
                      child: ColoredBox(
                        color: HomeSceneHero.roadFor(weather),
                        child: raining
                            ? const CustomPaint(
                                key: ValueKey('home-rain-wet-road'),
                                painter: _WetRoadPainter(),
                              )
                            : null,
                      ),
                    ),
                  for (final (index, hub) in const [
                    HomeSceneHero.rearHubX,
                    HomeSceneHero.frontHubX,
                  ].indexed)
                    Positioned(
                      left: riderLeft + hub * unit - shadow.width / 2,
                      bottom: ground - shadow.height / 2,
                      width: shadow.width,
                      height: shadow.height,
                      child: DecoratedBox(
                        key: ValueKey('home-scene-shadow-$index'),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: .15),
                          borderRadius: BorderRadius.all(Radius.elliptical(
                              shadow.width / 2, shadow.height / 2)),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withValues(alpha: .1),
                                blurRadius: 1),
                          ],
                        ),
                      ),
                    ),
                  // The frames' road line on the street's road line.
                  Positioned(
                    left: riderLeft,
                    bottom: ground - unit * (canvas.height - roadY),
                    width: unit * canvas.width,
                    height: unit * canvas.height,
                    child:
                        _Rider(time: _time, still: _reduced, raining: raining),
                  ),
                  if (effect != SceneEffect.none)
                    Positioned.fill(
                      child: _Effect(
                        key: ValueKey(effect),
                        effect: effect,
                        time: _time,
                        panoramaHeight: panorama,
                        // Where the tyres meet the road, for the rain's
                        // splashes: x across, and height above the bottom.
                        wheels: [
                          for (final hub in const [
                            HomeSceneHero.rearHubX,
                            HomeSceneHero.frontHubX,
                          ])
                            riderLeft + hub * unit,
                        ],
                        ground: ground,
                        wheelRadius: HomeSceneHero.wheelRadius * unit,
                      ),
                    ),
                ]),
              ),
            ),
          ),
          // The content sheet below begins here: a gentle rise across the
          // road below the wheels, outlined like Nudaeng.
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: HomeSceneHero.lip,
            child: CustomPaint(
              key: ValueKey('home-scene-horizon'),
              painter: _HorizonPainter(),
            ),
          ),
          // Content over the sky, the street's buildings kept clear below.
          Column(children: [
            widget.content,
            SizedBox(height: panorama * HomeSceneHero.buildingsShare),
          ]),
        ]),
      );
    });
  }
}

/// Nudaeng's kick cycle, on the scene's clock (so it pauses with it); the
/// first pose with reduced motion. Every frame is decoded up front, so the
/// loop never blinks while one loads.
class _Rider extends StatefulWidget {
  const _Rider(
      {required this.time, required this.still, required this.raining});

  final ValueListenable<double> time;
  final bool still;
  final bool raining;

  @override
  State<_Rider> createState() => _RiderState();
}

class _RiderState extends State<_Rider> {
  final _cachedOutfits = <bool>{};

  List<String> get _frames => widget.raining
      ? HomeSceneHero.rainRiderFrames
      : HomeSceneHero.riderFrames;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _cacheOutfit();
  }

  @override
  void didUpdateWidget(covariant _Rider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.raining != widget.raining) _cacheOutfit();
  }

  void _cacheOutfit() {
    if (!_cachedOutfits.add(widget.raining)) return;
    for (final frame in _frames) {
      precacheImage(AssetImage(frame), context, onError: (_, __) {});
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget frame(int index) => Image.asset(
          _frames[index],
          key: const ValueKey('home-scene-rider'),
          fit: BoxFit.fill,
          filterQuality: FilterQuality.medium,
          gaplessPlayback: true,
        );
    if (widget.still) return frame(0);
    return ValueListenableBuilder<double>(
      valueListenable: widget.time,
      builder: (context, seconds, _) =>
          frame(HomeSceneHero.riderFrameAt(seconds)),
    );
  }
}

/// The panorama, panned by the camera, one pass after another, each
/// fading into the next over [HomeSceneHero.seam]. Relit for the
/// [weather]; under rain, its road wet.
class _Street extends StatelessWidget {
  const _Street(
      {required this.travel,
      required this.width,
      required this.height,
      required this.weather});

  final ValueListenable<double> travel;
  final double width;
  final double height;
  final SceneEffect weather;

  /// One pass of the street, the panorama at its own proportions.
  Widget _pass(Key? key) {
    final image = Image.asset(
      HomeSceneHero.panoramaAsset,
      fit: BoxFit.fill,
      filterQuality: FilterQuality.medium,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
    );
    final grade = HomeSceneHero.grades[weather];
    return SizedBox(
      key: key,
      width: width * HomeSceneHero.panoramaWidths,
      height: height,
      // The box has the panorama's own proportions: nothing is stretched.
      child: Stack(fit: StackFit.expand, children: [
        if (grade != null)
          ColorFiltered(
            key: ValueKey('home-${weather.name}-colour-grade'),
            colorFilter: ColorFilter.matrix(grade),
            child: image,
          )
        else
          image,
        if (weather == SceneEffect.snow)
          Image.asset(
            HomeSceneHero.snowOverlayAsset,
            key: const ValueKey('home-snow-awning-overlay'),
            fit: BoxFit.fill,
            filterQuality: FilterQuality.medium,
            gaplessPlayback: true,
          ),
        if (weather == SceneEffect.rain)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: height * .18,
            child: const CustomPaint(
              key: ValueKey('home-rain-wet-road'),
              painter: _WetRoadPainter(),
            ),
          ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    const lap = HomeSceneHero.lap;
    const full = HomeSceneHero.panoramaWidths;
    return ValueListenableBuilder<double>(
      valueListenable: travel,
      builder: (context, seconds, _) {
        final camera = HomeSceneHero.cameraAt(seconds);
        // Each pass is drawn up to the next one, which starts after [lap];
        // its last [seam] is laid over the next one's start, fading out.
        final passes = [
          for (var i = math.max(0, ((camera - full) / lap).floor());
              i * lap < camera + 1;
              i++)
            if (i * lap + full > camera) i,
        ];
        return Stack(clipBehavior: Clip.none, children: [
          for (final i in passes)
            if (i * lap + lap > camera)
              Positioned(
                key: ValueKey('home-scene-pass-$i'),
                left: (i * lap - camera) * width,
                top: 0,
                child: ClipRect(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    widthFactor: lap / full,
                    child: _pass(ValueKey('home-scene-panorama-$i')),
                  ),
                ),
              ),
          for (final i in passes)
            if (i * lap + lap < camera + 1)
              Positioned(
                key: ValueKey('home-scene-seam-$i'),
                left: ((i + 1) * lap - camera) * width,
                top: 0,
                child: ShaderMask(
                  blendMode: BlendMode.dstIn,
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Color(0xFFFFFFFF), Color(0x00FFFFFF)],
                  ).createShader(bounds),
                  child: ClipRect(
                    child: Align(
                      alignment: Alignment.centerRight,
                      widthFactor: HomeSceneHero.seam / full,
                      child: _pass(null),
                    ),
                  ),
                ),
              ),
        ]);
      },
    );
  }
}

/// Where the scene meets Home's sheet: the sheet's colour under one soft
/// curve, highest in the middle, drawn with a thin dark line.
class _HorizonPainter extends CustomPainter {
  const _HorizonPainter();

  static const _line = 1.6;

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.height * .75;
    // A quadratic's middle is halfway between its ends and its control:
    // this puts the top of the curve half a line below the top edge.
    final control = _line - side;
    final curve = Path()
      ..moveTo(0, side)
      ..quadraticBezierTo(size.width / 2, control, size.width, side);
    canvas
      ..drawPath(
          Path.from(curve)
            ..lineTo(size.width, size.height)
            ..lineTo(0, size.height)
            ..close(),
          Paint()..color = AppColors.background)
      ..drawPath(
          curve,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = _line
            ..color = AppColors.textPrimary.withValues(alpha: .85));
  }

  @override
  bool shouldRepaint(_HorizonPainter oldDelegate) => false;
}

/// A quiet wet sheen, attached to the street so it pans/fades with it.
/// Soft broken highlights suggest damp asphalt rather than a mirror or flood.
class _WetRoadPainter extends CustomPainter {
  const _WetRoadPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    canvas.save();
    canvas.clipRect(bounds);
    canvas.drawRect(
        bounds,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x08506B79), Color(0x28506B79), Color(0x12506B79)],
          ).createShader(bounds));
    final sheen = Paint()
      ..color = const Color(0xFFD7E8E8).withValues(alpha: .16)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);
    for (final (x, y, length) in const [
      (.08, .25, .10),
      (.22, .62, .14),
      (.40, .32, .12),
      (.57, .73, .16),
      (.73, .44, .11),
      (.91, .21, .12),
    ]) {
      canvas.drawOval(
          Rect.fromCenter(
            center: Offset(size.width * x, size.height * y),
            width: size.width * length,
            height: math.max(1.2, size.height * .025),
          ),
          sheen);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_WetRoadPainter oldDelegate) => false;
}

/// Rain, snow or leaves over the scene. Decorative: no input, no semantics.
class _Effect extends StatefulWidget {
  const _Effect({
    super.key,
    required this.effect,
    required this.time,
    required this.panoramaHeight,
    required this.wheels,
    required this.ground,
    required this.wheelRadius,
  });

  final SceneEffect effect;
  final ValueListenable<double> time;
  final double panoramaHeight;

  /// The wheels' x, the road's height above the bottom and the tyres'
  /// radius: where the rain splashes up behind the wheels.
  final List<double> wheels;
  final double ground;
  final double wheelRadius;

  @override
  State<_Effect> createState() => _EffectState();
}

class _EffectState extends State<_Effect> {
  late final _particles = _Particle.generate(widget.effect);

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: ExcludeSemantics(
          child: RepaintBoundary(
            child: CustomPaint(
              key: const ValueKey('home-scene-effect'),
              size: Size.infinite,
              painter: _EffectPainter(
                effect: widget.effect,
                particles: _particles,
                time: widget.time,
                panoramaHeight: widget.panoramaHeight,
                wheels: widget.wheels,
                ground: widget.ground,
                wheelRadius: widget.wheelRadius,
              ),
            ),
          ),
        ),
      );
}

/// One raindrop, snowflake or leaf. Positions wrap, so the fall never ends.
class _Particle {
  const _Particle({
    required this.x,
    required this.y,
    required this.fall,
    required this.drift,
    required this.size,
    this.sway = 0,
    this.swayRate = 0,
    this.phase = 0,
    this.spin = 0,
    this.flipRate = 0,
    this.opacity = 1,
    this.soft = false,
    this.quiet = false,
    this.tint = 0,
  });

  /// Start, as shares of the area.
  final double x;
  final double y;

  /// Logical px per second, down and sideways (negative: left).
  final double fall;
  final double drift;

  /// Streak length, flake radius or leaf length.
  final double size;
  final double sway;
  final double swayRate;
  final double phase;

  /// Leaves: turns per second in the plane, and how often one shows its
  /// back as it tumbles.
  final double spin;
  final double flipRate;

  final double opacity;

  /// Near flakes, slightly out of focus.
  final bool soft;

  /// Gone over the prompt, rather than faint (see
  /// [HomeSceneHero.streetShare]).
  final bool quiet;

  /// Leaves: which colour.
  final int tint;

  /// Fixed seeds: the same scene on every launch and in tests.
  static List<_Particle> generate(SceneEffect effect) {
    final random = math.Random(switch (effect) {
      SceneEffect.leaves => 7,
      SceneEffect.rain => 13,
      SceneEffect.snow => 29,
      SceneEffect.none => 1,
    });
    double between(double min, double max) =>
        min + random.nextDouble() * (max - min);
    final count = switch (effect) {
      SceneEffect.leaves => 12,
      SceneEffect.rain => 42,
      SceneEffect.snow => 72,
      SceneEffect.none => 0,
    };
    return [
      for (var i = 0; i < count; i++)
        switch (effect) {
          // Slow, swaying, turning over; carried left by the ride.
          SceneEffect.leaves => _Particle(
              x: (i + between(.1, .9)) / count,
              y: between(0, 1),
              fall: between(18, 28),
              drift: -between(16, 26),
              size: between(17, 24),
              sway: between(6, 12),
              swayRate: between(.5, .9),
              phase: between(0, math.pi * 2),
              spin: between(-.45, .45),
              flipRate: between(.12, .28),
              quiet: i % 3 != 0,
              tint: random.nextInt(_EffectPainter.leafColours.length),
            ),
          // Fast streaks slanted by the ride.
          SceneEffect.rain => _Particle(
              x: between(0, 1),
              y: between(0, 1),
              fall: between(230, 300),
              drift: -between(55, 70),
              size: between(9, 15),
            ),
          // Three depths: far flakes small and slow, near ones large, fast
          // and soft.
          _ => switch (i % 3) {
              0 => _Particle(
                  x: between(0, 1),
                  y: between(0, 1),
                  fall: between(14, 22),
                  drift: -between(7, 11),
                  size: between(.9, 1.4),
                  sway: between(2, 4),
                  swayRate: between(.6, 1.2),
                  phase: between(0, math.pi * 2),
                  opacity: .6,
                  quiet: i ~/ 3 % 3 != 0,
                ),
              1 => _Particle(
                  x: between(0, 1),
                  y: between(0, 1),
                  fall: between(24, 34),
                  drift: -between(11, 17),
                  size: between(1.6, 2.5),
                  sway: between(3, 6),
                  swayRate: between(.5, 1),
                  phase: between(0, math.pi * 2),
                  opacity: .8,
                  quiet: i ~/ 3 % 3 != 0,
                ),
              _ => _Particle(
                  x: between(0, 1),
                  y: between(0, 1),
                  fall: between(40, 54),
                  drift: -between(18, 26),
                  size: between(2.8, 4.2),
                  sway: between(5, 9),
                  swayRate: between(.4, .8),
                  phase: between(0, math.pi * 2),
                  opacity: .92,
                  soft: true,
                  quiet: i ~/ 3 % 3 != 0,
                ),
            },
        },
    ];
  }
}

class _EffectPainter extends CustomPainter {
  _EffectPainter({
    required this.effect,
    required this.particles,
    required this.time,
    required this.panoramaHeight,
    required this.wheels,
    required this.ground,
    required this.wheelRadius,
  }) : super(repaint: time);

  final SceneEffect effect;
  final List<_Particle> particles;
  final ValueListenable<double> time;
  final double panoramaHeight;
  final List<double> wheels;
  final double ground;
  final double wheelRadius;

  /// Earthy yellow, light orange, ochre, rust.
  static const leafColours = [
    Color(0xFFC99A3B),
    Color(0xFFE39B57),
    Color(0xFFD4AE4F),
    Color(0xFFC77A3E),
  ];
  static const _leafVein = Color(0xFF7A5424);
  static const _leafBack = Color(0xFFF3E2B8);

  /// A leaf one unit long, base at the left, tip at the right.
  static final _leaf = Path()
    ..moveTo(-.5, 0)
    ..cubicTo(-.28, -.34, .22, -.3, .5, 0)
    ..cubicTo(.22, .3, -.28, .34, -.5, 0)
    ..close();

  /// Its stalk, midrib and three pairs of veins.
  static final _veins = Path()
    ..moveTo(-.64, .06)
    ..lineTo(-.5, 0)
    ..lineTo(.42, 0)
    ..moveTo(-.08, -.17)
    ..lineTo(-.24, 0)
    ..lineTo(-.08, .17)
    ..moveTo(.17, -.15)
    ..lineTo(.03, 0)
    ..lineTo(.17, .15)
    ..moveTo(.35, -.09)
    ..lineTo(.25, 0)
    ..lineTo(.35, .09);

  static const _soft = MaskFilter.blur(BlurStyle.normal, .8);
  static const _flakeRim = Color(0xFF5A7684);
  static const _drop = Color(0xFFF2F8F9);
  static const _dropRim = Color(0xFF4F6573);

  @override
  void paint(Canvas canvas, Size size) {
    final t = time.value;
    const margin = 24.0;
    final w = size.width + margin * 2;
    final h = size.height + margin * 2;
    final rooftops =
        size.height - panoramaHeight * HomeSceneHero.buildingsShare;
    final rain = Paint()
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    final flake = Paint();
    final rim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = .5;
    final leaf = Paint();
    final vein = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (final p in particles) {
      final wave = math.sin(p.phase + t * p.swayRate * math.pi * 2);
      final x = (p.x * w + p.drift * t + p.sway * wave) % w - margin;
      final y = (p.y * h + p.fall * t) % h - margin;
      final share = HomeSceneHero.streetShare(y, rooftops);
      switch (effect) {
        case SceneEffect.rain:
          // Quiet over the prompt; gradually clearer around the street.
          rain.color = Colors.white.withValues(alpha: .14 + .30 * share);
          // Along the direction of the fall.
          final length =
              p.size / math.sqrt(p.fall * p.fall + p.drift * p.drift);
          canvas.drawLine(Offset(x, y),
              Offset(x - p.drift * length, y - p.fall * length), rain);
        case SceneEffect.snow:
          final alpha = p.opacity * (p.quiet ? share : .35 + .65 * share);
          if (alpha <= 0) continue;
          flake
            ..color = Colors.white.withValues(alpha: alpha)
            ..maskFilter = p.soft ? _soft : null;
          canvas.drawCircle(Offset(x, y), p.size, flake);
          // A faint cool rim, so white flakes still read on the pale sky.
          if (!p.soft) {
            canvas.drawCircle(Offset(x, y), p.size,
                rim..color = _flakeRim.withValues(alpha: .3 * alpha));
          }
        case SceneEffect.leaves:
          final alpha = p.quiet ? share : .45 + .55 * share;
          if (alpha <= 0) continue;
          // Tumbling: narrow as it turns edge-on, paler when its back shows.
          final turn = math.cos(p.phase + t * p.flipRate * math.pi * 2);
          final face = turn >= 0 ? math.max(.3, turn) : math.min(-.3, turn);
          final colour = leafColours[p.tint];
          leaf.color = (face < 0 ? Color.lerp(colour, _leafBack, .3)! : colour)
              .withValues(alpha: alpha);
          vein
            ..color = _leafVein.withValues(alpha: .55 * alpha)
            ..strokeWidth = 1.1 / p.size;
          canvas
            ..save()
            ..translate(x, y)
            ..rotate(p.spin * t + .5 * wave)
            ..scale(p.size * face, p.size)
            ..drawPath(_leaf, leaf)
            ..drawPath(_veins, vein)
            ..restore();
        case SceneEffect.none:
          return;
      }
    }
    if (effect == SceneEffect.rain) {
      final roadTop = size.height - panoramaHeight * .15;
      final roadHeight = panoramaHeight * .10;
      final splash = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = .7;
      for (var i = 0; i < 7; i++) {
        final age = (t * .65 + i * .173) % 1;
        if (age > .65) continue;
        splash.color =
            const Color(0xFFE0ECEC).withValues(alpha: .22 * (1 - age / .65));
        canvas.drawOval(
            Rect.fromCenter(
              center: Offset(size.width * ((i * .137 + .09) % 1),
                  roadTop + roadHeight * ((i * .27 + .16) % 1)),
              width: 2 + age * 9,
              height: 1 + age * 2,
            ),
            splash);
      }
      // Small drops thrown up and back off each tyre, falling again.
      final road = size.height - ground;
      final drop = Paint();
      final rim = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = .5;
      for (final (index, wheel) in wheels.indexed) {
        for (var k = 0; k < 5; k++) {
          final life = ((t * 2.2 + k / 5 + index * .37) % 1) / .7;
          if (life > 1) continue;
          final s = life * .4; // seconds in the air
          final at = Offset(wheel - wheelRadius * .9 - (20 + 7 * k) * s,
              road - wheelRadius * .15 - (46 + 6 * (k % 2)) * s + 150 * s * s);
          final radius = 1 + .3 * (k % 3);
          final fade = 1 - life;
          canvas
            ..drawCircle(
                at, radius, drop..color = _drop.withValues(alpha: .8 * fade))
            ..drawCircle(at, radius,
                rim..color = _dropRim.withValues(alpha: .35 * fade));
        }
      }
    }
  }

  @override
  bool shouldRepaint(_EffectPainter old) =>
      old.effect != effect ||
      old.particles != particles ||
      old.time != time ||
      old.panoramaHeight != panoramaHeight ||
      !listEquals(old.wheels, wheels) ||
      old.ground != ground ||
      old.wheelRadius != wheelRadius;
}
