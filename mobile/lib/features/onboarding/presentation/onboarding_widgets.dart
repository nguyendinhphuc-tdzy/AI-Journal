import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../data/onboarding_store.dart';

/// Primary onboarding CTA: 56 high, radius 28, full width in the content
/// inset. Disabled when [onPressed] is null.
class OnboardingCta extends StatelessWidget {
  const OnboardingCta({super.key, required this.label, this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  static const labelStyle = TextStyle(
    fontFamily: 'BeVietnamPro',
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.5,
  );

  /// Height of the button at the current text scale.
  static double heightOf(BuildContext context) => math.max(
      56,
      MediaQuery.textScalerOf(context).scale(labelStyle.fontSize!) *
              labelStyle.height! +
          AppSpacing.md * 2);

  @override
  Widget build(BuildContext context) => FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primaryAction,
          foregroundColor: AppColors.surface,
          disabledBackgroundColor: AppColors.border,
          disabledForegroundColor: AppColors.textSecondary,
          elevation: 4,
          shadowColor: AppColors.textPrimary.withValues(alpha: .4),
          minimumSize: const Size.fromHeight(56),
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl, vertical: AppSpacing.md),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          textStyle: labelStyle,
        ),
        child: Text(label, textAlign: TextAlign.center),
      );
}

/// Secondary text action under the CTA, e.g. "Để sau". 48 high.
class OnboardingTextAction extends StatelessWidget {
  const OnboardingTextAction(
      {super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  /// Height at the current text scale.
  static double heightOf(BuildContext context) => math.max(
      48,
      MediaQuery.textScalerOf(context)
                  .scale(OnboardingCta.labelStyle.fontSize!) *
              OnboardingCta.labelStyle.height! +
          AppSpacing.xl);

  @override
  Widget build(BuildContext context) => TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          minimumSize: const Size.fromHeight(48),
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: 12),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          textStyle: OnboardingCta.labelStyle,
        ),
        child: Text(label, textAlign: TextAlign.center),
      );
}

/// Layout shared by OB02–OB11: safe area → top bar (Back + progress) →
/// scrollable [content] → [stage] in the space left (never makes the page
/// scroll; hidden while the keyboard is open) → [actions] dock, which rises
/// with the keyboard. Parts appear one after another; callers wrap their
/// pieces in [StaggerItem]s. The top bar stays put between steps.
///
/// The stage always ends on the same line from the bottom: with one action
/// it leaves the room a secondary action would take, so the mascot does not
/// move between steps with and without "Để sau".
class OnboardingStepScaffold extends StatefulWidget {
  const OnboardingStepScaffold({
    super.key,
    required this.step,
    required this.onBack,
    required this.content,
    this.stage,
    this.stageNeeds,
    required this.actions,
    this.background = AppColors.background,
    this.backdrop,
  });

  final OnboardingStep step;
  final VoidCallback onBack;
  final Widget content;
  final Widget? stage;

  /// Height the [stage] needs to show. Given, the stage is never hidden for
  /// want of room: when long content leaves less, it goes at the end of the
  /// content instead and scrolls with it (e.g. OB06's policy copy).
  final double? stageNeeds;
  final List<Widget> actions;

  /// Screen colour behind everything.
  final Color background;

  /// Decoration at the screen's bottom, behind the actions, in place of the
  /// shared ground (e.g. OB10's balloons). Kept below the feet line, so it
  /// never covers the mascot.
  final Widget? backdrop;

  /// Where every step's mascot stands, from the screen's bottom: the dock of
  /// a step with two actions, plus the mascot's gap. The ground uses it too.
  static double feetLineFromBottom(BuildContext context) =>
      MediaQuery.paddingOf(context).bottom +
      AppSpacing.md +
      OnboardingCta.heightOf(context) +
      AppSpacing.xs +
      OnboardingTextAction.heightOf(context) +
      AppSpacing.xs +
      OnboardingMascot.gap;

  /// What a secondary action adds to the dock: its height and the gap above
  /// it, less the bottom padding a single action gets instead.
  static double _secondarySlot(BuildContext context) =>
      AppSpacing.xs +
      OnboardingTextAction.heightOf(context) +
      AppSpacing.xs -
      AppSpacing.md;

