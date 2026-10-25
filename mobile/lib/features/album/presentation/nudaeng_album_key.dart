import 'package:flutter/material.dart';

/// Holds the key still until authentication succeeds, then puts it away once.
///
/// This is presentation only: the caller must pass a confirmed auth result.
/// Keep [authSucceeded] true after success; rebuilds do not replay the motion.
/// Setting it false cancels/resets the sequence for a new authentication attempt.
/// Reduced motion goes straight to the final pose and completes after the frame.
class NudaengAlbumKey extends StatefulWidget {
  const NudaengAlbumKey({
    super.key,
    required this.authSucceeded,
    this.onCompleted,
    this.semanticLabel,
  });

  final bool authSucceeded;

  /// Called once after the 1-second sequence (immediately for reduced motion).
  /// Does not itself unlock an album or navigate.
  final VoidCallback? onCompleted;
  final String? semanticLabel;

  static const duration = Duration(seconds: 1);
  static const frames = [
    'assets/Deimage/album-key-frame-01.png',
    'assets/Deimage/album-key-frame-02.png',
    'assets/Deimage/album-key-frame-03.png',
    'assets/Deimage/album-key-frame-04.png',
  ];

  @override
  State<NudaengAlbumKey> createState() => _NudaengAlbumKeyState();
}

class _NudaengAlbumKeyState extends State<NudaengAlbumKey>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: NudaengAlbumKey.duration,
  )..addListener(_onProgress);
  var _started = false;
  var _completionQueued = false;
  var _run = 0;

  void _onProgress() {
    // The controller reaches value 1 at 1000 ms; its completed status may
    // arrive on the next vsync. Notify at the actual end of the sequence.
    if (_controller.value < 1 || _completionQueued) return;
    _completionQueued = true;
    final run = _run;
    // Safe even when reduced motion completes during dependency updates.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.authSucceeded && run == _run) {
        widget.onCompleted?.call();
      }
    });
  }

  void _sync() {
    if (!widget.authSucceeded) {
      if (_started) {
        _run++;
        _started = false;
        _completionQueued = false;
        _controller.reset();
      }
      return;
    }
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    if (_started) {
      if (reducedMotion && !_controller.isCompleted) _controller.value = 1;
      return;
    }
    _started = true;
    _run++;
    if (reducedMotion) {
      _controller.value = 1;
    } else {
      _controller.forward(from: 0);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(NudaengAlbumKey oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
        image: widget.semanticLabel != null,
        label: widget.semanticLabel,
        child: ExcludeSemantics(
          child: AspectRatio(
            aspectRatio: 1,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final t = _controller.value;
                // 150 + 250 + 350 + 250 ms, then hold the key-free final pose.
                final frame = t < .15 ? 0 : (t < .40 ? 1 : (t < .75 ? 2 : 3));
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    // Mount all images from the waiting state so they decode
                    // before success, with a common canvas to avoid movement.
                    for (var i = 0; i < NudaengAlbumKey.frames.length; i++)
                      Opacity(
                        opacity: i == frame ? 1 : 0,
                        child: Image.asset(
                          NudaengAlbumKey.frames[i],
                          fit: BoxFit.fill,
                          gaplessPlayback: true,
                          excludeFromSemantics: true,
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      );
}
