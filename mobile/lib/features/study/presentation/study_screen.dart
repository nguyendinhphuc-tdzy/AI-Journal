import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import 'nudaeng_view.dart';
import 'nudaeng_artwork.dart';
import 'study_detail_layout.dart';
import 'study_motion.dart';
import 'study_theme.dart';
import '../data/study_mock_data.dart';

/// Study stays local/mock until its API contract is finalized. This state is
/// deliberately feature-scoped so navigation and progress work in the UI demo.
class StudyScreen extends StatelessWidget {
  const StudyScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const StudyTheme(child: _StudyOverview());
}

class _StudyOverview extends StatefulWidget {
  const _StudyOverview();

  @override
  State<_StudyOverview> createState() => _StudyScreenState();
}

class _StudyScreenState extends State<_StudyOverview> {
  String _filter = 'Tất cả';
  bool _joined = false;
  bool _paused = false;
  bool _left = false;
  final Map<int, String> _drafts = {};
  final Set<int> _doneTasks = <int>{};
  final Set<int> _doneLessons = <int>{};
  final StudyMockSession _session = StudyMockSession();
  bool _caseRead = false;

  static const _items = <_StudyItem>[
    _StudyItem(
        'Skills',
        'Khóa học',
        'Viết điều biết ơn mỗi ngày',
        'Một cách nhẹ nhàng để nhận ra điều đang nâng đỡ bạn.',
        '3 bài · 12 phút',
        course: true,
        practicePrompt: coursePracticePrompt,
        order: 3),
    _StudyItem('Framework', 'Framework', 'Clear My Mind',
        'Gỡ rối một suy nghĩ bằng vài bước viết chậm rãi.', 'Mẫu viết · 8 phút',
        framework: true, order: 2),
    _StudyItem(
        'Case study',
        'Bài đọc',
        'Nhìn lại những điều nhỏ đã làm được',
        'Một bài đọc ngắn về cách ghi nhận tiến bộ của chính mình.',
        'Bài đọc · 5 phút',
        order: 1),
  ];