  @override
  State<OnboardingStepScaffold> createState() => _OnboardingStepScaffoldState();
}

class _OnboardingStepScaffoldState extends State<OnboardingStepScaffold> {
  /// Room the stage leaves above the dock; the ground shows only when the
  /// content ends above its horizon, so text never sits on the drawing.
  final _stageRoom = ValueNotifier<double>(double.infinity);

  /// Gap below the feet, horizon above them, and a little air.
  static const _groundClearance =
      OnboardingMascot.gap + OnboardingGround.horizonAboveFeet + 8;

  /// The stage is at the end of the content, for want of room below it.
  bool _stageInContent = false;

  @override
  void dispose() {
    _stageRoom.dispose();
    super.dispose();
  }

  void _reportRoom(double room) {
    final needs = widget.stageNeeds;
    // In the content, the stage's own height is room it would have below.
    final inContent = needs != null &&
        (_stageInContent ? room + needs : room) < needs;
    if (room == _stageRoom.value && inContent == _stageInContent) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _stageRoom.value = room;
      if (inContent != _stageInContent) {
        setState(() => _stageInContent = inContent);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final stage = widget.stage;
    final actions = widget.actions;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: widget.background,
        body: OnboardingStagger(
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (widget.backdrop case final backdrop? when !keyboardOpen)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: OnboardingStepScaffold.feetLineFromBottom(context) -
                      OnboardingMascot.gap,
                  child: IgnorePointer(
                    child: ExcludeSemantics(
                      child: StaggerItem(order: 0, child: backdrop),
                    ),
                  ),
                )
              else if (!keyboardOpen)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: OnboardingStepScaffold.feetLineFromBottom(context) +
                      OnboardingGround.horizonAboveFeet +
                      _GroundPainter.crest,
                  child: ValueListenableBuilder(
                    valueListenable: _stageRoom,
                    builder: (context, room, child) =>
                        room >= _groundClearance ? child! : const SizedBox(),
                    child:
                        const StaggerItem(order: 0, child: OnboardingGround()),
                  ),
                ),
              SafeArea(
                child: Column(
                  children: [
                    // Not staggered: the bar stays put from step to step.
                    OnboardingTopBar(step: widget.step, onBack: widget.onBack),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, viewport) => SingleChildScrollView(
                          child: ConstrainedBox(
                            constraints:
                                BoxConstraints(minHeight: viewport.maxHeight),
                            child: IntrinsicHeight(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  widget.content,
                                  if (_stageInContent && !keyboardOpen)
                                    if ((stage, widget.stageNeeds)
                                        case (final stage?, final needs?))
                                      SizedBox(height: needs, child: stage),
                                  // Zero intrinsic height: the stage only takes
                                  // leftover space.
                                  Expanded(
                                    child: SizedBox(
                                      height: 0,
                                      child: keyboardOpen || stage == null
                                          ? const SizedBox.shrink()
                                          : Padding(
                                              padding: EdgeInsets.only(
                                                  bottom: actions.length > 1
                                                      ? 0
                                                      : OnboardingStepScaffold
                                                          ._secondarySlot(
                                                              context)),
                                              child: LayoutBuilder(
                                                builder: (context, box) {
                                                  _reportRoom(box.maxHeight);
                                                  return _stageInContent
                                                      ? const SizedBox.shrink()
                                                      : stage;
                                                },
                                              ),
                                            ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                          AppSpacing.lg,
                          AppSpacing.md,
                          AppSpacing.lg,
                          actions.length > 1 ? AppSpacing.xs : AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (var i = 0; i < actions.length; i++) ...[
                            if (i > 0) const SizedBox(height: AppSpacing.xs),
                            actions[i],
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Back plus "Bước x/9" progress for the interactive routes OB02–OB11.
class OnboardingTopBar extends StatelessWidget {
  const OnboardingTopBar({super.key, required this.step, required this.onBack});

  final OnboardingStep step;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final position = step.progressPosition ?? 0;
    const total = OnboardingStep.progressSteps;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.xs, AppSpacing.xs, AppSpacing.lg, AppSpacing.xs),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            tooltip: 'Quay lại',
            icon: const Icon(Icons.arrow_back_rounded),
            color: AppColors.textPrimary,
            constraints: const BoxConstraints.tightFor(width: 48, height: 48),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: ExcludeSemantics(
              child: _ProgressTrack(value: position / total),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Bước $position/$total',
            style: const TextStyle(
              fontFamily: 'BeVietnamPro',
              fontSize: 14,
              height: 20 / 14,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Light track, PrimaryDark fill, small bookmark at the fill's end. Each
/// step builds its own bar, so the fill grows (or shrinks, on Back) from
/// where the previous step's bar left it.
class _ProgressTrack extends StatefulWidget {
  const _ProgressTrack({required this.value});

  final double value;

  static const _height = 6.0;
  static const _mark = 20.0;
  static const _duration = Duration(milliseconds: 420);

  /// Fill last shown, by any step.
  static double? _shown;

  @override
  State<_ProgressTrack> createState() => _ProgressTrackState();
}

class _ProgressTrackState extends State<_ProgressTrack> {
  late final double _from = _ProgressTrack._shown ?? widget.value;

  @override
  void initState() {
    super.initState();
    _ProgressTrack._shown = widget.value;
  }

  @override
  void didUpdateWidget(_ProgressTrack oldWidget) {
    super.didUpdateWidget(oldWidget);
    _ProgressTrack._shown = widget.value;
  }

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: _from, end: widget.value),
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : _ProgressTrack._duration,
        curve: Curves.easeOutCubic,
        builder: (context, value, _) => _bar(value),
      );

  Widget _bar(double value) => LayoutBuilder(
        builder: (context, box) {
          const height = _ProgressTrack._height;
          const mark = _ProgressTrack._mark;
          final fill = box.maxWidth * value.clamp(0, 1);
          return SizedBox(
            height: mark,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.centerLeft,
              children: [
                Container(
                  height: height,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(height / 2),
                  ),
                ),
                Container(
                  width: fill,
                  height: height,
                  decoration: BoxDecoration(
                    color: AppColors.primaryDark,
                    borderRadius: BorderRadius.circular(height / 2),
                  ),
                ),
                Positioned(
                  left: (fill - mark / 2).clamp(0, box.maxWidth - mark),
                  top: 0,
                  child: const Icon(Icons.bookmark_rounded,
                      size: mark, color: AppColors.primaryDark),
                ),
              ],
            ),
          );
        },
      );
}

/// Soft contact shadow so Nudaeng stands on the ground.
class GroundShadow extends StatelessWidget {
  const GroundShadow({super.key});

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.all(Radius.elliptical(200, 30)),
            boxShadow: [
              BoxShadow(
                color: AppColors.textPrimary.withValues(alpha: .18),
                blurRadius: 10,
              ),
            ],
          ),
        ),
      );
}

/// Staggered entrance for a screen's parts: each [StaggerItem] fades in and
/// rises 12 px, in [StaggerItem.order]. Starts on mount, never blocks input.
/// Reduced motion shows everything at once.
class OnboardingStagger extends StatefulWidget {
  const OnboardingStagger({super.key, required this.child});

  final Widget child;

  static const delay = Duration(milliseconds: 80);
  static const step = Duration(milliseconds: 90);
  static const itemDuration = Duration(milliseconds: 380);

  /// Enough for eleven items (orders 0–10).
  static final total = delay + step * 10 + itemDuration;

  @override
  State<OnboardingStagger> createState() => _OnboardingStaggerState();
}

class _OnboardingStaggerState extends State<OnboardingStagger>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: OnboardingStagger.total);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller.status != AnimationStatus.dismissed) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _StaggerScope(animation: _controller, child: widget.child);
}

class _StaggerScope extends InheritedWidget {
  const _StaggerScope({required this.animation, required super.child});

  final Animation<double> animation;

  @override
  bool updateShouldNotify(_StaggerScope old) => old.animation != animation;
}

/// One part of an [OnboardingStagger]; shows directly outside of one.
class StaggerItem extends StatelessWidget {
  const StaggerItem({super.key, required this.order, required this.child});

  final int order;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_StaggerScope>();
    if (scope == null) return child;
    final total = OnboardingStagger.total.inMicroseconds;
    final start = (OnboardingStagger.delay + OnboardingStagger.step * order)
            .inMicroseconds /
        total;
    final end = start + OnboardingStagger.itemDuration.inMicroseconds / total;
    // drive() only forwards listeners, so rebuilding never leaks any.
    final curve = scope.animation.drive(CurveTween(
      curve: Interval(start.clamp(0, 1), end.clamp(0, 1),
          curve: Curves.easeOutCubic),
    ));
    return FadeTransition(
      opacity: curve,
      child: AnimatedBuilder(
        animation: curve,
        child: child,
        builder: (_, child) => Transform.translate(
            offset: Offset(0, 12 * (1 - curve.value)), child: child),
      ),
    );
  }
}

/// Slow idle "breath", 0 → 1 → 0 every 2.8 s, for a mascot standing still.
/// Reduced motion keeps it at 0.
class IdleBreath extends StatefulWidget {
  const IdleBreath({super.key, required this.builder});

  final Widget Function(BuildContext context, double breath) builder;

  static const halfCycle = Duration(milliseconds: 1400);

  @override
  State<IdleBreath> createState() => _IdleBreathState();
}

class _IdleBreathState extends State<IdleBreath>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: IdleBreath.halfCycle);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 0;
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => widget.builder(
            context, Curves.easeInOutSine.transform(_controller.value)),
      );
}

