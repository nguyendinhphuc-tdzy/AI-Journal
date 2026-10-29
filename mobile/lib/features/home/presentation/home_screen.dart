import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/data/app_data.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/widgets/app_ui.dart';
import '../../journal/data/journal_entry.dart';
import '../../journal/journal_scope.dart';
import '../../journal/presentation/journal_list_screen.dart';
import '../../journal/data/saved_quotes.dart';
import '../../journal/presentation/kept_analysis_chip.dart';
import '../../journal/presentation/write_journal_screen.dart';
import '../../insights/presentation/emotion_week_screen.dart';
import '../../onboarding/data/onboarding_scope.dart';
import '../../profile/profile_screen.dart';
import '../../streak/streak_state.dart';
import '../data/home_scene_settings.dart';
import 'widgets/home_scene_hero.dart';

/// H01: the Home tab.
///
/// - A large scene at the top ([HomeSceneHero]): Nudaeng riding through the
///   street chosen in the profile, with its effect. Over its sky: the
///   greeting with the nickname and today's date (streak and profile on
///   the right), "Khoảnh khắc suy ngẫm", the day's prompt, a new prompt and
///   "Cùng suy ngẫm" (J01) as the only primary action.
/// - Below, on the page background, as sections of cards:
///   - "Nhật ký của bạn" (once there is an entry): the latest few, and
///     every entry in [JournalListScreen];
///   - "Tuần này": the week's days with an entry, how much was written and
///     the AI suggestion;
///   - "Đã lưu" (once something is): the newest quote or reflection kept,
///     the rest in [SavedItemsScreen].
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  static const reflectionTitle = 'Một chút cho bản thân';
  static const startLabel = 'Viết nhật ký';
  static const latestTitle = 'Nhật ký gần đây';
  static const weekTitle = 'Nhìn lại tuần này';
  static const weekOpen = 'Xem cảm xúc tuần này';

  /// A saved reflection, in "Đã lưu".
  static const savedReflectionLabel = 'Nhìn lại hôm nay';
  static const savedTitle = 'Đã lưu';

  /// Entries shown on Home; the rest are one tap away.
  static const recentCount = 3;
  static const insightLabel = 'Góc nhìn từ AI';
  static const nextPromptTooltip = 'Đổi gợi ý';
  static const profileTooltip = 'Hồ sơ';

  static String greeting(String? nickname) {
    final name = nickname?.trim();
    return name == null || name.isEmpty ? 'Chào bạn' : 'Chào $name';
  }

  static const _weekdays = [
    'Thứ Hai',
    'Thứ Ba',
    'Thứ Tư',
    'Thứ Năm',
    'Thứ Sáu',
    'Thứ Bảy',
    'Chủ Nhật',
  ];

  /// "Thứ Hai, 26/10/2026".
  static String formatDate(DateTime date) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${_weekdays[date.weekday - 1]}, '
        '${two(date.day)}/${two(date.month)}/${date.year}';
  }

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Local sample prompts until the daily-prompt API is connected.
  static const _prompts = [
    'Hôm nay bạn cảm thấy thế nào?',
    'Điều nhỏ bé nào đã mang lại niềm vui cho bạn hôm nay?',
    'Ngay lúc này, điều gì có thể giúp bạn thấy nhẹ lòng hơn?',
  ];

  int _promptIndex = 0;
  String? _nickname;
  HomeScene _scene = HomeScene.street;
  SceneEffect _effect = SceneEffect.none;

  @override
  void initState() {
    super.initState();
    _loadNickname();
    _loadScene();
    _loadSavedQuotes();
    HomeSceneSettings.changes.addListener(_loadScene);
  }

  /// The quotes this account kept, back in "Đã lưu" after a restart.
  Future<void> _loadSavedQuotes() async {
    final userId =
        context.getInheritedWidgetOfExactType<OnboardingScope>()?.store.userId;
    try {
      final quotes = await SavedQuotes.open(userId: userId);
      if (mounted && quotes.all().isNotEmpty) quotes.show();
    } catch (_) {}
  }

  @override
  void dispose() {
    HomeSceneSettings.changes.removeListener(_loadScene);
    super.dispose();
  }

  Future<void> _loadScene() async {
    try {
      final settings = await HomeSceneSettings.open();
      if (!mounted) return;
      setState(() {
        _scene = settings.scene;
        _effect = settings.effect;
      });
    } catch (_) {
      // Without settings Home shows the default scene.
    }
  }

  Future<void> _loadNickname() async {
    try {
      final store = await OnboardingScope.storeOf(context);
      if (mounted) setState(() => _nickname = store.nickname);
    } catch (_) {
      // Without settings the greeting stays general.
    }
  }

  Future<void> _openProfile() async {
    await Navigator.push(
        context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
    // The nickname may have changed there.
    if (mounted) _loadNickname();
  }

  void _write() => Navigator.push(
      context, MaterialPageRoute(builder: (_) => const WriteJournalScreen()));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      // The scene runs up under the status bar; its content starts below it.
      body: MediaQuery.removePadding(
        context: context,
        removeTop: true,
        child: ListView(
          key: const PageStorageKey('home-scroll'),
          padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
          children: [
            HomeSceneHero(
              key: const ValueKey('home-reflection'),
              scene: _scene,
              effect: _effect,
              content: Padding(
                padding: EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    MediaQuery.paddingOf(context).top + AppSpacing.md,
                    AppSpacing.lg,
                    0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppPageHeader(
                      title: HomeScreen.greeting(_nickname),
                      subtitle: HomeScreen.formatDate(DateTime.now()),
                      titleStyle: _Journal.greeting,
                      subtitleStyle: _OnSky.subtitle,
                      trailing: [
                        ValueListenableBuilder<int>(
                          valueListenable: StreakState.shared,
                          builder: (context, count, _) => AppPill(
                            icon: Icons.local_fire_department_outlined,
                            label: '$count ngày',
                            semanticLabel: 'Chuỗi $count ngày liên tiếp',
                          ),
                        ),
                        Semantics(
                          container: true,
                          label: 'Ảnh đại diện hồ sơ',
                          button: true,
                          excludeSemantics: true,
                          onTap: _openProfile,
                          child: AppIconAction(
                            icon: Icons.person_outline_rounded,
                            tooltip: HomeScreen.profileTooltip,
                            onPressed: _openProfile,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    _Reflection(
                      prompt: _prompts[_promptIndex],
                      onNextPrompt: () => setState(() =>
                          _promptIndex = (_promptIndex + 1) % _prompts.length),
                      onStart: _write,
                    ),
                  ],
                ),
              ),
            ),
            // The sheet's rounded top (the hero's lip) is its top padding;
            // the first section follows right after it.
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _JournalSections(),
                  ValueListenableBuilder<List<Map<String, dynamic>>>(
                    valueListenable: savedThisWeekItems,
                    builder: (context, items, _) => items.isEmpty
                        ? const SizedBox.shrink()
                        : Column(
                            key: const ValueKey('home-saved'),
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const SizedBox(height: AppSpacing.xl),
                              _JournalHeading(
                                HomeScreen.savedTitle,
                                action: items.length > 1
                                    ? _SeeAll(
                                        key: const ValueKey('home-saved-all'),
                                        count: items.length,
                                        what: 'mục đã lưu',
                                        onTap: () => Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                                builder: (_) =>
                                                    const SavedItemsScreen())),
                                      )
                                    : null,
                              ),
                              const SizedBox(height: 12),
                              _SavedItem(item: items.first),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The day's prompt, with Nudaeng on the illustration panel above it.
/// The day's prompt over the sky: what it is, the question large, then a
/// new question or "Cùng suy ngẫm" (J01).
class _Reflection extends StatelessWidget {
  const _Reflection({
    required this.prompt,
    required this.onNextPrompt,
    required this.onStart,
  });

  final String prompt;
  final VoidCallback onNextPrompt;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(HomeScreen.reflectionTitle, style: _OnSky.eyebrow),
          const SizedBox(height: AppSpacing.sm),
          Semantics(
            liveRegion: true,
            child: Text(prompt, style: _Journal.prompt),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(children: [
            AppIconAction(
              icon: Icons.refresh_rounded,
              tooltip: HomeScreen.nextPromptTooltip,
              onPressed: onNextPrompt,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppPrimaryButton(
                  label: HomeScreen.startLabel, onPressed: onStart),
            ),
          ]),
        ],
      );
}

/// Text over the scene's sky: the primary text colour, since the secondary
/// one falls short of 4.5:1 on it.
abstract final class _OnSky {
  static const subtitle = _Journal.day;
  static const eyebrow = _Journal.day;
}

/// Home's type: Be Vietnam Pro, as the rest of the app reads. Large over
/// the sky (the greeting and the day's prompt), plainer in the sections.
abstract final class _Journal {
  static const greeting = TextStyle(
    fontFamily: 'BeVietnamPro',
    fontSize: 26,
    fontWeight: FontWeight.w600,
    height: 1.25,
    color: AppColors.textPrimary,
  );
  static const prompt = TextStyle(
    fontFamily: 'BeVietnamPro',
    fontSize: 23,
    fontWeight: FontWeight.w600,
    height: 1.35,
    color: AppColors.textPrimary,
  );
  static const heading = TextStyle(
    fontFamily: 'BeVietnamPro',
    fontSize: 19,
    fontWeight: FontWeight.w600,
    height: 1.3,
    color: AppColors.textPrimary,
  );
  static const day = TextStyle(
    fontFamily: 'BeVietnamPro',
    fontSize: 14,
    height: 20 / 14,
    color: AppColors.textPrimary,
  );
  static final soft = day.copyWith(color: AppColors.textSecondary);
  static const title = TextStyle(
    fontFamily: 'BeVietnamPro',
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.4,
    color: AppColors.textPrimary,
  );
  static const preview = TextStyle(
    fontFamily: 'BeVietnamPro',
    fontSize: 15,
    height: 1.5,
    color: AppColors.textPrimary,
  );
}

/// A section's title on the left, marked by a short bar in the action
/// colour (as the prompt in the editor), with its link to everything on
/// the right when there is more than the section shows.
class _JournalHeading extends StatelessWidget {
  const _JournalHeading(this.title, {this.action});

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(
          child: Semantics(
            header: true,
            child: IntrinsicHeight(
              // The bar as tall as the title.
              child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const DecoratedBox(
                      key: ValueKey('home-heading-bar'),
                      decoration: BoxDecoration(
                        color: AppColors.primaryAction,
                        borderRadius: BorderRadius.all(Radius.circular(2)),
                      ),
                      child: SizedBox(width: 4),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(title, style: _Journal.heading)),
                  ]),
            ),
          ),
        ),
        if (action != null) action!,
      ]);
}

/// "Nhật ký của bạn" (once there is an entry) and "Tuần này", both read
/// from the saved entries.
class _JournalSections extends StatelessWidget {
  const _JournalSections();

  @override
  Widget build(BuildContext context) {
    final journals = JournalScope.of(context);
    return ListenableBuilder(
      listenable: journals,
      builder: (context, _) => FutureBuilder<List<JournalEntry>>(
        future: journals.entries(),
        builder: (context, snapshot) {
          final entries = snapshot.data ?? const <JournalEntry>[];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (entries.isNotEmpty) ...[
                _JournalHeading(
                  HomeScreen.latestTitle,
                  action: _SeeAll(
                    key: const ValueKey('home-journal-all'),
                    count: entries.length,
                    what: 'nhật ký',
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const JournalListScreen())),
                  ),
                ),
                const SizedBox(height: 12),
                _RecentEntries(entries: entries),
                const SizedBox(height: AppSpacing.xl),
              ],
              Column(
                key: const ValueKey('this-week-panel'),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _JournalHeading(HomeScreen.weekTitle),
                  const SizedBox(height: 12),
                  _ThisWeek(entries: entries),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The latest [HomeScreen.recentCount] entries in one card, each to open
/// again in the editor: the day and mood, the first line as its title and
/// a glimpse of the rest.
class _RecentEntries extends StatelessWidget {
  const _RecentEntries({required this.entries});

  final List<JournalEntry> entries;

  @override
  Widget build(BuildContext context) {
    final recent = entries.take(HomeScreen.recentCount).toList();
    return _JournalCard(
      padding: EdgeInsets.zero,
      child: Column(children: [
        for (final (index, entry) in recent.indexed) ...[
          if (index > 0)
            const Divider(
                height: 1,
                indent: AppSpacing.lg,
                endIndent: AppSpacing.lg,
                color: AppColors.border),
          KeyedSubtree(
            // The newest one, as before ("Nhật ký gần nhất").
            key: index == 0
                ? const ValueKey('home-latest-entry')
                : ValueKey('home-entry-${entry.id}'),
            child: _entryRow(context, entry),
          ),
        ],
      ]),
    );
  }

  Widget _entryRow(BuildContext context, JournalEntry entry) {
    final (title, rest) = JournalListScreen.summary(entry);
    final (day, time) = _when(entry.createdAt);
    final mood = entry.content.mood;
    return InkWell(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => WriteJournalScreen(entry: entry))),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Expanded(
                child: Text.rich(TextSpan(children: [
                  TextSpan(text: day, style: _Journal.day),
                  TextSpan(text: '   $time', style: _Journal.soft),
                ])),
              ),
              if (mood != null) Text(mood.label, style: _Journal.soft),
            ]),
            const SizedBox(height: 6),
            Text(title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _Journal.title),
            if (rest.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(rest,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _Journal.preview
                      .copyWith(color: AppColors.textSecondary)),
            ],
            // The AI analysis kept for it, to read again.
            KeptAnalysisChip(
                entry: entry, padding: const EdgeInsets.only(top: 8)),
          ],
        ),
      ),
    );
  }

  /// "Hôm nay", "Hôm qua" or the weekday, and the date and time.
  static (String, String) _when(DateTime at) {
    final t = at.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    final now = DateTime.now();
    final days = DateTime(now.year, now.month, now.day)
        .difference(DateTime(t.year, t.month, t.day))
        .inDays;
    final day = switch (days) {
      0 => 'Hôm nay',
      1 => 'Hôm qua',
      _ => HomeScreen._weekdays[t.weekday - 1],
    };
    return (
      day,
      '${two(t.day)}/${two(t.month)} · ${two(t.hour)}:${two(t.minute)}'
    );
  }
}

