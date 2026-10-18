import 'package:flutter/material.dart';

import 'frame_sequence.dart';
import 'nudaeng_cockroach_idle.dart';

/// OB02: Nudaeng watches a cockroach run a circle around it (12 frames,
/// about 2.3 s). The last frames slow down so the run settles instead of
/// stopping dead, then [NudaengCockroachIdle] takes over from exactly the
/// last frame (the cockroach settles, then twitches its antennae) until the
/// next run after a random pause. Reduced motion shows the idle pose, still.
///
/// Frames are cut from `NudaenggifDe/Chú chó đuổi bắt gián hoạt hình.gif`
/// by `tool/build_cockroach_frames.py`. Give it a 306:319 box.
class NudaengChasingCockroach extends StatelessWidget {
  const NudaengChasingCockroach({super.key, this.semanticLabel});

  final String? semanticLabel;

  static const aspectRatio = 306 / 319;

  static final frames = [
    for (var i = 1; i <= 12; i++)
      'assets/Deimage/nudaeng-cockroach-frame-${i.toString().padLeft(2, '0')}.png',
  ];

  /// Source pace (170 ms), easing out over the last three frames.
  static final frameDurations = [
    for (var i = 0; i < 9; i++) const Duration(milliseconds: 170),
    const Duration(milliseconds: 200),
    const Duration(milliseconds: 240),
    const Duration(milliseconds: 300),
  ];

  /// Long enough for the idle to show a twitch or two between runs.
  static const minPause = Duration(seconds: 6);
  static const maxPause = Duration(seconds: 10);

  @override
  Widget build(BuildContext context) => FrameSequence(
        frames: frames,
        durations: frameDurations,
        pause: (minPause, maxPause),
        rest: (context, resting) => NudaengCockroachIdle(active: resting),
        semanticLabel: semanticLabel,
      );
}
