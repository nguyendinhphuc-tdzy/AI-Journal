import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_ui.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text.dart';
import 'nudaeng_view.dart';
import 'nudaeng_artwork.dart';
import 'study_detail_layout.dart';
import 'study_motion.dart';
import 'study_theme.dart';
import '../data/study_mock_data.dart';
import '../data/study_progress.dart';
import '../../journal/journal_scope.dart';
import '../../journal/presentation/write_journal_screen.dart'
    show JournalPaperView;
import '../../onboarding/data/onboarding_store.dart';
import '../../profile/data/writing_preferences.dart';
import '../../streak/streak_state.dart';

/// Study's catalog is local until its API contract is finalized. Progress
/// is kept on this device ([StudyProgressStore]) and what the user writes
/// goes into the journal ([StudySession]).
class StudyScreen extends StatelessWidget {
  const StudyScreen(
      {super.key, this.progress = const LocalStudyProgressStore()});

  /// Where the challenge, lessons read and drafts are kept.
  final StudyProgressStore progress;

  @override
  Widget build(BuildContext context) =>
      StudyTheme(child: _StudyOverview(progress: progress));
}

class _StudyOverview extends StatefulWidget {
  const _StudyOverview({required this.progress});

  final StudyProgressStore progress;

  @override
  State<_StudyOverview> createState() => _StudyScreenState();
}

class _StudyScreenState extends State<_StudyOverview> {
  String _filter = 'Tất cả';
  final _progress = StudyProgress();
  late final _session = StudySession(taskEntries: _progress.taskEntries)
    ..onChanged = _keep;
  Timer? _keepDrafts;

  /// Something changed before the kept progress arrived: it is not applied
  /// over the user's newer state.
  var _changed = false;

  bool get _joined => _progress.joined;
  set _joined(bool value) => _progress.joined = value;
  bool get _paused => _progress.paused;
  set _paused(bool value) => _progress.paused = value;
  bool get _left => _progress.left;
  set _left(bool value) => _progress.left = value;
  bool get _caseRead => _progress.caseRead;
  set _caseRead(bool value) => _progress.caseRead = value;
  Map<int, String> get _drafts => _progress.drafts;
  Set<int> get _doneTasks => _progress.doneTasks;
  Set<int> get _doneLessons => _progress.doneLessons;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _session.journals = JournalScope.of(context);
  }

  @override
  void dispose() {
    if (_keepDrafts?.isActive ?? false) _keep();
    _keepDrafts?.cancel();
    super.dispose();
  }

  /// The progress kept from before, then the task entries from the journal.
  Future<void> _load() async {
    StudyProgress? kept;
    try {
      kept = await widget.progress.load();
    } catch (_) {
      // Nothing kept can be read: this session starts fresh.
      return;
    }
    if (kept == null || !mounted || _changed) return;
    setState(() => _progress.replaceWith(kept!));
    try {
      await _session.load();
    } catch (_) {
      return;
    }
    if (mounted) setState(() {});
  }

  /// Keeps the progress on this device; if that fails it still holds for
  /// this session.
  void _keep() {
    _changed = true;
    _keepDrafts?.cancel();
    unawaited(widget.progress.save(_progress).catchError((Object _) {}));
  }

  /// Drafts change with every letter: kept once typing pauses.
  void _keepDraftsSoon() {
    _changed = true;
    _keepDrafts?.cancel();
    _keepDrafts = Timer(const Duration(milliseconds: 600), _keep);
  }

  static const _items = <_StudyItem>[
    _StudyItem(
        'Khóa học',
        'Viết điều biết ơn mỗi ngày',
        'Một cách nhẹ nhàng để nhận ra điều đang nâng đỡ bạn.',
        '3 bài · 12 phút',
        course: true,
        practicePrompt: coursePracticePrompt,
        order: 3),
    _StudyItem('Mẫu viết', frameworkTitle,
        'Gỡ rối một suy nghĩ bằng vài bước viết chậm rãi.', '8 phút',
        framework: true, order: 2),
    _StudyItem('Bài đọc', 'Nhìn lại những điều nhỏ đã làm được',
        'Một bài đọc ngắn về cách ghi nhận tiến bộ của chính mình.', '5 phút',
        order: 1),
  ];

  List<_StudyItem> get _visible {
    final result = _items
        .where((item) => _filter == 'Tất cả' || item.type == _filter)
        .toList();
    // Newest first is the only order with real data behind it.
    result.sort((a, b) => b.order.compareTo(a.order));
    return result;
  }

  void _openItem(_StudyItem item) {
    if (item.course || item.framework) {
      // The page-turn plays on every open of a detail, not only the first.
      Navigator.of(context).push(_studyRoute(
          builder: (_) => _CourseScreen(
              item: item,
              session: _session,
              read: _doneLessons,
              onRead: _markRead)));
    } else {
      Navigator.of(context).push(_studyRoute(
          builder: (_) => _ReaderScreen(
              lesson: studyCase,
              session: _session,
              initiallyRead: _caseRead,
              onRead: () {
                setState(() => _caseRead = true);
                _keep();
                return false;
              })));
    }
  }

  void _markRead(int lesson) {
    setState(() => _doneLessons.add(lesson));
    _keep();
  }

  void _openChallenge() {
    final detail = _studyRoute(
      builder: (_) => _ChallengeDetailScreen(
        joined: _joined,
        completed: _doneTasks.length == _prompts.length,
        onJoin: () {
          setState(() {
            _joined = true;
            _paused = false;
          });
          _keep();
        },
        openProgress: _openProgress,
      ),
    );
    if (MediaQuery.disableAnimationsOf(context)) {
      Navigator.of(context).push(detail);
      return;
    }
    // Opening S04 never joins; the hand-off only plays Nudaeng's head tilt.
    Navigator.of(context).push(PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 200),
      reverseTransitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (routeContext, _, __) => StudyTheme(
          child: _ChallengeLoading(
              onFinished: () =>
                  Navigator.of(routeContext).pushReplacement(detail))),
      transitionsBuilder: (_, animation, __, child) =>
          FadeTransition(opacity: animation, child: child),
    ));
  }

  void _openProgress() {
    if (_doneTasks.length == _prompts.length) {
      Navigator.of(context).push(_studyRoute(
          builder: (_) =>
              _ChallengeCompletion(animate: false, session: _session)));
      return;
    }
    Navigator.of(context).push(
      _studyRoute(
        builder: (_) => _ChallengeProgressScreen(
          session: _session,
          done: _doneTasks,
          drafts: _drafts,
          paused: _paused,
          left: _left,
          onLeave: () {
            setState(() {
              _left = true;
              _paused = false;
            });
            _keep();
          },
          onPause: (value) {
            setState(() {
              _paused = value;
              _left = false;
            });
            _keep();
          },
          onComplete: (task) {
            setState(() {
              _joined = true;
              _doneTasks.add(task);
            });
            _keep();
          },
          onDraftsChanged: _keepDraftsSoon,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final active = _joined && !_paused && !_left;
    final courseInProgress = _doneLessons.isNotEmpty && _doneLessons.length < 3;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: StudyEntrance(
            child: ListView(
          key: const PageStorageKey<String>('study-scroll'),
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xxl),
          children: [
            const AppPageHeader(
                title: 'Học tập',
                help: 'Học cách viết qua khóa học, mẫu viết và bài đọc ngắn. '
                    'Khi muốn luyện đều, hãy thử một challenge nhỏ mỗi ngày.'),
            const SizedBox(height: AppSpacing.md),
            _ChallengeBanner(
              active: active,
              paused: _paused,
              left: _left,
              complete: _doneTasks.length,
              secondary: _paused || _left || (!active && courseInProgress),
              onTap:
                  active || _paused || _left ? _openProgress : _openChallenge,
            ),
            if (courseInProgress) ...[
              const SizedBox(height: AppSpacing.xl),
              Text('Tiếp tục học',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.md),
              _ContinueCard(
                  completed: _doneLessons.length,
                  onTap: () => _openItem(_items.first)),
            ],
            const SizedBox(height: AppSpacing.xxl),
            const AppSectionHeader(
                title: 'Khám phá cách viết',
                help: 'Khóa học gồm vài bài nối tiếp nhau. Mẫu viết dẫn bạn '
                    'viết theo từng bước. Bài đọc là một câu chuyện ngắn để '
                    'tham khảo.'),
            const SizedBox(height: AppSpacing.sm),
            _FilterChips(
                selected: _filter,
                onSelected: (value) => setState(() => _filter = value)),
            const SizedBox(height: AppSpacing.md),
            // Results cross-fade on filter change; the banner never replays.
            AnimatedSwitcher(
              duration: StudyMotion.reduced(context)
                  ? StudyMotion.reducedFade
                  : const Duration(milliseconds: 180),
              switchInCurve: StudyMotion.change,
              switchOutCurve: StudyMotion.change,
              child: _visible.isEmpty
                  ? _NoResult(onClear: () => setState(() => _filter = 'Tất cả'))
                  : Column(
                      key: ValueKey<String>(_filter),
                      children: [
                        for (final item in _visible) ...[
                          _ContentCard(
                              item: item, onTap: () => _openItem(item)),
                          const SizedBox(height: 12)
                        ],
                      ],
                    ),
            ),
          ],
        )),
      ),
    );
  }
}

