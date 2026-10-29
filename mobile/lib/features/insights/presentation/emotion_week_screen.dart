import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/widgets/app_ui.dart';
import '../../journal/data/analysis_archive.dart';
import '../../journal/data/journal_entry.dart';
import '../../journal/journal_scope.dart';
import '../../journal/presentation/sentence_case.dart';
import '../../onboarding/data/onboarding_scope.dart';
import '../data/emotion_week.dart';

/// "Cảm xúc tuần này", opened from "Nhìn lại tuần này" on Home: the week's
/// feelings on a line, from the AI analyses kept with each entry; a day to
/// read by tapping or sliding along it; the feelings that stood out.
class EmotionWeekScreen extends StatefulWidget {
  const EmotionWeekScreen({super.key});

  static const title = 'Cảm xúc tuần này';
  static const chartTitle = 'Cảm xúc qua từng ngày';
  static const scoreLabel = 'ĐIỂM CẢM XÚC';
  static const hint = 'Chạm hoặc vuốt trên biểu đồ để xem từng ngày';
  static const aiNote = 'Theo phân tích của AI cho từng bài viết. Đây là ước '
      'lượng để bạn nhìn lại, không phải đánh giá hay chẩn đoán.';
  static const standoutTitle = 'Cảm xúc nổi bật';
  static const dayFeelings = 'CẢM XÚC TRONG NGÀY';
  static const noEntries = 'Tuần này bạn chưa viết bài nào.';
  static const noAnalyses = 'Chưa có phân tích AI cho tuần này. Phân tích '
      'được lưu khi bạn lưu nhật ký lúc phản hồi AI đang bật.';
  static const dayEmpty = 'Ngày này chưa có bài viết.';
  static const dayNotAnalysed = 'Chưa có phân tích AI cho bài viết ngày này.';
  static const loadFailed = 'Chưa tải được nhật ký. Bạn thử lại nhé.';

  static const weekdays = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
  static const weekdayNames = [
    'Thứ Hai', 'Thứ Ba', 'Thứ Tư', 'Thứ Năm', 'Thứ Sáu', 'Thứ Bảy', 'Chủ Nhật',
  ];

  static String date(DateTime at) =>
      '${at.day.toString().padLeft(2, '0')}/${at.month.toString().padLeft(2, '0')}';

  @override
  State<EmotionWeekScreen> createState() => _EmotionWeekScreenState();
}

class _EmotionWeekScreenState extends State<EmotionWeekScreen> {
  List<JournalEntry>? _entries;
  Map<String, SavedAnalysis> _analyses = const {};
  bool _failed = false;

  /// Weeks back from this one: 0 is this week.
  int _weeksBack = 0;

