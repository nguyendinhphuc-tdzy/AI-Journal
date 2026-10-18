import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Builds the pose shown between runs; [resting] is true while it shows.
typedef RestBuilder = Widget Function(BuildContext context, bool resting);

/// Plays PNG frames with per-frame durations: once on entry, then again
/// after a random [pause] when one is given. Between runs it holds the last
/// frame, or switches to [rest] when given. Reduced motion shows [rest]
/// (or the first frame) and never plays. Pauses while tickers are muted.
///
/// Fills its parent; frames are stretched to the same box so one-pixel
/// export differences never shift the layout.
class FrameSequence extends StatefulWidget {
  const FrameSequence({
    super.key,
    required this.frames,
    required this.durations,
    this.pause,
    this.rest,
    this.semanticLabel,
  }) : assert(frames.length == durations.length);

  final List<String> frames;
  final List<Duration> durations;

  /// Random wait between the end of one run and the next; null plays once.
  final (Duration, Duration)? pause;

  /// Pose between runs. It stays mounted (so it is decoded before it is
  /// needed) and swaps in at once, without a crossfade: it should start from
  /// exactly the last frame, then animate on its own while [resting].
  final RestBuilder? rest;
  final String? semanticLabel;

  /// Frame shown [elapsed] into a run; the last frame holds afterwards.
  static int frameAt(List<Duration> durations, Duration elapsed) {
    var end = Duration.zero;
    for (var i = 0; i < durations.length; i++) {
      end += durations[i];
      if (elapsed < end) return i;
    }
    return durations.length - 1;
  }

  @override
  State<FrameSequence> createState() => _FrameSequenceState();
}

class _FrameSequenceState extends State<FrameSequence>
    with SingleTickerProviderStateMixin {
  late final Duration _total = widget.durations.reduce((a, b) => a + b);
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: _total)
        ..addStatusListener(_onStatus);
  final _random = math.Random();
  Timer? _next;

  void _onStatus(AnimationStatus status) {
    final pause = widget.pause;
    if (status != AnimationStatus.completed || pause == null) return;
    final (min, max) = pause;
    _next = Timer(min + (max - min) * _random.nextDouble(), () {
      if (mounted) _controller.forward(from: 0);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Starts once per visit; replays are scheduled by _onStatus.
    if (_controller.status != AnimationStatus.dismissed) return;
    if (!MediaQuery.disableAnimationsOf(context) &&
        TickerMode.valuesOf(context).enabled) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _next?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.semanticLabel;
    final rest = widget.rest;
    if (MediaQuery.disableAnimationsOf(context)) {
      if (rest == null) return _frame(widget.frames.first, label);
      return Semantics(
        label: label,
        image: label != null,
        child: ExcludeSemantics(child: rest(context, true)),
      );
    }
    // All frames stay mounted so each is decoded before its turn; only the
    // current one paints.
    return Semantics(
      label: label,
      image: label != null,
      child: ExcludeSemantics(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final resting =
                rest != null && _controller.status == AnimationStatus.completed;
            final current = FrameSequence.frameAt(
                widget.durations, _total * _controller.value);
            return Stack(
              fit: StackFit.expand,
              children: [
                Opacity(
                  opacity: resting ? 0 : 1,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      for (var i = 0; i < widget.frames.length; i++)
                        Opacity(
                          opacity: i == current ? 1 : 0,
                          child: _frame(widget.frames[i], null),
                        ),
                    ],
                  ),
                ),
                if (rest != null)
                  Opacity(
                      opacity: resting ? 1 : 0, child: rest(context, resting)),
              ],
            );
          },
        ),
      ),
    );
  }

  static Widget _frame(String asset, String? label) => Image.asset(
        asset,
        fit: BoxFit.fill,
        gaplessPlayback: true,
        semanticLabel: label,
        excludeFromSemantics: label == null,
      );
}
