import 'package:flutter/material.dart';

import '../../core/data/app_data.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/app_ui.dart';
import '../streak/streak_screen.dart';
import '../sound/app_sound.dart';
import '../onboarding/data/onboarding_scope.dart';
import 'data/analysis_archive.dart';
import 'data/api_ai_service.dart';
import 'data/cloud_ai_api.dart';
import 'data/cloud_analysis_sync.dart';
import '../../core/network/api_client.dart';
import 'data/journal_entry.dart';
import 'data/quote_picker.dart';
import 'data/saved_quotes.dart';
import 'presentation/sentence_case.dart';
import '../streak/streak_state.dart';

enum _ReflectionStage { loading, quote, insight }

/// After saving: the AI's analysis of the entry ("Phân tích", with the
/// entry under "Nhật ký"), then, when the backend picked one, a quote
/// related to it, then the streak.
class AIReflectionScreen extends StatefulWidget {
  const AIReflectionScreen({
    super.key,
    required this.journalContent,
    this.analysisContent,
    this.entryParts,
    this.remote,
    this.entry,
    this.saved,
    this.backOnContinue = false,
  });

  /// Read again from an entry: the kept analysis, no new request; "Tiếp
  /// tục" goes back.
  const AIReflectionScreen.review({
    super.key,
    required this.journalContent,
    required SavedAnalysis this.saved,
    this.entryParts,
    this.entry,
  })  : remote = null,
        analysisContent = null,
        backOnContinue = true;

  /// The entry as saved.
  final String journalContent;

  /// What the AI reads, when more than the entry: "Nhìn lại cùng bạn"'s
  /// questions with the answers.
  final String? analysisContent;

  /// "Nhật ký" as written: each question with its answer.
  final List<({String question, String answer})>? entryParts;

  final ApiAIService? remote;

  /// The saved entry this analysis is for: the analysis is kept with it.
  final JournalEntry? entry;

  /// A kept analysis to show again ([AIReflectionScreen.review]).
  final SavedAnalysis? saved;

  /// Asked for from an entry written before (not right after a save):
  /// "Tiếp tục" goes back to it, never to the streak.
  final bool backOnContinue;

  static const failed = 'Không thể kết nối AI lúc này.';
  static const quotaFailed =
      'Bạn đã dùng AI nhiều lần trong một phút. Đợi một chút rồi thử lại nhé.';
  static const tooLong =
      'Bài viết dài hơn mức AI đọc được. Bạn vẫn có thể lưu và đọc lại bài.';
  static const editedMeanwhile =
      'Bài vừa được sửa trong lúc AI đang đọc. Bạn thử lại nhé.';
  static const ratingFailed = 'Chưa lưu được đánh giá. Bạn thử lại nhé.';
  static const deviceOnly = 'Phân tích này chỉ lưu trên máy này, không có '
      'trên máy khác khi bạn đăng nhập.';

  @override
  State<AIReflectionScreen> createState() => _AIReflectionScreenState();
}

class _AIReflectionScreenState extends State<AIReflectionScreen> {
  _ReflectionStage _stage = _ReflectionStage.loading;
  bool _showEntry = false;
  bool _quoteSaved = false;
  bool? _helpful;
  bool _openingStreak = false;
  AiAnalysis? _remoteInsight;
  bool _remoteFailed = false;

  /// Why the AI did not answer, in words the reader can act on.
  String _failMessage = AIReflectionScreen.failed;

  /// The server journal whose kept analysis is shown: 👍/👎 go there.
  int? _cloudJournal;

  /// The latest 👍/👎 tap: an older one finishing late never undoes it.
  int _ratingTap = 0;

  /// The quote after the analysis: the backend's pick, else the team's
  /// quote that fits the analysis best; none when nothing fits.
  ({String text, String author})? _remoteQuote;