class _ChallengeBanner extends StatelessWidget {
  const _ChallengeBanner(
      {required this.active,
      required this.left,
      required this.paused,
      required this.complete,
      required this.secondary,
      required this.onTap});

  final bool active;
  final bool left;
  final bool paused;
  final int complete;
  final bool secondary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final enrolled = active || paused || left;
    final eyebrow = left
        ? 'Đã rời challenge'
        : active
            ? 'Challenge của bạn'
            : paused
                ? 'Đã tạm dừng'
                : 'Challenge gợi ý';
    final label = complete == _prompts.length
        ? 'Xem kết quả'
        : active
            ? 'Tiếp tục challenge'
            : 'Xem challenge';
    return Container(
      key: const ValueKey('challenge-banner'),
      clipBehavior: Clip.antiAlias,
      decoration: _surface(),
      child: LayoutBuilder(builder: (context, constraints) {
        // Study.jpg is a landscape crop that ends at the dog's chest, so it
        // stands on the bottom edge of a full-width art panel above the copy.
        final compact = constraints.maxWidth < 300 ||
            MediaQuery.textScalerOf(context).scale(16) > 20;
        final artHeight = compact ? 108.0 : 136.0;
        final art = Container(
          height: artHeight + 12,
          color: AppColors.primaryLight,
          alignment: Alignment.bottomCenter,
          child: _Nudaeng(
            // Matches the cutout's 498:359 aspect ratio.
            size: (artHeight * 498 / 359).roundToDouble(),
            height: artHeight,
            label: 'Nudaeng cầm sách',
            artwork: NudaengArtwork.study,
            animate: false,
          ),
        );
        final content = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(eyebrow, style: _meta(context)),
            const SizedBox(height: 4),
            Text(_challengeTitle,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontSize: 18)),
            const SizedBox(height: 6),
            Text(enrolled
                ? '$complete/${_prompts.length} nhiệm vụ đã hoàn thành'
                : 'Mỗi ngày, viết một điều biết ơn.'),
            const SizedBox(height: 6),
            if (enrolled)
              _Progress(value: complete / _prompts.length)
            else
              Text('${_prompts.length} nhiệm vụ', style: _meta(context)),
            const SizedBox(height: 16),
            if (secondary)
              OutlinedButton(
                  style:
                      OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
                  onPressed: onTap,
                  child: Text(label, textAlign: TextAlign.center))
            else
              _PrimaryButton(label: label, onPressed: onTap, height: 48),
          ],
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            art,
            Padding(padding: const EdgeInsets.all(20), child: content),
          ],
        );
      }),
    );
  }
}

/// Short hand-off before S04: Nudaeng holds the book, tilts its head once and
/// settles, then the challenge detail replaces this screen.
class _ChallengeLoading extends StatelessWidget {
  const _ChallengeLoading({required this.onFinished});
  final VoidCallback onFinished;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.surface,
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _Nudaeng(
                // Matches the GIF cutout's 295:309 aspect ratio.
                size: 160,
                height: 168,
                label: 'Nudaeng nghiêng đầu đọc sách',
                artwork: NudaengArtwork.challengeLoading,
                onFinished: onFinished),
            const SizedBox(height: AppSpacing.md),
            Text('Đang mở challenge…', style: _meta(context)),
          ]),
        ),
      );
}

/// Content-type pills that scroll sideways, replacing the filter dropdown.
class _FilterChips extends StatelessWidget {
  const _FilterChips({required this.selected, required this.onSelected});
  final String selected;
  final ValueChanged<String> onSelected;

  static const _options = ['Tất cả', 'Khóa học', 'Mẫu viết', 'Bài đọc'];

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        // Its own storage key: without one it took the page's scroll offset
        // back on return and opened scrolled past "Tất cả".
        key: const PageStorageKey<String>('study-filters'),
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        child: Row(children: [
          for (final option in _options) ...[
            StudyPressable(
              child: Semantics(
                button: true,
                selected: option == selected,
                child: Material(
                  color: option == selected
                      ? AppColors.primaryLight
                      : AppColors.surface,
                  shape: StadiumBorder(
                      side: BorderSide(
                          color: option == selected
                              ? AppColors.primaryLight
                              : AppColors.border)),
                  child: InkWell(
                    customBorder: const StadiumBorder(),
                    onTap: () => onSelected(option),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 48),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      alignment: Alignment.center,
                      child: Text(option,
                          style: Theme.of(context)
                              .textTheme
                              .labelLarge
                              ?.copyWith(
                                  color: option == selected
                                      ? AppColors.primaryDark
                                      : AppColors.textPrimary,
                                  fontWeight: option == selected
                                      ? FontWeight.w600
                                      : FontWeight.w400)),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
        ]),
      );
}

class _ContinueCard extends StatelessWidget {
  const _ContinueCard({required this.completed, required this.onTap});
  final int completed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) =>
      StudyPressable(child: _surfaceFor(context));

  Widget _surfaceFor(BuildContext context) => Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: _surface(),
            child: Row(children: [
              Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(AppRadius.small)),
                  child: const Icon(Icons.menu_book_rounded,
                      color: AppColors.primaryDark)),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text('Viết điều biết ơn mỗi ngày',
                        style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: AppSpacing.xs),
                    Text('Đã học $completed/3 bài', style: _meta(context)),
                    const SizedBox(height: AppSpacing.sm),
                    _Progress(value: completed / 3),
                  ])),
              const Icon(Icons.chevron_right_rounded),
            ]),
          ),
        ),
      );
}