/// "Xem tất cả (N)" beside a section's title: to everything in it. Read
/// out with what it lists ([what]).
class _SeeAll extends StatelessWidget {
  const _SeeAll(
      {super.key,
      required this.count,
      required this.what,
      required this.onTap});

  final int count;
  final String what;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: 'Xem tất cả $what, $count mục',
        excludeSemantics: true,
        child: TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primaryAction,
            minimumSize: const Size(48, 48),
            padding: const EdgeInsets.only(left: 12, right: 4),
            textStyle: AppText.meta.copyWith(fontWeight: FontWeight.w600),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text('Xem tất cả ($count)'),
            const Icon(Icons.chevron_right_rounded, size: 20),
          ]),
        ),
      );
}

/// A page-like card: white, softly lifted, no outline, large corners. Its
/// rows can be tapped one by one (their ink stays inside the corners).
class _JournalCard extends StatelessWidget {
  const _JournalCard({
    required this.child,
    this.onTap,
    this.color = AppColors.surface,
    this.padding = const EdgeInsets.fromLTRB(
        AppSpacing.lg, 18, AppSpacing.lg, AppSpacing.lg),
  });

  final Widget child;

  /// The whole card opens something, when given.
  final VoidCallback? onTap;
  final Color color;
  final EdgeInsetsGeometry padding;

