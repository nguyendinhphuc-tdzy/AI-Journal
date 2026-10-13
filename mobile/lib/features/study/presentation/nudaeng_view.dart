import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'nudaeng_artwork.dart';

/// Shows the GIF's first frame, plays it once, then rests on the paired idle
/// pose (dissolving into it when that pose is a different drawing). The idle
/// pose never appears before the motion. No loop runs behind another route
/// or in the background.
class NudaengView extends StatefulWidget {
  const NudaengView({
    super.key,
    required this.artwork,
    required this.width,
    required this.height,
    required this.label,
    this.animate = true,
    this.onFinished,
  });

  final NudaengArtwork artwork;
  final double width;
  final double height;
  final String label;
  final bool animate;

  /// Called once when the motion has played (or was skipped) and the rest
  /// pose is showing. Never called after the view is disposed.
  final VoidCallback? onFinished;

  @override
  State<NudaengView> createState() => _NudaengViewState();
}

class _NudaengViewState extends State<NudaengView>
    with
        TickerProviderStateMixin,
        WidgetsBindingObserver,
        AutomaticKeepAliveClientMixin<NudaengView> {
  late final AnimationController _controller = AnimationController(vsync: this);
  // Dissolves the last motion frame into a rest pose drawn separately.
  late final AnimationController _settle = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 240));
  // Idle fidgets replay the hand-drawn frames after a varied pause, like a
  // Rive idle state, instead of transforming a still image.
  final math.Random _random = math.Random();
  Timer? _fidget;
  bool _appActive = true;
  final List<ui.Image> _frames = [];
  final List<int> _ends = [];
  ui.Image? _idle;
  Animation<double>? _routeAnimation;
  bool _started = false;
  bool _finished = false;
  int _duration = 0;

  // A lazily built hero must not restart its GIF after scrolling away and back.
  @override
  bool get wantKeepAlive => widget.animate;

  bool get _restIsSeparateDrawing =>
      widget.artwork.idleAsset != widget.artwork.animationAsset;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  Future<ui.Codec> _codec(String asset) async {
    final bytes = await rootBundle.load(asset);
    return ui.instantiateImageCodec(
        bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
        targetWidth: (widget.width * 3).ceil());
  }

  Future<void> _load() async {
    try {
      final animationAsset = widget.artwork.animationAsset;
      if (widget.animate && animationAsset != null) {
        await _loadMotion(animationAsset);
      }
      if (!mounted) return;
      final codec = await _codec(widget.artwork.idleAsset);
      late ui.FrameInfo idleFrame;
      try {
        final index = widget.artwork.idleFrame.clamp(0, codec.frameCount - 1);
        for (var i = 0; i <= index; i++) {
          idleFrame = await codec.getNextFrame();
          if (i < index) idleFrame.image.dispose();
        }
      } finally {
        codec.dispose();
      }
      if (!mounted) {
        idleFrame.image.dispose();
        return;
      }
      setState(() => _idle = idleFrame.image);
      if (_frames.isEmpty) {
        _finish();
      } else {
        _playIfVisible();
      }
    } catch (error, stack) {
      _finish();
      FlutterError.reportError(FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'Study Nudaeng artwork',
        context: ErrorDescription('loading ${widget.artwork.idleAsset}'),
      ));
    }
  }

  /// The first motion frame is the poster: the rest pose must not appear
  /// before the motion, or the mascot visibly swaps drawings twice.
  Future<void> _loadMotion(String asset) async {
    final codec = await _codec(asset);
    try {
      if (!mounted || MediaQuery.disableAnimationsOf(context)) return;
      for (var i = 0; i < codec.frameCount; i++) {
        final frame = await codec.getNextFrame();
        if (!mounted) {
          frame.image.dispose();
          return;
        }
        _duration += frame.duration.inMilliseconds.clamp(20, 1000);
        _ends.add(_duration);
        if (i == 0) {
          setState(() => _frames.add(frame.image));
        } else {
          _frames.add(frame.image);
        }
      }
      _controller.duration = Duration(
          milliseconds:
              _duration.clamp(1, widget.artwork.maxDuration.inMilliseconds));
    } finally {
      codec.dispose();
    }
  }

  void _playIfVisible() {
    if (_started ||
        _idle == null ||
        _frames.isEmpty ||
        _controller.duration == null ||
        !TickerMode.valuesOf(context).enabled) {
      return;
    }
    // Let the destination finish entering before spending its one-shot motion.
    if (_routeAnimation != null && !_routeAnimation!.isCompleted) return;
    _started = true;
    // A TickerFuture never completes when cut short, so a skipped motion
    // jumps straight to rest without the dissolve.
    _controller.forward().then((_) {
      if (!mounted) return;
      if (_restIsSeparateDrawing) {
        _settle.forward(from: 0).then((_) => _finish());
      } else {
        _finish();
      }
    });
  }

  void _skipToRest() {
    _started = true;
    _controller.value = 1;
    _settle.value = 1;
    // May run during didChangeDependencies; callers may navigate.
    WidgetsBinding.instance.addPostFrameCallback((_) => _finish());
  }

  void _finish() {
    if (_finished || !mounted) return;
    _finished = true;
    _scheduleFidget();
    widget.onFinished?.call();
  }

  void _scheduleFidget([Duration playing = Duration.zero]) {
    _fidget?.cancel();
    if (!mounted ||
        !widget.artwork.idleFidget ||
        _frames.isEmpty ||
        MediaQuery.disableAnimationsOf(context)) {
      return;
    }
    final pause = Duration(milliseconds: 3000 + _random.nextInt(3000));
    _fidget = Timer(playing + pause, _playFidget);
  }

  bool get _onScreen {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return false;
    final rect = box.localToGlobal(Offset.zero) & box.size;
    return rect.overlaps(Offset.zero & MediaQuery.sizeOf(context));
  }

  void _playFidget() {
    if (!mounted) return;
    // Hidden behind another route, scrolled out of view or app in the
    // background: skip this turn and wait for the next one.
    final visible =
        TickerMode.valuesOf(context).enabled && _appActive && _onScreen;
    if (visible && !_controller.isAnimating) {
      _controller.forward(from: 0);
      _scheduleFidget(_controller.duration ?? Duration.zero);
    } else {
      _scheduleFidget();
    }
  }

  void _onRouteStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) _playIfVisible();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final animation = ModalRoute.of(context)?.animation;
    if (animation != _routeAnimation) {
      _routeAnimation?.removeStatusListener(_onRouteStatus);
      _routeAnimation = animation;
      _routeAnimation?.addStatusListener(_onRouteStatus);
    }
    if (MediaQuery.disableAnimationsOf(context)) {
      _fidget?.cancel();
      _skipToRest();
    } else if (!TickerMode.valuesOf(context).enabled) {
      if (_started) _skipToRest();
    } else {
      _playIfVisible();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appActive = state == AppLifecycleState.resumed;
    if (state == AppLifecycleState.resumed) {
      _playIfVisible();
    } else if (_started) {
      _skipToRest();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _routeAnimation?.removeStatusListener(_onRouteStatus);
    _controller.dispose();
    _fidget?.cancel();
    _settle.dispose();
    _idle?.dispose();
    for (final frame in _frames) {
      frame.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Semantics(
      image: true,
      label: widget.label,
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: AnimatedBuilder(
          animation: Listenable.merge([_controller, _settle]),
          builder: (_, __) => _frame(),
        ),
      ),
    );
  }

  Widget _frame() {
    if (_frames.isNotEmpty && !_controller.isCompleted) {
      final elapsed = (_controller.value * _duration).floor();
      final index = _ends.indexWhere((end) => elapsed < end);
      return RawImage(
        image: _frames[index < 0 ? 0 : index],
        fit: BoxFit.contain,
      );
    }
    if (_frames.isNotEmpty && _restIsSeparateDrawing && _settle.value < 1) {
      final t = Curves.easeOut.transform(_settle.value);
      return Stack(fit: StackFit.expand, children: [
        Opacity(
            opacity: 1 - t,
            child: RawImage(image: _frames.last, fit: BoxFit.contain)),
        Opacity(opacity: t, child: RawImage(image: _idle, fit: BoxFit.contain)),
      ]);
    }
    return RawImage(image: _idle, fit: BoxFit.contain);
  }
}
