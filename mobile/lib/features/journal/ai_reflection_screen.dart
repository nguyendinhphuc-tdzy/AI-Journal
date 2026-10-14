import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../navigation/app_shell.dart';
import '../../navigation/custom_bottom_navigation.dart';
import '../streak/streak_screen.dart';

class AIReflectionScreen extends StatefulWidget {
  const AIReflectionScreen({super.key, required this.journalContent});
  final String journalContent;

  @override
  State<AIReflectionScreen> createState() => _AIReflectionScreenState();
}

class _AIReflectionScreenState extends State<AIReflectionScreen> {
  bool _isLoading = true;
  // Replace with the API response inside setState when integration is ready.
  String aiSummaryText =
      'It sounds like you found a lot of comfort in simple moments today. '
      'Taking time to notice these moments may help you understand what '
      'brings you a sense of calm and connection.';

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() => _isLoading = false);
    });
  }

  void _selectTab(int index) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => AppShell(initialIndex: index)),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: Image.asset('assets/images/background_journal.png',
                fit: BoxFit.cover),
          ),
          Column(children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (_isLoading) ...[
                    const Positioned.fill(
                      child: ColoredBox(
                        key: ValueKey('reflection-loading-overlay'),
                        color: Color(0x66000000),
                      ),
                    ),
                    SafeArea(
                      bottom: false,
                      child: Center(
                        child: Semantics(
                          label: 'Nudaeng is reflecting',
                          liveRegion: true,
                          child: _mascot('assets/images/loading.gif', 150),
                        ),
                      ),
                    ),
                  ] else
                    _buildResult(context),
                ],
              ),
            ),
            // Outside the overlay: always clear and interactive.
            CustomBottomNavigation(
                selectedIndex: 0, onDestinationSelected: _selectTab),
          ]),
        ],
      ),
    );
  }

  Widget _buildResult(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(builder: (context, constraints) {
          return Center(
            child: Container(
              width: constraints.maxWidth,
              height: math.min(620, constraints.maxHeight),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(children: [
                Row(children: [
                  IconButton(
                    tooltip: 'Return to Home',
                    onPressed: () => Navigator.of(context)
                        .popUntil((route) => route.isFirst),
                    icon: const Icon(Icons.close),
                  ),
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text("✨ Nudaeng's thought...",
                          style: textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 48),
                ]),
                Expanded(
                  flex: 4,
                  child: LayoutBuilder(builder: (context, contentConstraints) {
                    return Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: SizedBox(
                          width: contentConstraints.maxWidth,
                          child:
                              Column(mainAxisSize: MainAxisSize.min, children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 24),
                              child: Text(
                                aiSummaryText,
                                textAlign: TextAlign.center,
                                style: textTheme.bodyLarge?.copyWith(
                                  fontSize: 20,
                                  height: 1.5,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            _mascot('assets/images/like.gif', 120),
                          ]),
                        ),
                      ),
                    );
                  }),
                ),
                const Spacer(),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Tooltip(
                          message: 'Save to Album is coming soon',
                          child: OutlinedButton(
                              onPressed: null, child: Text('Save to Album')),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: AppColors.surface),
                          onPressed: () =>
                              Navigator.push(context, StreakScreen.route()),
                          child: const Text('Continue'),
                        ),
                      ]),
                ),
              ]),
            ),
          );
        }),
      ),
    );
  }

  Widget _mascot(String asset, double size) {
    return Container(
      width: size,
      height: size,
      color: Colors.transparent,
      child: ColorFiltered(
        // Key near-white pixels to alpha. White details also become transparent.
        colorFilter: const ColorFilter.matrix([
          // dart format off
          1, 0, 0, 0, 0,
          0, 1, 0, 0, 0,
          0, 0, 1, 0, 0,
          -4.252, -14.304, -1.444, 20, 0,
          // dart format on
        ]),
        child:
            Image.asset(asset, width: size, height: size, fit: BoxFit.contain),
      ),
    );
  }
}