  static const _radius = BorderRadius.all(Radius.circular(AppRadius.modal));

  @override
  Widget build(BuildContext context) => Semantics(
        container: true,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: color,
            borderRadius: _radius,
            boxShadow: const [
              BoxShadow(
                color: Color(0x0F1F201C),
                blurRadius: 16,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Material(
            type: MaterialType.transparency,
            borderRadius: _radius,
            clipBehavior: Clip.antiAlias,
            child: onTap == null
                ? Padding(padding: padding, child: child)
                : InkWell(
                    onTap: onTap,
                    child: Padding(padding: padding, child: child),
                  ),
          ),
        ),
      );
}

/// The week so far (Monday first): a dot for each day with an entry and how
/// much was written. No "Góc nhìn từ AI" here until the backend writes a
/// real one for the week: a fixed text under that label would be a fake AI
/// reading of what the user wrote.
class _ThisWeek extends StatelessWidget {
  const _ThisWeek({required this.entries});

  final List<JournalEntry> entries;

  static const _days = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final monday = today.subtract(Duration(days: today.weekday - 1));
    final week = [
      for (final entry in entries)
        if (_day(entry.createdAt)
                .isAfter(monday.subtract(const Duration(days: 1))) &&
            !_day(entry.createdAt).isAfter(today))
          entry,
    ];
    final written = {for (final entry in week) _day(entry.createdAt)};
    return _JournalCard(
      color: AppColors.primaryLight,
      // The week's feelings in full.
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => const EmotionWeekScreen())),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            for (var i = 0; i < 7; i++)
              Expanded(
                child: _DayDot(
                  label: _days[i],
                  name: HomeScreen._weekdays[i],
                  written: written.contains(monday.add(Duration(days: i))),
                  today: i == today.weekday - 1,
                  future: i > today.weekday - 1,
                ),
              ),
          ]),
          const SizedBox(height: AppSpacing.md),
          Text(
            week.isEmpty
                ? 'Tuần này bạn chưa viết bài nào.'
                : '${week.length} bài viết · ${written.length} ngày có viết',
            key: const ValueKey('this-week-summary'),
            style: _Journal.day.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.md),
          const Divider(height: 1, color: AppColors.softAccent),
          const SizedBox(height: 12),
          Row(children: [
            const Icon(Icons.show_chart_rounded,
                size: 20, color: AppColors.primaryAction),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(HomeScreen.weekOpen,
                  style: _Journal.day.copyWith(
                      color: AppColors.primaryAction,
                      fontWeight: FontWeight.w600)),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.primaryAction),
          ]),
        ],
      ),
    );
  }

  static DateTime _day(DateTime at) {
    final t = at.toLocal();
    return DateTime(t.year, t.month, t.day);
  }
}