/// Where Nudaeng stands inside a mascot image, in the image's own pixels:
/// the top of the head and the centre/bottom of the feet.
class MascotFrame {
  const MascotFrame({
    required this.canvas,
    required this.headTop,
    required this.feet,
  });

  final Size canvas;
  final double headTop;
  final Offset feet;

  double get figureHeight => feet.dy - headTop;
}

/// The desk scenes (OB05 guide, OB06 tearing paper) share one 518×490
/// crop, so the desk and Nudaeng stay put when those steps change.
const deskScene = MascotFrame(
  canvas: Size(518, 490),
  headTop: 2,
  feet: Offset(259, 488),
);

/// Seated at the desk, the scene is 120 high: the head then matches the
/// standing poses at 96.
const deskSceneHeight = 120.0;

/// Nudaeng at the same size and spot on every onboarding step, so moving
/// between steps never makes it jump: head to feet [figureHeight] tall, feet
/// centred on the screen and [gap] above the actions, a ground shadow, and a
/// slow breath. When the stage has less room it hides rather than shrinks,
/// so content and actions win. Reduced motion: no breath.
class OnboardingMascot extends StatelessWidget {
  const OnboardingMascot({
    super.key,
    required this.frame,
    required this.child,
    this.bubble,
    this.height = figureHeight,
    this.wholeCanvas = false,
  });

