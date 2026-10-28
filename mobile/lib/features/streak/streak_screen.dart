import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/app_ui.dart';
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

  /// Back to Home under everything the entry opened (writer, reflection,
  /// streak).
  static void returnHome(BuildContext context) {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.popUntil((route) => route.isFirst);
    } else {
      navigator
          .pushReplacement(MaterialPageRoute(builder: (_) => const AppShell()));
    }
  }

  @override
  State<StreakScreen> createState() => _StreakScreenState();
}

class _StreakScreenState extends State<StreakScreen> {
  int _previousCount = 0;
  int _newCount = 0;
  bool _remoteRequested = false;
  bool _serverCountVerified = false;
  bool _hasAuthenticatedScope = false;
  bool _waitingOnServer = false;
  static const _days = ['CN', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7'];
  static const _dayNames = [
    'Chủ nhật',
    'Thứ hai',
    'Thứ ba',
    'Thứ tư',
    'Thứ năm',
    'Thứ sáu',
    'Thứ bảy',
  ];

  @override
  void initState() {
    super.initState();
    _previousCount = StreakState.shared.value;
    _newCount = StreakState.shared.nextCount;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final api = StreakApiScope.maybeOf(context)?.client;
    if (api == null || _remoteRequested) return;
    _remoteRequested = true;
    _hasAuthenticatedScope = true;
    _waitingOnServer = true;
    _fetchServerStreak(api);
  }

  Future<void> _fetchServerStreak(ApiClient api) async {
    try {
      final data = await api.getJson('/streak', requireAuth: true);
      final count = data['current_streak'];
      final completed = data['today_completed'];
      if (count is! int || count < 0 || completed is! bool) {
        throw const FormatException('Invalid streak response');
      }
      if (!mounted) return;
      StreakState.shared.applyServerSnapshot(
        currentStreak: count, todayCompleted: completed);
      setState(() {
        _previousCount = completed && count > 0 ? count - 1 : count;
        _newCount = count;
        _serverCountVerified = true;
        _waitingOnServer = false;
      });
    } catch (_) {
      // No invented numbers if the authenticated service cannot be reached.
      if (mounted) setState(() { _serverCountVerified = false; _waitingOnServer = false; });
    }
  }

  void _continue() {
    StreakState.shared.completeToday();
    StreakScreen.returnHome(context);
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
                          label: 'Nudaeng đang ăn mừng',
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
                        if (_serverCountVerified && _newCount > 0)
                          TweenAnimationBuilder<double>(
                            tween: Tween(
                                begin: _previousCount.toDouble(),
                                end: _newCount.toDouble()),
                            duration: MediaQuery.disableAnimationsOf(context)
                                ? Duration.zero
                                : const Duration(milliseconds: 900),
                            curve: Curves.easeInCubic,
                            builder: (context, count, _) => Text(
                              'Bạn đã viết nhật ký ${count.round()} ngày liên tục!',
                              textAlign: TextAlign.center,
                              style: AppText.pageTitle
                                  .copyWith(color: AppColors.primaryAction),
                            ),
                          )
                        else
                          Text(
                            _hasAuthenticatedScope && _waitingOnServer
                                ? 'Đang kiểm tra chuỗi ngày...'
                                : 'Bạn đã lưu nhật ký hôm nay!',
                            textAlign: TextAlign.center,
                            style: AppText.pageTitle
                                .copyWith(color: AppColors.primaryAction),
                          ),
                        const SizedBox(height: 12),
                        Text(
                            _serverCountVerified && _newCount > 0
                                ? 'Thật vui khi bạn đã dành thời gian nhìn lại bản thân trong $_newCount ngày qua.'
                                : 'Một trang nhật ký nữa đã được lưu. Cảm ơn bạn đã dành thời gian cho bản thân.',
                            textAlign: TextAlign.center,
                            style: AppText.bodySecondary),
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
                                      ? AppColors.primaryAction
                                      : AppColors.primaryLight),
                              child: Text(_days[index],
                                  style: AppText.label.copyWith(
                                      fontSize: 14,
                                      color: active
                                          ? AppColors.surface
                                          : AppColors.textPrimary)),
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
              child: AppPrimaryButton(
                  label: 'Khám phá tiếp', onPressed: _continue),
            ),
          ]),
        ),
      ),
    );
  }
}