/// One day of the week: filled when written, ringed when today, faint
/// when still ahead.
class _DayDot extends StatelessWidget {
  const _DayDot({
    required this.label,
    required this.name,
    required this.written,
    required this.today,
    required this.future,
  });

  final String label;
  final String name;
  final bool written;
  final bool today;
  final bool future;

  @override
  Widget build(BuildContext context) => Semantics(
        label: [
          name,
          if (today) 'hôm nay',
          written ? 'đã viết' : (future ? 'chưa tới' : 'chưa viết'),
        ].join(', '),
        excludeSemantics: true,
        child: Opacity(
          opacity: future ? .45 : 1,
          child: Column(children: [
            Text(label,
                style: _Journal.soft.copyWith(
                    fontSize: 14,
                    color: today
                        ? AppColors.primaryAction
                        : AppColors.textSecondary)),
            const SizedBox(height: 6),
            Container(
              key: written ? const ValueKey('this-week-written') : null,
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: written ? AppColors.primaryAction : AppColors.surface,
                border: Border.all(
                  color: today || written
                      ? AppColors.primaryAction
                      : AppColors.softAccent,
                  width: today ? 2 : 1,
                ),
              ),
              child: written
                  ? const Icon(Icons.check_rounded,
                      size: 16, color: AppColors.surface)
                  : null,
            ),
          ]),
        ),
      );
}