  /// The day read under the chart, 0 (Monday) to 6.
  int? _selected;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_entries == null && !_failed) _load();
  }

  Future<void> _load() async {
    final journals = JournalScope.of(context);
    final userId = OnboardingScope.maybeOf(context)?.userId;
    try {
      final entries = await journals.entries();
      final archive = await AnalysisArchive.open(userId: userId);
      final analyses = {
        for (final entry in entries)
          if (archive.of(entry.id) case final saved?) entry.id: saved,
      };
      if (!mounted) return;
      setState(() {
        _entries = entries;
        _analyses = analyses;
        _failed = false;
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  EmotionWeek _week(List<JournalEntry> entries) => EmotionWeek.of(
      DateTime.now().subtract(Duration(days: 7 * _weeksBack)),
      entries,
      _analyses);

  /// The day shown: the chosen one, else today (this week) or the last day
  /// with an entry.
  int _shownDay(EmotionWeek week) {
    if (_selected case final day?) return day;
    if (_weeksBack == 0) return DateTime.now().weekday - 1;
    final written = week.days.lastIndexWhere((day) => day.entries > 0);
    return written < 0 ? 6 : written;
  }

  void _moveWeek(int by) => setState(() {
        _weeksBack = math.max(0, _weeksBack + by);
        _selected = null;
      });

  @override
  Widget build(BuildContext context) {
    final entries = _entries;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 12),
            child: AppPageHeader(
              title: EmotionWeekScreen.title,
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
            child: _failed
                ? _message(EmotionWeekScreen.loadFailed, retry: true)
                : entries == null
                    ? const Center(child: CircularProgressIndicator())
                    : _body(_week(entries)),
          ),
        ]),
      ),
    );
  }

  Widget _message(String text, {bool retry = false}) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(text, textAlign: TextAlign.center, style: AppText.body),
            if (retry) ...[
              const SizedBox(height: AppSpacing.md),
              TextButton(
                onPressed: () {
                  setState(() => _failed = false);
                  _load();
                },
                child: const Text('Thử lại'),
              ),
            ],
          ]),
        ),
      );

  Widget _body(EmotionWeek week) {
    final shown = _shownDay(week);
    final day = week.days[shown];
    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 40),
      children: [
        _weekSwitcher(week),
        const SizedBox(height: AppSpacing.md),
        const Text(EmotionWeekScreen.chartTitle, style: AppText.sectionTitle),
        const SizedBox(height: 12),
        _Card(
          child: week.entries == 0
              ? const Text(EmotionWeekScreen.noEntries, style: AppText.body)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _dayScore(day),
                    const SizedBox(height: AppSpacing.md),
                    _EmotionChart(
                      week: week,
                      selected: shown,
                      onSelect: (index) => setState(() => _selected = index),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    const Text(EmotionWeekScreen.hint,
                        textAlign: TextAlign.center, style: AppText.meta),
                    const SizedBox(height: AppSpacing.lg),
                    ..._dayDetails(day),
                  ],
                ),
        ),
        if (week.entries > 0) ...[
          const SizedBox(height: AppSpacing.xl),
          const Text(EmotionWeekScreen.standoutTitle,
              style: AppText.sectionTitle),
          const SizedBox(height: 12),
          _Card(child: _standout(week)),
        ],
        const SizedBox(height: AppSpacing.lg),
        const Text(EmotionWeekScreen.aiNote, style: AppText.meta),
      ],
    );
  }

  Widget _weekSwitcher(EmotionWeek week) => Row(children: [
        IconButton(
          tooltip: 'Tuần trước',
          onPressed: () => _moveWeek(1),
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        Expanded(
          child: Text(
            _weeksBack == 0
                ? 'Tuần này · ${EmotionWeekScreen.date(week.monday)} – '
                    '${EmotionWeekScreen.date(week.sunday)}'
                : '${EmotionWeekScreen.date(week.monday)} – '
                    '${EmotionWeekScreen.date(week.sunday)}/${week.sunday.year}',
            textAlign: TextAlign.center,
            style: AppText.label,
          ),
        ),
        IconButton(
          tooltip: 'Tuần sau',
          onPressed: _weeksBack == 0 ? null : () => _moveWeek(-1),
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ]);

  Widget _dayScore(EmotionDay day) {
    final score = day.score;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.end,
          spacing: AppSpacing.sm,
          children: [
            Text(score == null ? '–' : '${score.round()}',
                style: AppText.pageTitle.copyWith(
                    fontSize: 40, height: 1, color: AppColors.primaryAction)),
            const Padding(
              padding: EdgeInsets.only(bottom: 4),
              child: Text(EmotionWeekScreen.scoreLabel, style: AppText.meta),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '${EmotionWeekScreen.weekdayNames[day.date.weekday - 1]}, '
          '${EmotionWeekScreen.date(day.date)}'
          '${day.entries > 0 ? ' (${day.entries} bài)' : ''}',
          style: AppText.meta,
        ),
      ],
    );
  }

  List<Widget> _dayDetails(EmotionDay day) {
    if (day.entries == 0) {
      return const [Text(EmotionWeekScreen.dayEmpty, style: AppText.body)];
    }
    if (day.analyses.isEmpty) {
      return const [
        Text(EmotionWeekScreen.dayNotAnalysed, style: AppText.body)
      ];
    }
    return [
      Text(sentenceCase(day.analyses.first.analysis.observation),
          style: AppText.body.copyWith(height: 1.6)),
      const SizedBox(height: AppSpacing.md),
      const Text(EmotionWeekScreen.dayFeelings, style: AppText.meta),
      const SizedBox(height: AppSpacing.sm),
      Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, children: [
        for (final emotion in day.emotions) _chip(sentenceCase(emotion)),
      ]),
    ];
  }

  Widget _standout(EmotionWeek week) {
    final standout = week.standout;
    if (standout.isEmpty) {
      return Text(
          week.analysed == 0
              ? EmotionWeekScreen.noAnalyses
              : 'Chưa xếp được cảm xúc nào của tuần này vào nhóm.',
          style: AppText.body);
    }
    final total = standout.fold(0, (sum, item) => sum + item.count);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, (:group, :count)) in standout.take(4).indexed) ...[
          if (i > 0) const SizedBox(height: 12),
          MergeSemantics(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  Expanded(
                    child: Text(group.label,
                        style: i == 0 ? AppText.label : AppText.body),
                  ),
                  Text('$count lần', style: AppText.meta),
                ]),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: count / total,
                    minHeight: 8,
                    color: i == 0 ? AppColors.primaryAction : AppColors.primary,
                    backgroundColor: AppColors.primaryLight,
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        Text(
            'Từ ${week.analysed} bài có phân tích trong '
            '${week.entries} bài tuần này.',
            style: AppText.meta),
      ],
    );
  }

  static Widget _chip(String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: const ShapeDecoration(
          color: AppColors.primaryLight,
          shape: StadiumBorder(),
        ),
        child: Text(label, style: AppText.body),
      );
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: AppColors.border),
        ),
        child: child,
      );
}

