import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import 'package:ai_diary/features/journal/presentation/write_journal_screen.dart';
import '../../journal/data/journal_entry.dart';
import '../../journal/journal_scope.dart';
import 'widgets/journal_card.dart';
import 'widgets/primary_button.dart';
import '../../streak/streak_state.dart';
import '../../profile/profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Local sample prompts until the daily-prompt API is connected.
  static const _prompts = [
    'What do you notice about your mood today?',
    'What is one small thing that brought you joy today?',
    'What would help you feel more at ease right now?',
  ];

  // Mock data; update inside setState when the weekly AI API is connected.
  String weeklyAiInsight =
      'Tuần này bạn có vẻ tìm thấy nhiều niềm vui từ những khởi đầu mới. '
      'Hãy tiếp tục giữ năng lượng tích cực này nhé!';

  int _promptIndex = 0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // The baked-in mascot starts at ~76% of the source image height.
        // Covering the bottom 32% leaves a margin above its head when the
        // centered background is cropped with BoxFit.cover.
        final weekHeight = constraints.maxHeight * 0.32;
        final topInset = MediaQuery.paddingOf(context).top;
        final upperHeight = constraints.maxHeight - weekHeight - topInset - 8;
        final cardGap = upperHeight < 180 ? 4.0 : 20.0;
        // Keep a 200px GIF on regular screens; shrink on short viewports
        // so the card and mascot never overlap or require scrolling.
        final mascotSize =
            math.min(200.0, math.max(0.0, (upperHeight - 68 - cardGap) * 0.5));

        return Scaffold(
          backgroundColor: AppColors.background,
          body: Stack(
            fit: StackFit.expand,
            children: [
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image:
                          AssetImage('assets/images/background_homescreen.png'),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 0,
                left: 20,
                right: 20,
                bottom: weekHeight + 8 + mascotSize,
                child: SafeArea(
                  bottom: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      const SizedBox(height: 20),
                      _buildTopBar(context),
                      SizedBox(height: cardGap),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, cardConstraints) => FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.topCenter,
                            child: SizedBox(
                              width: cardConstraints.maxWidth,
                              child: _buildDailyReflection(context),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: weekHeight,
                child: _buildThisWeek(context),
              ),
              Positioned(
                // Lower the mascot by 20px, slightly overlapping the panel rim.
                bottom: weekHeight - 12,
                left: 0,
                right: 0,
                height: mascotSize,
                child: Align(
                  alignment: Alignment.center,
                  child: SizedBox(
                    width: mascotSize,
                    height: mascotSize,
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: _buildMascot(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.local_fire_department_outlined,
                color: AppColors.primaryDark, size: 22),
            const SizedBox(width: 8),
            ValueListenableBuilder<int>(
              valueListenable: StreakState.shared,
              builder: (context, count, _) => Text(
                '$count day streak',
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
          ]),
        ),
        Semantics(
          label: 'Profile avatar',
          button: true,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ),
            child: const CircleAvatar(
              radius: 24,
              backgroundColor: AppColors.primaryLight,
              child: Icon(Icons.person_outline, color: AppColors.primaryDark),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDailyReflection(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return JournalCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const SizedBox(width: 48),
            Expanded(
              child: Text(
                'Daily Reflection',
                textAlign: TextAlign.center,
                style: textTheme.headlineSmall?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Refresh prompt',
              onPressed: () => setState(() {
                _promptIndex = (_promptIndex + 1) % _prompts.length;
              }),
              icon: const Icon(Icons.refresh_rounded),
              color: AppColors.primaryDark,
            ),
          ]),
          const SizedBox(height: 12),
          Semantics(
            liveRegion: true,
            child: Text(_prompts[_promptIndex],
                style: textTheme.headlineSmall?.copyWith(height: 1.35)),
          ),
          const SizedBox(height: 20),
          PrimaryButton(
            label: 'Reflect ➔',
            onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const WriteJournalScreen(),
                )),
          ),
          const _LatestEntry(),
        ],
      ),
    );
  }

  Widget _buildMascot() {
    return Semantics(
      label: 'Nudaeng, idle',
      excludeSemantics: true,
      child: Container(
        width: 200,
        height: 200,
        color: Colors.transparent,
        child: ColorFiltered(
          // Preserve the existing white-to-alpha filter. It also removes
          // white details inside the mascot, not just its background.
          colorFilter: const ColorFilter.matrix([
            // dart format off
            1, 0, 0, 0, 0,
            0, 1, 0, 0, 0,
            0, 0, 1, 0, 0,
            -4.252, -14.304, -1.444, 20, 0,
            // dart format on
          ]),
          child: Image.asset(
            'assets/images/laixe.gif',
            width: 200,
            height: 200,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }

  Widget _buildThisWeek(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: LayoutBuilder(
          builder: (context, constraints) => FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: constraints.maxWidth,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('This Week', style: textTheme.titleLarge),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 24,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          const Icon(Icons.auto_awesome,
                              size: 16, color: AppColors.primaryDark),
                          const SizedBox(width: 6),
                          Text('AI Insight',
                              style: textTheme.labelSmall?.copyWith(
                                color: AppColors.primaryDark,
                                fontWeight: FontWeight.bold,
                              )),
                        ]),
                        const SizedBox(height: 12),
                        Text(weeklyAiInsight,
                            style: textTheme.bodyLarge?.copyWith(
                              color: AppColors.textPrimary,
                              fontSize: 18,
                              height: 1.5,
                            )),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The newest saved entry, if any, to open again in the editor. Hidden until
/// there is one, so Home looks as before for a new user.
class _LatestEntry extends StatelessWidget {
  const _LatestEntry();

  @override
  Widget build(BuildContext context) {
    final journals = JournalScope.of(context);
    return ListenableBuilder(
      listenable: journals,
      builder: (context, _) => FutureBuilder<List<JournalEntry>>(
        future: journals.entries(),
        builder: (context, snapshot) {
          final entries = snapshot.data;
          if (entries == null || entries.isEmpty) {
            return const SizedBox.shrink();
          }
          final latest = entries.first;
          final textTheme = Theme.of(context).textTheme;
          return Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Material(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => WriteJournalScreen(entry: latest)),
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 56),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(children: [
                      const Icon(Icons.history_edu_outlined,
                          color: AppColors.primaryAction),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Nhật ký gần nhất',
                                style: textTheme.labelMedium?.copyWith(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w600)),
                            Text(
                              latest.body.split('\n').first,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.bodyMedium
                                  ?.copyWith(color: AppColors.textPrimary),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded,
                          color: AppColors.textPrimary),
                    ]),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
