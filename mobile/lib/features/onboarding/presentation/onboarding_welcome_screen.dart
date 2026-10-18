import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import 'falling_petals.dart';
import 'nudaeng_umbrella_blink.dart';
import 'onboarding_widgets.dart';

/// OB01: welcome and first meeting with Nudaeng. No Back and no progress;
/// "Bắt đầu" is available immediately.
///
/// Layout: the background fills the screen. Nudaeng is shown whole, standing
/// just above the floating CTA in the space left under the text; the CTA has
/// no band or fade behind it. On short screens or large text Nudaeng shrinks
/// to 128 and the content scrolls; font size never shrinks.
class OnboardingWelcomeScreen extends StatelessWidget {
  const OnboardingWelcomeScreen({
    super.key,
    required this.brandName,
    required this.onStart,
    this.gust,
  });

  final String brandName;
  final VoidCallback onStart;

  /// Transition wind (0 → 1) that carries the petals away after "Bắt đầu".
  final Animation<double>? gust;

  static const backgroundAsset = 'assets/Deimage/nudaeng-mint-background.png';
  static const title = 'Một góc nhỏ để viết về ngày của bạn.';
  static const body =
      'Ghi lại suy nghĩ, lưu những điều đáng nhớ và khám phá cách viết cùng Nudaeng.';
  static const startLabel = 'Bắt đầu';

  static const _minStage = 128.0;

  @override
  Widget build(BuildContext context) {
    final dock = _Dock.heightOf(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              backgroundAsset,
              fit: BoxFit.cover,
              alignment: Alignment.bottomCenter,
              excludeFromSemantics: true,
            ),
            LayoutBuilder(
              builder: (context, viewport) => SingleChildScrollView(
                // The stage ends at the CTA, so scrolled text never ends up
                // behind the button.
                padding: EdgeInsets.only(bottom: dock),
                child: ConstrainedBox(
                  constraints:
                      BoxConstraints(minHeight: viewport.maxHeight - dock),
                  child: IntrinsicHeight(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _Intro(brandName: brandName),
                        // Tight height answers the intrinsic query without
                        // asking the LayoutBuilder; Expanded still sizes it.
                        Expanded(
                          child: SizedBox(
                              height: _minStage, child: _Stage(gust: gust)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _Dock(onStart: onStart),
            ),
          ],
        ),
      ),
    );
  }
}

class _Intro extends StatelessWidget {
  const _Intro({required this.brandName});

  final String brandName;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    // A light veil only: the clouds stay visible, and the text uses the
    // darkest colours so it still reads over them.
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.background.withValues(alpha: .55),
            AppColors.background.withValues(alpha: .4),
            AppColors.background.withValues(alpha: 0),
          ],
          stops: const [0, .7, 1],
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          topInset + AppSpacing.xl,
          AppSpacing.lg,
          AppSpacing.xl,
        ),
        child: Column(
          children: [
            Text(
              brandName,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontSize: 20,
                fontWeight: FontWeight.w800,
                height: 1.25,
                color: AppColors.primaryAction,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Semantics(
              header: true,
              child: const Text(
                OnboardingWelcomeScreen.title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              OnboardingWelcomeScreen.body,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'BeVietnamPro',
                fontSize: 16,
                height: 1.5,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Space between the text and the CTA: Nudaeng whole, feet just above the
/// CTA, with petals falling around. Reduced motion: no petals.
class _Stage extends StatelessWidget {
  const _Stage({this.gust});

  final Animation<double>? gust;

  /// Visible part of the 1083×1453 frames (alpha bounds of frame 01). The
  /// transparent margin is not counted when fitting Nudaeng.
  static const _content = Rect.fromLTRB(31, 33, 1055, 1418);
  static const _frame = Size(1083, 1453);

  /// Centre of the feet, as a share of the frame width.
  static const _feetX = .565;

  // Never wider than this share of the screen, so the scene keeps air.
  static const _maxWidthShare = .86;

  // Gap between the feet and the CTA.
  static const _footGap = AppSpacing.sm;

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    return LayoutBuilder(builder: (context, box) {
      final room = box.maxHeight - _footGap;
      final scale = math.min(
        box.maxWidth * _maxWidthShare / _content.width,
        room / _content.height,
      );
      final width = _content.width * scale;
      final left = (box.maxWidth - width) / 2 - _content.left * scale;
      final top = room - _content.bottom * scale;
      final feet = Offset(left + _frame.width * _feetX * scale, room);
      return Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: feet.dx - width * .22,
            top: feet.dy - width * .03,
            width: width * .44,
            height: width * .06,
            child: const GroundShadow(),
          ),
          Positioned(
            left: left,
            top: top,
            width: _frame.width * scale,
            height: _frame.height * scale,
            child: const NudaengUmbrellaBlink(
              semanticLabel: 'Nudaeng cầm ô đứng dưới mưa cánh hoa',
            ),
          ),
          if (!reduced) Positioned.fill(child: FallingPetals(gust: gust)),
        ],
      );
    });
  }
}

/// The CTA alone, floating over the scene: no band or fade behind it.
class _Dock extends StatelessWidget {
  const _Dock({required this.onStart});

  final VoidCallback onStart;

  /// Space the dock takes at the bottom, including the safe area.
  static double heightOf(BuildContext context) =>
      AppSpacing.md * 2 +
      OnboardingCta.heightOf(context) +
      MediaQuery.paddingOf(context).bottom;

  @override
  Widget build(BuildContext context) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md)
              .copyWith(left: AppSpacing.lg, right: AppSpacing.lg),
          child: OnboardingCta(
            label: OnboardingWelcomeScreen.startLabel,
            onPressed: onStart,
          ),
        ),
      );
}
