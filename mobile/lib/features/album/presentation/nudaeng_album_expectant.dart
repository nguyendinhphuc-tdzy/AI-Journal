import 'package:flutter/material.dart';

/// ND01: already seated, a small head tilt and eye glints, one blink,
/// a glance toward the CTA below, then a quiet resting pose. Never loops.
class NudaengAlbumExpectant extends StatefulWidget {
  const NudaengAlbumExpectant({super.key, this.animate = true});

  final bool animate;
  static const duration = Duration(milliseconds: 1800);
  static const frames = [
    'assets/Deimage/album-expectant-frame-01.png',
    'assets/Deimage/album-expectant-frame-02.png',
    'assets/Deimage/album-expectant-frame-03.png',
    'assets/Deimage/album-expectant-frame-04.png',
    'assets/Deimage/album-expectant-frame-05.png',
    'assets/Deimage/album-expectant-frame-06.png',
  ];

  @override
  State<NudaengAlbumExpectant> createState() => _NudaengAlbumExpectantState();
}

class _NudaengAlbumExpectantState extends State<NudaengAlbumExpectant>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
      vsync: this, duration: NudaengAlbumExpectant.duration);
  bool _started = false;

  void _sync() {
    if (!widget.animate || MediaQuery.disableAnimationsOf(context)) {
      _started = true;
      _controller.value = 1;
    } else if (!_started) {
      _started = true;
      _controller.forward();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(NudaengAlbumExpectant oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Dissolves between registered poses; never translates the seated body.
  (int, int, double) _pose(double ms) {
    if (ms < 250) return (0, 0, 0);
    if (ms < 450) return (0, 1, (ms - 250) / 200);
    if (ms < 700) return (1, 2, (ms - 450) / 250);
    if (ms < 760) return (2, 3, (ms - 700) / 60);
    if (ms < 840) return (3, 3, 0);
    if (ms < 920) return (3, 4, (ms - 840) / 80);
    if (ms < 1250) return (4, 4, 0);
    if (ms < 1800) return (4, 5, (ms - 1250) / 550);
    return (5, 5, 0);
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final (from, to, progress) = _pose(_controller.value * 1800);
            final blend = Curves.easeInOut.transform(progress.clamp(0, 1));
            return Stack(fit: StackFit.expand, children: [
              // Mounted together to decode before their turn; common canvases
              // and BoxFit.contain preserve the character's proportions.
              for (var i = 0; i < NudaengAlbumExpectant.frames.length; i++)
                Opacity(
                  opacity: from == to
                      ? (i == from ? 1 : 0)
                      : (i == from ? 1 - blend : (i == to ? blend : 0)),
                  child: Image.asset(NudaengAlbumExpectant.frames[i],
                      fit: BoxFit.contain,
                      gaplessPlayback: true,
                      excludeFromSemantics: true),
                ),
            ]);
          },
        ),
      );
}
