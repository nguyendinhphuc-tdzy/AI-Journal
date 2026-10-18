import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/data/app_data.dart';
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

  int _promptIndex = 0;
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/background_homescreen.png',
              fit: BoxFit.cover,
            ),
          ),
          LayoutBuilder(builder: (context, constraints) {
            return SingleChildScrollView(
              key: const PageStorageKey('home-scroll'),
              controller: _scrollController,
              physics: const ClampingScrollPhysics(),
              child: Column(
                children: [
                  SizedBox(height: 100 + MediaQuery.paddingOf(context).top),
                  AnimatedBuilder(
                    animation: _scrollController,
                    builder: (context, child) {
                      final offset = _scrollController.hasClients
                          ? _scrollController.offset
                          : 0.0;
                      final opacity = (1 - offset / 150).clamp(0.0, 1.0);
                      return IgnorePointer(
                        ignoring: opacity == 0,
                        child: Opacity(
                          key: const ValueKey('home-header-fade'),
                          opacity: opacity,
                          child: child,
                        ),
                      );
                    },
                    child: Column(children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: SizedBox(
                          height: math.max(130.0, constraints.maxHeight * 0.35),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.topCenter,
                            child: SizedBox(
                              width: constraints.maxWidth - 40,
                              child: _buildDailyReflection(context),
                            ),
                          ),
                        ),
                      ),
                      // Reserve 170px for the 200px GIF so the opaque panel
                      // below covers its lower 30px and the baked-in artwork.
                      Align(
                        alignment: Alignment.topCenter,
                        heightFactor: 0.85,
                        child: _buildMascot(),
                      ),
                    ]),
                  ),
                  Container(
                    key: const ValueKey('this-week-panel'),
                    width: double.infinity,
                    padding: const EdgeInsets.only(top: 20),
                    constraints:
                        BoxConstraints(minHeight: constraints.maxHeight),
                    clipBehavior: Clip.antiAlias,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE8F3F1),
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(30)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text('This Week',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 22,
                                  )),
                        ),
                        _buildWeeklyInsight(context),
                        ValueListenableBuilder<List<Map<String, dynamic>>>(
                          valueListenable: savedThisWeekItems,
                          builder: (context, items, _) => Column(
                            key: const ValueKey('this-week-list'),
                            children: [
                              for (final item in items)
                                _buildWeekItem(context, item),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Container(
                key: const ValueKey('home-sticky-top-bar'),
                color: Colors.transparent,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                child: _buildTopBar(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyInsight(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.auto_awesome,
                size: 18, color: AppColors.primaryDark),
            const SizedBox(width: 8),
            Text('AI Insight',
                style: textTheme.titleSmall?.copyWith(
                  color: AppColors.primaryDark,
                  fontWeight: FontWeight.w600,
                )),
          ]),
          const SizedBox(height: 12),
          Text(
            'Tuần này bạn có vẻ tìm thấy nhiều niềm vui từ những khởi đầu mới. '
            'Hãy tiếp tục giữ năng lượng tích cực này nhé!',
            style: textTheme.bodyLarge?.copyWith(
              color: AppColors.textPrimary,
              height: 1.5,
            ),
          ),
        ],
      ),
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
      child: SizedBox(
        width: 200,
        height: 200,
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

  Widget _buildWeekItem(BuildContext context, Map<String, dynamic> item) {
    final textTheme = Theme.of(context).textTheme;
    final quote = item['type'] == 'quote';
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(item['date'] as String? ?? 'Today',
                style: textTheme.labelLarge?.copyWith(color: Colors.black)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(item['timestamp'] as String? ?? '',
                  style: textTheme.bodySmall
                      ?.copyWith(color: AppColors.textSecondary)),
            ),
            const Tooltip(
              message: 'More options (coming soon)',
              child: Icon(Icons.more_horiz, size: 22),
            ),
          ]),
          const SizedBox(height: 16),
          Text(quote ? 'Quote' : 'Daily Reflection',
              style: textTheme.bodySmall
                  ?.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 10),
          if (!quote) ...[
            Text(item['title'] as String? ?? 'AI Insight',
                style: textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
          ],
          Text(item['content'] as String? ?? '',
              style: textTheme.bodyLarge?.copyWith(
                color: AppColors.textPrimary,
                fontSize: 18,
                height: 1.5,
              )),
          const SizedBox(height: 20),
          if (quote)
            Row(children: [
              Expanded(
                  child: Text('-${item['author'] ?? ''}',
                      style: textTheme.bodyMedium)),
              IconButton(
                tooltip: 'Unsave quote',
                icon: const Icon(Icons.bookmark,
                    size: 20, color: AppColors.primaryDark),
                onPressed: () {
                  savedThisWeekItems.value =
                      List<Map<String, dynamic>>.from(savedThisWeekItems.value)
                        ..remove(item);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Quote removed from This Week')),
                  );
                },
              ),
            ])
          else if (item['mood'] != null)
            Text('${item['moodIcon'] ?? '😕'}  ${item['mood']}',
                style:
                    textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
        ],
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