class _ContentCard extends StatelessWidget {
  const _ContentCard({required this.item, required this.onTap});
  final _StudyItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) =>
      StudyPressable(child: _surfaceFor(context));

  Widget _surfaceFor(BuildContext context) => Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.card),
          // Title, short description, and what it is and how long.
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: _surface(),
            child: Builder(builder: (context) {
              final large = MediaQuery.textScalerOf(context).scale(16) > 20;
              return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.title,
                        maxLines: large ? null : 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontSize: 18)),
                    const SizedBox(height: AppSpacing.sm),
                    Text(item.description,
                        maxLines: large ? null : 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: AppColors.textSecondary)),
                    const SizedBox(height: AppSpacing.sm),
                    Text('${item.type} · ${item.meta}',
                        style: _meta(context)
                            .copyWith(color: AppColors.primaryAction)),
                  ]);
            }),
          ),
        ),
      );
}

class _NoResult extends StatelessWidget {
  const _NoResult({required this.onClear});
  final VoidCallback onClear;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(AppSpacing.xl),
        decoration: _surface(),
        child: Column(children: [
          const Icon(Icons.search_off_rounded,
              size: 32, color: AppColors.textSecondary),
          const SizedBox(height: AppSpacing.sm),
          const Text('Không có nội dung phù hợp bộ lọc này.'),
          TextButton(onPressed: onClear, child: const Text('Xóa bộ lọc'))
        ]),
      );
}

class _CourseScreen extends StatefulWidget {
  const _CourseScreen(
      {required this.item,
      required this.session,
      required this.read,
      required this.onRead});
  final _StudyItem item;
  final StudySession session;
  final Set<int> read;
  final ValueChanged<int> onRead;

  @override
  State<_CourseScreen> createState() => _CourseScreenState();
}

class _CourseScreenState extends State<_CourseScreen> {
  final _scroll = ScrollController();
  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  _StudyItem get item => widget.item;
  Set<int> get read => widget.read;

  void _openLesson(int index) {
    Navigator.of(context).push(_studyRoute(
        builder: (_) => _ReaderScreen(
            lesson: studyLessons[index],
            session: widget.session,
            initiallyRead: read.contains(index),
            onRead: () {
              final wasComplete = read.length == _lessons.length;
              widget.onRead(index);
              setState(() {});
              return !wasComplete && read.length == _lessons.length;
            })));
  }

  @override
  Widget build(BuildContext context) {
    if (item.framework) {
      return _FrameworkScreen(item: item, session: widget.session);
    }
    final completed = read.length == _lessons.length;
    final index = List.generate(_lessons.length, (i) => i)
        .firstWhere((i) => !read.contains(i), orElse: () => 0);
    return Scaffold(
      appBar: AppBar(title: const Text('Khóa học')),
      body: SafeArea(
          child: Stack(children: [
        ListView(
            controller: _scroll,
            padding: const EdgeInsets.only(bottom: 120),
            children: [
              _DetailIntro(
                  cardColor: AppColors.primaryDark,
                  eyebrow: item.type,
                  title: item.title,
                  description: item.description,
                  meta: item.meta,
                  mascot: true),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (read.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.lg),
                        Text('${read.length}/${_lessons.length} bài đã đọc',
                            style: _meta(context)),
                        const SizedBox(height: AppSpacing.sm),
                        _Progress(value: read.length / _lessons.length),
                      ],
                      const SizedBox(height: AppSpacing.xxl),
                      StudySection(title: 'Bạn sẽ thử điều gì', children: [
                        for (final line in courseBenefits) StudyCheckLine(line)
                      ]),
                      const SizedBox(height: AppSpacing.xl),
                      StudySection(title: 'Bài học', children: [
                        for (var lesson = 0;
                            lesson < _lessons.length;
                            lesson++) ...[
                          _LessonRow(
                              number: lesson + 1,
                              title: _lessons[lesson],
                              minutes: studyLessons[lesson].minutes,
                              done: read.contains(lesson),
                              onTap: () => _openLesson(lesson)),
                          const SizedBox(height: 12),
                        ],
                      ]),
                    ]),
              ),
            ]),
        _Dock(
            label: completed
                ? item.practicePrompt != null
                    ? 'Viết thực hành'
                    : 'Xem lại bài học'
                : read.isEmpty
                    ? 'Bắt đầu học'
                    : 'Tiếp tục học',
            onPressed: () {
              if (completed) {
                final prompt = item.practicePrompt;
                if (prompt == null) {
                  _scroll.animateTo(_scroll.position.maxScrollExtent,
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut);
                  return;
                }
                Navigator.of(context).push(_studyRoute(
                    builder: (_) => _Editor(
                        session: widget.session,
                        source: const StudyWritingContext(
                            kind: 'course', sourceId: 'gratitude-course'),
                        title: 'Viết thực hành',
                        prompt: prompt,
                        returnLabel: 'Về khóa học')));
              } else {
                _openLesson(index);
              }
            }),
      ])),
    );
  }
}

class _FrameworkScreen extends StatelessWidget {
  const _FrameworkScreen({required this.item, required this.session});
  final _StudyItem item;
  final StudySession session;
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Mẫu viết')),
        body: SafeArea(
            child: Stack(children: [
          ListView(padding: const EdgeInsets.only(bottom: 120), children: [
            _DetailIntro(
                cardColor: AppColors.textPrimary,
                eyebrow: item.type,
                title: item.title,
                description: item.description,
                meta: item.meta,
                mascot: true),
            const SizedBox(height: AppSpacing.xxl),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: StudySection(title: 'Các bước mẫu', children: [
                for (var i = 0; i < frameworkSteps.length; i++)
                  StudyStepLine(number: i + 1, text: frameworkSteps[i])
              ]),
            ),
          ]),
          _Dock(
              label: 'Viết theo phương pháp này',
              onPressed: () => Navigator.of(context).push(_studyRoute(
                  builder: (_) => _Editor(
                      session: session,
                      source: const StudyWritingContext(
                          kind: 'framework', sourceId: 'clear-my-mind'),
                      title: frameworkTitle,
                      prompt: frameworkPrompt,
                      returnLabel: 'Về mẫu viết')))),
        ])),
      );
}

class _ReaderScreen extends StatefulWidget {
  const _ReaderScreen(
      {required this.lesson,
      required this.session,
      required this.onRead,
      this.initiallyRead = false});
  final StudyLesson lesson;
  final StudySession session;
  final bool initiallyRead;
  final ValueGetter<bool> onRead;
  @override
  State<_ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<_ReaderScreen> {
  late bool _read = widget.initiallyRead;
  void _markRead() {
    if (_read) return;
    setState(() => _read = true);
    final courseCompleted = widget.onRead();
    if (courseCompleted) {
      Navigator.of(context).pushReplacement(_studyRoute(
          builder: (_) => _CourseCompletion(session: widget.session)));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.surface,
        appBar: AppBar(
            backgroundColor: AppColors.surface,
            title: Text(widget.lesson.title, overflow: TextOverflow.ellipsis)),
        body: ListView(padding: const EdgeInsets.all(AppSpacing.lg), children: [
          // Static card only: S03 keeps motion away from the article.
          StudyTitleCard(
              title: widget.lesson.title, color: AppColors.warmAccent),
          const SizedBox(height: AppSpacing.xl),
          StudyEyebrow('Bài đọc · ${widget.lesson.minutes} phút'),
          const SizedBox(height: AppSpacing.sm),
          Text(widget.lesson.title,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: AppSpacing.xl),
          for (final paragraph in widget.lesson.paragraphs) ...[
            Text(paragraph, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: AppSpacing.md),
          ],
          const SizedBox(height: AppSpacing.md),
          StudySection(title: 'Điều cần nhớ', children: [
            for (final line in widget.lesson.summary) StudyCheckLine(line)
          ]),
          const SizedBox(height: AppSpacing.md),
          Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(AppRadius.card)),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _Nudaeng(
                        size: 64,
                        label: 'Nudaeng bên bài học',
                        artwork: NudaengArtwork.lesson,
                        animate: false),
                    const SizedBox(height: AppSpacing.sm),
                    Text('Thử viết từ bài học này',
                        style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: AppSpacing.sm),
                    Text(widget.lesson.prompt),
                    const SizedBox(height: AppSpacing.md),
                    _PrimaryButton(
                        label: 'Thực hành',
                        onPressed: () => Navigator.of(context).push(_studyRoute(
                            builder: (_) => _Editor(
                                session: widget.session,
                                source: StudyWritingContext(
                                    kind: 'lesson', sourceId: widget.lesson.id),
                                title: 'Thực hành từ bài học',
                                prompt: widget.lesson.prompt,
                                returnLabel: 'Về bài học')))),
                  ])),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton.icon(
              onPressed: _read ? null : _markRead,
              icon: Icon(_read
                  ? Icons.check_circle_rounded
                  : Icons.check_circle_outline_rounded),
              label: Text(_read ? 'Đã đọc' : 'Đánh dấu đã đọc')),
        ]),
      );
}

