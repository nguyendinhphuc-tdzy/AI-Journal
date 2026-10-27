import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/app_ui.dart';
import '../onboarding/data/onboarding_store.dart';
import '../auth/presentation/auth_gate.dart';
import '../onboarding/data/nickname.dart';
import '../onboarding/data/journal_goal.dart';
import '../home/data/home_scene_settings.dart';
import '../sound/app_sound.dart';
import '../sound/data/sound_settings.dart';
import 'data/writing_preferences.dart';
import 'widgets/setting_editor.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Preview selection only: native app icons and persistence are not connected.
  int _selectedIcon = 0;
  late Future<OnboardingStore> _onboarding;
  late Future<WritingPreferences> _preferences;
  late Future<HomeSceneSettings> _scene;
  late Future<SoundSettings> _sound;
  bool _editing = false;
  bool _signingOut = false;

  @override
  void initState() {
    super.initState();
    _onboarding = OnboardingStore.open();
    _preferences = WritingPreferences.open();
    _scene = HomeSceneSettings.open();
    _sound = SoundSettings.open();
  }

  Future<void> _edit(String item) async {
    if (_editing) return;
    _editing = true;
    try {
      final store = await _onboarding;
      final prefs = await _preferences;
      final scene = await _scene;
      final sound = await _sound;
      if (!mounted) return;
      String initial;
      Map<String, String>? options;
      String? note;
      String? Function(String)? validate;
      double Function(String)? previewSize;
      ValueChanged<String>? onPreview;
      Future<void> Function(String) save;
      switch (item) {
        case 'what do friends call you?':
          initial = store.nickname ?? '';
          note = 'Tối đa 30 ký tự. Để trống để bỏ biệt danh.';
          validate = (value) =>
              Nickname.isTooLong(value) ? 'Biệt danh tối đa 30 ký tự.' : null;
          save = (value) => store.saveNickname(Nickname.normalize(value));
        case 'pick your inspirations path':
          initial = store.goal?.name ?? 'unset';
          options = {
            'unset': 'Chưa chọn mục tiêu',
            for (final goal in JournalGoal.values) goal.name: goal.label
          };
          save =
              (value) => store.saveGoal(JournalGoal.values.asNameMap()[value]);
        case 'text size':
          initial = prefs.textSize.toString();
          options = {
            for (final size in WritingPreferences.sizes)
              size.toString(): '${size.toInt()} px'
          };
          note = 'Áp dụng cho nội dung bạn viết trong Nhật ký hôm nay.';
          previewSize = double.parse;
          save = (value) => prefs.saveTextSize(double.parse(value));
        case 'scene':
          initial = scene.scene.name;
          options = {
            for (final value in HomeScene.values) value.name: value.label
          };
          note = 'Cảnh ở đầu thẻ Khoảnh khắc suy ngẫm trên Trang chủ.';
          save = (value) => scene.saveScene(HomeScene.values.byName(value));
        case 'dynamic theme':
          initial = scene.effect.name;
          options = {
            for (final value in SceneEffect.values) value.name: value.label
          };
          note = 'Rơi trong khung cảnh trên Trang chủ. Tự tắt khi máy bật '
              'giảm chuyển động.';
          save = (value) => scene.saveEffect(SceneEffect.values.byName(value));
        case 'background music':
          initial = sound.music.name;
          options = {
            for (final track in MusicTrack.values) track.name: track.label
          };
          note = 'Phát nhỏ khi bạn dùng app; tự dừng khi thoát ra ngoài. '
              'Chạm để nghe thử.';
          onPreview = (value) =>
              AppSound.instance.previewMusic(MusicTrack.values.byName(value));
          save = (value) => sound.saveMusic(MusicTrack.values.byName(value));
        case 'music volume':
          initial = sound.musicLevel.name;
          options = {
            for (final level in SoundLevel.values)
              if (level != SoundLevel.off) level.name: level.label
          };
          save =
              (value) => sound.saveMusicLevel(SoundLevel.values.byName(value));
        case 'pen sound':
          initial = sound.pen.name;
          options = {for (final pen in PenSound.values) pen.name: pen.label};
          note = 'Nghe khi bạn viết nhật ký. Chạm để nghe thử.';
          onPreview = (value) =>
              AppSound.instance.previewPen(PenSound.values.byName(value));
          save = (value) => sound.savePen(PenSound.values.byName(value));
        case 'interface sounds':
          initial = sound.effects.name;
          options = {
            for (final level in SoundLevel.values) level.name: level.label
          };
          note = 'Tiếng bút, lật trang, lưu bài và những khoảnh khắc nhỏ '
              'khác. Trên iPhone, im khi máy đang ở chế độ im lặng.';
          save = (value) => sound.saveEffects(SoundLevel.values.byName(value));
        case 'haptic':
          initial = prefs.haptic ? 'on' : 'off';
          options = {'off': 'Tắt', 'on': 'Bật'};
          note =
              'Rung nhẹ khi lưu cài đặt, đổi nền, suy ngẫm sâu hơn và hoàn thành nhật ký trên thiết bị hỗ trợ.';
          save = (value) => prefs.saveHaptic(value == 'on');
        default:
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(item == 'daily reminders'
                  ? 'Lịch nhắc hiện chỉ là mô phỏng, chưa phát thông báo thật.'
                  : 'Tính năng này chưa được hỗ trợ trong phiên bản hiện tại.')));
          return;
      }
      final changed = await showAppSheet<bool>(context,
          builder: (_) => SettingEditor(
              title: _settingsLabel(item),
              initial: initial,
              options: options,
              note: note,
              validate: validate,
              previewSize: previewSize,
              onPreview: onPreview,
              save: save));
      // A preview (e.g. another music) gives way to what is saved.
      await AppSound.instance.refresh();
      if (!mounted || changed != true) return;
      await prefs.feedback();
      if (!mounted) return;
      setState(() {});
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Không tải được cài đặt. Hãy mở lại màn hình để thử lại.')));
      }
    } finally {
      _editing = false;
    }
  }

  Widget _buildPreferences() =>
      FutureBuilder<(WritingPreferences, HomeSceneSettings, SoundSettings)>(
        future: (_preferences, _scene, _sound).wait,
        builder: (context, snapshot) {
          final prefs = snapshot.data?.$1;
          final scene = snapshot.data?.$2;
          final sound = snapshot.data?.$3;
          return _buildSettingsGroup('Tùy chỉnh', const [
            'dynamic theme',
            'scene',
            'handwriting',
            'text size',
            'background music',
            'music volume',
            'pen sound',
            'interface sounds',
            'haptic',
          ], values: {
            'dynamic theme': scene?.effect.label ?? 'Đang tải…',
            'scene': scene?.scene.label ?? 'Đang tải…',
            'text size':
                prefs == null ? 'Đang tải…' : '${prefs.textSize.toInt()} px',
            'background music': sound?.music.label ?? 'Đang tải…',
            'music volume': sound?.musicLevel.label ?? 'Đang tải…',
            'pen sound': sound?.pen.label ?? 'Đang tải…',
            'interface sounds': sound?.effects.label ?? 'Đang tải…',
            'haptic':
                prefs == null ? 'Đang tải…' : (prefs.haptic ? 'Bật' : 'Tắt'),
          });
        },
      );

  Widget _buildGeneralSettings() {
    return FutureBuilder<OnboardingStore>(
      future: _onboarding,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Column(children: [
            _buildGroupTitle('Cài đặt chung'),
            const Text('Không tải được thông tin của bạn.',
                style: AppText.body),
            TextButton(
              onPressed: () => setState(() {
                _onboarding = OnboardingStore.open();
              }),
              child: const Text('Thử lại'),
            ),
          ]);
        }
        final store = snapshot.data;
        final loading = store == null;
        final reminders = store?.reminders;
        return _buildSettingsGroup('Cài đặt chung', const [
          'who says plus',
          'what do friends call you?',
          'pick your inspirations path',
          'daily reminders',
          'language',
        ], values: {
          'what do friends call you?': loading
              ? 'Đang tải…'
              : (store.nickname?.trim().isNotEmpty == true
                  ? store.nickname!
                  : 'Chưa đặt biệt danh'),
          'pick your inspirations path':
              loading ? 'Đang tải…' : store.goal?.label ?? 'Chưa chọn mục tiêu',
          'daily reminders': loading
              ? 'Đang tải…'
              : (reminders!.isEmpty
                  ? 'Chưa có lịch nhắc đã lưu'
                  : reminders.entries
                      .map(
                          (entry) => '${entry.key.label}: ${entry.value.label}')
                      .join('\n')),
          'language': 'Tiếng Việt',
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(children: [
          // Fixed, like the top of other screens opened over a tab: Close
          // stays in reach however far the settings scroll.
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 12),
            child: AppPageHeader(
              title: 'Hồ sơ',
              subtitle: 'Thông tin và tùy chỉnh của bạn',
              trailing: [
                AppIconAction(
                  icon: Icons.close_rounded,
                  tooltip: 'Đóng',
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          // Where the fixed header ends and the settings scroll under it.
          const Divider(height: 1, color: AppColors.border),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, 0, AppSpacing.lg, 40),
              children: [
                _buildGeneralSettings(),
                _buildPreferences(),
                _buildSettingsGroup(
                    'Bảo mật',
                    const [
                      'lock with passcode',
                      'lock with face id',
                    ],
                    comingSoon: true),
                _buildSettingsGroup('Thông tin', const [
                  'notes for you',
                  'rate app',
                  'contact support',
                ]),
                _buildIconGroup('Biểu tượng ứng dụng', 0, const [
                  (Icons.auto_stories_outlined, Color(0xFFD6E9E4)),
                  (Icons.pets_outlined, Color(0xFFF1E4CE)),
                  (Icons.local_florist_outlined, Color(0xFFECDDE4)),
                  (Icons.wb_sunny_outlined, Color(0xFFE4E5F1)),
                ]),
                // Only authenticated accounts have a real sign-out action.
                // This restores AuthGate navigation after PR29 replaced the
                // old profile without its logout button.
                if (AuthScope.maybeOf(context) case final auth?) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Center(
                    child: TextButton.icon(
                      onPressed: _signingOut ? null : () async {
                        final messenger = ScaffoldMessenger.of(context);
                        setState(() => _signingOut = true);
                        try {
                          await auth.signOut();
                        } catch (_) {
                          if (mounted) {
                            messenger.showSnackBar(
                              const SnackBar(content: Text(
                                'Không thể đăng xuất. Hãy thử lại.',
                              )),
                            );
                          }
                        } finally {
                          if (mounted) setState(() => _signingOut = false);
                        }
                      },
                      icon: const Icon(Icons.logout),
                      label: const Text('Đăng xuất'),
                    ),
                  ),
                ],
                _buildIconGroup('Biểu tượng đặc biệt', 4, const [
                  (Icons.nightlight_round, Color(0xFFD7DFE8)),
                  (Icons.favorite_border, Color(0xFFECCFCB)),
                  (Icons.forest_outlined, Color(0xFFDDE5D1)),
                  (Icons.star_outline, Color(0xFFF1E6BF)),
                ]),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildGroupTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(
          top: AppSpacing.xxl, bottom: AppSpacing.sm, left: AppSpacing.xs),
      child: Semantics(
        header: true,
        child: Text(title,
            style: AppText.label.copyWith(color: AppColors.textSecondary)),
      ),
    );
  }

  /// One card per group; each setting is a row with its current value under
  /// the name. Settings not built yet say "Sắp có" and look disabled.
  Widget _buildSettingsGroup(String title, List<String> items,
      {bool comingSoon = false, Map<String, String> values = const {}}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildGroupTitle(title),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(children: [
            for (var index = 0; index < items.length; index++) ...[
              if (index > 0)
                const Divider(
                    height: 1,
                    indent: AppSpacing.md + _iconTile + 14,
                    color: AppColors.border),
              _buildSettingRow(items[index], values[items[index]], comingSoon),
            ],
          ]),
        ),
      ],
    );
  }

  Widget _buildSettingRow(String item, String? value, bool comingSoon) {
    return InkWell(
      key: ValueKey('setting-item-$item'),
      onTap: () => _edit(item),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: Padding(
          padding:
              const EdgeInsets.fromLTRB(AppSpacing.md, 12, AppSpacing.sm, 12),
          child: Row(children: [
            // The setting's icon on a soft tile; muted when not built yet.
            Container(
              width: _iconTile,
              height: _iconTile,
              decoration: BoxDecoration(
                color:
                    comingSoon ? AppColors.background : AppColors.primaryLight,
                borderRadius:
                    const BorderRadius.all(Radius.circular(AppRadius.small)),
              ),
              child: Icon(_settingIcon(item),
                  size: 20,
                  color: comingSoon
                      ? AppColors.textSecondary
                      : AppColors.primaryAction),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _settingsLabel(item),
                    style: AppText.body.copyWith(
                        color: comingSoon
                            ? AppColors.textSecondary
                            : AppColors.textPrimary),
                  ),
                  if (value != null) ...[
                    const SizedBox(height: 2),
                    Text(value,
                        key: ValueKey('setting-value-$item'),
                        style: AppText.meta),
                  ],
                ],
              ),
            ),
            if (comingSoon)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                margin: const EdgeInsets.only(right: AppSpacing.sm),
                decoration: const ShapeDecoration(
                    color: AppColors.background,
                    shape: StadiumBorder(
                        side: BorderSide(color: AppColors.border))),
                child: const Text('Sắp có', style: AppText.meta),
              )
            else
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textSecondary),
          ]),
        ),
      ),
    );
  }

  String _settingsLabel(String item) => switch (item) {
        'who says plus' => 'Gói Nudaeng Plus',
        'what do friends call you?' => 'Bạn bè gọi bạn là gì?',
        'pick your inspirations path' => 'Chọn con đường truyền cảm hứng',
        'daily reminders' => 'Nhắc nhở mỗi ngày',
        'language' => 'Ngôn ngữ',
        'dynamic theme' => 'Giao diện động',
        'scene' => 'Khung cảnh',
        'handwriting' => 'Nét chữ',
        'text size' => 'Cỡ chữ',
        'background music' => 'Nhạc nền',
        'music volume' => 'Âm lượng nhạc',
        'pen sound' => 'Tiếng bút',
        'interface sounds' => 'Âm thanh giao diện',
        'haptic' => 'Rung phản hồi',
        'lock with passcode' => 'Khóa bằng mật mã',
        'lock with face id' => 'Khóa bằng Face ID',
        'notes for you' => 'Ghi chú cho bạn',
        'rate app' => 'Đánh giá ứng dụng',
        'contact support' => 'Liên hệ hỗ trợ',
        _ => item,
      };

  /// Size of the icon tile at the start of each setting row.
  static const _iconTile = 40.0;

  IconData _settingIcon(String item) => switch (item) {
        'who says plus' => Icons.workspace_premium_outlined,
        'what do friends call you?' => Icons.badge_outlined,
        'pick your inspirations path' => Icons.explore_outlined,
        'daily reminders' => Icons.notifications_none_rounded,
        'language' => Icons.translate_rounded,
        'dynamic theme' => Icons.auto_awesome_outlined,
        'scene' => Icons.landscape_outlined,
        'handwriting' => Icons.draw_outlined,
        'text size' => Icons.format_size_rounded,
        'background music' => Icons.music_note_outlined,
        'music volume' => Icons.volume_up_outlined,
        'pen sound' => Icons.edit_outlined,
        'interface sounds' => Icons.touch_app_outlined,
        'haptic' => Icons.vibration_rounded,
        'lock with passcode' => Icons.pin_outlined,
        'lock with face id' => Icons.face_outlined,
        'notes for you' => Icons.mail_outline_rounded,
        'rate app' => Icons.star_outline_rounded,
        'contact support' => Icons.support_agent_outlined,
        _ => Icons.tune_rounded,
      };

  Widget _buildIconGroup(
      String title, int startIndex, List<(IconData, Color)> icons) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildGroupTitle(title),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Chỉ xem trước; chưa đổi icon ngoài màn hình chính.',
                  style: AppText.meta),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.md,
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
                              onTap: () {
                                setState(
                                    () => _selectedIcon = startIndex + index);
                              },
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
                                      color: AppColors.primaryAction,
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
          ),
        ),
      ],
    );
  }
}