/// A small line above a card's words: what it is and when, with an icon.
class _JournalEyebrow extends StatelessWidget {
  const _JournalEyebrow(this.text, {required this.icon});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    const color = AppColors.textSecondary;
    return Row(children: [
      Icon(icon, size: 18, color: color),
      const SizedBox(width: AppSpacing.sm),
      Flexible(child: Text(text, style: _Journal.soft.copyWith(color: color))),
    ]);
  }
}

/// A reflection or quote that was saved, with what can be done with it.
class _SavedItem extends StatelessWidget {
  const _SavedItem({required this.item});

  final Map<String, dynamic> item;

  bool get _quote => item['type'] == 'quote';

  void _unsave(BuildContext context) {
    savedThisWeekItems.value =
        List<Map<String, dynamic>>.from(savedThisWeekItems.value)..remove(item);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_quote ? 'Đã bỏ lưu trích dẫn' : 'Đã bỏ lưu phân tích')));
    if (_quote) {
      // Let go for good, not only until the next start.
      _forget(context
          .getInheritedWidgetOfExactType<OnboardingScope>()
          ?.store
          .userId);
    }
  }

  Future<void> _forget(String? userId) async {
    try {
      await (await SavedQuotes.open(userId: userId))
          .remove(item['content'] as String? ?? '');
    } catch (_) {}
  }

  Future<void> _copy(BuildContext context) async {
    final content = item['content'] as String? ?? '';
    final text = _quote
        ? '$content (${item['author'] ?? ''})'
        : '${item['title'] ?? HomeScreen.insightLabel}\n$content';
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Đã sao chép')));
  }

  /// "Thêm lựa chọn": copy or unsave, in the app's sheet.
  Future<void> _showActions(BuildContext context) async {
    final action = await showAppSheet<String>(
      context,
      builder: (sheet) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
              _quote
                  ? 'Trích dẫn'
                  : item['title'] as String? ?? HomeScreen.insightLabel,
              style: AppText.sectionTitle),
          const SizedBox(height: AppSpacing.md),
          _SheetAction(
            icon: Icons.copy_rounded,
            label: 'Sao chép',
            onTap: () => Navigator.pop(sheet, 'copy'),
          ),
          const SizedBox(height: AppSpacing.sm),
          _SheetAction(
            icon: Icons.bookmark_remove_outlined,
            label: 'Bỏ lưu',
            onTap: () => Navigator.pop(sheet, 'unsave'),
          ),
        ],
      ),
    );
    if (!context.mounted) return;
    switch (action) {
      case 'copy':
        await _copy(context);
      case 'unsave':
        _unsave(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final quote = _quote;
    final rawDate = item['date'] as String? ?? 'Hôm nay';
    final dateLabel = rawDate == 'Today' ? 'Hôm nay' : rawDate;
    final timestamp = item['timestamp'] as String? ?? '';
    return _JournalCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: _JournalEyebrow(
                  [
                    quote ? 'Trích dẫn' : HomeScreen.savedReflectionLabel,
                    dateLabel,
                    if (timestamp.isNotEmpty) timestamp,
                  ].join(' · '),
                  icon: quote
                      ? Icons.format_quote_rounded
                      : Icons.edit_note_rounded),
            ),
            IconButton(
              tooltip: 'Thêm lựa chọn',
              onPressed: () => _showActions(context),
              icon: const Icon(Icons.more_horiz,
                  size: 22, color: AppColors.textSecondary),
            ),
          ]),
          const SizedBox(height: AppSpacing.xs),
          if (!quote) ...[
            Text(item['title'] as String? ?? HomeScreen.insightLabel,
                style: _Journal.title),
            const SizedBox(height: 6),
          ],
          Text(item['content'] as String? ?? '', style: _Journal.preview),
          if (quote)
            Row(children: [
              Expanded(
                  child:
                      Text('– ${item['author'] ?? ''}', style: _Journal.soft)),
              IconButton(
                tooltip: 'Bỏ lưu trích dẫn',
                icon: const Icon(Icons.bookmark,
                    size: 20, color: AppColors.primaryAction),
                onPressed: () => _unsave(context),
              ),
            ])
          else if (item['mood'] != null) ...[
            const SizedBox(height: 12),
            Text('${item['moodIcon'] ?? '😕'}  ${item['mood']}',
                style: _Journal.day),
          ],
        ],
      ),
    );
  }
}

