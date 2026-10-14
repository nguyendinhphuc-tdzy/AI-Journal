import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../navigation/app_shell.dart';
import '../../navigation/custom_bottom_navigation.dart';
import 'streak_state.dart';

class StreakScreen extends StatefulWidget {
  const StreakScreen({super.key});

  static Route<void> route() => PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 450),
        reverseTransitionDuration: const Duration(milliseconds: 250),
        pageBuilder: (_, __, ___) => const StreakScreen(),
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity: animation,
          child: child,
        ),
      );

  @override
  State<StreakScreen> createState() => _StreakScreenState();
}

class _StreakScreenState extends State<StreakScreen> {
  late final int _previousCount;
  late final int _newCount;
  static const _days = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
  static const _dayNames = [
    'Sunday',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
  ];

  @override
  void initState() {
    super.initState();
    _previousCount = StreakState.shared.value;
    _newCount = StreakState.shared.nextCount;
  }

  void _continue() {
    StreakState.shared.completeToday();
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.popUntil((route) => route.isFirst);
    } else {
      navigator
          .pushReplacement(MaterialPageRoute(builder: (_) => const AppShell()));
    }
  }

  void _selectTab(int index) {
    StreakState.shared.completeToday();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => AppShell(initialIndex: index)),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final todayIndex = DateTime.now().weekday % 7;
    return Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: CustomBottomNavigation(
        selectedIndex: 0,
        onDestinationSelected: _selectTab,
      ),
      body: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Column(children: [
            Expanded(
              child: LayoutBuilder(builder: (context, constraints) {
                return Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: SizedBox(
                      width: constraints.maxWidth,
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Semantics(
                          label: 'Nudaeng, celebrating',
                          child: Container(
                            width: 150,
                            height: 150,
                            color: Colors.transparent,
                            child: ColorFiltered(
                              // White-to-alpha key also affects white mascot details.
                              colorFilter: const ColorFilter.matrix([
                                // dart format off
                                1, 0, 0, 0, 0,
                                0, 1, 0, 0, 0,
                                0, 0, 1, 0, 0,
                                -4.252, -14.304, -1.444, 20, 0,
                                // dart format on
                              ]),
                              child: Image.asset('assets/images/like.gif',
                                  width: 150, height: 150, fit: BoxFit.contain),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        TweenAnimationBuilder<double>(
                          tween: Tween(
                              begin: _previousCount.toDouble(),
                              end: _newCount.toDouble()),
                          duration: MediaQuery.disableAnimationsOf(context)
                              ? Duration.zero
                              : const Duration(milliseconds: 900),
                          curve: Curves.easeInCubic,
                          builder: (context, count, _) => Text(
                            '${count.round()} day streak',
                            textAlign: TextAlign.center,
                            style: textTheme.headlineLarge?.copyWith(
                                color: AppColors.primaryDark,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text('Reflect daily to keep your mind healthy...',
                            textAlign: TextAlign.center,
                            style: textTheme.bodyLarge?.copyWith(
                                color: AppColors.textSecondary, height: 1.5)),
                        const SizedBox(height: 28),
                        Row(
                            children: List.generate(7, (index) {
                          final active = index == todayIndex;
                          return Expanded(
                              child: Center(
                                  child: Semantics(
                            label: _dayNames[index],
                            selected: active,
                            excludeSemantics: true,
                            child: Container(
                              width: active ? 40 : 32,
                              height: active ? 40 : 32,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: active
                                      ? AppColors.primary
                                      : AppColors.border),
                              child: Text(_days[index],
                                  style: textTheme.labelLarge?.copyWith(
                                      color: active
                                          ? AppColors.surface
                                          : AppColors.textSecondary)),
                            ),
                          )));
                        })),
                      ]),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _continue,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.surface,
                  minimumSize: const Size.fromHeight(54),
                ),
                child: const Text('Continue'),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