class _ChallengeDetailScreen extends StatefulWidget {
  const _ChallengeDetailScreen(
      {required this.joined,
      required this.completed,
      required this.onJoin,
      required this.openProgress});
  final bool joined;
  final bool completed;
  final VoidCallback onJoin;
  final VoidCallback openProgress;
  @override
  State<_ChallengeDetailScreen> createState() => _ChallengeDetailScreenState();
}

class _ChallengeDetailScreenState extends State<_ChallengeDetailScreen> {
  bool _joining = false;
  Future<void> _join() async {
    if (_joining) return;
    setState(() => _joining = true);
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;
    widget.onJoin();
    Navigator.pop(context);
    widget.openProgress();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Challenge')),
        body: SafeArea(
            child: Stack(children: [
          ListView(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 104),
              children: [
                const _Hero(
                    title: '7 ngày viết điều biết ơn',
                    tag: '7 nhiệm vụ · Linh hoạt theo nhịp của bạn',
                    mascotArtwork: NudaengArtwork.challengeInvitation,
                    mascotWidth: 112,
                    mascotHeight: 128,
                    description:
                        'Dành vài phút để nhận ra điều đang làm ngày hôm nay có ý nghĩa.'),
                const SizedBox(height: AppSpacing.xl),
                const _Info(title: 'Challenge này dành cho bạn khi…', lines: [
                  'Bạn muốn bắt đầu viết bằng một câu gợi ý thật nhỏ.',
                  'Bạn muốn có nhịp gợi ý nhưng không bị áp lực theo ngày.'
                ]),
                const SizedBox(height: AppSpacing.xl),
                Text('Cách tham gia',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: AppSpacing.sm),
                const Text(
                    'Mỗi nhiệm vụ là một câu gợi ý. Nhiệm vụ hoàn thành khi bạn lưu bài viết.'),
                const SizedBox(height: AppSpacing.xl),
                Text('Các nhiệm vụ',
                    style: Theme.of(context).textTheme.titleLarge),
                for (var i = 0; i < _prompts.length; i++)
                  ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                          backgroundColor: AppColors.primaryLight,
                          child: Text('${i + 1}')),
                      title: Text('Nhiệm vụ ${i + 1}'),
                      subtitle: Text(_prompts[i],
                          maxLines: 2, overflow: TextOverflow.ellipsis)),
                Text('Bạn có thể tiếp tục theo nhịp của mình.',
                    style: _meta(context)),
              ]),
          _Dock(
              label: _joining
                  ? 'Đang tham gia…'
                  : widget.completed
                      ? 'Xem kết quả'
                      : widget.joined
                          ? 'Tiếp tục challenge'
                          : 'Tham gia challenge',
              onPressed: _joining
                  ? null
                  : widget.joined
                      ? widget.openProgress
                      : _join),
        ])),
      );
}

class _ChallengeProgressScreen extends StatefulWidget {
  const _ChallengeProgressScreen(
      {required this.done,
      required this.session,
      required this.drafts,
      required this.paused,
      required this.left,
      required this.onLeave,
      required this.onPause,
      required this.onComplete,
      required this.onDraftsChanged});
  final Set<int> done;
  final StudySession session;
  final Map<int, String> drafts;
  final bool paused;
  final bool left;
  final VoidCallback onLeave;
  final ValueChanged<bool> onPause;
  final ValueChanged<int> onComplete;

  /// [drafts] changed, to keep them.
  final VoidCallback onDraftsChanged;

  @override
  State<_ChallengeProgressScreen> createState() => _ChallengeProgressState();
}

class _ChallengeProgressState extends State<_ChallengeProgressScreen> {
  late bool paused = widget.paused;
  late bool left = widget.left;
  Set<int> get done => widget.done;
  int _completionEvent = 0;

  void onPause(bool value) {
    widget.onPause(value);
    setState(() {
      paused = value;
      left = false;
    });
  }

