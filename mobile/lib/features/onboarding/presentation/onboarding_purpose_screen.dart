import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../data/journal_goal.dart';
import '../data/onboarding_store.dart';
import 'onboarding_widgets.dart';

/// OB03: why the user wants to journal. Single choice; picking an option only
/// updates the selection (no auto-next). "Tiếp tục" is enabled once something
/// is picked; "Để sau" moves on with no goal. "Một lý do khác" asks for no
/// free text in this version.
class OnboardingPurposeScreen extends StatefulWidget {
  const OnboardingPurposeScreen({
    super.key,
    required this.nickname,
    required this.initialGoal,
    required this.onChanged,
    required this.onBack,
    required this.onContinue,
    required this.onSkip,
  });

  /// Saved OB02 nickname; null means "bạn".
  final String? nickname;
  final JournalGoal? initialGoal;
  final ValueChanged<JournalGoal> onChanged;
  final VoidCallback onBack;
  final ValueChanged<JournalGoal> onContinue;
  final VoidCallback onSkip;

  static String eyebrow(String? nickname) =>
      'Rất vui được gặp ${nickname ?? 'bạn'}.';
  static const title = 'Bạn muốn bắt đầu viết vì điều gì?';
  static const helper = 'Chọn điều gần với bạn nhất. Bạn có thể đổi sau.';
  static const continueLabel = 'Tiếp tục';
  static const skipLabel = 'Để sau';

  static const mascotAsset = 'assets/Deimage/Nudaeng gãy đàn.png';

  @override
  State<OnboardingPurposeScreen> createState() =>
      _OnboardingPurposeScreenState();
}

class _OnboardingPurposeScreenState extends State<OnboardingPurposeScreen> {
  late JournalGoal? _goal = widget.initialGoal;

  void _select(JournalGoal goal) {
    if (goal == _goal) return;
    setState(() => _goal = goal);
    widget.onChanged(goal);
  }

  // Parts appear one after another: top bar, eyebrow, title, helper, the
  // five options, Nudaeng, actions.
  @override
  Widget build(BuildContext context) {
    final goal = _goal;
    return OnboardingStepScaffold(
      step: OnboardingStep.purpose,
      onBack: widget.onBack,
      content: Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            StaggerItem(
              order: 1,
              child: Text(OnboardingPurposeScreen.eyebrow(widget.nickname),
                  style: _Text.eyebrow),
            ),
            const SizedBox(height: AppSpacing.sm),
            StaggerItem(
              order: 2,
              child: Semantics(
                header: true,
                child: const Text(OnboardingPurposeScreen.title,
                    style: _Text.title),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            const StaggerItem(
              order: 3,
              child: Text(OnboardingPurposeScreen.helper, style: _Text.helper),
            ),
            // 16, not 24: leaves room for Nudaeng under the list on 430×932.
            const SizedBox(height: AppSpacing.md),
            for (final option in JournalGoal.values) ...[
              if (option.index > 0) const SizedBox(height: 12),
              StaggerItem(
                order: 4 + option.index,
                child: OnboardingOptionCard(
                  label: option.label,
                  selected: option == goal,
                  onTap: () => _select(option),
                ),
              ),
            ],
          ],
        ),
      ),
      stage: const StaggerItem(order: 9, child: _Stage()),
      actions: [
        StaggerItem(
          order: 10,
          child: OnboardingCta(
            label: OnboardingPurposeScreen.continueLabel,
            onPressed: goal == null ? null : () => widget.onContinue(goal),
          ),
        ),
        StaggerItem(
          order: 10,
          child: OnboardingTextAction(
            label: OnboardingPurposeScreen.skipLabel,
            onPressed: widget.onSkip,
          ),
        ),
      ],
    );
  }
}

abstract final class _Text {
  static const eyebrow = TextStyle(
    fontFamily: 'BeVietnamPro',
    fontSize: 16,
    height: 1.5,
    color: AppColors.textSecondary,
  );
  static const title = TextStyle(
    fontFamily: 'Nunito',
    fontSize: 28,
    fontWeight: FontWeight.w700,
    height: 1.25,
    color: AppColors.textPrimary,
  );
  static const helper = TextStyle(
    fontFamily: 'BeVietnamPro',
    fontSize: 14,
    height: 20 / 14,
    color: AppColors.textSecondary,
  );
}

/// Nudaeng with the guitar under the list, sized and placed like every
/// onboarding mascot ([OnboardingMascot]); hidden when the list needs the
/// room.
class _Stage extends StatelessWidget {
  const _Stage();

  /// In the 1254 px image: head top and feet.
  static const _frame = MascotFrame(
    canvas: Size(1254, 1254),
    headTop: 92,
    feet: Offset(600, 1194),
  );

  @override
  Widget build(BuildContext context) {
    // Decoded at display size; the source is 1254 px.
    final side = _frame.canvas.width *
        OnboardingMascot.figureHeight /
        _frame.figureHeight;
    final decodeWidth =
        (side * MediaQuery.devicePixelRatioOf(context) / 64).ceil() * 64;
    return OnboardingMascot(
      frame: _frame,
      child: Image.asset(
        OnboardingPurposeScreen.mascotAsset,
        cacheWidth: decodeWidth,
        semanticLabel: 'Nudaeng ôm đàn',
      ),
    );
  }
}
