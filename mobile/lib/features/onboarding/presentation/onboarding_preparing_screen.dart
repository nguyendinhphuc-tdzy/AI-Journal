import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../data/onboarding_store.dart';
import 'first_reflection.dart';
import 'onboarding_widgets.dart';

/// OB08: transient. Shown only once the entry is saved, AI is on and the
/// reflection request is running. It leaves for OB09 the moment the request
/// settles (ready, failed or cancelled): no minimum duration, no fake
/// percentage, and the request is never held back for the mascot.
/// "Xem phản hồi sau" leaves at once for OB09's pending variant.
class OnboardingPreparingScreen extends StatefulWidget {
  const OnboardingPreparingScreen({
    super.key,
    required this.reflection,
    required this.onBack,
    required this.onLeave,
  });

  final FirstReflection reflection;
  final VoidCallback onBack;

  /// To OB09, on settling or on "Xem phản hồi sau". Called once.
  final VoidCallback onLeave;

  static const savedLabel = 'Nhật ký đã lưu';
  static const title = 'Nhật ký đã lưu. Đang chuẩn bị phản hồi AI…';
  static const hint = 'Bạn có thể đợi ở đây hoặc xem phản hồi sau.';
  static const laterLabel = 'Xem phản hồi sau';

  static const mascotAsset = 'assets/Deimage/Nudaeng writing-transparent.png';

  @override
  State<OnboardingPreparingScreen> createState() =>
      _OnboardingPreparingScreenState();
}

class _OnboardingPreparingScreenState extends State<OnboardingPreparingScreen> {
  var _left = false;

  @override
  void initState() {
    super.initState();
    widget.reflection.addListener(_check);
    // Nothing running (e.g. resumed here after a restart): no fake wait.
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  void _check() {
    if (widget.reflection.status != ReflectionStatus.pending) _leave();
  }

  void _leave() {
    if (_left || !mounted) return;
    _left = true;
    widget.onLeave();
  }

  @override
  void dispose() {
    widget.reflection.removeListener(_check);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => OnboardingStepScaffold(
        step: OnboardingStep.saving,
        onBack: widget.onBack,
        content: Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const StaggerItem(order: 1, child: _SavedLabel()),
              const SizedBox(height: AppSpacing.xxl + AppSpacing.lg),
              // The status sits mid-screen, Nudaeng writing below it, like
              // a quiet "analysing" moment. Indeterminate on purpose: there
              // is no real progress to show.
              const StaggerItem(
                order: 2,
                child: Center(
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: AppColors.primaryAction),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              StaggerItem(
                order: 2,
                child: Semantics(
                  header: true,
                  liveRegion: true,
                  child: const Text(OnboardingPreparingScreen.title,
                      textAlign: TextAlign.center, style: _title),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              const StaggerItem(
                order: 3,
                child: Text(OnboardingPreparingScreen.hint,
                    textAlign: TextAlign.center, style: _hint),
              ),
            ],
          ),
        ),
        stage: const StaggerItem(order: 4, child: _Stage()),
        actions: [
          StaggerItem(
            order: 5,
            child: OnboardingCta(
              label: OnboardingPreparingScreen.laterLabel,
              onPressed: _leave,
            ),
          ),
        ],
      );
}

const _title = TextStyle(
  fontFamily: 'Nunito',
  fontSize: 24,
  fontWeight: FontWeight.w700,
  height: 1.3,
  color: AppColors.textPrimary,
);

const _hint = TextStyle(
  fontFamily: 'BeVietnamPro',
  fontSize: 16,
  height: 1.5,
  color: AppColors.textSecondary,
);

class _SavedLabel extends StatelessWidget {
  const _SavedLabel();

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(AppRadius.small),
          ),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            ExcludeSemantics(
              child: Icon(Icons.check_circle_outline_rounded,
                  size: 18, color: AppColors.primaryAction),
            ),
            SizedBox(width: 6),
            Flexible(
              child: Text(
                OnboardingPreparingScreen.savedLabel,
                style: TextStyle(
                  fontFamily: 'BeVietnamPro',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  height: 20 / 14,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ]),
        ),
      );
}

/// The writing desk ([deskScene]), 120 high, as on OB07 and OB09.
class _Stage extends StatelessWidget {
  const _Stage();

  @override
  Widget build(BuildContext context) {
    final width =
        deskScene.canvas.width * deskSceneHeight / deskScene.figureHeight;
    final decodeWidth =
        (width * MediaQuery.devicePixelRatioOf(context) / 64).ceil() * 64;
    return OnboardingMascot(
      frame: deskScene,
      height: deskSceneHeight,
      child: Image.asset(
        OnboardingPreparingScreen.mascotAsset,
        cacheWidth: decodeWidth,
        semanticLabel: 'Nudaeng ngồi bàn viết nhật ký',
      ),
    );
  }
}