  List<_StudyItem> get _visible {
    final result = _items
        .where((item) => _filter == 'Tất cả' || item.category == _filter)
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
                return false;
              })));
    }
  }

  void _markRead(int lesson) => setState(() => _doneLessons.add(lesson));

  void _openChallenge() {
    final detail = _studyRoute(
      builder: (_) => _ChallengeDetailScreen(
        joined: _joined,
        completed: _doneTasks.length == _prompts.length,
        onJoin: () => setState(() {
          _joined = true;
          _paused = false;
        }),
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
          onLeave: () => setState(() {
            _left = true;
            _paused = false;
          }),
          onPause: (value) => setState(() {
            _paused = value;
            _left = false;
          }),
          onComplete: (task) => setState(() {
            _joined = true;
            _doneTasks.add(task);
          }),
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
            _TitleWithHelp(
                title: 'Study',
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
                help: 'Học cách viết qua khóa học, framework và bài đọc ngắn. '
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
            _TitleWithHelp(
                title: 'Khám phá cách viết',
                style: Theme.of(context).textTheme.titleLarge,
                help: 'Khóa học gồm vài bài nối tiếp nhau. Framework là mẫu '
                    'viết theo từng bước. Case study là một bài đọc ngắn để '
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

/// Heading with a "?" that opens its description on demand, keeping the
/// overview free of explanatory copy.
class _TitleWithHelp extends StatelessWidget {
  const _TitleWithHelp(
      {required this.title, required this.style, required this.help});
  final String title;
  final TextStyle? style;
  final String help;

  void _show(BuildContext context) => showModalBottomSheet<void>(
        context: context,
        sheetAnimationStyle: StudyMotion.sheet(context),
        backgroundColor: AppColors.surface,
        barrierColor: Colors.black.withValues(alpha: .35),
        shape: const RoundedRectangleBorder(
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(AppRadius.modal))),
        builder: (sheet) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl, AppSpacing.xl, AppSpacing.xl, AppSpacing.md),
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: AppSpacing.md),
                  Text(help),
                  const SizedBox(height: AppSpacing.xl),
                  _PrimaryButton(
                      label: 'Đã hiểu', onPressed: () => Navigator.pop(sheet)),
                ]),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => Row(children: [
        Flexible(child: Text(title, style: style)),
        IconButton(
          tooltip: 'Giới thiệu $title',
          onPressed: () => _show(context),
          icon: const Icon(Icons.help_outline_rounded,
              color: AppColors.textSecondary),
        ),
      ]);
}

/// Content-type pills that scroll sideways, replacing the filter dropdown.
class _FilterChips extends StatelessWidget {
  const _FilterChips({required this.selected, required this.onSelected});
  final String selected;
  final ValueChanged<String> onSelected;

  static const _options = ['Tất cả', 'Skills', 'Framework', 'Case study'];

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
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
          // Title and short description only; type and length live in S02.
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
  final StudyMockSession session;
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
                  eyebrow: '${item.category} · ${item.type}',
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
  final StudyMockSession session;
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Framework')),
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
                      title: 'Clear My Mind',
                      prompt: frameworkPrompt,
                      returnLabel: 'Về framework')))),
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
  final StudyMockSession session;
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
                  'Bạn muốn bắt đầu viết bằng một prompt thật nhỏ.',
                  'Bạn muốn có nhịp gợi ý nhưng không bị áp lực theo ngày.'
                ]),
                const SizedBox(height: AppSpacing.xl),
                Text('Cách tham gia',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: AppSpacing.sm),
                const Text(
                    'Mỗi nhiệm vụ là một prompt. Nhiệm vụ được hoàn thành khi bạn lưu một entry.'),
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
      required this.onComplete});
  final Set<int> done;
  final StudyMockSession session;
  final Map<int, String> drafts;
  final bool paused;
  final bool left;
  final VoidCallback onLeave;
  final ValueChanged<bool> onPause;
  final ValueChanged<int> onComplete;

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

  Future<void> _leave() async {
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
              title: const Text('Rời challenge?'),
              content: const Text('Nhật ký đã viết vẫn được giữ.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(dialog, false),
                    child: const Text('Ở lại')),
                TextButton(
                    onPressed: () => Navigator.pop(dialog, true),
                    child: const Text('Rời challenge')),
              ],
            ));
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
              onDraftChanged: (text) => widget.drafts[current] = text,
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
  final StudyMockSession session;
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
  late final _controller = TextEditingController(text: widget.initialText);
  bool _saving = false;
  String? _question;
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _deeper() {
    if (_controller.text.trim().isEmpty) return;
    showModalBottomSheet<void>(
      context: context,
      sheetAnimationStyle: StudyMotion.sheet(context),
      backgroundColor: AppColors.surface,
      barrierColor: Colors.black.withValues(alpha: .35),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppRadius.modal)),
      ),
      builder: (sheet) => Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text('Go Deeper', style: Theme.of(context).textTheme.titleLarge)
            ]),
            const SizedBox(height: AppSpacing.lg),
            const Text(
                'Điều gì khiến khoảnh khắc này khác với những ngày khác?'),
            const SizedBox(height: AppSpacing.lg),
            _PrimaryButton(
              label: 'Dùng câu hỏi',
              onPressed: () {
                setState(() => _question =
                    'Điều gì khiến khoảnh khắc này khác với những ngày khác?');
                Navigator.pop(sheet);
              },
            ),
            TextButton(
                onPressed: () => Navigator.pop(sheet),
                child: const Text('Bỏ qua')),
          ],
        ),
      ),
    );
  }

  Future<void> _finish() async {
    if (_saving || _controller.text.trim().isEmpty) return;
    setState(() => _saving = true);
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;
    widget.session.save(_controller.text.trim(), widget.prompt, widget.source);
    widget.onSaved?.call();
    await Navigator.of(context).push(_studyRoute(
        builder: (_) => _Reflection(
            returnLabel: widget.returnLabel,
            nextTask: widget.nextTask,
            onWriteNext: widget.onWriteNext)));
    if (mounted) Navigator.pop(context);
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
                    Text('Bản nháp', style: _meta(context)),
                    const SizedBox(height: AppSpacing.sm),
                    Expanded(
                        child: TextField(
                            controller: _controller,
                            autofocus: true,
                            expands: true,
                            maxLines: null,
                            textAlignVertical: TextAlignVertical.top,
                            onChanged: (text) {
                              widget.onDraftChanged?.call(text);
                              setState(() {});
                            },
                            decoration: InputDecoration(
                                hintText:
                                    'Bắt đầu ở bất cứ nơi nào bạn đang có mặt…',
                                filled: true,
                                fillColor: AppColors.background,
                                border: OutlineInputBorder(
                                    borderRadius:
                                        BorderRadius.circular(AppRadius.input),
                                    borderSide: const BorderSide(
                                        color: AppColors.border))))),
                    if (_question != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(_question!, style: _meta(context))
                    ],
                    const SizedBox(height: AppSpacing.sm),
                    // Explains the disabled actions; space stays reserved.
                    Text(
                        _controller.text.trim().isEmpty
                            ? 'Viết vài dòng để dùng Go Deeper hoặc Hoàn tất.'
                            : '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _meta(context)),
                    const SizedBox(height: AppSpacing.sm),
                    Row(children: [
                      Expanded(
                          child: OutlinedButton(
                              onPressed: _controller.text.trim().isEmpty
                                  ? null
                                  : _deeper,
                              child: const Text('Go Deeper'))),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                          child: _PrimaryButton(
                              label: _saving ? 'Đang lưu…' : 'Hoàn tất',
                              onPressed: _controller.text.trim().isEmpty
                                  ? null
                                  : _finish))
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
                    Text('Entry đã lưu',
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
class _NextTaskNotice extends StatelessWidget {
  const _NextTaskNotice({required this.index});
  final int index;

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
      ]));
}

class _ChallengeCompletion extends StatelessWidget {
  const _ChallengeCompletion({required this.animate, required this.session});
  final bool animate;
  final StudyMockSession session;
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
                    // First completion: tail wag only. The completion drawing
                    // waits until S06 is reopened after leaving it.
                    artwork: animate
                        ? NudaengArtwork.challengeCelebration
                        : NudaengArtwork.challengeCompletion)),
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
  final StudyMockSession session;
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
  final StudyMockEntry entry;
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
  final StudyMockSession session;
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

  Widget _buttonFor(BuildContext context) => FilledButton(
      style: FilledButton.styleFrom(
          backgroundColor: AppColors.primaryAction,
          foregroundColor: AppColors.surface,
          minimumSize: Size(0, height),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          textStyle: Theme.of(context).textTheme.labelLarge,
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg, vertical: 12)),
      onPressed: onPressed,
      child: Text(label, textAlign: TextAlign.center));
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
  const _StudyItem(
      this.category, this.type, this.title, this.description, this.meta,
      {this.course = false,
      this.framework = false,
      this.practicePrompt,
      required this.order});
  final String category;
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
