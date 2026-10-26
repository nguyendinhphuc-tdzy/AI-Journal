import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../data/data_policy.dart';
import '../data/onboarding_store.dart';
import 'onboarding_widgets.dart';

/// OB06: how AI and data work, and the user's choice, before anything is
/// sent. Two explicit paths and no pre-set toggle: "Tiếp tục với AI" or
/// "Chỉ viết nhật ký". Nothing is sent to AI from this screen.
///
/// The copy comes from [DataPolicy]; while it is not approved the screen
/// says it is a demo build with simulated AI.
class OnboardingAiDataScreen extends StatelessWidget {
  const OnboardingAiDataScreen({
    super.key,
    this.policy = DataPolicy.current,
    required this.onBack,
    required this.onChoose,
  });

  final DataPolicy policy;
  final VoidCallback onBack;

  /// true: "Tiếp tục với AI"; false: "Chỉ viết nhật ký".
  final ValueChanged<bool> onChoose;

  static const title = 'Bạn chọn cách dùng AI.';
  static const demoLabel = 'Bản thử nghiệm: phản hồi AI là mô phỏng';
  static const realAiLabel = 'Bản thử nghiệm: AI chạy trên máy tính của nhóm';
  static const storageHeading = 'Nhật ký của bạn';
  static const aiHeading = 'Khi yêu cầu phản hồi AI';
  static const choiceHeading = 'Quyền lựa chọn';
  static const withAiLabel = 'Tiếp tục với AI';
  static const journalOnlyLabel = 'Chỉ viết nhật ký';

  static const mascotAsset = 'assets/Deimage/Nudaeng xé-transparent.png';

  // Parts appear one after another: top bar, title, demo label, the three
  // sections, Nudaeng, actions.
  @override
  Widget build(BuildContext context) => OnboardingStepScaffold(
        step: OnboardingStep.aiAndData,
        onBack: onBack,
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
                  child: const Text(title, style: _Text.title),
                ),
              ),
              if (!policy.approved) ...[
                const SizedBox(height: 12),
                StaggerItem(order: 2, child: _DemoLabel(
                  policy.realLocalAi ? realAiLabel : demoLabel,
                )),
              ],
              const SizedBox(height: AppSpacing.md),
              StaggerItem(
                order: 3,
                child: _Sections(sections: [
                  (Icons.menu_book_outlined, storageHeading, policy.storage),
                  (Icons.send_outlined, aiHeading, policy.aiRequest),
                  (Icons.tune_rounded, choiceHeading, DataPolicy.choiceNote),
                ]),
              ),
            ],
          ),
        ),
        stage: const StaggerItem(order: 5, child: _Stage()),
        actions: [
          StaggerItem(
            order: 6,
            child: OnboardingCta(
                label: withAiLabel, onPressed: () => onChoose(true)),
          ),
          StaggerItem(
            order: 6,
            child: OnboardingTextAction(
                label: journalOnlyLabel, onPressed: () => onChoose(false)),
          ),
        ],
      );
}

class _DemoLabel extends StatelessWidget {
  const _DemoLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 12, vertical: AppSpacing.xs + 2),
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(AppRadius.small),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ExcludeSemantics(
                child: Icon(Icons.science_outlined,
                    size: 18, color: AppColors.primaryAction),
              ),
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child:
                    Text(label, style: _Text.label),
              ),
            ],
          ),
        ),
      );
}

/// One Surface card, three sections split by hairlines.
class _Sections extends StatelessWidget {
  const _Sections({required this.sections});

  final List<(IconData, String, String)> sections;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            for (final (i, (icon, heading, body)) in sections.indexed) ...[
              if (i > 0)
                const Divider(height: 1, thickness: 1, color: AppColors.border),
              MergeSemantics(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: ExcludeSemantics(
                          child: Icon(icon,
                              size: 22, color: AppColors.primaryAction),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Semantics(
                              header: true,
                              child: Text(heading, style: _Text.heading),
                            ),
                            const SizedBox(height: 2),
                            Text(body, style: _Text.body),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      );
}

abstract final class _Text {
  static const title = TextStyle(
    fontFamily: 'Nunito',
    fontSize: 28,
    fontWeight: FontWeight.w700,
    height: 1.25,
    color: AppColors.textPrimary,
  );
  static const label = TextStyle(
    fontFamily: 'BeVietnamPro',
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 20 / 14,
    color: AppColors.textPrimary,
  );
  static const heading = TextStyle(
    fontFamily: 'BeVietnamPro',
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.5,
    color: AppColors.textPrimary,
  );
  static const body = TextStyle(
    fontFamily: 'BeVietnamPro',
    fontSize: 16,
    height: 1.5,
    color: AppColors.textSecondary,
  );
}

/// The OB05 desk again, Nudaeng now tearing up a note: same crop, size and
/// spot ([deskScene]), so only the pose changes between the two steps.
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
        OnboardingAiDataScreen.mascotAsset,
        cacheWidth: decodeWidth,
        semanticLabel: 'Nudaeng ngồi bàn xé một mẩu giấy',
      ),
    );
  }
}