  /// Asks in the app's confirm sheet, as the journal editor does.
  Future<void> _leave() async {
    final confirmed = await showAppSheet<bool>(
      context,
      builder: (sheet) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Rời challenge?', style: AppText.sectionTitle),
          const SizedBox(height: AppSpacing.sm),
          const Text(
              'Tiến độ và những gì bạn đã viết vẫn được giữ. Bạn có thể '
              'quay lại bất cứ lúc nào.',
              style: AppText.bodySecondary),
          const SizedBox(height: AppSpacing.xl),
          Row(children: [
            Expanded(
              child: AppSecondaryButton(
                  label: 'Ở lại', onPressed: () => Navigator.pop(sheet, false)),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: AppPrimaryButton(
                  label: 'Rời challenge',
                  onPressed: () => Navigator.pop(sheet, true)),
            ),
          ]),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    widget.onLeave();
    Navigator.pop(context);
  }

  Future<void> _writeTask(int current) async {
    if (paused || left || done.contains(current)) return;
    final before = done.length;
    final next = List<int>.generate(_prompts.length, (i) => i)
        .where((i) => i != current && !done.contains(i))
        .firstOrNull;
    var writeNext = false;
    await Navigator.of(context).push(_studyRoute(
        builder: (_) => _Editor(
              session: widget.session,
              source: StudyWritingContext(
                  kind: 'challenge',
                  sourceId: 'task-${current + 1}',
                  challenge: challengeId,
                  taskIndex: current),
              title: 'Nhiệm vụ ${current + 1}/${_prompts.length}',
              prompt: _prompts[current],
              returnLabel: 'Về challenge',
              initialText: widget.drafts[current] ?? '',
              onDraftChanged: (text) {
                widget.drafts[current] = text;
                widget.onDraftsChanged();
              },
              onSaved: () {
                widget.drafts.remove(current);
                widget.onComplete(current);
              },
              nextTask: next,
              onWriteNext: () => writeNext = true,
            )));
    if (!mounted) return;
    final saved = done.length > before;
    setState(() {
      if (saved && done.length < _prompts.length) {
        _completionEvent++;
      }
    });
    if (saved && done.length == _prompts.length) {
      Navigator.of(context).push(_studyRoute(
          builder: (_) =>
              _ChallengeCompletion(animate: true, session: widget.session)));
    } else if (saved && writeNext && next != null) {
      // Positions are not calendar-locked, so the next task may start now.
      _writeTask(next);
    }
  }

  void _openTask(int task, int current) {
    final entry = widget.session.entryForTask(task);
    if (entry != null) {
      Navigator.of(context)
          .push(_studyRoute(builder: (_) => _EntryReader(entry: entry)));
    } else if (done.contains(task)) {
      // Done, but its entry was deleted from the journal since.
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
            content: Text('Bài viết của nhiệm vụ này đã được xóa khỏi '
                'nhật ký. Nhiệm vụ vẫn được tính là đã xong.')));
    } else if (task == current && !paused && !left) {
      _writeTask(task);
    } else {
      Navigator.of(context).push(_studyRoute(
          builder: (_) => Scaffold(
                appBar: AppBar(title: Text('Nhiệm vụ ${task + 1}')),
                body: ListView(padding: const EdgeInsets.all(20), children: [
                  Text('Xem trước nhiệm vụ',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 16),
                  Text(_prompts[task]),
                  const SizedBox(height: 24),
                  Text(paused || left
                      ? 'Tiếp tục challenge để viết nhiệm vụ hiện tại.'
                      : 'Bạn có thể xem trước và viết khi đến nhiệm vụ này.'),
                ]),
              )));
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = List<int>.generate(_prompts.length, (i) => i)
        .firstWhere((i) => !done.contains(i), orElse: () => 6);
    final complete = done.length == 7;
    return Scaffold(
      appBar: AppBar(title: const Text('Challenge của bạn'), actions: [
        PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'leave') {
                _leave();
              } else {
                onPause(value == 'pause');
              }
            },
            itemBuilder: (_) => [
                  PopupMenuItem(
                      value: paused || left ? 'resume' : 'pause',
                      child: Text(
                          paused || left ? 'Tiếp tục challenge' : 'Tạm dừng')),
                  if (!left)
                    const PopupMenuItem(
                        value: 'leave', child: Text('Rời challenge')),
                ])
      ]),
      body: SafeArea(
          child:
              ListView(padding: const EdgeInsets.all(AppSpacing.lg), children: [
        Text('7 ngày viết điều biết ơn',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: AppSpacing.md),
        Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: _surface(),
            child: Row(children: [
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text('${done.length}/7 nhiệm vụ đã hoàn thành',
                        style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: AppSpacing.md),
                    _Progress(value: done.length / 7)
                  ])),
              const SizedBox(width: AppSpacing.md),
              _Nudaeng(
                  key: ValueKey(_completionEvent),
                  size: 64,
                  height: 72,
                  label: 'Nudaeng đồng hành cùng challenge',
                  artwork: NudaengArtwork.challengeProgress,
                  animate: _completionEvent > 0)
            ])),
        if (paused || left) ...[
          const SizedBox(height: AppSpacing.md),
          Text(left
              ? 'Bạn đã rời challenge. Tiến độ và nhật ký vẫn được giữ.'
              : 'Challenge đang tạm dừng. Bạn có thể tiếp tục khi thấy phù hợp.'),
          const SizedBox(height: 12),
          _PrimaryButton(
              label: 'Tiếp tục challenge', onPressed: () => onPause(false))
        ],
        const SizedBox(height: AppSpacing.xl),
        Text('Nhiệm vụ tiếp theo',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.md),
        if (complete)
          _Message(
              text: 'Bạn đã hoàn thành toàn bộ challenge này.',
              action: 'Xem kết quả',
              onTap: () => Navigator.of(context).push(_studyRoute(
                  builder: (_) => _ChallengeCompletion(
                      animate: false, session: widget.session))))
        else
          _CurrentTask(
              index: current,
              disabled: paused || left,
              hasDraft: widget.drafts[current]?.trim().isNotEmpty ?? false,
              onWrite: () => _writeTask(current)),
        const SizedBox(height: AppSpacing.xl),
        Text('Các nhiệm vụ', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.md),
        for (var task = 0; task < 7; task++) ...[
          _TaskRow(
              number: task + 1,
              prompt: _prompts[task],
              done: done.contains(task),
              onTap: () => _openTask(task, current),
              current: !done.contains(task) && task == current),
          const SizedBox(height: 12)
        ],
      ])),
    );
  }
}

class _CurrentTask extends StatelessWidget {
  const _CurrentTask(
      {required this.index,
      required this.disabled,
      required this.onWrite,
      this.hasDraft = false});
  final int index;
  final bool hasDraft;
  final bool disabled;
  final VoidCallback onWrite;
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
          color: AppColors.primaryLight,
          borderRadius: BorderRadius.circular(AppRadius.card)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Nhiệm vụ ${index + 1}/7', style: _meta(context)),
        const SizedBox(height: AppSpacing.sm),
        Text(_prompts[index], style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: AppSpacing.md),
        _PrimaryButton(
            label: hasDraft ? 'Tiếp tục bản nháp' : 'Viết nhiệm vụ này',
            onPressed: disabled ? null : onWrite)
      ]));
}

class _TaskRow extends StatelessWidget {
  const _TaskRow(
      {required this.number,
      required this.onTap,
      required this.prompt,
      required this.done,
      required this.current});
  final int number;
  final String prompt;
  final bool done;
  final bool current;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) =>
      StudyPressable(child: _surfaceFor(context));

  Widget _surfaceFor(BuildContext context) {
    final label = done
        ? 'Đã hoàn thành'
        : current
            ? 'Tiếp theo'
            : 'Chưa thực hiện';
    return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.input),
        child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
                color: current ? AppColors.primaryLight : AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.input),
                border: Border.all(
                    color: current ? AppColors.primary : AppColors.border)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // The check scales in only when completion is committed.
              AnimatedSwitcher(
                  duration: StudyMotion.reduced(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 180),
                  switchInCurve: StudyMotion.enter,
                  transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: ScaleTransition(
                          scale: Tween<double>(begin: .8, end: 1)
                              .animate(animation),
                          child: child)),
                  child: Icon(
                      key: ValueKey(done),
                      done ? Icons.check_circle_rounded : Icons.circle_outlined,
                      color:
                          done ? AppColors.positive : AppColors.primaryDark)),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text('Nhiệm vụ $number',
                        style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: AppSpacing.xs),
                    Text(prompt, maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: AppSpacing.xs),
                    Text(label,
                        style: _meta(context).copyWith(
                            color: done
                                ? AppColors.positive
                                : AppColors.textSecondary))
                  ]))
            ])));
  }
}

class _Editor extends StatefulWidget {
  const _Editor(
      {required this.title,
      required this.session,
      required this.source,
      required this.prompt,
      required this.returnLabel,
      this.onSaved,
      this.initialText = '',
      this.onDraftChanged,
      this.nextTask,
      this.onWriteNext});
  final String title;
  final String prompt;
  final StudySession session;
  final StudyWritingContext source;
  final String returnLabel;
  final VoidCallback? onSaved;
  final String initialText;
  final ValueChanged<String>? onDraftChanged;

  /// Challenge only: the task J03 points to after this one is saved.
  final int? nextTask;
  final VoidCallback? onWriteNext;
  @override
  State<_Editor> createState() => _EditorState();
}

class _EditorState extends State<_Editor> {
  /// As in the journal editor.
  static const _deeperLabel = 'Suy ngẫm sâu hơn';

  late final _controller = TextEditingController(text: widget.initialText);
  final _focus = FocusNode();
  final _scroll = ScrollController();

  /// The one field, moved below the questions when going deeper: the same
  /// field keeps its focus, so the keyboard stays up.
  final _fieldKey = GlobalKey();
  bool _saving = false;

  /// "Suy ngẫm sâu hơn": the questions that follow this prompt, asked one
  /// at a time, and the answers already given (the first to the prompt).
  /// The field holds the answer being written.
  late final List<String> _followUps = studyFollowUps(widget.source);
  final List<String> _answers = [];

