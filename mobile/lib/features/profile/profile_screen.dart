import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../auth/presentation/auth_gate.dart';
import '../journal/data/api_ai_service.dart';
import '../onboarding/data/onboarding_scope.dart';
import '../onboarding/data/onboarding_store.dart';
import '../onboarding/data/nickname.dart';
import '../onboarding/data/journal_goal.dart';
import '../onboarding/data/journaling_experience.dart';
import '../onboarding/data/data_policy.dart';
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
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    _onboarding = OnboardingStore.open();
    _preferences = WritingPreferences.open();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scoped = OnboardingScope.maybeOf(context);
    if (scoped != null) _onboarding = Future.value(scoped);
  }

  Future<void> _edit(String item) async {
    if (_editing) return;
    _editing = true;
    try {
      final store = await _onboarding;
      final prefs = await _preferences;
      if (!mounted) return;
      String initial;
      Map<String, String>? options;
      String? note;
      String? Function(String)? validate;
      double Function(String)? previewSize;
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
        case 'journaling experience':
          initial = store.experience?.name ?? 'unknown';
          options = {
            'unknown': 'Chưa thiết lập',
            for (final experience in JournalingExperience.options)
              experience.name: experience.label
          };
          save = (value) =>
              store.saveExperience(JournalingExperience.values.byName(value));
        case 'ai reflections':
          initial = store.aiEnabled == true ? 'on' : 'off';
          final aiPolicy = AiRemoteScope.maybeOf(context) == null
              ? DataPolicy.current
              : DataPolicy.localOllama;
          options = {
            'off': 'Không dùng AI',
            'on': aiPolicy.realLocalAi
                ? 'Dùng AI local qua backend'
                : 'Dùng phản hồi AI mô phỏng'
          };
          note = '${aiPolicy.aiRequest}\n${DataPolicy.choiceNote}';
          save = (value) => store.saveAiChoice(
              enabled: value == 'on',
              policyVersion: aiPolicy.version);
        case 'paper':
          initial = prefs.paper ? 'paper' : 'plain';
          options = {'paper': 'Nền giấy', 'plain': 'Nền trắng'};
          save = (value) => prefs.savePaper(value == 'paper');
        case 'text size':
          initial = prefs.textSize.toString();
          options = {
            for (final size in WritingPreferences.sizes)
              size.toString(): '${size.toInt()} px'
          };
          note = 'Áp dụng cho nội dung bạn viết trong Nhật ký hôm nay.';
          previewSize = double.parse;
          save = (value) => prefs.saveTextSize(double.parse(value));
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
      final changed = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (_) => SettingEditor(
              title: _settingsLabel(item),
              initial: initial,
              options: options,
              note: note,
              validate: validate,
              previewSize: previewSize,
              save: save));
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

  Widget _buildPreferences() => FutureBuilder<WritingPreferences>(
        future: _preferences,
        builder: (context, snapshot) {
          final prefs = snapshot.data;
          return _buildSettingsGroup('TÙY CHỈNH', const [
            'dynamic theme',
            'scene',
            'paper',
            'handwriting',
            'text size',
            'background music',
            'pencil sound',
            'haptic',
          ], values: {
            'paper':
                prefs == null ? '—' : (prefs.paper ? 'Nền giấy' : 'Nền trắng'),
            'text size': prefs == null ? '—' : '${prefs.textSize.toInt()} px',
            'haptic': prefs == null ? '—' : (prefs.haptic ? 'Bật' : 'Tắt'),
          });
        },
      );

  Widget _buildGeneralSettings() {
    return FutureBuilder<OnboardingStore>(
      future: _onboarding,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Column(children: [
            _buildGroupTitle('CÀI ĐẶT CHUNG'),
            const Text('Không tải được thông tin của bạn.',
                textAlign: TextAlign.center),
            TextButton(
              onPressed: () => setState(() {
                final scoped = OnboardingScope.maybeOf(context);
                _onboarding = scoped == null
                    ? OnboardingStore.open()
                    : Future.value(scoped);
              }),
              child: const Text('Thử lại'),
            ),
          ]);
        }
        final store = snapshot.data;
        final loading = store == null;
        final reminders = store?.reminders;
        final experience = store?.experience?.label;
        return _buildSettingsGroup('CÀI ĐẶT CHUNG', const [
          'who says plus',
          'what do friends call you?',
          'pick your inspirations path',
          'journaling experience',
          'ai reflections',
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
          'journaling experience': loading
              ? 'Đang tải…'
              : (experience == null || experience.isEmpty
                  ? 'Chưa thiết lập'
                  : experience),
          'ai reflections': loading
              ? 'Đang tải…'
              : switch (store.aiEnabled) {
                  true => 'Đã chọn dùng AI',
                  false => 'Đã chọn không dùng AI',
                  null => 'Chưa thiết lập',
                },
          'daily reminders': loading
              ? 'Đang tải…'
              : (reminders!.isEmpty
                  ? 'Chưa có lịch nhắc đã lưu'
                  : reminders.entries
                      .map(
                          (entry) => '${entry.key.label}: ${entry.value.label}')
                      .join('\n')),
        });
      },
    );
  }

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
                  tooltip: 'Đóng',
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
                  icon: const Icon(Icons.logout),
                  label: const Text('Đăng xuất'),
                  onPressed: () async {
                    try {
                      await auth.signOut();
                    } catch (_) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Không thể đăng xuất. Thử lại.')),
                      );
                    }
                  },
                ),
              ),
            if (GuestScope.maybeOf(context) case final guest?)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.person_add_alt_1_outlined),
                  label: const Text('Đăng nhập / Tạo tài khoản'),
                  onPressed: () async {
                    final discard = await showDialog<bool>(
                      context: context,
                      builder: (dialogContext) => AlertDialog(
                        title: const Text('Rời chế độ khách?'),
                        content: const Text(
                          'Nhật ký, bản nháp và album của khách trên thiết bị '
                          'sẽ bị xóa, không chuyển sang tài khoản mới.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(dialogContext, false),
                            child: const Text('Hủy'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(dialogContext, true),
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
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Chưa thể xóa dữ liệu khách. Thử lại.'),
                      ));
                    }
                  },
                ),
              ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                children: [
                  _buildGeneralSettings(),
                  _buildPreferences(),
                  _buildSettingsGroup(
                      'BẢO MẬT',
                      const [
                        'lock with passcode',
                        'lock with face id',
                      ],
                      strikethrough: true),
                  _buildSettingsGroup('THÔNG TIN', const [
                    'notes for you',
                    'rate app',
                    'contact support',
                  ]),
                  _buildIconGroup('BIỂU TƯỢNG ỨNG DỤNG', 0, const [
                    (Icons.auto_stories_outlined, Color(0xFFD6E9E4)),
                    (Icons.pets_outlined, Color(0xFFF1E4CE)),
                    (Icons.local_florist_outlined, Color(0xFFECDDE4)),
                    (Icons.wb_sunny_outlined, Color(0xFFE4E5F1)),
                  ]),
                  _buildIconGroup('BIỂU TƯỢNG ĐẶC BIỆT', 4, const [
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
      {bool strikethrough = false, Map<String, String> values = const {}}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildGroupTitle(title),
        for (final item in items)
          InkWell(
            key: ValueKey('setting-item-$item'),
            borderRadius: BorderRadius.circular(12),
            onTap: () => _edit(item),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
              child: Column(children: [
                Text(
                  _settingsLabel(item),
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
                if (values[item] case final value?) ...[
                  const SizedBox(height: 6),
                  Text(value,
                      key: ValueKey('setting-value-$item'),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                            height: 1.4,
                          )),
                ],
              ]),
            ),
          ),
      ],
    );
  }

  String _settingsLabel(String item) => switch (item) {
        'who says plus' => 'Gói Nudaeng Plus',
        'what do friends call you?' => 'Bạn bè gọi bạn là gì?',
        'pick your inspirations path' => 'Chọn con đường truyền cảm hứng',
        'journaling experience' => 'Trải nghiệm viết nhật ký',
        'ai reflections' => 'AI Chiêm nghiệm',
        'daily reminders' => 'Nhắc nhở mỗi ngày',
        'language' => 'Ngôn ngữ',
        'dynamic theme' => 'Giao diện động',
        'scene' => 'Khung cảnh',
        'paper' => 'Nền giấy',
        'handwriting' => 'Nét chữ',
        'text size' => 'Cỡ chữ',
        'background music' => 'Nhạc nền',
        'pencil sound' => 'Tiếng bút chì',
        'haptic' => 'Rung phản hồi',
        'lock with passcode' => 'Khóa bằng mật mã',
        'lock with face id' => 'Khóa bằng Face ID',
        'notes for you' => 'Ghi chú cho bạn',
        'rate app' => 'Đánh giá ứng dụng',
        'contact support' => 'Liên hệ hỗ trợ',
        _ => item,
      };

  Widget _buildIconGroup(
      String title, int startIndex, List<(IconData, Color)> icons) {
    return Column(
      children: [
        _buildGroupTitle(title),
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text('Chỉ xem trước; chưa đổi icon ngoài màn hình chính.',
              textAlign: TextAlign.center),
        ),
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
                        onTap: () {
                          setState(() => _selectedIcon = startIndex + index);
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
