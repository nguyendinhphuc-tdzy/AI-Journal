import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/widgets/app_ui.dart';
import '../../../navigation/app_shell.dart';
import '../data/journal_entry.dart';
import '../journal_scope.dart';
import '../data/api_ai_service.dart';
import '../../onboarding/data/data_policy.dart';
import '../../onboarding/data/onboarding_scope.dart';
import 'ai_reflection_screen.dart';
import '../../onboarding/data/onboarding_store.dart';
import '../../profile/data/writing_preferences.dart';
import '../../sound/app_sound.dart';
import '../../streak/streak_screen.dart';
import '../../streak/streak_state.dart';

class WriteJournalScreen extends StatefulWidget {
  const WriteJournalScreen({super.key, this.entry});

  static const title = 'Nhật ký hôm nay';
  static const prompt = 'Hôm nay bạn cảm thấy thế nào?';
  static const followUpPrompt =
      'Gần đây, điều gì trong chuyện học khiến bạn thấy áp lực?';
  static const finishLabel = 'Lưu nhật ký';
  static const deeperLabel = 'Nhìn lại cùng bạn';
  static const confirmTitle = 'Bạn đã hoàn tất chưa?';
  static const confirmBody =
      'Nhật ký sẽ được lưu. Bạn vẫn có thể mở lại để viết tiếp từ Trang chủ.';

  /// An entry to keep writing (e.g. from Home); saving updates the same id.
  final JournalEntry? entry;

  @override
  State<WriteJournalScreen> createState() => _WriteJournalScreenState();
}

class _WriteJournalScreenState extends State<WriteJournalScreen> {
  late final _controller = TextEditingController(text: widget.entry?.body);
  late JournalEntry? _saved = widget.entry;
  bool _saving = false;
  final _followUpController = TextEditingController();
  final _followUpFocus = FocusNode();
  final _scrollController = ScrollController();
  bool _hasFollowUp = false;
  JournalPaper _paper = JournalPaper.doPaper;
  bool _hasText = false;
  double _textSize = 16;
  WritingPreferences? _preferences;
  bool _changingPaper = false;

  @override
  void initState() {
    super.initState();
    _hasText = _controller.text.trim().isNotEmpty;
    // The pen (or the eraser) while writing comes from AppSound, as in
    // every text field.
    _controller.addListener(_onTextChanged);
    // Back to a page written before.
    if (widget.entry != null) AppSound.instance.play(SoundCue.pageTurn);
    _loadPreferences();
  }