  /// The paper and text size chosen for the journal, so writing here feels
  /// the same.
  JournalPaper _paper = JournalPaper.plain;
  double _textSize = 16;
  WritingPreferences? _preferences;

  @override
  void initState() {
    super.initState();
    // The outline follows the focus.
    _focus.addListener(() => setState(() {}));
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await WritingPreferences.open();
      if (!mounted) return;
      setState(() {
        _preferences = prefs;
        _paper = prefs.paper;
        _textSize = prefs.textSize;
      });
    } catch (_) {
      // Plain paper at the default size.
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// Every answer, as one entry (as the journal editor joins them).
  String get _text => [..._answers, _controller.text.trim()]
      .where((answer) => answer.isNotEmpty)
      .join('\n\n');

  bool get _canGoDeeper =>
      _controller.text.trim().isNotEmpty && _answers.length < _followUps.length;

  /// How the journal names this entry, e.g. "Challenge · Nhiệm vụ 2".
  String get _label {
    final source = widget.source;
    if (source.kind == 'challenge') {
      return 'Challenge · Nhiệm vụ ${source.taskIndex! + 1}';
    }
    if (source.kind == 'framework') return 'Mẫu viết · $frameworkTitle';
    for (final lesson in [...studyLessons, studyCase]) {
      if (lesson.id == source.sourceId) return 'Bài học · ${lesson.title}';
    }
    return 'Khóa học · ${_StudyScreenState._items.first.title}';
  }

  /// Keeps what was written above and asks the next question, with a fresh
  /// field for the answer.
  void _deeper() {
    if (!_canGoDeeper) return;
    setState(() {
      _answers.add(_controller.text.trim());
      _controller.clear();
    });
    _preferences?.feedback();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focus.requestFocus();
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: StudyMotion.reduced(context)
                ? Duration.zero
                : const Duration(milliseconds: 250),
            curve: StudyMotion.change);
      }
    });
  }

  /// Saves into the journal; writing today counts for the streak (its
  /// celebration stays with the journal editor). A failure keeps the text.
  Future<void> _finish() async {
    final text = _text;
    if (_saving || text.isEmpty) return;
    setState(() => _saving = true);
    try {
      await widget.session
          .save(text, widget.prompt, widget.source, label: _label);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Chưa lưu được bài viết. Nội dung vẫn còn ở đây.')));
      return;
    }
    if (!mounted) return;
    if (!StreakState.shared.completedToday) StreakState.shared.completeToday();
    widget.onSaved?.call();
    await Navigator.of(context).push(_studyRoute(
        builder: (_) => _Reflection(
            returnLabel: widget.returnLabel,
            nextTask: widget.nextTask,
            onWriteNext: widget.onWriteNext)));
    if (mounted) Navigator.pop(context);
  }

  /// One line under the paper, its space kept so the actions never jump.
  String get _hint {
    if (_controller.text.trim().isEmpty) {
      return _answers.isEmpty
          ? 'Viết vài dòng để dùng các nút bên dưới.'
          : 'Viết câu trả lời, hoặc Hoàn tất với những gì đã viết.';
    }
    return _answers.length < _followUps.length
        ? ''
        : 'Bạn đã đi hết các câu hỏi gợi ý.';
  }

  Widget _question(String text) => Container(
      key: const ValueKey('study-follow-up'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: AppColors.primaryLight,
          borderRadius: BorderRadius.circular(AppRadius.small)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Padding(
          padding: EdgeInsets.only(top: 2),
          child: Icon(Icons.subdirectory_arrow_right_rounded,
              size: 18, color: AppColors.primaryDark),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
            child: Text(text, style: Theme.of(context).textTheme.titleSmall)),
      ]));

  Widget _field({required bool expands}) => TextField(
      key: _fieldKey,
      controller: _controller,
      focusNode: _focus,
      autofocus: true,
      expands: expands,
      minLines: expands ? null : 5,
      maxLines: null,
      textAlignVertical: TextAlignVertical.top,
      textCapitalization: TextCapitalization.sentences,
      style: AppText.body.copyWith(fontSize: _textSize),
      onChanged: (_) {
        widget.onDraftChanged?.call(_text);
        setState(() {});
      },
      decoration: InputDecoration(
        hintText: _answers.isEmpty
            ? 'Bắt đầu ở bất cứ nơi nào bạn đang có mặt…'
            : 'Viết tiếp tại đây…',
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        contentPadding: const EdgeInsets.all(AppSpacing.md),
      ));

  /// The answers given so far, each under the question it answered, then
  /// the current question and its field.
  Widget _rounds() {
    final answered = AppText.body
        .copyWith(fontSize: _textSize, color: AppColors.textSecondary);
    return ListView(
        controller: _scroll,
        padding: const EdgeInsets.only(top: AppSpacing.md),
        children: [
          for (final (index, answer) in _answers.indexed) ...[
            if (index > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md, 0, AppSpacing.md, AppSpacing.sm),
                child: Text(_followUps[index - 1], style: _meta(context)),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md, 0, AppSpacing.md, AppSpacing.lg),
              child: Text(answer, style: answered),
            ),
          ],
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: _question(_followUps[_answers.length - 1]),
          ),
          _field(expands: false),
        ]);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      backgroundColor: AppColors.surface,
      appBar:
          AppBar(backgroundColor: AppColors.surface, title: Text(widget.title)),
      body: SafeArea(
          child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            borderRadius:
                                BorderRadius.circular(AppRadius.input)),
                        child: Text(widget.prompt,
                            style: Theme.of(context).textTheme.titleSmall)),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                        _answers.isEmpty
                            ? 'Bản nháp'
                            : 'Bản nháp · Suy ngẫm ${_answers.length}/'
                                '${_followUps.length}',
                        style: _meta(context)),
                    const SizedBox(height: AppSpacing.sm),
                    // On the journal's chosen paper, at its text size.
                    Expanded(
                        child: DecoratedBox(
                      position: DecorationPosition.foreground,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppRadius.input),
                        border: Border.all(
                            color: _focus.hasFocus
                                ? AppColors.primaryAction
                                : AppColors.border,
                            width: _focus.hasFocus ? 1.5 : 1),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.input),
                        child: Stack(children: [
                          Positioned.fill(
                              child: JournalPaperView(paper: _paper)),
                          _answers.isEmpty ? _field(expands: true) : _rounds(),
                        ]),
                      ),
                    )),
                    const SizedBox(height: AppSpacing.sm),
                    // Explains the disabled actions; space stays reserved.
                    Text(_hint,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _meta(context)),
                    const SizedBox(height: AppSpacing.sm),
                    Row(children: [
                      Expanded(
                          child: OutlinedButton(
                              onPressed: _canGoDeeper ? _deeper : null,
                              style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: AppSpacing.sm)),
                              // One line, as tall as "Hoàn tất" beside it.
                              child: const FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(_deeperLabel, maxLines: 1)))),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                          child: _PrimaryButton(
                              label: _saving ? 'Đang lưu…' : 'Hoàn tất',
                              onPressed: _text.isEmpty ? null : _finish))
                    ]),
                  ]))));
}