  Future<void> _fetchRemote() async {
    final service = widget.remote;
    if (service == null) return;
    // A journal saved on the server is analysed there, from its saved
    // version, and the analysis is kept with it (any phone sees it).
    final journal = switch (widget.entry) {
      final entry? => cloudJournalNumber(entry.id),
      null => null,
    };
    try {
      final AiAnalysis result;
      CloudAnalysis? cloud;
      if (journal != null) {
        cloud = await CloudAiApi(service.client).analyze(journal);
        result = cloud.analysis;
      } else {
        result = await service
            .analyze(widget.analysisContent ?? widget.journalContent);
      }
      if (!mounted) return;
      final picked = const QuotePicker().pick(result,
          entry: widget.journalContent, seed: widget.journalContent);
      final ({String text, String author})? quote = switch (result.quote) {
        final quote? => (text: quote.text, author: quote.author),
        null when picked != null => (text: picked.text, author: picked.author),
        null => null,
      };
      if (cloud != null) {
        _keepCloud(cloud, quote);
      } else {
        _keep(result, quote);
      }
      if (quote != null) _loadQuoteSaved(quote.text);
      setState(() {
        _remoteInsight = result;
        _remoteQuote = quote;
        _remoteFailed = false;
        _cloudJournal = cloud?.journalNumber;
        _helpful = _helpfulOf(cloud?.feedback);
        _stage = _ReflectionStage.insight;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _remoteFailed = true;
        _failMessage = switch (error) {
          ApiException(statusCode: 429) => AIReflectionScreen.quotaFailed,
          ApiException(statusCode: 422) => AIReflectionScreen.tooLong,
          ApiException(statusCode: 409) => AIReflectionScreen.editedMeanwhile,
          _ => AIReflectionScreen.failed,
        };
        _stage = _ReflectionStage.insight;
      });
    }
  }

  static bool? _helpfulOf(String? feedback) => switch (feedback) {
        'up' => true,
        'down' => false,
        _ => null,
      };

  /// The server's analysis, copied here for the lists and the chart.
  Future<void> _keepCloud(
      CloudAnalysis cloud, ({String text, String author})? quote) async {
    try {
      final archive = await AnalysisArchive.open(userId: _userId);
      await CloudAnalysisSync.keep(archive, cloud, quote: quote);
    } catch (_) {}
  }

