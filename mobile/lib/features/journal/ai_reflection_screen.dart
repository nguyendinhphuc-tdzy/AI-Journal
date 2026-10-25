import 'package:flutter/material.dart';

import '../../core/data/app_data.dart';
import '../../core/theme/app_colors.dart';
import '../streak/streak_screen.dart';

enum _ReflectionStage { loading, quote, insight }

class AIReflectionScreen extends StatefulWidget {
  const AIReflectionScreen({super.key, required this.journalContent});

  final String journalContent;

  @override
  State<AIReflectionScreen> createState() => _AIReflectionScreenState();
}

class _AIReflectionScreenState extends State<AIReflectionScreen> {
  _ReflectionStage _stage = _ReflectionStage.loading;
  bool _showEntry = false;
  bool _quoteSaved = false;
  bool? _helpful;
  bool _openingStreak = false;

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
    savedThisWeekItems.value = [
      {
        'type': 'quote',
        'content':
            'Hãy làm những gì bạn có thể, với những gì bạn đang có, ngay tại nơi bạn đang đứng.',
        'author': 'Theodore Roosevelt',
        'date': 'Hôm nay',
        'timestamp': '${months[now.month - 1]} ${now.day} - '
            '${now.hour.toString().padLeft(2, '0')}:'
            '${now.minute.toString().padLeft(2, '0')}',
      },
      ...savedThisWeekItems.value,
    ];
    setState(() => _quoteSaved = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đã lưu vào mục Tuần này!')),
    );
  }

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(seconds: 3), () {
      if (!mounted || _stage != _ReflectionStage.loading) return;
      setState(() => _stage = _ReflectionStage.quote);
    });
    Future<void>.delayed(const Duration(seconds: 7), () {
      if (!mounted || _stage == _ReflectionStage.insight) return;
      _showInsight();
    });
  }

  void _showInsight() {
    setState(() => _stage = _ReflectionStage.insight);
  }

  Future<void> _continueToStreak() async {
    if (_openingStreak) return;
    setState(() => _openingStreak = true);
    await Navigator.of(context).push(StreakScreen.route());
    if (mounted) setState(() => _openingStreak = false);
  }

  ButtonStyle get _blackButton => ElevatedButton.styleFrom(
        backgroundColor: AppColors.primaryDark,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
      );

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
    final textTheme = Theme.of(context).textTheme;
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
                          style: textTheme.headlineMedium?.copyWith(
                            fontSize: compact ? 23 : 30,
                            height: 1.45,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                        ),
                        if (quote) ...[
                          const SizedBox(height: 20),
                          Text('Theodore Roosevelt',
                              style: textTheme.bodyMedium?.copyWith(
                                color: Colors.black54,
                              )),
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
                    child: OutlinedButton.icon(
                      onPressed: _quoteSaved ? null : _saveQuote,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.black,
                        side: const BorderSide(color: Colors.black),
                        minimumSize: const Size.fromHeight(52),
                      ),
                      icon: Icon(
                          _quoteSaved ? Icons.bookmark : Icons.bookmark_border),
                      label: Text(_quoteSaved ? 'Đã lưu' : 'Lưu'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _showInsight,
                      style: _blackButton,
                      child: const Text('Tiếp tục'),
                    ),
                  ),
                ])
              else
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Hủy phân tích',
                    style: TextStyle(
                      color: Colors.black,
                      decoration: TextDecoration.underline,
                    ),
                  ),
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
    final textTheme = Theme.of(context).textTheme;
    return Column(
      key: const ValueKey('reflection-insight'),
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Góc suy ngẫm', style: textTheme.labelLarge),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FittedBox(
                    alignment: Alignment.centerLeft,
                    fit: BoxFit.scaleDown,
                    child: Text('Né tránh chuyện học hành',
                        maxLines: 1,
                        style: textTheme.headlineLarge?.copyWith(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        )),
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8E8E8),
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
                    style: textTheme.bodyLarge?.copyWith(height: 1.7),
                  )
                else ...[
                  // Mock insight for the prototype; replace with the API response.
                  Text(
                    'Có lẽ chuyện học hành đang trở thành một gánh nặng trong lòng bạn. '
                    'Ngay cả khi nghĩ về nó, bạn cũng có thể cảm thấy áp lực, bối rối, '
                    'hoặc có những cảm xúc khó gọi thành tên. Giữ một khoảng cách đôi khi '
                    'là cách để bạn kịp thở. Bạn không cần phải giải quyết mọi thứ ngay lập tức. '
                    'Nhận ra điều gì đang nặng lòng và cho mình không gian để gọi tên nó '
                    'có thể là một khởi đầu dịu dàng.',
                    style: textTheme.bodyLarge?.copyWith(height: 1.7),
                  ),
                  const SizedBox(height: 32),
                  _buildSectionTitle(
                      Icons.push_pin_outlined, 'Chúng mình nhận thấy rằng'),
                  const SizedBox(height: 12),
                  Text(
                    'Chuyện học hành đang mang nhiều cảm xúc đến mức tâm trí bạn muốn giữ một khoảng cách để tự bảo vệ mình.',
                    style: textTheme.bodyLarge?.copyWith(height: 1.7),
                  ),
                  const SizedBox(height: 28),
                  _buildSectionTitle(Icons.star_border, 'Tâm trạng & chủ đề'),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECEFF1),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child:
                        const Text('😕  Bồn chồn · né tránh chuyện học hành'),
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
            backgroundColor: selected ? Colors.white : Colors.transparent,
            foregroundColor: Colors.black,
            minimumSize: const Size.fromHeight(48),
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
      Icon(icon, size: 20),
      const SizedBox(width: 8),
      Expanded(
        child: Text(title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                )),
      ),
    ]);
  }

  Widget _buildFeedback() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Color(0x10000000), blurRadius: 20, offset: Offset(0, -4))
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            const Expanded(child: Text('Góc suy ngẫm này có ích cho bạn chứ?')),
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
            child: ElevatedButton(
              onPressed: _openingStreak ? null : _continueToStreak,
              style: _blackButton,
              child: const Text('Tiếp tục'),
            ),
          ),
        ],
      ),
    );
  }
}