  final MascotFrame frame;

  /// Head to feet on screen. Keep [figureHeight] for standing poses; a
  /// seated scene may be taller so the head stays the same size.
  final double height;

  /// Fills [frame.canvas], scaled.
  final Widget child;

  /// Shown above the head (e.g. [MascotBubble]) when there is room for it;
  /// without room only the bubble hides.
  final Widget? bubble;

  /// The whole [frame.canvas] must fit in the stage, not just the figure:
  /// for art that rises above the head (OB10's balloons), which would
  /// otherwise draw over the content. Without room it all hides.
  final bool wholeCanvas;

  static const figureHeight = 96.0;
  static const gap = 12.0;

  /// Room a bubble needs above the head.
  static const bubbleRoom = 56.0;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        if (box.maxHeight < height + gap) return const SizedBox.shrink();
        final scale = height / frame.figureHeight;
        final feet = Offset(box.maxWidth / 2, box.maxHeight - gap);
        final canvas = frame.canvas * scale;
        if (wholeCanvas && feet.dy - frame.feet.dy * scale < 0) {
          return const SizedBox.shrink();
        }
        final shadow = Size(height * .9, height * .07);
        final bubble = this.bubble;
        final headTop = feet.dy - height;
        final showBubble = bubble != null && headTop >= bubbleRoom;
        return IdleBreath(
          builder: (context, breath) => Stack(
            clipBehavior: Clip.none,
            children: [
              if (showBubble)
                Positioned(
                  left: AppSpacing.lg,
                  right: AppSpacing.lg,
                  bottom: box.maxHeight - headTop + AppSpacing.sm,
                  child: Center(child: bubble),
                ),
              Positioned(
                left: feet.dx - shadow.width / 2,
                top: feet.dy - shadow.height / 2,
                width: shadow.width,
                height: shadow.height,
                child: Transform.scale(
                    scaleX: 1 - .05 * breath, child: const GroundShadow()),
              ),
              Positioned(
                left: feet.dx - frame.feet.dx * scale,
                top: feet.dy - frame.feet.dy * scale,
                width: canvas.width,
                height: canvas.height,
                // A 2% stretch from the feet; the shadow tightens as it rises.
                child: Transform(
                  alignment: Alignment(
                    frame.feet.dx / frame.canvas.width * 2 - 1,
                    frame.feet.dy / frame.canvas.height * 2 - 1,
                  ),
                  transform: Matrix4.diagonal3Values(
                      1 - .01 * breath, 1 + .02 * breath, 1),
                  child: child,
                ),
              ),
            ],
          ),
        );
      });
}

