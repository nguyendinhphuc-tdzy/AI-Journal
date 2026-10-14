import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // UI-only preferences; scheduling, audio and persistence are not connected.
  bool _dailyReminder = false;
  bool _soundEffects = true;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(children: [
                IconButton(
                  tooltip: 'Back to Home',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_ios_new),
                  color: AppColors.textPrimary,
                ),
                Expanded(
                  child: Text(
                    'Settings',
                    textAlign: TextAlign.center,
                    style: textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 48),
              ]),
            ),
            Expanded(
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Center(
                            child: CircleAvatar(
                              radius: 40,
                              backgroundColor: AppColors.primaryLight,
                              child: Icon(Icons.person_outline,
                                  size: 40, color: AppColors.primaryDark),
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Sample profile until account data is available.
                          Text('Nudaeng Lover',
                              textAlign: TextAlign.center,
                              style: textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              )),
                          const SizedBox(height: 4),
                          Text('Joined October 2026',
                              textAlign: TextAlign.center,
                              style: textTheme.bodySmall?.copyWith(
                                color: AppColors.textSecondary,
                              )),
                          const SizedBox(height: 28),
                          _settingsCard(
                            context,
                            title: 'Preferences',
                            children: [
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Daily Reminder'),
                                value: _dailyReminder,
                                activeThumbColor: AppColors.primary,
                                activeTrackColor: AppColors.primaryLight,
                                onChanged: (value) =>
                                    setState(() => _dailyReminder = value),
                              ),
                              const Divider(height: 1, color: AppColors.border),
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Sound Effects'),
                                value: _soundEffects,
                                activeThumbColor: AppColors.primary,
                                activeTrackColor: AppColors.primaryLight,
                                onChanged: (value) =>
                                    setState(() => _soundEffects = value),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _settingsCard(
                            context,
                            title: 'Data & Privacy',
                            // Disabled until cloud/export flows are implemented.
                            children: const [
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                enabled: false,
                                leading: Icon(Icons.cloud_outlined),
                                title: Text('Sync to Cloud'),
                              ),
                              Divider(height: 1, color: AppColors.border),
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                enabled: false,
                                leading: Icon(Icons.file_download_outlined),
                                title: Text('Export Journal'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          const SizedBox(height: 24),
                          Center(
                            child: Semantics(
                              label: 'Nudaeng companion',
                              child: Container(
                                width: 80,
                                height: 80,
                                color: Colors.transparent,
                                child: ColorFiltered(
                                  // White-to-alpha key also removes white details.
                                  colorFilter: const ColorFilter.matrix([
                                    // dart format off
                                    1, 0, 0, 0, 0,
                                    0, 1, 0, 0, 0,
                                    0, 0, 1, 0, 0,
                                    -4.252, -14.304, -1.444, 20, 0,
                                    // dart format on
                                  ]),
                                  child: Image.asset(
                                    'assets/images/loading.gif',
                                    width: 80,
                                    height: 80,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Display version requested by the UI wireframe.
                          Text('v1.0.0',
                              textAlign: TextAlign.center,
                              style: textTheme.bodySmall?.copyWith(
                                color: AppColors.textSecondary,
                              )),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _settingsCard(BuildContext context,
      {required String title, required List<Widget> children}) {
    return Card(
      color: AppColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    )),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }
}