  /// 👍/👎, and a second tap to take it back. Kept with a server analysis
  /// (no journal text is sent), or on the device for a device-only one.
  Future<void> _rate(bool? helpful) async {
    final before = _helpful;
    final tap = ++_ratingTap;
    setState(() => _helpful = helpful);
    final rating = switch (helpful) {
      true => 'up',
      false => 'down',
      null => null,
    };
    // Read from the tree before any wait.
    final userId = _userId;
    final journal = _cloudJournal;
    final service = AiRemoteScope.maybeOf(context) ?? widget.remote;
    try {
      final archive = await AnalysisArchive.open(userId: userId);
      if (journal != null && service != null) {
        final cloud = await CloudAiApi(service.client).rate(journal, rating);
        await CloudAnalysisSync.keep(archive, cloud, quote: _remoteQuote);
      } else if (widget.entry case final entry?) {
        final kept = archive.of(entry.id);
        if (kept != null) {
          await archive.save(kept.copyWith(feedback: () => rating));
        }
      }
    } catch (_) {
      if (!mounted || tap != _ratingTap) return;
      setState(() => _helpful = before);
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AIReflectionScreen.ratingFailed)));
    }
  }

  /// Kept with its entry, to read again from "Nhật ký gần đây" and for the
  /// week's emotions. Not kept is not a failure the reader should see.
  Future<void> _keep(
      AiAnalysis analysis, ({String text, String author})? quote) async {
    final entry = widget.entry;
    if (entry == null) return;
    final userId =
        context.getInheritedWidgetOfExactType<OnboardingScope>()?.store.userId;
    try {
      final archive = await AnalysisArchive.open(userId: userId);
      await archive.save(SavedAnalysis(
        entryId: entry.id,
        bodyVersion: entry.bodyVersion,
        savedAt: DateTime.now(),
        analysis: analysis,
        quote: quote,
      ));
    } catch (_) {}
  }

  static String _date(DateTime at) =>
      '${at.day.toString().padLeft(2, '0')}/${at.month.toString().padLeft(2, '0')}/${at.year}';

  /// A real analysis: asked for now, or kept from before.
  bool get _real => widget.remote != null || widget.saved != null;

  /// The quote on screen: the backend's for a real analysis, else the
  /// prototype's.
  ({String text, String author}) get _quote => switch (_remoteQuote) {
        final quote? => quote,
        null => (
            text: 'Hãy làm những gì bạn có thể, bằng những gì bạn có, '
                'ngay tại nơi bạn đang đứng.',
            author: 'Theodore Roosevelt',
          ),
      };

  String? get _userId =>
      context.getInheritedWidgetOfExactType<OnboardingScope>()?.store.userId;

  /// Whether this quote is already kept, so its button says so.
  Future<void> _loadQuoteSaved(String text) async {
    try {
      final saved = (await SavedQuotes.open(userId: _userId)).contains(text);
      if (mounted) setState(() => _quoteSaved = saved);
    } catch (_) {}
  }

  /// A real quote: kept for the account, or let go on a second tap.
  Future<void> _toggleRealQuote() async {
    final (:text, :author) = _quote;
    final keep = !_quoteSaved;
    // A signed-in account keeps it on the server; a guest has none.
    final service = AiRemoteScope.maybeOf(context) ?? widget.remote;
    final cloud = service == null ? null : CloudAiApi(service.client);
    try {
      final quotes = await SavedQuotes.open(userId: _userId, cloud: cloud);
      keep ? await quotes.save(text, author) : await quotes.remove(text);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Chưa lưu được trích dẫn. Bạn thử lại nhé.')));
      }
      return;
    }
    if (!mounted) return;
    setState(() => _quoteSaved = keep);
    if (keep) AppSound.instance.play(SoundCue.paper);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
          content: Text(keep
              ? 'Đã lưu. Xem lại ở mục Đã lưu trên Trang chủ.'
              : 'Đã bỏ lưu trích dẫn.')));
  }

  void _saveQuote() {
    if (_real) {
      _toggleRealQuote();
      return;
    }
    if (_quoteSaved) return;
    final now = DateTime.now();
    const months = [
      'Thg 1',
      'Thg 2',
      'Thg 3',
      'Thg 4',
      'Thg 5',
      'Thg 6',
      'Thg 7',
      'Thg 8',
      'Thg 9',
      'Thg 10',
      'Thg 11',
      'Thg 12'
    ];
    final (:text, :author) = _quote;
    final content = text;
    // One card per quote: saved again, it moves to the top with today's time.
    savedThisWeekItems.value = [
      {
        'type': 'quote',
        'content': content,
        'author': author,
        'date': 'Hôm nay',
        'timestamp': '${months[now.month - 1]} ${now.day} - '
            '${now.hour.toString().padLeft(2, '0')}:'
            '${now.minute.toString().padLeft(2, '0')}',
      },
      for (final item in savedThisWeekItems.value)
        if (item['type'] != 'quote' || item['content'] != content) item,
    ];
    setState(() => _quoteSaved = true);
    AppSound.instance.play(SoundCue.paper);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Đã lưu. Xem lại ở mục Đã lưu trên Trang chủ.')),
    );
  }

  @override
  void initState() {
    super.initState();
    if (widget.saved case final saved?) {
      _remoteInsight = saved.analysis;
      _remoteQuote = saved.quote;
      // The rating given before; a server copy is rated on the server.
      _helpful = _helpfulOf(saved.feedback);
      _cloudJournal = saved.cloud ? cloudJournalNumber(saved.entryId) : null;
      if (saved.quote case final quote?) {
        WidgetsBinding.instance
            .addPostFrameCallback((_) => _loadQuoteSaved(quote.text));
      }
      _stage = _ReflectionStage.insight;
      return;
    }
    if (widget.remote != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _fetchRemote());
      return;
    }
    // The pause while the entry is read. The quote then stays until the
    // reader moves on (Tiếp tục): never taken away mid-read.
    Future<void>.delayed(const Duration(seconds: 3), () {
      if (!mounted || _stage != _ReflectionStage.loading) return;
      setState(() => _stage = _ReflectionStage.quote);
    });
  }

  void _showInsight() {
    setState(() => _stage = _ReflectionStage.insight);
  }

  /// "Tiếp tục" under the analysis: the quote first when there is one.
  void _afterInsight() {
    // Read again: the quote is on the analysis itself; back to the entry.
    if (widget.saved != null) {
      _continueToStreak();
      return;
    }
    if (_real && _remoteQuote != null && _stage == _ReflectionStage.insight) {
      setState(() => _stage = _ReflectionStage.quote);
    } else {
      _continueToStreak();
    }
  }

  /// After the reflection: the streak celebrates the day's first entry;
  /// later entries the same day go straight back Home.
  Future<void> _continueToStreak() async {
    if (_openingStreak) return;
    if (widget.saved != null || widget.backOnContinue) {
      // Read again, or asked for from an older entry: back to it.
      Navigator.of(context).pop();
      return;
    }
    if (StreakState.shared.completedToday) {
      StreakScreen.returnHome(context);
      return;
    }
    setState(() => _openingStreak = true);
    await Navigator.of(context).push(StreakScreen.route());
    if (mounted) setState(() => _openingStreak = false);
  }

  @override
  Widget build(BuildContext context) {
    final insight = _stage == _ReflectionStage.insight;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 400);
    return Scaffold(
      body: AnimatedContainer(
        duration: duration,
        color: insight ? AppColors.surface : AppColors.background,
        child: SafeArea(
          child: AnimatedSwitcher(
            duration: duration,
            child: insight
                ? _buildInsight()
                : _buildPause(_stage == _ReflectionStage.quote),
          ),
        ),
      ),
    );
  }

  Widget _buildPause(bool quote) {
    return LayoutBuilder(
      key: ValueKey(_stage),
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 450;
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          quote
                              ? _quote.text
                              : 'Hãy hít thở thật sâu và thư giãn tâm trí trong lúc chúng mình đọc nhật ký của bạn nhé...',
                          textAlign: TextAlign.center,
                          style: AppText.pageTitle.copyWith(
                            fontSize: compact ? 22 : 28,
                            height: 1.45,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (quote) ...[
                          const SizedBox(height: 20),
                          // A short dash only, never an em dash.
                          Text('– ${_quote.author}', style: AppText.meta),
                        ],
                        SizedBox(height: compact ? 12 : 24),
                        _buildMascot(quote, compact ? 80 : 150),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(height: compact ? 8 : 24),
              if (quote)
                Row(children: [
                  Expanded(
                    child: AppSecondaryButton(
                      // A real quote can be let go again; the demo's stays.
                      onPressed: _quoteSaved && !_real ? null : _saveQuote,
                      icon:
                          _quoteSaved ? Icons.bookmark : Icons.bookmark_border,
                      label: _quoteSaved ? 'Đã lưu' : 'Lưu',
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: AppPrimaryButton(
                      // A real quote comes after the analysis.
                      onPressed: _real
                          ? (_openingStreak ? null : _continueToStreak)
                          : _showInsight,
                      label: 'Tiếp tục',
                    ),
                  ),
                ])
              else
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    minimumSize: const Size(48, 48),
                    textStyle: AppText.label,
                  ),
                  child: const Text('Hủy phân tích'),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMascot(bool quote, double size) {
    return Center(
      child: ColorFiltered(
        // Match the app's mascot treatment: key near-white pixels to alpha.
        // White details inside the mascot also become transparent.
        colorFilter: const ColorFilter.matrix([
          // dart format off
          1, 0, 0, 0, 0,
          0, 1, 0, 0, 0,
          0, 0, 1, 0, 0,
          -4.252, -14.304, -1.444, 20, 0,
          // dart format on
        ]),
        child: Image.asset(
          quote ? 'assets/images/like.gif' : 'assets/images/loading.gif',
          width: size,
          height: size,
          fit: BoxFit.contain,
          semanticLabel: quote
              ? 'Nudaeng đang động viên bạn'
              : 'Nudaeng đang cùng bạn suy ngẫm',
        ),
      ),
    );
  }

  Widget _buildInsight() {
    if (_real) {
      return _buildRemoteInsight();
    }
    return Column(
      key: const ValueKey('reflection-insight'),
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppEyebrow('Góc suy ngẫm', icon: Icons.auto_awesome),
                const SizedBox(height: AppSpacing.sm),
                Semantics(
                  header: true,
                  child: const Text('Chuyện học hành đang khiến bạn áp lực?',
                      style: AppText.pageTitle),
                ),
                const SizedBox(height: AppSpacing.xl),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(children: [
                    _buildTab('Nhật ký', _showEntry,
                        () => setState(() => _showEntry = true)),
                    _buildTab('Phân tích', !_showEntry,
                        () => setState(() => _showEntry = false)),
                  ]),
                ),
                const SizedBox(height: 28),
                if (_showEntry)
                  SelectableText(
                    widget.journalContent.isEmpty
                        ? 'Chưa có nội dung nhật ký.'
                        : widget.journalContent,
                    style: AppText.body.copyWith(height: 1.7),
                  )
                else ...[
                  // Mock insight for the prototype; replace with the API response.
                  for (final (i, paragraph) in const [
                    'Bạn chia sẻ rằng gần đây mình đang cố gắng không nghĩ đến '
                        'chuyện học. Có thể bạn đang có nhiều việc phải lo, hoặc '
                        'đơn giản là chưa muốn đối diện với những điều còn dang dở. '
                        'Đôi khi, tạm gác một vấn đề sang một bên cũng là cách để '
                        'chúng ta có thêm thời gian suy nghĩ.',
                    'Nếu muốn, bạn có thể thử nhìn lại một chút: Điều gì trong '
                        'chuyện học đang khiến bạn ngại nghĩ đến nhất? Khối lượng '
                        'bài tập, kỳ vọng về kết quả, hay một lý do khác?',
                    'Bạn không nhất thiết phải tìm ra câu trả lời ngay lúc này.',
                  ].indexed) ...[
                    if (i > 0) const SizedBox(height: AppSpacing.md),
                    Text(paragraph, style: AppText.body.copyWith(height: 1.7)),
                  ],
                  const SizedBox(height: 32),
                  _buildSectionTitle(
                      Icons.push_pin_outlined, 'Điều chúng mình nhận thấy'),
                  const SizedBox(height: 12),
                  Text(
                    'Bạn đang có xu hướng tránh nghĩ đến chuyện học. Tuy nhiên, '
                    'từ những gì bạn chia sẻ, vẫn chưa rõ điều gì khiến bạn cảm '
                    'thấy như vậy.',
                    style: AppText.body.copyWith(height: 1.7),
                  ),
                  const SizedBox(height: 28),
                  _buildSectionTitle(Icons.star_border, 'Tâm trạng & chủ đề'),
                  const SizedBox(height: 12),
                  Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        for (final tag in const [
                          '😕  Tâm trạng: Bồn chồn',
                          'Chủ đề: Áp lực học tập',
                        ])
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            decoration: const ShapeDecoration(
                              color: AppColors.primaryLight,
                              shape: StadiumBorder(),
                            ),
                            child: Text(tag, style: AppText.body),
                          ),
                      ]),
                ],
              ],
            ),
          ),
        ),
        _buildFeedback(),
      ],
    );
  }

  Widget _buildRemoteInsight() {
    if (_remoteFailed) {
      return Center(
          child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Text(_failMessage, textAlign: TextAlign.center),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _remoteFailed = false;
                _stage = _ReflectionStage.loading;
              });
              _fetchRemote();
            },
            child: const Text('Thử lại AI'),
          ),
        ],
      ));
    }
    final result = _remoteInsight;
    if (result == null) {
      return const Center(child: CircularProgressIndicator());
    }
    const reading = TextStyle(height: 1.7);
    return LayoutBuilder(
        key: const ValueKey('reflection-insight'),
        builder: (context, box) {
          // Pinned under the reading where it leaves it room; on a short
          // screen or with large text, at the end of the reading instead.
          final pinned = box.maxHeight >= 600 &&
              MediaQuery.textScalerOf(context).scale(1) <= 1.3;
          return Column(children: [
            Expanded(
                child: ListView(padding: const EdgeInsets.all(24), children: [
              const AppEyebrow('Góc suy ngẫm', icon: Icons.auto_awesome),
              const SizedBox(height: AppSpacing.sm),
              Semantics(
                header: true,
                child: Text(sentenceCase(result.title ?? result.emotion),
                    style: AppText.pageTitle),
              ),
              if (widget.saved case final saved?) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  // Read again: when, and whether the entry changed since.
                  [
                    'Phân tích ngày ${_date(saved.savedAt)}',
                    if (widget.entry case final entry?
                        when entry.bodyVersion != saved.bodyVersion)
                      'cho bản trước khi bạn sửa',
                  ].join(', '),
                  style: AppText.meta,
                ),
                // Never promise it is on the account when it is not.
                if (!saved.cloud) ...[
                  const SizedBox(height: AppSpacing.xs),
                  const Text(AIReflectionScreen.deviceOnly,
                      style: AppText.meta),
                ],
              ],
              const SizedBox(height: AppSpacing.xl),
              _buildTabs(),
              const SizedBox(height: 28),
              if (_showEntry)
                ..._buildEntry()
              else ...[
                for (final (i, paragraph) in [
                  result.analysis ?? result.reflection,
                  result.question,
                ].indexed) ...[
                  if (i > 0) const SizedBox(height: AppSpacing.md),
                  Text(sentenceCase(paragraph),
                      style: AppText.body.merge(reading)),
                ],
                const SizedBox(height: 32),
                _buildSectionTitle(
                    Icons.push_pin_outlined, 'Điều chúng mình nhận thấy'),
                const SizedBox(height: 12),
                Text(sentenceCase(result.observation),
                    style: AppText.body.merge(reading)),
                const SizedBox(height: 28),
                _buildSectionTitle(Icons.star_border, 'Tâm trạng & chủ đề'),
                const SizedBox(height: 12),
                Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      _buildChip('Tâm trạng: ${sentenceCase(result.emotion)}'),
                      // At most three: the reading stays short.
                      for (final topic in result.topics.take(3))
                        _buildChip('Chủ đề: ${sentenceCase(topic)}'),
                    ]),
                // Read again: the quote shown then, here, not a screen
                // of its own once more.
                if (widget.saved != null && _remoteQuote != null) ...[
                  const SizedBox(height: 28),
                  _buildSectionTitle(
                      Icons.format_quote_rounded, 'Câu trích dẫn cho bài này'),
                  const SizedBox(height: 12),
                  Text(_quote.text, style: AppText.body.merge(reading)),
                  const SizedBox(height: AppSpacing.xs),
                  Text('– ${_quote.author}', style: AppText.meta),
                  const SizedBox(height: AppSpacing.sm),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _saveQuote,
                      icon: Icon(
                          _quoteSaved ? Icons.bookmark : Icons.bookmark_border),
                      label: Text(_quoteSaved ? 'Đã lưu' : 'Lưu'),
                    ),
                  ),
                ],
              ],
              if (!pinned) ...[
                const SizedBox(height: 32),
                _buildFeedback(inline: true),
              ],
            ])),
            if (pinned) _buildFeedback(),
          ]);
        });
  }

  Widget _buildTabs() => Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppColors.primaryLight,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(children: [
          _buildTab(
              'Nhật ký', _showEntry, () => setState(() => _showEntry = true)),
          _buildTab('Phân tích', !_showEntry,
              () => setState(() => _showEntry = false)),
        ]),
      );

  /// "Nhật ký": what was written, under each question it answers.
  List<Widget> _buildEntry() {
    const reading = TextStyle(height: 1.7);
    final parts = [
      for (final part in widget.entryParts ?? const [])
        if (part.answer.trim().isNotEmpty) part,
    ];
    if (parts.isEmpty) {
      return [
        SelectableText(
          widget.journalContent.isEmpty
              ? 'Chưa có nội dung nhật ký.'
              : widget.journalContent,
          style: AppText.body.merge(reading),
        ),
      ];
    }
    return [
      for (final (i, part) in parts.indexed) ...[
        if (i > 0) const SizedBox(height: AppSpacing.lg),
        Text(part.question,
            style: AppText.cardTitle.copyWith(color: AppColors.primaryAction)),
        const SizedBox(height: AppSpacing.xs),
        SelectableText(part.answer.trim(), style: AppText.body.merge(reading)),
      ],
    ];
  }

  Widget _buildChip(String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const ShapeDecoration(
          color: AppColors.primaryLight,
          shape: StadiumBorder(),
        ),
        child: Text(label, style: AppText.body),
      );

  Widget _buildTab(String label, bool selected, VoidCallback onTap) {
    return Expanded(
      child: Semantics(
        selected: selected,
        child: TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(
            backgroundColor: selected ? AppColors.surface : Colors.transparent,
            foregroundColor: AppColors.textPrimary,
            minimumSize: const Size.fromHeight(48),
            textStyle: selected
                ? AppText.label
                : AppText.label.copyWith(fontWeight: FontWeight.w400),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Text(label),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(IconData icon, String title) {
    return Row(children: [
      Icon(icon, size: 20, color: AppColors.primaryAction),
      const SizedBox(width: AppSpacing.sm),
      Expanded(child: Text(title, style: AppText.cardTitle)),
    ]);
  }

  /// "Có ích chứ?" and "Tiếp tục": a bar under the reading, or, [inline],
  /// its last part.
  Widget _buildFeedback({bool inline = false}) {
    return Container(
      padding:
          inline ? EdgeInsets.zero : const EdgeInsets.fromLTRB(24, 12, 24, 16),
      decoration: inline
          ? null
          : const BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            const Expanded(
                child: Text('Góc suy ngẫm này có ích cho bạn chứ?',
                    style: AppText.body)),
            IconButton(
              tooltip: 'Hữu ích',
              isSelected: _helpful == true,
              onPressed: () => _rate(_helpful == true ? null : true),
              icon: const Icon(Icons.thumb_up_outlined),
              selectedIcon: const Icon(Icons.thumb_up),
            ),
            IconButton(
              tooltip: 'Chưa hữu ích',
              isSelected: _helpful == false,
              onPressed: () => _rate(_helpful == false ? null : false),
              icon: const Icon(Icons.thumb_down_outlined),
              selectedIcon: const Icon(Icons.thumb_down),
            ),
          ]),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: AppPrimaryButton(
              onPressed: _openingStreak ? null : _afterInsight,
              label: 'Tiếp tục',
            ),
          ),
        ],
      ),
    );
  }
}
