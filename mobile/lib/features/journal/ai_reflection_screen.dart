import 'package:flutter/material.dart';

import '../../core/data/app_data.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/app_ui.dart';
import '../streak/streak_screen.dart';
import '../sound/app_sound.dart';
import 'data/api_ai_service.dart';
import '../streak/streak_state.dart';

enum _ReflectionStage { loading, quote, insight }

class AIReflectionScreen extends StatefulWidget {
  const AIReflectionScreen({super.key, required this.journalContent, this.remote});

  final String journalContent;
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
  AiAnalysis? _remoteInsight;
  bool _remoteFailed = false;

  Future<void> _fetchRemote() async {
    final service = widget.remote;
    if (service == null) return;
    try {
      final result = await service.analyze(widget.journalContent);
      if (!mounted) return;
      setState(() {
        _remoteInsight = result;
        _remoteFailed = false;
        _stage = _ReflectionStage.insight;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _remoteFailed = true;
        _stage = _ReflectionStage.insight;
      });
    }
  }


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
        'Hãy làm những gì bạn có thể, bằng những gì bạn có, ngay tại nơi bạn đang đứng.';
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
                              ? 'Hãy làm những gì bạn có thể, bằng những gì bạn có, ngay tại nơi bạn đang đứng.'
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
    if (widget.remote != null) {
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
      return Center(child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Không thể kết nối AI lúc này.'),
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
    return Column(children: [
      Expanded(child: ListView(padding: const EdgeInsets.all(24), children: [
        const AppEyebrow('Góc suy ngẫm', icon: Icons.auto_awesome),
        const SizedBox(height: 16),
        Text(result.emotion, style: AppText.pageTitle),
        const SizedBox(height: 20),
        Text(result.observation, style: AppText.body),
        const SizedBox(height: 16),
        Text(result.reflection, style: AppText.body),
        const SizedBox(height: 16),
        Text(result.question, style: AppText.body),
      ])),
      _buildFeedback(),
    ]);
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