  void _onTextChanged() {
    final hasText = _controller.text.trim().isNotEmpty;
    if (hasText != _hasText) setState(() => _hasText = hasText);
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Chưa tải được tùy chỉnh. Đang dùng giao diện mặc định.')));
      }
    }
  }

  Future<void> _choosePaper() async {
    if (_changingPaper) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final chosen = await showAppSheet<JournalPaper>(
      context,
      builder: (sheet) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Nền giấy', style: AppText.sectionTitle),
          const SizedBox(height: AppSpacing.sm),
          const Text('Chọn trang giấy bạn muốn viết lên.',
              style: AppText.bodySecondary),
          const SizedBox(height: AppSpacing.lg),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (index, paper) in JournalPaper.values.indexed) ...[
                if (index > 0) const SizedBox(width: 12),
                Expanded(
                  child: _PaperChoice(
                    paper: paper,
                    selected: paper == _paper,
                    onTap: () => Navigator.pop(sheet, paper),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
    if (!mounted || chosen == null || chosen == _paper) return;
    setState(() => _changingPaper = true);
    try {
      final prefs = _preferences ?? await WritingPreferences.open();
      await prefs.savePaper(chosen);
      if (!mounted) return;
      setState(() {
        _preferences = prefs;
        _paper = chosen;
      });
      AppSound.instance.play(SoundCue.paper);
      await prefs.feedback();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Chưa lưu được nền giấy. Hãy thử lại.')));
      }
    } finally {
      if (mounted) setState(() => _changingPaper = false);
    }
  }

  String get _entryText => [
        _controller.text.trim(),
        if (_hasFollowUp) _followUpController.text.trim(),
      ].where((answer) => answer.isNotEmpty).join('\n\n');

  void _showEmptyEntryMessage() {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content:
          Text('Vui lòng viết ít nhất một dòng nhật ký trước khi hoàn thành.'),
    ));
  }

  void _goDeeper() {
    if (_hasFollowUp || _controller.text.trim().isEmpty) return;
    setState(() => _hasFollowUp = true);
    _preferences?.feedback();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _followUpFocus.requestFocus();
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _finishEntry() async {
    if (_saving) return;
    FocusManager.instance.primaryFocus?.unfocus();
    if (_entryText.isEmpty) {
      _showEmptyEntryMessage();
      return;
    }
    final confirmed = await showAppSheet<bool>(
      context,
      builder: (sheet) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(WriteJournalScreen.confirmTitle,
              style: AppText.sectionTitle),
          const SizedBox(height: AppSpacing.sm),
          const Text(WriteJournalScreen.confirmBody, style: AppText.body),
          const SizedBox(height: AppSpacing.xl),
          Row(children: [
            Expanded(
              child: AppSecondaryButton(
                label: 'Quay lại',
                onPressed: () => Navigator.pop(sheet, false),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: AppPrimaryButton(
                label: 'Xác nhận',
                onPressed: () => Navigator.pop(sheet, true),
              ),
            ),
          ]),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    // Recheck after the modal: content could have changed while it was open.
    final text = _entryText;
    if (_saving) return;
    if (text.isEmpty) {
      _showEmptyEntryMessage();
      return;
    }

    setState(() => _saving = true);
    final saved = _saved;
    // Preserve guided metadata only while the journal body is unchanged.
    final content = JournalContent(
      body: text,
      mood: saved?.content.mood,
      guided: saved != null && saved.body == text ? saved.content.guided : null,
      // Written in Study, it stays a Study entry when edited here.
      source: saved?.content.source,
    );
    final scopedOnboarding = OnboardingScope.maybeOf(context);
    final journals = JournalScope.of(context);
    final remoteAi = AiRemoteScope.maybeOf(context);
    bool useAi;
    try {
      final settings = scopedOnboarding ?? await OnboardingStore.open();
      // Cloud AI needs an explicit, current policy choice; never use mock insights.
      useAi = remoteAi != null &&
          settings.aiEnabled == true &&
          settings.aiPolicyVersion == DataPolicy.localOllama.version;
      if (!mounted) return;
      _saved = saved == null
          ? await journals.create(content)
          : await journals.update(saved.id, content);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Chưa lưu được nhật ký. Nội dung vẫn còn ở đây.')));
      return;
    }
    if (!mounted) return;
    setState(() => _saving = false);
    AppSound.instance.play(SoundCue.penClick);
    await _preferences?.feedback();
    if (!mounted) return;
    if (useAi) {
      _openReflection();
    } else if (!StreakState.shared.completedToday) {
      // No reflection without AI, but the day's first entry still counts:
      // the streak celebrates it, then Home.
      FocusManager.instance.primaryFocus?.unfocus();
      Navigator.of(context).push(StreakScreen.route());
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Đã lưu nhật ký. Phản hồi AI đang tắt.')));
      if (Navigator.of(context).canPop()) {
        Navigator.pop(context);
      } else {
        _selectTab(0);
      }
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _followUpController.dispose();
    _followUpFocus.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _openReflection() {
    FocusManager.instance.primaryFocus?.unfocus();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AiReflectionScreen(
          journalContent: _entryText,
          remote: AiRemoteScope.maybeOf(context),
        ),
      ),
    );
  }

  void _selectTab(int index) {
    FocusManager.instance.primaryFocus?.unfocus();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => AppShell(initialIndex: index)),
      (_) => false,
    );
  }

  /// Line height of the writing, in multiples of the text size: roomy, like
  /// a notebook's rows.
  static const _lineSpacing = 1.75;

  /// Space between the page's edges and the writing.
  static const _gutter = AppSpacing.xl;

  TextStyle get _writingStyle =>
      AppText.body.copyWith(fontSize: _textSize, height: _lineSpacing);

  @override
  Widget build(BuildContext context) {
    final ruled = _paper == JournalPaper.ruled;
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: AppColors.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // The whole screen is the page, up to its edges.
          Positioned.fill(child: JournalPaperView(paper: _paper, margin: true)),
          SafeArea(
            child: LayoutBuilder(builder: (context, page) {
              // Short (landscape, or the keyboard up): tools and actions
              // share one row.
              final compact = page.maxHeight < 420;
              return Column(
                children: [
                  _buildHeader(),
                  Expanded(
                    child: LayoutBuilder(builder: (context, constraints) {
                      // Leave typing space when the keyboard reduces height.
                      final mascotSize = math.min(
                          110.0,
                          math.min(constraints.maxWidth,
                              constraints.maxHeight * 0.4));
                      return Stack(
                        children: [
                          Positioned.fill(
                            child: SingleChildScrollView(
                              controller: _scrollController,
                              padding: const EdgeInsets.fromLTRB(
                                  _gutter, AppSpacing.sm, _gutter, 0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _buildPrompt(WriteJournalScreen.prompt),
                                  const SizedBox(height: AppSpacing.md),
                                  if (_hasFollowUp) ...[
                                    _RuledLines(
                                      style: _writingStyle,
                                      on: ruled,
                                      bleed: _gutter,
                                      child: Text(
                                        _controller.text,
                                        strutStyle:
                                            _RuledLines.strut(_writingStyle),
                                        style: _writingStyle.copyWith(
                                            color: AppColors.textSecondary),
                                      ),
                                    ),
                                    const SizedBox(height: AppSpacing.xl),
                                    _buildPrompt(
                                        WriteJournalScreen.followUpPrompt),
                                    const SizedBox(height: AppSpacing.md),
                                  ],
                                  _RuledLines(
                                    style: _writingStyle,
                                    on: ruled,
                                    bleed: _gutter,
                                    // The rows carry on down the page.
                                    below: 2000,
                                    child: TextField(
                                      key: ValueKey(_hasFollowUp),
                                      controller: _hasFollowUp
                                          ? _followUpController
                                          : _controller,
                                      focusNode:
                                          _hasFollowUp ? _followUpFocus : null,
                                      minLines: 3,
                                      maxLines: null,
                                      keyboardType: TextInputType.multiline,
                                      textCapitalization:
                                          TextCapitalization.sentences,
                                      cursorColor: AppColors.primaryAction,
                                      style: _writingStyle,
                                      strutStyle:
                                          _RuledLines.strut(_writingStyle),
                                      onTapOutside: (_) => FocusManager
                                          .instance.primaryFocus
                                          ?.unfocus(),
                                      decoration: InputDecoration(
                                        isCollapsed: true,
                                        hintText: _hasFollowUp
                                            ? 'Chia sẻ suy nghĩ của bạn...'
                                            : 'Bắt đầu viết...',
                                        hintStyle: _writingStyle.copyWith(
                                            color: AppColors.textSecondary),
                                        filled: false,
                                        border: InputBorder.none,
                                        enabledBorder: InputBorder.none,
                                        focusedBorder: InputBorder.none,
                                        contentPadding: EdgeInsets.zero,
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: mascotSize),
                                ],
                              ),
                            ),
                          ),
                          if (mascotSize >= 64)
                            Positioned(
                              right: _gutter - AppSpacing.sm,
                              bottom: 0,
                              width: mascotSize,
                              height: mascotSize,
                              child: IgnorePointer(
                                child: Semantics(
                                  label: 'Nudaeng đang đọc sách',
                                  child: ColorFiltered(
                                    // Remove near-white pixels, including white
                                    // details inside the mascot, as on Home.
                                    colorFilter: const ColorFilter.matrix([
                                      // dart format off
                                      1, 0, 0, 0, 0,
                                      0, 1, 0, 0, 0,
                                      0, 0, 1, 0, 0,
                                      -4.252, -14.304, -1.444, 20, 0,
                                      // dart format on
                                    ]),
                                    child: Image.asset(
                                      'assets/images/docsach.gif',
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    }),
                  ),
                  _buildActions(compact: compact),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  /// Close, the title, and the paper: nothing else above the page.
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      child: Row(children: [
        IconButton(
          tooltip: 'Đóng',
          icon: const Icon(Icons.close_rounded),
          color: AppColors.textPrimary,
          onPressed: () => Navigator.of(context).pop(),
        ),
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Semantics(
              header: true,
              child: const Text(
                WriteJournalScreen.title,
                textAlign: TextAlign.center,
                style: AppText.sectionTitle,
              ),
            ),
          ),
        ),
        IconButton(
          tooltip: 'Đổi nền nhật ký',
          icon: const Icon(Icons.palette_outlined),
          color: AppColors.textPrimary,
          onPressed: _changingPaper ? null : _choosePaper,
        ),
      ]),
    );
  }

  Widget _buildPrompt(String prompt) {
    return Container(
      padding: const EdgeInsets.only(left: 12),
      decoration: const BoxDecoration(
        border:
            Border(left: BorderSide(color: AppColors.primaryAction, width: 3)),
      ),
      child: Text(prompt,
          style: AppText.cardTitle.copyWith(color: AppColors.primaryAction)),
    );
  }

  /// Tools on their own line, then the two actions across the page; on a
  /// short screen all in one row.
  Widget _buildActions({required bool compact}) {
    // Attachment flows are not implemented in this UI prototype.
    const tools = [
      IconButton(
        tooltip: 'Nhập bằng giọng nói (sắp có)',
        onPressed: null,
        disabledColor: AppColors.textSecondary,
        icon: Icon(Icons.mic_none_outlined),
      ),
      IconButton(
        tooltip: 'Thêm ảnh (sắp có)',
        onPressed: null,
        disabledColor: AppColors.textSecondary,
        icon: Icon(Icons.image_outlined),
      ),
    ];
    final finish = AppSecondaryButton(
      label: WriteJournalScreen.finishLabel,
      onPressed: _saving ? null : _finishEntry,
      compact: compact,
    );
    final deeper = AppPrimaryButton(
      label: WriteJournalScreen.deeperLabel,
      icon: Icons.auto_awesome,
      // Something to go deeper on first.
      onPressed: _hasFollowUp || !_hasText ? null : _goDeeper,
      compact: compact,
    );
    if (compact) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.md, AppSpacing.xs, AppSpacing.md, AppSpacing.sm),
        child: Row(children: [
          ...tools,
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                finish,
                const SizedBox(width: AppSpacing.sm),
                deeper,
              ]),
            ),
          ),
        ]),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          _gutter, AppSpacing.xs, _gutter, AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The icons' own padding lines their glyphs up with the writing.
          Transform.translate(
            offset: const Offset(-AppSpacing.sm, 0),
            child: const Row(children: tools),
          ),
          const SizedBox(height: AppSpacing.sm),
          LayoutBuilder(
            builder: (context, actions) => actions.maxWidth >= 320
                // Finish as wide as its word; going deeper, the main
                // action, takes the rest, its label on one line.
                ? Row(children: [
                    finish,
                    const SizedBox(width: 12),
                    Expanded(child: deeper),
                  ])
                // Too narrow for both labels side by side: stacked.
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      deeper,
                      const SizedBox(height: AppSpacing.sm),
                      finish,
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

/// A journal page's paper, filling its box: the sheet's texture, or the
/// app background for plain paper. With [margin], the ruled sheet shows
/// its margin line (its rows are drawn under the text, [_RuledLines]).
class JournalPaperView extends StatelessWidget {
  const JournalPaperView({super.key, required this.paper, this.margin = false});

  final JournalPaper paper;
  final bool margin;

  /// The ruling's colours, taken from the printed sheet they replace.
  static const ruleColor = Color(0xFFB9C6D1);
  static const marginColor = Color(0xFFDDB9BE);

  @override
  Widget build(BuildContext context) {
    final asset = paper.asset;
    if (asset == null) {
      return const ColoredBox(
          key: ValueKey('journal-paper-plain'), color: AppColors.background);
    }
    return Stack(fit: StackFit.expand, children: [
      Image.asset(
        asset,
        key: ValueKey('journal-paper-${paper.name}'),
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) =>
            const ColoredBox(color: AppColors.background),
      ),
      if (margin && paper == JournalPaper.ruled)
        const Positioned(
          left: 14,
          top: 0,
          bottom: 0,
          width: 1.2,
          child: ColoredBox(color: marginColor),
        ),
    ]);
  }
}

/// Notebook rows under [child]'s text: one line under each line of [style]
/// (the text must use [strut] so every line is exactly that tall), across
/// the page ([bleed] past each side) and on for [below] past the text.
class _RuledLines extends StatelessWidget {
  const _RuledLines({
    required this.style,
    required this.child,
    required this.on,
    this.bleed = 0,
    this.below = 0,
  });

  final TextStyle style;
  final Widget child;
  final bool on;
  final double bleed;
  final double below;

  static StrutStyle strut(TextStyle style) =>
      StrutStyle.fromTextStyle(style, forceStrutHeight: true);

  @override
  Widget build(BuildContext context) {
    if (!on) return child;
    // Where the letters sit within one line.
    final metrics = TextPainter(
      text: TextSpan(text: 'Ág', style: style),
      strutStyle: strut(style),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final line = metrics.preferredLineHeight;
    final baseline =
        metrics.computeDistanceToActualBaseline(TextBaseline.alphabetic);
    metrics.dispose();
    return CustomPaint(
      key: const ValueKey('journal-ruled-lines'),
      painter: _RowsPainter(
          line: line, baseline: baseline, bleed: bleed, below: below),
      child: child,
    );
  }
}

class _RowsPainter extends CustomPainter {
  const _RowsPainter(
      {required this.line,
      required this.baseline,
      required this.bleed,
      required this.below});

  final double line;
  final double baseline;
  final double bleed;
  final double below;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = JournalPaperView.ruleColor
      ..strokeWidth = 1;
    // Just under the letters, as on a printed row.
    for (var y = baseline + 3; y < size.height + below; y += line) {
      canvas.drawLine(Offset(-bleed, y), Offset(size.width + bleed, y), paint);
    }
  }

  @override
  bool shouldRepaint(_RowsPainter old) =>
      old.line != line ||
      old.baseline != baseline ||
      old.bleed != bleed ||
      old.below != below;
}

/// One paper in the picker: a small sheet of it, its name below; the
/// chosen one outlined with a check.
class _PaperChoice extends StatelessWidget {
  const _PaperChoice(
      {required this.paper, required this.selected, required this.onTap});

  final JournalPaper paper;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        selected: selected,
        inMutuallyExclusiveGroup: true,
        label: paper.label,
        excludeSemantics: true,
        child: InkWell(
          key: ValueKey('journal-paper-option-${paper.name}'),
          onTap: onTap,
          borderRadius:
              const BorderRadius.all(Radius.circular(AppRadius.small)),
          child: Column(children: [
            AspectRatio(
              aspectRatio: .62,
              child: DecoratedBox(
                position: DecorationPosition.foreground,
                decoration: BoxDecoration(
                  borderRadius:
                      const BorderRadius.all(Radius.circular(AppRadius.small)),
                  border: Border.all(
                      color:
                          selected ? AppColors.primaryAction : AppColors.border,
                      width: selected ? 2 : 1),
                ),
                child: ClipRRect(
                  borderRadius:
                      const BorderRadius.all(Radius.circular(AppRadius.small)),
                  child: Stack(fit: StackFit.expand, children: [
                    JournalPaperView(paper: paper),
                    // Rows and a margin, so the ruled sheet reads as ruled.
                    if (paper == JournalPaper.ruled)
                      const CustomPaint(painter: _ThumbnailRows()),
                    if (selected)
                      const Positioned(
                        top: 6,
                        right: 6,
                        child: Icon(Icons.check_circle_rounded,
                            size: 20, color: AppColors.primaryAction),
                      ),
                  ]),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              paper.label,
              textAlign: TextAlign.center,
              style: AppText.meta.copyWith(
                  color: selected
                      ? AppColors.primaryAction
                      : AppColors.textPrimary,
                  fontWeight: selected ? FontWeight.w600 : null),
            ),
          ]),
        ),
      );
}

class _ThumbnailRows extends CustomPainter {
  const _ThumbnailRows();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = JournalPaperView.ruleColor
      ..strokeWidth = 1;
    for (var y = 18.0; y < size.height; y += 9) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    paint.color = JournalPaperView.marginColor;
    canvas.drawLine(const Offset(9, 0), Offset(9, size.height), paint);
  }

  @override
  bool shouldRepaint(_ThumbnailRows old) => false;
}
