import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/app_delete_dialog.dart';
import '../../core/widgets/app_ui.dart';
import '../onboarding/data/onboarding_scope.dart';
import '../onboarding/data/onboarding_store.dart';
import '../onboarding/data/nickname.dart';
import '../onboarding/data/journal_goal.dart';
import '../explore/data/place_mood.dart';
import '../journal/data/api_ai_service.dart';
import '../home/data/home_scene_settings.dart';
import '../social/data/friends_account.dart';
import '../social/data/friend_space.dart';
import '../social/presentation/facebook_login_screen.dart';
import '../sound/app_sound.dart';
import '../auth/presentation/auth_gate.dart';
import '../sound/data/sound_settings.dart';
import 'data/writing_preferences.dart';
import 'widgets/setting_editor.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, FriendsAccount? friends})
      : _friends = friends;

  final FriendsAccount? _friends;

  /// Facebook login for friends on the app (simulated for now).
  FriendsAccount get friends => _friends ?? MockFriendsAccount.instance;

  static const accountTitle = 'Tài khoản';
  static const facebookLabel = 'Facebook';
  static const facebookOff = 'Chưa kết nối · để chia sẻ với bạn bè trên app';
  static String facebookOn(int count) =>
      'Đã kết nối · $count bạn bè trên app (bản thử)';
  static const disconnectTitle = 'Ngắt kết nối Facebook?';
  static const disconnectBody =
      'Space của bạn sẽ được làm trống và bạn không chia sẻ được bài 24 giờ '
      'cho đến khi đăng nhập lại. Kỷ niệm của bạn vẫn ở nguyên.';
  static const disconnectLabel = 'Ngắt kết nối';
  static const keepLabel = 'Giữ kết nối';
  static const signOutLabel = 'Đăng xuất';
  static const aiRepliesNote = 'Khi bật, nội dung bạn lưu hoặc dùng Nhìn lại '
      'cùng bạn được gửi tới AI của nhóm để phân tích và đặt câu hỏi. Khi tắt, '
      'nhật ký không được gửi tới AI. Phân tích hiện chỉ lưu trên thiết bị, '
      'không đồng bộ khi đổi máy.';
  static const guestSignOutTitle = 'Thoát chế độ khách?';
  static const guestSignOutBody =
      'Bạn chưa có tài khoản, nên nhật ký, kỷ niệm và ảnh chỉ nằm trên máy '
      'này. Khi thoát, tất cả sẽ bị xóa và không lấy lại được.';
  static const guestSignOutConfirm = 'Xóa và thoát';
  static const guestSignOutFailed =
      'Chưa xóa được dữ liệu khách. Bạn thử lại nhé.';

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

  @override
  void initState() {
    super.initState();
    _onboarding = OnboardingScope.storeOf(context);
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
        case 'ai replies':
          initial = store.aiInApp ? 'on' : 'off';
          options = {'on': 'Bật', 'off': 'Tắt'};
          note = ProfileScreen.aiRepliesNote;
          save = (value) => store.saveAiInApp(value == 'on');
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
          note = 'Cảnh ở đầu thẻ Một chút cho bản thân trên Trang chủ.';
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
                _onboarding = OnboardingScope.storeOf(context);
              }),
              child: const Text('Thử lại'),
            ),
          ]);
        }
        final store = snapshot.data;
        final loading = store == null;
        // Only settings that open something; the rest (Plus, reminders,
        // language) come back once they work. "Phản hồi AI" only where there
        // is AI: a signed-in account.
        return _buildSettingsGroup('Cài đặt chung', [
          'what do friends call you?',
          'pick your inspirations path',
          if (AiRemoteScope.maybeOf(context) != null) 'ai replies',
        ], values: {
          'what do friends call you?': loading
              ? 'Đang tải…'
              : (store.nickname?.trim().isNotEmpty == true
                  ? store.nickname!
                  : 'Chưa đặt biệt danh'),
          'pick your inspirations path':
              loading ? 'Đang tải…' : store.goal?.label ?? 'Chưa chọn mục tiêu',
          'ai replies': loading ? 'Đang tải…' : (store.aiInApp ? 'Bật' : 'Tắt'),
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
                _buildAccount(),
                _buildGeneralSettings(),
                _buildPreferences(),
                _buildIconGroup(),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  /// Facebook: connected or not; a tap connects, or asks before
  /// disconnecting.
  Widget _buildAccount() => ValueListenableBuilder<FriendsSession?>(
        valueListenable: widget.friends.session,
        builder: (context, session, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildGroupTitle(ProfileScreen.accountTitle),
            AppCard(
              padding: EdgeInsets.zero,
              child: InkWell(
                key: const ValueKey('setting-item-facebook'),
                onTap: () => session == null
                    ? openFacebookLogin(context, widget.friends)
                    : _disconnect(),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 64),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                        AppSpacing.md, 12, AppSpacing.sm, 12),
                    child: Row(children: [
                      Container(
                        width: _iconTile,
                        height: _iconTile,
                        decoration: BoxDecoration(
                          color: facebookBlue.withValues(alpha: .1),
                          borderRadius: const BorderRadius.all(
                              Radius.circular(AppRadius.small)),
                        ),
                        child: const Icon(Icons.facebook_rounded,
                            size: 22, color: facebookBlue),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(ProfileScreen.facebookLabel,
                                style: AppText.body),
                            const SizedBox(height: 2),
                            Text(
                                session == null
                                    ? ProfileScreen.facebookOff
                                    : ProfileScreen.facebookOn(
                                        session.friends.length),
                                style: AppText.meta),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded,
                          color: AppColors.textSecondary),
                    ]),
                  ),
                ),
              ),
            ),
            if (AuthScope.maybeOf(context) != null || GuestScope.maybeOf(context) != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.logout),
                  label: const Text(ProfileScreen.signOutLabel),
                  onPressed: () async {
                    final auth = AuthScope.maybeOf(context);
                    final guest = GuestScope.maybeOf(context);
                    try {
                      if (auth != null) {
                        await auth.signOut();
                      } else if (guest != null) {
                        // A guest's data goes for good: say so first. The
                        // dialog shows its own failure and "Thử lại".
                        final left = await AppDeleteDialog.present(context,
                            builder: (_) => AppDeleteDialog(
                                  title: ProfileScreen.guestSignOutTitle,
                                  body: ProfileScreen.guestSignOutBody,
                                  confirmLabel:
                                      ProfileScreen.guestSignOutConfirm,
                                  failed: ProfileScreen.guestSignOutFailed,
                                  onConfirm: guest.onLeaveGuest,
                                ));
                        if (!left) return;
                      }
                      if (context.mounted) {
                        Navigator.of(context).popUntil((route) => route.isFirst);
                      }
                    } catch (_) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Không thể đăng xuất. Thử lại.')),
                        );
                      }
                    }
                  },
                ),
              ),
          ],
        ),
      );

  Future<void> _disconnect() async {
    final confirmed = await showAppSheet<bool>(
      context,
      builder: (sheet) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(ProfileScreen.disconnectTitle,
              style: AppText.sectionTitle),
          const SizedBox(height: AppSpacing.sm),
          const Text(ProfileScreen.disconnectBody,
              style: AppText.bodySecondary),
          const SizedBox(height: AppSpacing.lg),
          AppPrimaryButton(
              label: ProfileScreen.keepLabel,
              compact: true,
              onPressed: () => Navigator.pop(sheet, false)),
          const SizedBox(height: AppSpacing.sm),
          AppSecondaryButton(
              label: ProfileScreen.disconnectLabel,
              compact: true,
              onPressed: () => Navigator.pop(sheet, true)),
        ],
      ),
    );
    if (confirmed == true) {
      await widget.friends.disconnect();
      // Signed out: the space goes too (it was made of Facebook friends).
      await FriendSpace.instance.clear();
    }
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
        'ai replies' => 'Phản hồi AI',
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
        'ai replies' => Icons.psychology_outlined,
        'lock with passcode' => Icons.pin_outlined,
        'lock with face id' => Icons.face_outlined,
        'notes for you' => Icons.mail_outline_rounded,
        'rate app' => Icons.star_outline_rounded,
        'contact support' => Icons.support_agent_outlined,
        _ => Icons.tune_rounded,
      };

  /// Three Nudaeng app icons to pick from. Only a preview here: the icon on
  /// the home screen does not change yet.
  static const appIcons = [
    ('Nudaeng vui vẻ', PlaceMood.happy, Color(0xFFF1E4CE)),
    ('Nudaeng bình yên', PlaceMood.peaceful, Color(0xFFD6E9E4)),
    ('Nudaeng háo hức', PlaceMood.excited, Color(0xFFE4E5F1)),
  ];

  Widget _buildIconGroup() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildGroupTitle('Biểu tượng ứng dụng'),
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
                    for (final (index, (name, mood, tint)) in appIcons.indexed)
                      Semantics(
                        button: true,
                        selected: _selectedIcon == index,
                        label: name,
                        excludeSemantics: true,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Material(
                              color: tint,
                              clipBehavior: Clip.antiAlias,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                                side: BorderSide(
                                    color: _selectedIcon == index
                                        ? AppColors.primaryAction
                                        : Colors.transparent,
                                    width: 2),
                              ),
                              child: InkWell(
                                key: ValueKey('app-icon-$index'),
                                onTap: () =>
                                    setState(() => _selectedIcon = index),
                                child: SizedBox.square(
                                  dimension: 72,
                                  // Head and shoulders, as on a launcher.
                                  child: Image.asset(mood.asset,
                                      fit: BoxFit.cover,
                                      alignment: const Alignment(0, -.6),
                                      cacheWidth: 220),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(name.replaceFirst('Nudaeng ', ''),
                                style: AppText.meta.copyWith(
                                    color: _selectedIcon == index
                                        ? AppColors.primaryAction
                                        : AppColors.textSecondary,
                                    fontWeight: _selectedIcon == index
                                        ? FontWeight.w600
                                        : null)),
                            const SizedBox(height: 4),
                            SizedBox(
                              height: 6,
                              width: 6,
                              child: _selectedIcon == index
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