/// One action in a sheet: a rounded row with its icon.
class _SheetAction extends StatelessWidget {
  const _SheetAction(
      {required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: AppColors.background,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(AppRadius.input))),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Row(children: [
                Icon(icon, color: AppColors.primaryAction),
                const SizedBox(width: AppSpacing.md),
                Expanded(child: Text(label, style: AppText.body)),
              ]),
            ),
          ),
        ),
      );
}

/// Everything saved from reflections, newest first.
class SavedItemsScreen extends StatelessWidget {
  const SavedItemsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ValueListenableBuilder<List<Map<String, dynamic>>>(
          valueListenable: savedThisWeekItems,
          builder: (context, items, _) => Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 12),
              child: AppPageHeader(
                title: HomeScreen.savedTitle,
                subtitle: items.isEmpty
                    ? 'Chưa có mục nào'
                    : '${items.length} trích dẫn và phân tích',
                trailing: [
                  AppIconAction(
                    icon: Icons.close_rounded,
                    tooltip: 'Đóng',
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.border),
            Expanded(
              child: items.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(AppSpacing.xl),
                        child: Text(
                            'Bấm Lưu ở một trích dẫn sau khi viết để giữ lại ở đây.',
                            textAlign: TextAlign.center,
                            style: AppText.bodySecondary),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(AppSpacing.lg,
                          AppSpacing.lg, AppSpacing.lg, AppSpacing.xxl),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (_, index) => _SavedItem(item: items[index]),
                    ),
            ),
          ]),
        ),
      ),
    );
  }
}
