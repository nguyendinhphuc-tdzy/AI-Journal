import 'package:flutter/material.dart';

import '../../core/data/app_data.dart';
import 'data/api_ai_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/app_ui.dart';
import '../streak/streak_screen.dart';
import '../sound/app_sound.dart';
import '../streak/streak_state.dart';

enum _ReflectionStage { loading, quote, insight }

class AIReflectionScreen extends StatefulWidget {
  const AIReflectionScreen({super.key, required this.journalContent, this.remote});

  final String journalContent;

  /// Real backend AI service when authenticated and opted in.
  final ApiAIService? remote;

  @override
  State<AIReflectionScreen> createState() => _AIReflectionScreenState();
}

class _AIReflectionScreenState extends State<AIReflectionScreen> {
  _ReflectionStage _stage = _ReflectionStage.loading;
  bool _showEntry = false;
  bool _quoteSaved = false;
  bool? _helpful;
  bool _openingStreak = false;
  AiAnalysis? _analysis;
  bool _aiFailed = false;
  int _aiRequest = 0;

  void _saveQuote() {
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
    const content =
        'Hãy làm những gì bạn có thể, với những gì bạn đang có, ngay tại nơi bạn đang đứng.';
    // One card per quote: saved again, it moves to the top with today's time.
    savedThisWeekItems.value = [
      {
        'type': 'quote',
        'content': content,
        'author': 'Theodore Roosevelt',
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
    if (widget.remote != null) {
      _loadRemote();
      return;
    }
    // The pause while the entry is read. The quote then stays until the
    // reader moves on (Tiếp tục): never taken away mid-read.
    Future<void>.delayed(const Duration(seconds: 3), () {
      if (!mounted || _stage != _ReflectionStage.loading) return;
      setState(() => _stage = _ReflectionStage.quote);
    });
  }

  Future<void> _loadRemote() async {
    final remote = widget.remote;
    if (remote == null) return;
    final request = ++_aiRequest;
    setState(() {
      _stage = _ReflectionStage.loading;
      _aiFailed = false;
      _analysis = null;
    });
    try {
      final analysis = await remote.analyze(widget.journalContent);
      if (!mounted || request != _aiRequest) return;
      setState(() {
        _analysis = analysis;
        _stage = _ReflectionStage.insight;
      });
    } catch (_) {
      if (!mounted || request != _aiRequest) return;
      setState(() {
        _aiFailed = true;
        _stage = _ReflectionStage.insight;
      });
    }
  }

  @override
  void dispose() {
    _aiRequest++;
    super.dispose();
  }

  void _showInsight() {
    setState(() => _stage = _ReflectionStage.insight);
  }

  /// After the reflection: the streak celebrates the day's first entry;
  /// later entries the same day go straight back Home.
  Future<void> _continueToStreak() async {
    if (_openingStreak) return;
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
                              ? 'Hãy làm những gì bạn có thể, với những gì bạn đang có, ngay tại nơi bạn đang đứng.'
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
                          const Text('Theodore Roosevelt', style: AppText.meta),
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
                      onPressed: _quoteSaved ? null : _saveQuote,
                      icon:
                          _quoteSaved ? Icons.bookmark : Icons.bookmark_border,
                      label: _quoteSaved ? 'Đã lưu' : 'Lưu',
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: AppPrimaryButton(
                      onPressed: _showInsight,
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
                  child: Text(
                    widget.remote == null
                        ? 'Né tránh chuyện học hành'
                        : (_analysis?.emotion ?? 'Phản hồi AI'),
                    style: AppText.pageTitle,
                  ),
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
                else if (widget.remote != null) ...[
                  if (_aiFailed || _analysis == null) ...[
                    const Text(
                      'Phản hồi AI chưa sẵn sàng. Bạn có thể thử lại; '
                      'chúng mình sẽ không hiển thị phân tích mô phỏng thay cho AI thật.',
                      style: AppText.body,
                    ),
                    const SizedBox(height: 16),
                    AppSecondaryButton(
                      onPressed: _loadRemote,
                      label: 'Thử lại AI',
                    ),
                  ] else ...[
                    Text(_analysis!.reflection, style: AppText.body.copyWith(height: 1.7)),
                    const SizedBox(height: 32),
                    _buildSectionTitle(Icons.push_pin_outlined, 'Chúng mình nhận thấy rằng'),
                    const SizedBox(height: 12),
                    Text(_analysis!.observation, style: AppText.body.copyWith(height: 1.7)),
                    const SizedBox(height: 28),
                    _buildSectionTitle(Icons.star_border, 'Tâm trạng & chủ đề'),
                    const SizedBox(height: 12),
                    Text(_analysis!.emotion, style: AppText.body.copyWith(height: 1.7)),
                    const SizedBox(height: 28),
                    _buildSectionTitle(Icons.question_answer_outlined, 'Một câu hỏi cho bạn'),
                    const SizedBox(height: 12),
                    Text(_analysis!.question, style: AppText.body.copyWith(height: 1.7)),
                  ],
                ] else ...[
                  // Device-only preview; authenticated AI never shows this text.
                  Text(
                    'Có lẽ chuyện học hành đang trở thành một gánh nặng trong lòng bạn. '
                    'Ngay cả khi nghĩ về nó, bạn cũng có thể cảm thấy áp lực, bối rối, '
                    'hoặc có những cảm xúc khó gọi thành tên. Giữ một khoảng cách đôi khi '
                    'là cách để bạn kịp thở. Bạn không cần phải giải quyết mọi thứ ngay lập tức. '
                    'Nhận ra điều gì đang nặng lòng và cho mình không gian để gọi tên nó '
                    'có thể là một khởi đầu dịu dàng.',
                    style: AppText.body.copyWith(height: 1.7),
                  ),
                  const SizedBox(height: 32),
                  _buildSectionTitle(
                      Icons.push_pin_outlined, 'Chúng mình nhận thấy rằng'),
                  const SizedBox(height: 12),
                  Text(
                    'Chuyện học hành đang mang nhiều cảm xúc đến mức tâm trí bạn muốn giữ một khoảng cách để tự bảo vệ mình.',
                    style: AppText.body.copyWith(height: 1.7),
                  ),
                  const SizedBox(height: 28),
                  _buildSectionTitle(Icons.star_border, 'Tâm trạng & chủ đề'),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: const ShapeDecoration(
                      color: AppColors.primaryLight,
                      shape: StadiumBorder(),
                    ),
                    child: const Text('😕  Bồn chồn · né tránh chuyện học hành',
                        style: AppText.body),
                  ),
                ],
              ],
            ),
          ),
        ),
        _buildFeedback(),
      ],
    );
  }

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

  Widget _buildFeedback() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
      decoration: const BoxDecoration(
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
              onPressed: () =>
                  setState(() => _helpful = _helpful == true ? null : true),
              icon: const Icon(Icons.thumb_up_outlined),
              selectedIcon: const Icon(Icons.thumb_up),
            ),
            IconButton(
              tooltip: 'Chưa hữu ích',
              isSelected: _helpful == false,
              onPressed: () =>
                  setState(() => _helpful = _helpful == false ? null : false),
              icon: const Icon(Icons.thumb_down_outlined),
              selectedIcon: const Icon(Icons.thumb_down),
            ),
          ]),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: AppPrimaryButton(
              onPressed: _openingStreak ? null : _continueToStreak,
              label: 'Tiếp tục',
            ),
          ),
        ],
      ),
    );
  }
}
