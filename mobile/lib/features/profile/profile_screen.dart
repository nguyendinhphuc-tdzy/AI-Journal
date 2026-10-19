import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../auth/presentation/auth_gate.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Preview selection only: native app icons and persistence are not connected.
  int _selectedIcon = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: IconButton(
                  tooltip: 'close',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            if (AuthScope.maybeOf(context) case final auth?)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: OutlinedButton.icon(
                  onPressed: () async {
                    try {
                      await auth.signOut();
                    } catch (_) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text(
                          'Không thể đăng xuất. Vui lòng thử lại.')),
                      );
                    }
                  },
                  icon: const Icon(Icons.logout),
                  label: const Text('Đăng xuất'),
                ),
              ),
            if (GuestScope.maybeOf(context) case final guest?)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const Text(
                      'Chế độ khách — dữ liệu chỉ nằm trên thiết bị này, '
                      'không được đồng bộ với tài khoản.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.person_add_alt_1_outlined),
                      label: const Text('Đăng nhập / Tạo tài khoản'),
                      onPressed: () async {
                        final discard = await showDialog<bool>(
                          context: context,
                          builder: (dialogContext) => AlertDialog(
                            title: const Text('Rời chế độ khách?'),
                            content: const Text(
                              'Nhật ký, bản nháp và onboarding trong chế độ '
                              'khách sẽ bị xóa khỏi thiết bị. Dữ liệu này '
                              'không được chuyển sang tài khoản mới.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.pop(dialogContext, false),
                                child: const Text('Hủy'),
                              ),
                              FilledButton(
                                onPressed: () =>
                                    Navigator.pop(dialogContext, true),
                                child: const Text('Xóa dữ liệu và tiếp tục'),
                              ),
                            ],
                          ),
                        );
                        if (discard != true || !context.mounted) return;
                        try {
                          await guest.onLeaveGuest();
                        } catch (_) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text(
                              'Chưa thể xóa dữ liệu khách. Vui lòng thử lại.',
                            )),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                children: [
                  _buildSettingsGroup('GENERAL', const [
                    'who says plus',
                    'what do friends call you?',
                    'pick your inspirations path',
                    'daily reminders',
                    'language',
                  ]),
                  _buildSettingsGroup('PREFERENCE', const [
                    'dynamic theme',
                    'scene',
                    'paper',
                    'handwriting',
                    'text size',
                    'background music',
                    'pencil sound',
                    'haptic',
                  ]),
                  _buildSettingsGroup(
                      'PRIVACY',
                      const [
                        'lock with passcode',
                        'lock with face id',
                      ],
                      strikethrough: true),
                  _buildSettingsGroup('ABOUT', const [
                    'notes for you',
                    'rate app',
                    'contact support',
                  ]),
                  _buildIconGroup('APP ICON', 0, const [
                    (Icons.auto_stories_outlined, Color(0xFFD6E9E4)),
                    (Icons.pets_outlined, Color(0xFFF1E4CE)),
                    (Icons.local_florist_outlined, Color(0xFFECDDE4)),
                    (Icons.wb_sunny_outlined, Color(0xFFE4E5F1)),
                  ]),
                  _buildIconGroup('SPECIAL APP ICON', 4, const [
                    (Icons.nightlight_round, Color(0xFFD7DFE8)),
                    (Icons.favorite_border, Color(0xFFECCFCB)),
                    (Icons.forest_outlined, Color(0xFFDDE5D1)),
                    (Icons.star_outline, Color(0xFFF1E6BF)),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 32, bottom: 16),
      child: Text(
        title,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.textSecondary,
              fontSize: 12,
              letterSpacing: 1.6,
              fontWeight: FontWeight.w500,
            ),
      ),
    );
  }

  Widget _buildSettingsGroup(String title, List<String> items,
      {bool strikethrough = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildGroupTitle(title),
        for (final item in items)
          InkWell(
            borderRadius: BorderRadius.circular(12),
            // UI-only tap feedback; the team will connect settings actions later.
            onTap: () {},
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
              child: Text(
                item,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w400,
                      height: 1.4,
                      decoration:
                          strikethrough ? TextDecoration.lineThrough : null,
                    ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildIconGroup(
      String title, int startIndex, List<(IconData, Color)> icons) {
    return Column(
      children: [
        _buildGroupTitle(title),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 16,
          runSpacing: 16,
          children: [
            for (var index = 0; index < icons.length; index++)
              Semantics(
                button: true,
                selected: _selectedIcon == startIndex + index,
                label: '${title.toLowerCase()} ${index + 1}',
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Material(
                      color: icons[index].$2,
                      borderRadius: BorderRadius.circular(18),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        key: ValueKey('app-icon-${startIndex + index}'),
                        onTap: () =>
                            setState(() => _selectedIcon = startIndex + index),
                        child: SizedBox(
                          width: 64,
                          height: 64,
                          child: Icon(icons[index].$1,
                              size: 30, color: AppColors.textPrimary),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 6,
                      width: 6,
                      child: _selectedIcon == startIndex + index
                          ? const DecoratedBox(
                              key: ValueKey('selected-icon-dot'),
                              decoration: BoxDecoration(
                                color: AppColors.textSecondary,
                                shape: BoxShape.circle,
                              ),
                            )
                          : null,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}
