import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../data/journaling_experience.dart';
import '../data/onboarding_store.dart';
import 'onboarding_widgets.dart';

/// OB04: how familiar the user is with journaling. Same single-choice cards
/// as OB03, each with a short description. Picking only updates the
/// selection; "Tiếp tục" needs one; "Để sau" saves
/// [JournalingExperience.unknown].
class OnboardingExperienceScreen extends StatefulWidget {
  const OnboardingExperienceScreen({
    super.key,
    required this.initialExperience,
    required this.onChanged,
    required this.onBack,
    required this.onContinue,
    required this.onSkip,
  });

  final JournalingExperience? initialExperience;
  final ValueChanged<JournalingExperience> onChanged;
  final VoidCallback onBack;
  final ValueChanged<JournalingExperience> onContinue;
  final VoidCallback onSkip;

  static const title = 'Bạn đã quen với việc viết nhật ký chưa?';
  static const continueLabel = 'Tiếp tục';
  static const skipLabel = 'Để sau';

  static const mascotAsset =
      'assets/Deimage/Nudaeng quàng khăn-transparent.png';

  @override
  State<OnboardingExperienceScreen> createState() =>
      _OnboardingExperienceScreenState();
}

class _OnboardingExperienceScreenState
    extends State<OnboardingExperienceScreen> {
  // "Để sau" is not a card, so it is never shown as selected.
  late JournalingExperience? _experience =
      widget.initialExperience == JournalingExperience.unknown
          ? null
          : widget.initialExperience;

  void _select(JournalingExperience experience) {
    if (experience == _experience) return;
    setState(() => _experience = experience);
    widget.onChanged(experience);
  }

  // Parts appear one after another: top bar, title, the three options,
  // Nudaeng, actions.
  @override
  Widget build(BuildContext context) {
    final experience = _experience;
    return OnboardingStepScaffold(
      step: OnboardingStep.experience,
      onBack: widget.onBack,
      content: Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            StaggerItem(
              order: 1,
              child: Semantics(
                header: true,
                child:
                    const Text(OnboardingExperienceScreen.title, style: _title),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            for (final (i, option) in JournalingExperience.options.indexed) ...[
              if (i > 0) const SizedBox(height: 12),
              StaggerItem(
                order: 2 + i,
                child: OnboardingOptionCard(
                  label: option.label,
                  description: option.description,
                  selected: option == experience,
                  onTap: () => _select(option),
                ),
              ),
            ],
          ],
        ),
      ),
      stage: const StaggerItem(order: 5, child: _Stage()),
      actions: [
        StaggerItem(
          order: 6,
          child: OnboardingCta(
            label: OnboardingExperienceScreen.continueLabel,
            onPressed:
                experience == null ? null : () => widget.onContinue(experience),
          ),
        ),
        StaggerItem(
          order: 6,
          child: OnboardingTextAction(
            label: OnboardingExperienceScreen.skipLabel,
            onPressed: widget.onSkip,
          ),
        ),
      ],
    );
  }
}

const _title = TextStyle(
  fontFamily: 'Nunito',
  fontSize: 28,
  fontWeight: FontWeight.w700,
  height: 1.25,
  color: AppColors.textPrimary,
);

/// Nudaeng in its scarf, sized and placed like every onboarding mascot
/// ([OnboardingMascot]).
class _Stage extends StatelessWidget {
  const _Stage();

  /// In the 435×536 cut-out: head top and feet.
  static const _frame = MascotFrame(
    canvas: Size(435, 536),
    headTop: 3,
    feet: Offset(223, 532),
  );

  @override
  Widget build(BuildContext context) {
    final width = _frame.canvas.width *
        OnboardingMascot.figureHeight /
        _frame.figureHeight;
    final decodeWidth =
        (width * MediaQuery.devicePixelRatioOf(context) / 64).ceil() * 64;
    return OnboardingMascot(
      frame: _frame,
      child: Image.asset(
        OnboardingExperienceScreen.mascotAsset,
        cacheWidth: decodeWidth,
        semanticLabel: 'Nudaeng quàng khăn',
      ),
    );
  }
}
