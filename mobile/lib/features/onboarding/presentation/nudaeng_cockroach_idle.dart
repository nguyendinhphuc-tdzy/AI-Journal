import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// OB02 rest between cockroach runs. It starts from exactly the run's last
/// frame (Nudaeng and the cockroach split from it, motion marks removed), so
/// the switch from the run is invisible. Then:
/// - the twitching cockroach sprite fades in over the run's cockroach
///   (260 ms; the one below stays opaque, so nothing dims);
/// - after a breath of 1.2–2 s, its antennae twitch (left 200 ms → centre
///   120 ms → right 200 ms → centre), again every 2–4 s.
///
/// While not [active] it holds the start pose and runs no timers. Laid out
/// in the 306×319 space of the run frames. Reduced motion holds still.
class NudaengCockroachIdle extends StatefulWidget {
  const NudaengCockroachIdle({super.key, this.active = true, this.random});

  final bool active;

  /// Seeded in tests; random otherwise.
  final math.Random? random;

  /// Built by `tool/build_cockroach_frames.py` from the run's frame 12.
  static const dogFrame = 'assets/Deimage/nudaeng-cockroach-rest-dog.png';
  static const runCockroachFrame =
      'assets/Deimage/nudaeng-cockroach-rest-cockroach.png';

  static const cockroachFrames = [
    'assets/Deimage/ob02-cockroach-idle-01.png', // antennae centred
    'assets/Deimage/ob02-cockroach-idle-02.png', // bent left
    'assets/Deimage/ob02-cockroach-idle-03.png', // bent right
  ];

  /// Run-frame space; Nudaeng and the run's cockroach fill it.
  static const space = Size(306, 319);

  /// Idle sprites retain the run's full canvas and original cockroach pixels.
  /// Only the antenna tips change; no rescaling or repositioning at rest.
  static const cockroachRect = Rect.fromLTWH(0, 0, 306, 319);

  static const reveal = Duration(milliseconds: 260);

  /// Antenna frame and how long it holds; ends back on centre.
  static const twitch = [
    (1, Duration(milliseconds: 200)),
    (0, Duration(milliseconds: 120)),
    (2, Duration(milliseconds: 200)),
    (0, Duration.zero),
  ];

  @override
  State<NudaengCockroachIdle> createState() => _NudaengCockroachIdleState();
}

class _NudaengCockroachIdleState extends State<NudaengCockroachIdle>
    with SingleTickerProviderStateMixin {
  late final math.Random _random = widget.random ?? math.Random();
  late final AnimationController _reveal =
      AnimationController(vsync: this, duration: NudaengCockroachIdle.reveal);
  final _timers = <Timer>{};
  var _antennae = 0;

  bool get _still => MediaQuery.disableAnimationsOf(context);

  void _after(Duration delay, VoidCallback action) {
    late final Timer timer;
    timer = Timer(delay, () {
      _timers.remove(timer);
      if (mounted) action();
    });
    _timers.add(timer);
  }

  void _start() {
    if (_still) {
      _reveal.value = 1;
      return;
    }
    _reveal.forward(from: 0);
    _scheduleTwitch(1200, 2000);
  }

  /// Back to the run's last frame, ready for the next rest.
  void _stop() {
    for (final timer in _timers) {
      timer.cancel();
    }
    _timers.clear();
    _reveal.value = 0;
    _antennae = 0;
  }

  void _scheduleTwitch(int minMs, int maxMs) =>
      _after(Duration(milliseconds: minMs + _random.nextInt(maxMs - minMs + 1)),
          () {
        var at = Duration.zero;
        for (final (frame, hold) in NudaengCockroachIdle.twitch) {
          _after(at, () => setState(() => _antennae = frame));
          at += hold;
        }
        _after(at, () => _scheduleTwitch(2000, 4000));
      });

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.active && _reveal.isDismissed && _timers.isEmpty) _start();
  }

  @override
  void didUpdateWidget(NudaengCockroachIdle old) {
    super.didUpdateWidget(old);
    if (widget.active == old.active) return;
    widget.active ? _start() : _stop();
  }

  @override
  void dispose() {
    _stop();
    _reveal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final k = box.maxWidth / NudaengCockroachIdle.space.width;
        const rect = NudaengCockroachIdle.cockroachRect;
        final width = rect.width * k;
        // Decode at display size, capped at the source's native width.
        final decodeWidth = math.min(NudaengCockroachIdle.space.width.toInt(),
            (width * MediaQuery.devicePixelRatioOf(context) / 64).ceil() * 64);
        Widget runLayer(String asset) => Image.asset(
              asset,
              fit: BoxFit.fill,
              gaplessPlayback: true,
              excludeFromSemantics: true,
            );
        return Stack(
          clipBehavior: Clip.none,
          fit: StackFit.expand,
          children: [
            runLayer(NudaengCockroachIdle.dogFrame),
            // The run's cockroach stays under the sprite until it has fully
            // faded in, then hides so its outline never peeks out.
            AnimatedBuilder(
              animation: _reveal,
              builder: (context, child) =>
                  Opacity(opacity: _reveal.isCompleted ? 0 : 1, child: child),
              child: runLayer(NudaengCockroachIdle.runCockroachFrame),
            ),
            Positioned(
              left: rect.left * k,
              top: rect.top * k,
              width: width,
              height: rect.height * k,
              child: FadeTransition(
                opacity: _reveal,
                // Every antenna pose stays mounted; only the current paints.
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    for (var i = 0;
                        i < NudaengCockroachIdle.cockroachFrames.length;
                        i++)
                      Opacity(
                        opacity: i == _antennae ? 1 : 0,
                        child: Image.asset(
                          NudaengCockroachIdle.cockroachFrames[i],
                          cacheWidth: decodeWidth,
                          fit: BoxFit.fill,
                          gaplessPlayback: true,
                          excludeFromSemantics: true,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      });
}