/// The week as a line, 0–100, a point per day with a score; tap or slide
/// to choose a day. The weekday names under it are buttons too.
class _EmotionChart extends StatelessWidget {
  const _EmotionChart({
    required this.week,
    required this.selected,
    required this.onSelect,
  });

  final EmotionWeek week;
  final int selected;
  final ValueChanged<int> onSelect;

  static const _height = 180.0;

  /// Left room for the scale's numbers.
  static const _axis = 32.0;

  int _dayAt(double x, double width) {
    final step = (width - _axis) / 6;
    return ((x - _axis) / step).round().clamp(0, 6);
  }

  @override
  Widget build(BuildContext context) {
    final scores = [for (final day in week.days) day.score];
    return Column(children: [
      LayoutBuilder(
        builder: (context, box) => Semantics(
          label: [
            for (final (i, day) in week.days.indexed)
              '${EmotionWeekScreen.weekdayNames[i]}: '
                  '${day.score == null ? 'chưa có điểm' : '${day.score!.round()} điểm'}',
          ].join('. '),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (details) =>
                onSelect(_dayAt(details.localPosition.dx, box.maxWidth)),
            onHorizontalDragUpdate: (details) =>
                onSelect(_dayAt(details.localPosition.dx, box.maxWidth)),
            child: CustomPaint(
              size: Size(box.maxWidth, _height),
              painter: _ChartPainter(
                scores: scores,
                selected: selected,
                axis: _axis,
                labelStyle: AppText.meta,
              ),
            ),
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.only(left: _axis - 20),
        child: Row(children: [
          for (final (i, name) in EmotionWeekScreen.weekdays.indexed)
            Expanded(
              child: Semantics(
                button: true,
                selected: i == selected,
                label: EmotionWeekScreen.weekdayNames[i],
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppRadius.small),
                  onTap: () => onSelect(i),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 40),
                    child: Center(
                      child: ExcludeSemantics(
                        child: Text(name,
                            style: AppText.meta.copyWith(
                              color: i == selected
                                  ? AppColors.primaryAction
                                  : AppColors.textSecondary,
                              fontWeight: i == selected
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                            )),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ]),
      ),
    ]);
  }
}

class _ChartPainter extends CustomPainter {
  _ChartPainter({
    required this.scores,
    required this.selected,
    required this.axis,
    required this.labelStyle,
  });

  final List<double?> scores;
  final int selected;
  final double axis;
  final TextStyle labelStyle;

  static const _top = 8.0;
  static const _bottom = 8.0;

  @override
  void paint(Canvas canvas, Size size) {
    final left = axis;
    final width = size.width - left;
    final height = size.height - _top - _bottom;
    double xOf(int day) => left + width * day / 6;
    double yOf(double score) => _top + height * (1 - score / 100);

    final grid = Paint()
      ..color = AppColors.border
      ..strokeWidth = 1;
    for (final mark in const [0, 25, 50, 75, 100]) {
      final y = yOf(mark.toDouble());
      if (mark == 50) {
        // The middle, dashed.
        for (var x = left; x < size.width; x += 8) {
          canvas.drawLine(
              Offset(x, y), Offset(math.min(x + 4, size.width), y), grid);
        }
      } else {
        canvas.drawLine(Offset(left, y), Offset(size.width, y), grid);
      }
      final label = TextPainter(
        text: TextSpan(text: '$mark', style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      label.paint(canvas,
          Offset(left - label.width - 8, y - label.height / 2));
    }

    // The chosen day.
    canvas.drawLine(
      Offset(xOf(selected), _top),
      Offset(xOf(selected), _top + height),
      Paint()
        ..color = AppColors.border
        ..strokeWidth = 2,
    );

    final points = [
      for (final (i, score) in scores.indexed)
        if (score != null) (day: i, at: Offset(xOf(i), yOf(score))),
    ];
    if (points.length > 1) {
      final path = Path()..moveTo(points.first.at.dx, points.first.at.dy);
      for (final point in points.skip(1)) {
        path.lineTo(point.at.dx, point.at.dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = AppColors.primaryAction
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeJoin = StrokeJoin.round,
      );
    }
    for (final point in points) {
      final chosen = point.day == selected;
      canvas.drawCircle(point.at, chosen ? 7 : 4.5,
          Paint()..color = AppColors.primaryAction);
      if (chosen) {
        canvas.drawCircle(point.at, 3, Paint()..color = AppColors.surface);
      }
    }
  }

  @override
  bool shouldRepaint(_ChartPainter old) =>
      old.selected != selected || old.scores != scores;
}