class _Reflection extends StatelessWidget {
  const _Reflection(
      {required this.returnLabel, this.nextTask, this.onWriteNext});
  final String returnLabel;
  final int? nextTask;
  final VoidCallback? onWriteNext;
  @override
  Widget build(BuildContext context) {
    final canContinue = nextTask != null && onWriteNext != null;
    return Scaffold(
      appBar: AppBar(title: const Text('Phản hồi cho bạn')),
      // Actions stay docked so a longer reflection never hides the next step.
      body: Stack(children: [
        ListView(
            padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg,
                AppSpacing.lg, canContinue ? 168 : 112),
            children: [
              Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: _surface(),
                  child: Row(children: [
                    const Icon(Icons.check_circle_rounded,
                        color: AppColors.positive),
                    const SizedBox(width: AppSpacing.sm),
                    Text('Đã lưu bài viết',
                        style: Theme.of(context).textTheme.titleSmall)
                  ])),
              const SizedBox(height: AppSpacing.md),
              const _Info(title: 'Điều mình nhận ra', lines: [
                'Bạn đã dành chỗ cho một điều nhỏ nhưng có ý nghĩa trong ngày hôm nay.'
              ]),
              const SizedBox(height: AppSpacing.md),
              const _Info(title: 'Một câu hỏi để giữ lại', lines: [
                'Bạn muốn mang cảm giác này sang ngày mai bằng cách nào?'
              ]),
              if (nextTask != null) ...[
                const SizedBox(height: AppSpacing.md),
                _NextTaskNotice(index: nextTask!),
              ],
            ]),
        _Dock(
          label: returnLabel,
          onPressed: () => Navigator.pop(context),
          secondaryLabel:
              canContinue ? 'Viết tiếp nhiệm vụ ${nextTask! + 1}' : null,
          onSecondary: canContinue
              ? () {
                  onWriteNext!();
                  Navigator.pop(context);
                }
              : null,
        ),
      ]),
    );
  }
}

/// The 7-day challenge paces one task per day. This is a suggestion only:
/// tasks are positions, not calendar locks, and a missed day keeps progress.
/// J03's "Hẹn bạn ngày mai": the next task, and when the daily reminder
/// will call the user back (or where to set one).
class _NextTaskNotice extends StatefulWidget {
  const _NextTaskNotice({required this.index});
  final int index;

  @override
  State<_NextTaskNotice> createState() => _NextTaskNoticeState();
}

class _NextTaskNoticeState extends State<_NextTaskNotice> {
  /// The reminder times set in onboarding or Hồ sơ; null until read (or
  /// when they cannot be).
  List<String>? _reminders;

  @override
  void initState() {
    super.initState();
    OnboardingStore.open().then((store) {
      final times = store.reminders.values.toList()
        ..sort((a, b) => (a.hour * 60 + a.minute) - (b.hour * 60 + b.minute));
      if (mounted) {
        setState(() => _reminders = [for (final t in times) t.label]);
      }
    }, onError: (Object _) {});
  }

  int get index => widget.index;

  String? get _reminderLine {
    final reminders = _reminders;
    if (reminders == null) return null;
    return reminders.isEmpty
        ? 'Muốn được nhắc? Bạn có thể đặt lời nhắc mỗi ngày trong Hồ sơ.'
        : 'Lời nhắc viết mỗi ngày của bạn: ${reminders.join(' và ')}.';
  }

  @override
  Widget build(BuildContext context) => Container(
      key: const ValueKey('next-task-notice'),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
          color: AppColors.primaryLight,
          borderRadius: BorderRadius.circular(AppRadius.card)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.event_available_rounded,
              size: 20, color: AppColors.primaryDark),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
              child: Text('Hẹn bạn ngày mai',
                  style: Theme.of(context).textTheme.titleSmall)),
        ]),
        const SizedBox(height: AppSpacing.sm),
        Text('Nhiệm vụ ${index + 1}/${_prompts.length}', style: _meta(context)),
        const SizedBox(height: AppSpacing.xs),
        Text(_prompts[index]),
        const SizedBox(height: AppSpacing.sm),
        Text(
            'Challenge này gợi ý viết mỗi ngày một nhiệm vụ. '
            'Lỡ một ngày cũng không sao, tiến độ vẫn được giữ.',
            style: _meta(context)),
        if (_reminderLine case final line?) ...[
          const SizedBox(height: AppSpacing.sm),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Icon(Icons.notifications_none_rounded,
                  size: 18, color: AppColors.primaryDark),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(child: Text(line, style: _meta(context))),
          ]),
        ],
      ]));
}

class _ChallengeCompletion extends StatelessWidget {
  const _ChallengeCompletion({required this.animate, required this.session});
  final bool animate;
  final StudySession session;
  void _backToStudy(BuildContext context) =>
      Navigator.of(context).popUntil((route) => route.isFirst);
  @override
  Widget build(BuildContext context) => PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _backToStudy(context);
      },
      child: Scaffold(
          appBar: AppBar(
              leading: BackButton(onPressed: () => _backToStudy(context)),
              title: const Text('Challenge hoàn thành')),
          body:
              ListView(padding: const EdgeInsets.all(AppSpacing.lg), children: [
            Center(
                child: _Nudaeng(
                    size: 144,
                    label: 'Nudaeng chúc mừng',
                    animate: animate,
                    artwork: NudaengArtwork.challengeCompletion)),
            const SizedBox(height: AppSpacing.lg),
            Text('Bạn đã hoàn thành challenge',
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: AppSpacing.sm),
            Text(
                '$_challengeTitle · ${session.challengeEntries.length} nhiệm vụ đã hoàn thành',
                textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.xl),
            _Info(title: 'Những điều bạn đã viết', lines: [
              for (final entry in session.challengeEntries) entry.prompt
            ]),
            const SizedBox(height: AppSpacing.xl),
            _PrimaryButton(
                label: 'Xem nhật ký đã viết',
                onPressed: () => Navigator.of(context).push(_studyRoute(
                    builder: (_) => _ChallengeEntries(session: session)))),
            TextButton(
                onPressed: () =>
                    Navigator.of(context).popUntil((route) => route.isFirst),
                child: const Text('Về Study')),
          ])));
}

class _ChallengeEntries extends StatelessWidget {
  const _ChallengeEntries({required this.session});
  final StudySession session;
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Nhật ký của challenge')),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          Text(_challengeTitle, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          for (final entry in session.challengeEntries)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Nhiệm vụ ${entry.source.taskIndex! + 1}'),
              subtitle: Text(entry.content,
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.of(context).push(
                  _studyRoute(builder: (_) => _EntryReader(entry: entry))),
            ),
        ]),
      );
}

class _EntryReader extends StatelessWidget {
  const _EntryReader({required this.entry});
  final StudyEntry entry;
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Nhật ký đã viết')),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          Text(entry.prompt, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 24),
          SelectableText(entry.content,
              style: Theme.of(context).textTheme.bodyMedium),
        ]),
      );
}

class _CourseCompletion extends StatelessWidget {
  const _CourseCompletion({required this.session});
  final StudySession session;
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Khóa học hoàn thành')),
      body: ListView(padding: const EdgeInsets.all(AppSpacing.lg), children: [
        const Center(
            child: _Nudaeng(
                size: 132,
                label: 'Nudaeng ôm sách',
                artwork: NudaengArtwork.courseCompletion)),
        const SizedBox(height: AppSpacing.lg),
        Text('Bạn đã học xong khóa này',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: AppSpacing.sm),
        Text('${studyLessons.length}/${studyLessons.length} bài đã đọc',
            textAlign: TextAlign.center),
        const SizedBox(height: AppSpacing.xl),
        const _Info(title: 'Bạn có thể mang theo', lines: courseSummary),
        const SizedBox(height: AppSpacing.xl),
        _PrimaryButton(
            label: 'Viết theo phương pháp này',
            onPressed: () => Navigator.of(context).pushReplacement(_studyRoute(
                builder: (_) => _Editor(
                    session: session,
                    source: const StudyWritingContext(
                        kind: 'course', sourceId: 'gratitude-course'),
                    title: 'Viết thực hành',
                    prompt: coursePracticePrompt,
                    returnLabel: 'Về khóa học')))),
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Về khóa học')),
      ]));
}

