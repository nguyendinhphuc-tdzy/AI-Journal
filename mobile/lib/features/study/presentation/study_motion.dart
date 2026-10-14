import 'package:flutter/material.dart';

/// Motion rules for Study (spec section 14). Entering uses easeOutCubic,
/// state changes use easeInOut. With reduced motion there is no scale or
/// slide: content updates directly or with a short fade.
abstract final class StudyMotion {
  static const enter = Curves.easeOutCubic;
  static const change = Curves.easeInOut;
  static const reducedFade = Duration(milliseconds: 120);

  static bool reduced(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context);

  /// Sheets slide up over 300 ms and close in 220 ms, without bounce.
  static AnimationStyle sheet(BuildContext context) => reduced(context)
      ? const AnimationStyle(
          duration: reducedFade, reverseDuration: reducedFade)
      : const AnimationStyle(
          duration: Duration(milliseconds: 300),
          reverseDuration: Duration(milliseconds: 220),
          curve: enter,
          reverseCurve: change,
        );
}

/// First-visit entrance: fade in and rise 8 px over 280 ms. It starts the
/// first time its tab is actually shown (tickers enabled), never replays,
/// and never blocks input.
class StudyEntrance extends StatefulWidget {
  const StudyEntrance({super.key, required this.child});
  final Widget child;

  @override
  State<StudyEntrance> createState() => _StudyEntranceState();
}

class _StudyEntranceState extends State<StudyEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 280));
  late final Animation<double> _curve =
      CurvedAnimation(parent: _controller, curve: StudyMotion.enter);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller.status != AnimationStatus.dismissed) return;
    if (StudyMotion.reduced(context)) {
      _controller.value = 1;
    } else if (TickerMode.valuesOf(context).enabled) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _curve,
        child: widget.child,
        builder: (_, child) => Opacity(
          opacity: _curve.value,
          child: Transform.translate(
              offset: Offset(0, 8 * (1 - _curve.value)), child: child),
        ),
      );
}

/// Press feedback for cards and buttons: 1 → 0.98 in 80 ms, back in 120 ms.
/// It listens to raw pointers, so the tap action itself fires immediately.
class StudyPressable extends StatefulWidget {
  const StudyPressable({super.key, required this.child, this.enabled = true});
  final Widget child;
  final bool enabled;

  @override
  State<StudyPressable> createState() => _StudyPressableState();
}

class _StudyPressableState extends State<StudyPressable>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 80),
    reverseDuration: const Duration(milliseconds: 120),
  );

  void _down(PointerDownEvent _) {
    if (widget.enabled && !StudyMotion.reduced(context)) _controller.forward();
  }

  void _up(PointerEvent _) {
    if (_controller.value > 0) _controller.reverse();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Listener(
        onPointerDown: _down,
        onPointerUp: _up,
        onPointerCancel: _up,
        child: AnimatedBuilder(
          animation: _controller,
          child: widget.child,
          builder: (_, child) => Transform.scale(
            scale: 1 - .02 * StudyMotion.change.transform(_controller.value),
            child: child,
          ),
        ),
      );
}

/// Child-detail route: fade and slide 12 px from the right over 280 ms;
/// Back plays the same motion in reverse. Reduced motion: 120 ms fade only.
class StudyRoute<T> extends MaterialPageRoute<T> {
  StudyRoute({required super.builder});

  bool get _reduced {
    final context = navigator?.context;
    return context != null && StudyMotion.reduced(context);
  }

  @override
  Duration get transitionDuration =>
      _reduced ? StudyMotion.reducedFade : const Duration(milliseconds: 280);

  @override
  Duration get reverseTransitionDuration => transitionDuration;

  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation, Widget child) {
    final curved = CurvedAnimation(
        parent: animation,
        curve: StudyMotion.enter,
        reverseCurve: StudyMotion.enter.flipped);
    if (StudyMotion.reduced(context)) {
      return FadeTransition(opacity: curved, child: child);
    }
    return FadeTransition(
      opacity: curved,
      child: AnimatedBuilder(
        animation: curved,
        child: child,
        builder: (_, child) => Transform.translate(
            offset: Offset(12 * (1 - curved.value), 0), child: child),
      ),
    );
  }
}
