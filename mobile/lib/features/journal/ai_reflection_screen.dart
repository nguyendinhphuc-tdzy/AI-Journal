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
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    savedThisWeekItems.value = [
      {
        'type': 'quote',
        'content': 'Do what you can, with what you have, where you are.',
        'author': 'Theodore Roosevelt',
        'date': 'Today',
        'timestamp': '${months[now.month - 1]} ${now.day} - '
            '${now.hour.toString().padLeft(2, '0')}:'
            '${now.minute.toString().padLeft(2, '0')}',
      },
      ...savedThisWeekItems.value,
    ];
    setState(() => _quoteSaved = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Saved to This Week!')),
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
                              ? 'Do what you can, with what you have, where you are.'
                              : "Take a deep breath and calm your mind while we're analyzing your entry...",
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
                      label: Text(_quoteSaved ? 'Saved' : 'Save'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _showInsight,
                      style: _blackButton,
                      child: const Text('Continue'),
                    ),
                  ),
                ])
              else
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Cancel analysis',
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
          semanticLabel:
              quote ? 'Nudaeng, encouraging you' : 'Nudaeng, reflecting',
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
                Text('Your Reflection', style: textTheme.labelLarge),
                const SizedBox(height: 12),
                Text('Avoiding school',
                    style: textTheme.headlineLarge?.copyWith(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    )),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8E8E8),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(children: [
                    _buildTab('Entry', _showEntry,
                        () => setState(() => _showEntry = true)),
                    _buildTab('Analysis', !_showEntry,
                        () => setState(() => _showEntry = false)),
                  ]),
                ),
                const SizedBox(height: 28),
                if (_showEntry)
                  SelectableText(
                    widget.journalContent.isEmpty
                        ? 'No entry text.'
                        : widget.journalContent,
                    style: textTheme.bodyLarge?.copyWith(height: 1.7),
                  )
                else ...[
                  // Mock insight for the prototype; replace with the API response.
                  Text(
                    'It sounds like school has become something with weight around it. '
                    'Even thinking about it may bring up a mix of pressure, uncertainty, '
                    'or feelings that are hard to put into words. Keeping some distance '
                    'can feel like a way to catch your breath. You do not have to figure '
                    'everything out at once. Noticing what feels heavy, and giving '
                    'yourself room to name it, can be a gentle place to start.',
                    style: textTheme.bodyLarge?.copyWith(height: 1.7),
                  ),
                  const SizedBox(height: 32),
                  _buildSectionTitle(
                      Icons.push_pin_outlined, 'What we noticed'),
                  const SizedBox(height: 12),
                  Text(
                    'School feels emotionally loaded enough that your mind is trying to keep some distance from it.',
                    style: textTheme.bodyLarge?.copyWith(height: 1.7),
                  ),
                  const SizedBox(height: 28),
                  _buildSectionTitle(Icons.star_border, 'Mood & Topics'),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECEFF1),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Text('😕  Uneasy & school - avoidance'),
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
            const Expanded(child: Text('How helpful was this reflection?')),
            IconButton(
              tooltip: 'Helpful',
              isSelected: _helpful == true,
              onPressed: () =>
                  setState(() => _helpful = _helpful == true ? null : true),
              icon: const Icon(Icons.thumb_up_outlined),
              selectedIcon: const Icon(Icons.thumb_up),
            ),
            IconButton(
              tooltip: 'Not helpful',
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
              child: const Text('Continue'),
            ),
          ),
        ],
      ),
    );
  }
}
