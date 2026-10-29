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
import '../data/analysis_archive.dart';
import '../data/api_ai_service.dart';
import '../../onboarding/data/onboarding_scope.dart';
import '../../onboarding/data/onboarding_store.dart';
import 'ai_conversation.dart';
import 'ai_reflection_screen.dart';
import 'sentence_case.dart';
import '../../profile/data/writing_preferences.dart';
import '../../sound/app_sound.dart';
import '../../streak/streak_screen.dart';
import '../../streak/streak_state.dart';

class WriteJournalScreen extends StatefulWidget {
  const WriteJournalScreen({super.key, this.entry});

  static const title = 'Nhật ký hôm nay';
  static const prompt = 'Hôm nay bạn cảm thấy thế nào?';
  static const finishLabel = 'Lưu nhật ký';
  static const deeperLabel = 'Nhìn lại cùng bạn';
  static const thinkingLabel = 'Nudaeng đang nghĩ câu hỏi tiếp theo...';
  static const deeperFailed =
      'Chưa tạo được câu hỏi. Nội dung vẫn còn ở đây, bạn thử lại nhé.';
  static const deeperNeedsAccount =
      'Nhìn lại cùng bạn cần đăng nhập. Bạn vẫn viết và lưu nhật ký bình thường.';
  static const aiOff =
      'Phản hồi AI đang tắt. Bạn có thể bật lại trong Hồ sơ.';

  /// After this many questions, a gentle note suggests saving; asking on
  /// is still allowed.
  static const deepNudgeAfter = 5;
  static const deepNudge = 'Bạn đã đi khá sâu rồi, lưu lại nhé?';
  static const reviewLabel = 'Xem phân tích AI';
  static const analyzeLabel = 'Phân tích bài này';
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

  /// "Nhìn lại cùng bạn" so far: each AI question with the answer to it.
  /// The last answer is the one being written.
  final List<({String question, TextEditingController answer})> _deeper = [];