/// Speech bubble for the mascot, tail pointing down at its head. Grows and
/// shrinks smoothly with its text; one line, ellipsised when long.
/// Decorative for screen readers (it repeats what the screen says).
class MascotBubble extends StatelessWidget {
  const MascotBubble({super.key, required this.text});

  final String text;

  static const style = TextStyle(
    fontFamily: 'BeVietnamPro',
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.5,
    color: AppColors.textPrimary,
  );

  @override
  Widget build(BuildContext context) {
    final label = Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm,
          AppSpacing.md, AppSpacing.sm + _BubblePainter.tail),
      child: Text(text,
          maxLines: 1, overflow: TextOverflow.ellipsis, style: style),
    );
    return ExcludeSemantics(
      child: CustomPaint(
        painter: _BubblePainter(),
        // No AnimatedSize under reduced motion: a zero duration would
        // re-layout it from inside its own layout.
        child: MediaQuery.disableAnimationsOf(context)
            ? label
            : AnimatedSize(
                duration: const Duration(milliseconds: 160),
                curve: Curves.easeOutCubic,
                child: label,
              ),
      ),
    );
  }
}

class _BubblePainter extends CustomPainter {
  static const tail = 8.0;
  static const radius = 16.0;

  @override
  void paint(Canvas canvas, Size size) {
    final body = RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height - tail),
        const Radius.circular(radius));
    final centre = size.width / 2;
    final path = Path()
      ..addRRect(body)
      ..moveTo(centre - 7, size.height - tail - 1)
      ..lineTo(centre, size.height)
      ..lineTo(centre + 7, size.height - tail - 1)
      ..close();
    canvas
      ..drawShadow(path, AppColors.textPrimary.withValues(alpha: .25), 3, false)
      ..drawPath(path, Paint()..color = AppColors.surface)
      ..drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = AppColors.border);
  }

  @override
  bool shouldRepaint(_BubblePainter old) => false;
}

/// Soft mint ground shared by OB02+, so steps read as one place: a gently
/// wavy, hand-drawn horizon just above Nudaeng's feet, a few flowers and
/// grass tufts, filled down to the screen's bottom (the actions float over
/// it, as on OB01). Purely decorative.
class OnboardingGround extends StatelessWidget {
  const OnboardingGround({super.key});

  /// The horizon sits this far above the feet line, so Nudaeng stands on
  /// the ground rather than on its edge.
  static const horizonAboveFeet = 16.0;

  @override
  Widget build(BuildContext context) => const IgnorePointer(
        child: ExcludeSemantics(
          child: CustomPaint(size: Size.infinite, painter: _GroundPainter()),
        ),
      );
}

class _GroundPainter extends CustomPainter {
  const _GroundPainter();

  /// Top padding inside the box for the wave's crests.
  static const crest = 6.0;

  // Petal colours from the OB01 petal artwork.
  static const _petal = Color(0xFFF6E6C8);
  static const _petalLine = Color(0xFF9C8466);
  static const _heart = Color(0xFFE7C77F);

