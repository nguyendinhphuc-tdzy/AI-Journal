import 'package:flutter/material.dart';

import 'frame_sequence.dart';

/// OB01: Nudaeng holding the umbrella, blinking now and then: open → half →
/// closed → open on entry, then again after a random pause, so blinks land
/// roughly 3–6 s apart. Reduced motion shows frame 01 and never blinks.
///
/// Give it a 1083:1453 box.
class NudaengUmbrellaBlink extends StatelessWidget {
  const NudaengUmbrellaBlink({super.key, this.semanticLabel});

  final String? semanticLabel;

  static const aspectRatio = 1083 / 1453;

  static const frames = [
    'assets/Deimage/nudaeng-umbrella-frame-01.png',
    'assets/Deimage/nudaeng-umbrella-frame-02.png',
    'assets/Deimage/nudaeng-umbrella-frame-03.png',
    'assets/Deimage/nudaeng-umbrella-frame-04.png',
  ];

  /// How long each frame shows, from the asset delivery notes.
  static const frameDurations = [
    Duration(milliseconds: 800),
    Duration(milliseconds: 100),
    Duration(milliseconds: 120),
    Duration(milliseconds: 780),
  ];

  static final total = frameDurations.reduce((a, b) => a + b);

  /// Wait after one blink sequence before the next. Each sequence already
  /// holds the eyes open for 780 + 800 ms around the blink.
  static const minPause = Duration(milliseconds: 1500);
  static const maxPause = Duration(milliseconds: 4500);

  /// Frame shown [elapsed] after a blink sequence starts.
  static int frameAt(Duration elapsed) =>
      FrameSequence.frameAt(frameDurations, elapsed);

  @override
  Widget build(BuildContext context) => FrameSequence(
        frames: frames,
        durations: frameDurations,
        pause: (minPause, maxPause),
        semanticLabel: semanticLabel,
      );
}