  /// Waiting for the AI's next question.
  bool _asking = false;
  final _followUpFocus = FocusNode();
  final _scrollController = ScrollController();
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
    _loadKeptAnalysis();
  }

  /// The analysis kept for the entry being written again, to read again.
  SavedAnalysis? _kept;

  /// Whether [_kept] was looked for: no "Phân tích bài này" before that.
  bool _keptLoaded = false;

  Future<void> _loadKeptAnalysis() async {
    final entry = widget.entry;
    if (entry == null) return;
    final userId =
        context.getInheritedWidgetOfExactType<OnboardingScope>()?.store.userId;
    try {
      final kept = (await AnalysisArchive.open(userId: userId)).of(entry.id);
      if (mounted) {
        setState(() {
          _kept = kept;
          _keptLoaded = true;
        });
      }
    } catch (_) {}
  }

  /// An entry written before analyses were kept (or while AI was off):
  /// analysed now, as saved, on request. Kept like any other, so it shows
  /// in the lists and the week's emotions.
  Future<void> _analyzeOld(ApiAIService ai, JournalEntry entry) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AiReflectionScreen(
          journalContent: entry.body,
          analysisContent: AiConversation(
            prompt: WriteJournalScreen.prompt,
            entry: entry.body,
          ).text(budget: AiConversation.reflectionBudget),
          entryParts: [
            (question: WriteJournalScreen.prompt, answer: entry.body),
          ],
          remote: ai,
          entry: entry,
          backOnContinue: true,
        ),
      ),
    );
    if (mounted) _loadKeptAnalysis();
  }

  void _review(SavedAnalysis kept) {
    FocusManager.instance.primaryFocus?.unfocus();
    final entry = _saved ?? widget.entry;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AiReflectionScreen.review(
          journalContent: entry?.body ?? _entryText,
          saved: kept,
          entry: entry,
        ),
      ),
    );
  }

  bool get _hasFollowUp => _deeper.isNotEmpty;

  /// The field being written: the entry, or the answer to the last question.
  TextEditingController get _current =>
      _hasFollowUp ? _deeper.last.answer : _controller;

  void _onTextChanged() {
    final hasText = _current.text.trim().isNotEmpty;
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

  /// The entry as saved: what was written first, then each "Nhìn lại cùng
  /// bạn" question on its own line above its answer, so it still reads
  /// as a conversation later. A question left unanswered is not kept.
  String get _entryText => [
        _controller.text.trim(),
        for (final round in _deeper)
          if (round.answer.text.trim() case final answer
              when answer.isNotEmpty)
            '${round.question}\n$answer',
      ].where((part) => part.isNotEmpty).join('\n\n');

  /// What the AI reads: each question with what was written for it, and
  /// why the user journals (OB03), if said.
  AiConversation _conversation(OnboardingStore? onboarding) => AiConversation(
        prompt: WriteJournalScreen.prompt,
        entry: _controller.text,
        rounds: [
          for (final round in _deeper)
            (question: round.question, answer: round.answer.text),
        ],
        goal: onboarding?.goal?.label,
      );

  /// AI for this account now: signed in (guests have none) and not turned
  /// off in Hồ sơ. The onboarding choice does not turn it off (product
  /// decision, 29/10/2026); never a mock insight.
  ApiAIService? get _ai {
    final ai = AiRemoteScope.maybeOf(context);
    final onboarding = OnboardingScope.maybeOf(context);
    return onboarding == null || onboarding.aiInApp ? ai : null;
  }

  void _showEmptyEntryMessage() {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content:
          Text('Vui lòng viết ít nhất một dòng nhật ký trước khi hoàn thành.'),
    ));
  }

  bool get _canGoDeeper => _hasText && !_asking;

  /// "Nhìn lại cùng bạn": the AI reads what is written so far and asks one
  /// more question to dig into it; the answer goes under it.
  Future<void> _goDeeper() async {
    if (!_canGoDeeper) return;
    final ai = _ai;
    if (ai == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(AiRemoteScope.maybeOf(context) == null
              ? WriteJournalScreen.deeperNeedsAccount
              : WriteJournalScreen.aiOff)));
      return;
    }
    final conversation =
        _conversation(OnboardingScope.maybeOf(context)).text();
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _asking = true);
    _preferences?.feedback();
    final String question;
    try {
      question = await ai.goDeeper(conversation);
    } catch (_) {
      if (!mounted) return;
      setState(() => _asking = false);
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(WriteJournalScreen.deeperFailed)));
      return;
    }
    if (!mounted) return;
    setState(() {
      _asking = false;
      _deeper.add((
        question: sentenceCase(question),
        answer: TextEditingController()..addListener(_onTextChanged),
      ));
      _hasText = false;
    });
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
    final journals = JournalScope.of(context);
    final ai = _ai;
    try {
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
    if (ai != null) {
      _openReflection(ai);
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
    for (final round in _deeper) {
      round.answer.dispose();
    }
    _followUpFocus.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// The analysis of the whole entry, "Nhìn lại cùng bạn" included: the AI
  /// reads the questions with the answers, and "Nhật ký" shows them too.
  void _openReflection(ApiAIService ai) {
    FocusManager.instance.primaryFocus?.unfocus();
    final conversation = _conversation(OnboardingScope.maybeOf(context));
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AiReflectionScreen(
          journalContent: _entryText,
          analysisContent: conversation.text(
              budget: AiConversation.reflectionBudget),
          entryParts: [
            (question: WriteJournalScreen.prompt, answer: _controller.text),
            for (final round in _deeper)
              (question: round.question, answer: round.answer.text),
          ],
          remote: ai,
          entry: _saved,
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
                                  if ((_saved ?? widget.entry, _ai)
                                          case (final entry?, final ai?)
                                      when _keptLoaded &&
                                          _kept == null &&
                                          widget.entry != null) ...[
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: TextButton.icon(
                                        onPressed: () =>
                                            _analyzeOld(ai, entry),
                                        icon: const Icon(
                                            Icons.auto_awesome_outlined,
                                            size: 18),
                                        label: const Text(
                                            WriteJournalScreen.analyzeLabel),
                                      ),
                                    ),
                                    const SizedBox(height: AppSpacing.xs),
                                  ],
                                  if (_kept case final kept?) ...[
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: TextButton.icon(
                                        onPressed: () => _review(kept),
                                        icon: const Icon(
                                            Icons.auto_awesome_outlined,
                                            size: 18),
                                        label: const Text(
                                            WriteJournalScreen.reviewLabel),
                                      ),
                                    ),
                                    const SizedBox(height: AppSpacing.xs),
                                  ],
                                  _buildPrompt(WriteJournalScreen.prompt),
                                  const SizedBox(height: AppSpacing.md),
                                  // Each question asked: what was written
                                  // before it, then the question.
                                  for (final (i, round) in _deeper.indexed) ...[
                                    _RuledLines(
                                      style: _writingStyle,
                                      on: ruled,
                                      bleed: _gutter,
                                      child: Text(
                                        i == 0
                                            ? _controller.text
                                            : _deeper[i - 1].answer.text,
                                        strutStyle:
                                            _RuledLines.strut(_writingStyle),
                                        style: _writingStyle.copyWith(
                                            color: AppColors.textSecondary),
                                      ),
                                    ),
                                    const SizedBox(height: AppSpacing.xl),
                                    _buildPrompt(round.question),
                                    const SizedBox(height: AppSpacing.md),
                                  ],
                                  _RuledLines(
                                    style: _writingStyle,
                                    on: ruled,
                                    bleed: _gutter,
                                    // The rows carry on down the page.
                                    below: 2000,
                                    child: TextField(
                                      key: ValueKey(_deeper.length),
                                      controller: _current,
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
                                  if (_asking) ...[
                                    const SizedBox(height: AppSpacing.md),
                                    _buildThinking(),
                                  ] else if (_deeper.length >=
                                      WriteJournalScreen.deepNudgeAfter) ...[
                                    const SizedBox(height: AppSpacing.md),
                                    _buildNudge(),
                                  ],
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

  /// While the AI writes the next question.
  Widget _buildThinking() => Semantics(
        liveRegion: true,
        child: const Row(children: [
          SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: AppColors.primaryAction),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(WriteJournalScreen.thinkingLabel,
                style: AppText.bodySecondary),
          ),
        ]),
      );

  /// Many questions in: a gentle note to save, never a stop.
  Widget _buildNudge() => const Row(children: [
        Icon(Icons.bookmark_border_rounded,
            size: 18, color: AppColors.primaryAction),
        SizedBox(width: 12),
        Expanded(
          child: Text(WriteJournalScreen.deepNudge,
              style: AppText.bodySecondary),
        ),
      ]);

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
      // Something to go deeper on first; one question at a time.
      onPressed: _canGoDeeper ? _goDeeper : null,
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
            // The width both labels need grows with the text size.
            builder: (context, actions) => actions.maxWidth >=
                    MediaQuery.textScalerOf(context).scale(320)
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