  double _horizon(double x, double width) {
    final t = x / width * math.pi * 2;
    return crest + 2.6 * math.sin(t * 1.15 + .6) + 1.2 * math.sin(t * 3.4);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final line = Path()..moveTo(0, _horizon(0, size.width));
    for (var x = 4.0; x <= size.width; x += 4) {
      line.lineTo(x, _horizon(x, size.width));
    }
    final fill = Path.from(line)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas
      ..drawPath(fill, Paint()..color = AppColors.primaryLight)
      ..drawPath(
          line,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6
            ..strokeCap = StrokeCap.round
            ..color = AppColors.softAccent);

    // Kept to the sides, clear of Nudaeng in the middle.
    for (final (x, dy, r) in const [
      (.09, 14.0, 3.2),
      (.86, 10.0, 2.6),
      (.94, 24.0, 3.4)
    ]) {
      _flower(canvas,
          Offset(x * size.width, _horizon(x * size.width, size.width) + dy), r);
    }
    for (final (x, dy) in const [(.2, 8.0), (.72, 16.0)]) {
      _tuft(canvas,
          Offset(x * size.width, _horizon(x * size.width, size.width) + dy));
    }
  }

  void _flower(Canvas canvas, Offset centre, double r) {
    final petal = Paint()..color = _petal;
    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = .8
      ..color = _petalLine;
    for (var i = 0; i < 5; i++) {
      final a = i / 5 * math.pi * 2 - math.pi / 2;
      final c = centre + Offset(math.cos(a), math.sin(a)) * r;
      canvas
        ..drawCircle(c, r * .75, petal)
        ..drawCircle(c, r * .75, outline);
    }
    canvas.drawCircle(centre, r * .55, Paint()..color = _heart);
  }

  void _tuft(Canvas canvas, Offset base) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..color = AppColors.softAccent;
    for (final (dx, h) in const [(-4.0, 6.0), (0.0, 9.0), (4.0, 6.5)]) {
      canvas.drawPath(
          Path()
            ..moveTo(base.dx + dx * .4, base.dy)
            ..quadraticBezierTo(
                base.dx + dx * .6, base.dy - h * .6, base.dx + dx, base.dy - h),
          paint);
    }
  }

  @override
  bool shouldRepaint(_GroundPainter old) => false;
}

/// Single-choice card shared by OB03 and OB04: the whole card is the hit
/// area, the radio sits on the right, label (and optional [description])
/// wrap. Selected is not colour alone: Primary Light fill, a 2 px Primary
/// Action border, a filled radio and a semibold label. (Primary on Primary
/// Light is under the 3:1 a control's boundary needs.) Screen readers get a
/// checked item in a mutually exclusive group.
class OnboardingOptionCard extends StatelessWidget {
  const OnboardingOptionCard({
    super.key,
    required this.label,
    this.description,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String? description;
  final bool selected;
  final VoidCallback onTap;

  static const labelStyle = TextStyle(
    fontFamily: 'BeVietnamPro',
    fontSize: 16,
    height: 1.5,
    color: AppColors.textPrimary,
  );
  static const descriptionStyle = TextStyle(
    fontFamily: 'BeVietnamPro',
    fontSize: 14,
    height: 20 / 14,
    color: AppColors.textSecondary,
  );

  @override
  Widget build(BuildContext context) {
    final description = this.description;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.card),
      side: BorderSide(
        color: selected ? AppColors.primaryAction : AppColors.border,
        width: selected ? 2 : 1,
      ),
    );
    return Semantics(
      container: true,
      inMutuallyExclusiveGroup: true,
      checked: selected,
      label: description == null ? label : '$label. $description',
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: selected ? AppColors.primaryLight : AppColors.surface,
        shape: shape,
        child: InkWell(
          onTap: onTap,
          customBorder: shape,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: labelStyle.copyWith(
                            fontWeight:
                                selected ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                        if (description != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            description,
                            // Secondary text on Primary Light is under 4.5:1.
                            style: descriptionStyle.copyWith(
                              color: selected
                                  ? AppColors.textPrimary
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  _RadioMark(selected: selected),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RadioMark extends StatelessWidget {
  const _RadioMark({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 150),
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.surface,
          border: Border.all(
            color: selected ? AppColors.primaryAction : AppColors.textSecondary,
            width: 2,
          ),
        ),
        alignment: Alignment.center,
        child: selected
            ? Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primaryAction,
                ),
              )
            : null,
      );
}