/// Shared top of S02: inked title card, Nudaeng on the ground line, then the
/// eyebrow, title, description and metadata.
class _DetailIntro extends StatelessWidget {
  const _DetailIntro(
      {required this.cardColor,
      required this.eyebrow,
      required this.title,
      required this.description,
      required this.meta,
      this.mascot = false});
  final Color cardColor;
  final String eyebrow;
  final String title;
  final String description;
  final String meta;
  final bool mascot;

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 0),
            child: StudyTitleCard(title: title, color: cardColor)),
        if (mascot)
          const StudyGroundScene(
              // The page-turn cutout is 264:323.
              mascotWidth: 108,
              mascotHeight: 132,
              mascot: _Nudaeng(
                  size: 108,
                  height: 132,
                  label: 'Nudaeng lật trang sách',
                  artwork: NudaengArtwork.courseDetail))
        else
          const SizedBox(height: AppSpacing.xl),
        const SizedBox(height: AppSpacing.lg),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            StudyEyebrow(eyebrow),
            const SizedBox(height: AppSpacing.sm),
            Text(title,
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Text(description,
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge
                    ?.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            Row(children: [
              const Icon(Icons.schedule_rounded,
                  size: 16, color: AppColors.textSecondary),
              const SizedBox(width: AppSpacing.xs),
              Text(meta, style: _meta(context)),
            ]),
          ]),
        ),
      ]);
}

class _Hero extends StatelessWidget {
  const _Hero(
      {required this.title,
      required this.tag,
      required this.description,
      required this.mascotArtwork,
      this.mascotWidth = 96,
      this.mascotHeight = 112});
  final String title;
  final String tag;
  final String description;
  final NudaengArtwork mascotArtwork;
  final double mascotWidth;
  final double mascotHeight;
  @override
  Widget build(BuildContext context) =>
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(tag, style: _meta(context)),
          const SizedBox(height: AppSpacing.sm),
          Text(title,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: AppSpacing.sm),
          Text(description, style: Theme.of(context).textTheme.bodyLarge)
        ])),
        const SizedBox(width: AppSpacing.sm),
        _Nudaeng(
            size: mascotWidth,
            height: mascotHeight,
            label: mascotArtwork == NudaengArtwork.courseDetail
                ? 'Nudaeng lật trang sách'
                : 'Nudaeng mời bạn tham gia',
            artwork: mascotArtwork)
      ]);
}

class _Info extends StatelessWidget {
  const _Info({required this.title, required this.lines});
  final String title;
  final List<String> lines;
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: _surface(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        for (final line in lines)
          Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Padding(
                    padding: EdgeInsets.only(top: 7),
                    child: Icon(Icons.circle,
                        size: 6, color: AppColors.primaryDark)),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: Text(line))
              ]))
      ]));
}

class _LessonRow extends StatelessWidget {
  const _LessonRow(
      {required this.number,
      required this.title,
      required this.minutes,
      required this.done,
      required this.onTap});
  final int number;
  final String title;
  final int minutes;
  final bool done;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) =>
      StudyPressable(child: _surfaceFor(context));

  Widget _surfaceFor(BuildContext context) => Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.input),
      child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.input),
          child: Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: _surface(),
              child: Row(children: [
                CircleAvatar(
                    backgroundColor: AppColors.primaryLight,
                    child: Text('$number')),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(title,
                          style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: AppSpacing.xs),
                      Text('Bài đọc · $minutes phút', style: _meta(context))
                    ])),
                Icon(
                    done
                        ? Icons.check_circle_rounded
                        : Icons.chevron_right_rounded,
                    color: done ? AppColors.positive : AppColors.textSecondary)
              ]))));
}

class _Dock extends StatelessWidget {
  const _Dock(
      {required this.label,
      required this.onPressed,
      this.secondaryLabel,
      this.onSecondary});
  final String label;
  final VoidCallback? onPressed;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  @override
  Widget build(BuildContext context) => Align(
      alignment: Alignment.bottomCenter,
      // Content fades out under a floating pill rather than a hard bar.
      child: DecoratedBox(
          decoration: BoxDecoration(
              gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [
                0,
                .35
              ],
                  colors: [
                Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0),
                Theme.of(context).scaffoldBackgroundColor,
              ])),
          child: SafeArea(
              top: false,
              child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _PrimaryButton(label: label, onPressed: onPressed),
                        if (secondaryLabel != null) ...[
                          const SizedBox(height: AppSpacing.sm),
                          OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(0, 48)),
                              onPressed: onSecondary,
                              child: Text(secondaryLabel!,
                                  textAlign: TextAlign.center)),
                        ],
                      ])))));
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton(
      {required this.label, required this.onPressed, this.height = 56});
  final String label;
  final VoidCallback? onPressed;
  final double height;
  @override
  Widget build(BuildContext context) =>
      StudyPressable(enabled: onPressed != null, child: _buttonFor(context));

  Widget _buttonFor(BuildContext context) => AppPrimaryButton(
      label: label, onPressed: onPressed, compact: height < 56);
}

class _Progress extends StatelessWidget {
  const _Progress({required this.value});
  final double value;
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 200),
      curve: StudyMotion.change,
      tween: Tween<double>(begin: value, end: value),
      builder: (_, progress, __) => ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: AppColors.border,
              color: AppColors.primaryDark)));
}

class _Nudaeng extends StatelessWidget {
  const _Nudaeng(
      {super.key,
      required this.size,
      required this.label,
      this.height,
      required this.artwork,
      this.animate = true,
      this.onFinished});
  final double size;
  final double? height;
  final String label;
  final NudaengArtwork artwork;
  final bool animate;
  final VoidCallback? onFinished;

  @override
  Widget build(BuildContext context) => NudaengView(
        artwork: artwork,
        width: size,
        height: height ?? size,
        label: label,
        animate: animate,
        onFinished: onFinished,
      );
}

class _Message extends StatelessWidget {
  const _Message(
      {required this.text, required this.action, required this.onTap});
  final String text;
  final String action;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: _surface(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(text),
        const SizedBox(height: AppSpacing.sm),
        TextButton(onPressed: onTap, child: Text(action))
      ]));
}

class _StudyItem {
  const _StudyItem(this.type, this.title, this.description, this.meta,
      {this.course = false,
      this.framework = false,
      this.practicePrompt,
      required this.order});

  /// What it is ("Khóa học", "Mẫu viết", "Bài đọc"); also its filter.
  final String type;
  final String title;
  final String description;
  final String meta;
  final bool course;
  final bool framework;
  final String? practicePrompt;
  final int order;
}

BoxDecoration _surface() => BoxDecoration(
    color: AppColors.surface,
    borderRadius: BorderRadius.circular(AppRadius.card),
    border: Border.all(color: AppColors.border));
TextStyle _meta(BuildContext context) => Theme.of(context)
    .textTheme
    .bodySmall!
    .copyWith(color: AppColors.textSecondary, fontSize: 14, height: 20 / 14);

final _lessons =
    studyLessons.map((lesson) => lesson.title).toList(growable: false);
const _prompts = challengePrompts;

const _challengeTitle = '7 ngày viết điều biết ơn';

StudyRoute<void> _studyRoute({required WidgetBuilder builder}) =>
    StudyRoute<void>(
        builder: (context) => StudyTheme(
              child: Builder(builder: builder),
            ));
