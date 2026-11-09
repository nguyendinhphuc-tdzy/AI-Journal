import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../data/build_features.dart';
import '../data/onboarding_store.dart';
import 'onboarding_widgets.dart';

/// One OB05 card: what the user can do, shown only if the build has it.
class FeatureCard {
  const FeatureCard(this.icon, this.title, this.body,
      {required this.available});

  final IconData icon;
  final String title;
  final String body;
  final bool available;
}

/// OB05: what the user can do in the app. Three short, read-only cards in
/// one outline icon set; nothing advances on its own (no timer, no
/// carousel). "Xem cách hoạt động" → OB06; Back → OB04.
///
/// The AI card says what is true for this user: on for an account
/// ([aiAvailable]), after signing in for a guest.
class OnboardingFeaturesScreen extends StatelessWidget {
  const OnboardingFeaturesScreen({
    super.key,
    required this.onBack,
    required this.onContinue,
    this.aiAvailable = true,
  });

  final VoidCallback onBack;
  final VoidCallback onContinue;
  final bool aiAvailable;

  static const title = 'Bạn có thể bắt đầu từ vài dòng.';
  static const continueLabel = 'Xem cách hoạt động';
  static const more =
      'Bạn cũng có thể tìm cách viết trong Study và gắn kỷ niệm với địa điểm '
      'khi muốn.';

  static const cards = [
    FeatureCard(
      Icons.lightbulb_outline_rounded,
      'Gợi ý để bắt đầu',
      'Một câu hỏi nhỏ giúp bạn tìm điều muốn viết.',
      available: BuildFeatures.writingPrompts,
    ),
    FeatureCard(
      Icons.chat_bubble_outline_rounded,
      'Phản hồi AI cho nhật ký',
      'Một góc nhìn gợi mở và những câu hỏi giúp bạn hiểu mình hơn.',
      available: BuildFeatures.aiReflection,
    ),
    FeatureCard(
      Icons.photo_library_outlined,
      'Giữ lại những điều đáng nhớ',
      'Lưu ảnh và ghi chú trong Album riêng của bạn.',
      available: BuildFeatures.album,
    ),
  ];

  /// The AI card for a guest: no AI until signing in.
  static const guestAiCard = FeatureCard(
    Icons.chat_bubble_outline_rounded,
    'Phản hồi AI khi đăng nhập',
    'Đăng nhập để nhận góc nhìn gợi mở và câu hỏi từ AI cho nhật ký.',
    available: BuildFeatures.aiReflection,
  );

  /// Only when both modules are in the build.
  static const showMore = BuildFeatures.study && BuildFeatures.places;

  static const mascotAsset =
      'assets/Deimage/Nudaeng xem hướng dẫn-transparent.png';

  // Parts appear one after another: top bar, title, cards, the extra line,
  // Nudaeng, CTA.
  @override
  Widget build(BuildContext context) {
    final shown = [
      for (final card in cards)
        if (card.available) aiAvailable || card != cards[1] ? card : guestAiCard
    ];
    return OnboardingStepScaffold(
      step: OnboardingStep.features,
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
            // 16 and a 14 px body (not 24 / 15): leaves room for Nudaeng
            // on 390×844.
            const SizedBox(height: AppSpacing.md),
            for (final (i, card) in shown.indexed) ...[
              if (i > 0) const SizedBox(height: 12),
              StaggerItem(order: 2 + i, child: _Card(card)),
            ],
            if (showMore) ...[
              const SizedBox(height: AppSpacing.md),
              const StaggerItem(order: 5, child: Text(more, style: _Text.more)),
            ],
          ],
        ),
      ),
      stage: const StaggerItem(order: 6, child: _Stage()),
      actions: [
        StaggerItem(
          order: 7,
          child: OnboardingCta(label: continueLabel, onPressed: onContinue),
        ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card(this.card);

  final FeatureCard card;

  @override
  Widget build(BuildContext context) => MergeSemantics(
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: AppColors.primaryLight,
                  shape: BoxShape.circle,
                ),
                child: ExcludeSemantics(
                  child:
                      Icon(card.icon, size: 22, color: AppColors.primaryAction),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(card.title, style: _Text.cardTitle),
                    const SizedBox(height: 2),
                    Text(card.body, style: _Text.cardBody),
                  ],
                ),
              ),
            ],
          ),
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
  static const cardTitle = TextStyle(
    fontFamily: 'BeVietnamPro',
    fontSize: 17,
    fontWeight: FontWeight.w600,
    height: 24 / 17,
    color: AppColors.textPrimary,
  );
  static const cardBody = TextStyle(
    fontFamily: 'BeVietnamPro',
    fontSize: 14,
    height: 20 / 14,
    color: AppColors.textSecondary,
  );
  static const more = TextStyle(
    fontFamily: 'BeVietnamPro',
    fontSize: 14,
    height: 20 / 14,
    color: AppColors.textSecondary,
  );
}

/// Nudaeng at its desk, checking the guide, placed like every onboarding
/// mascot ([OnboardingMascot]). Seated, so the whole scene is 120 high: that
/// keeps the head the same size as the standing poses at 96.
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
        OnboardingFeaturesScreen.mascotAsset,
        cacheWidth: decodeWidth,
        semanticLabel: 'Nudaeng ngồi bàn xem hướng dẫn trên điện thoại',
      ),
    );
  }
}
