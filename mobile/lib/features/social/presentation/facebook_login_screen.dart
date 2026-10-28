import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/widgets/app_ui.dart';
import '../data/friends_account.dart';

abstract final class FacebookLoginText {
  static const backTooltip = 'Quay lại';
  static const title = 'Tiếp tục với Facebook';
  static const subtitle =
      'Để thấy bạn bè Facebook cũng dùng app và chia sẻ kỷ niệm với họ.';
  static const mockNote =
      'Bản thử: chưa kết nối Facebook thật. Khi có, Facebook tự hỏi bạn đăng '
      'nhập; app không bao giờ nhận mật khẩu Facebook. Bạn bè hiện ra là bạn '
      'bè mẫu.';
  static const laterLabel = 'Để sau';

  static const consentTitle = 'Nhật ký AI muốn nhận';
  static const consentGets = [
    (Icons.account_circle_outlined, 'Tên và ảnh đại diện công khai'),
    (Icons.group_outlined, 'Bạn bè của bạn cũng dùng app'),
  ];
  static const consentNever =
      'Không đăng gì lên Facebook. Không đọc tin nhắn hay bài đăng của bạn.';
  static const allowLabel = 'Cho phép';
  static const denyLabel = 'Không cho phép';
  static const simulateFailure = 'Giả lập lỗi kết nối';

  static const connecting = 'Đang kết nối với Facebook…';
  static const doneTitle = 'Đã kết nối';
  static String doneBody(int count) =>
      '$count bạn bè của bạn đang dùng app. Thêm họ vào Space ở Khám phá để '
      'chia sẻ kỷ niệm.';
  static const continueLabel = 'Tiếp tục';
  static const failedTitle = 'Chưa đăng nhập được';
  static const failedBody =
      'Có thể mạng đang chập chờn. Bạn thử lại, hoặc để sau cũng được.';
  static const retryLabel = 'Thử lại';
}

/// Facebook's blue, only where Facebook login is started.
const facebookBlue = Color(0xFF1877F2);

/// Facebook login (simulated): what the app asks Facebook for, then done.
/// True once connected; false when refused or closed. The password is never
/// typed in the app: in the real build Facebook's own screen asks for it
/// before this consent.
Future<bool> openFacebookLogin(
        BuildContext context, FriendsAccount account) async =>
    await Navigator.of(context).push<bool>(MaterialPageRoute(
        builder: (_) => FacebookLoginScreen(account: account))) ??
    false;

enum _Step { consent, connecting, done, failed }

/// The login itself. A real build hands this to the Facebook Login SDK:
/// Facebook's own screen takes the password and the app never sees it. This
/// stand-in keeps nothing typed: the password is only checked as filled in
/// and cleared as soon as the form is sent.
class FacebookLoginScreen extends StatefulWidget {
  const FacebookLoginScreen({super.key, required this.account});

  final FriendsAccount account;

  @override
  State<FacebookLoginScreen> createState() => _FacebookLoginScreenState();
}

class _FacebookLoginScreenState extends State<FacebookLoginScreen> {
  var _step = _Step.consent;
  FriendsSession? _session;

  Future<void> _connect({bool fail = false}) async {
    final account = widget.account;
    if (fail && account is MockFriendsAccount) account.failNext = true;
    setState(() => _step = _Step.connecting);
    try {
      final session = await account.connect();
      if (!mounted) return;
      setState(() {
        _session = session;
        _step = _Step.done;
      });
    } on FriendsConnectFailed {
      if (mounted) setState(() => _step = _Step.failed);
    }
  }

  bool get _busy => _step == _Step.connecting;

  void _finish(bool connected) => Navigator.pop(context, connected);

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.sm, AppSpacing.sm, AppSpacing.sm, 0),
              child: Row(children: [
                IconButton(
                  tooltip: FacebookLoginText.backTooltip,
                  onPressed: _busy ? null : () => _finish(false),
                  icon: const Icon(Icons.arrow_back_rounded,
                      color: AppColors.textPrimary),
                ),
              ]),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xl),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: AnimatedSwitcher(
                      duration: reduced
                          ? Duration.zero
                          : const Duration(milliseconds: 200),
                      child: KeyedSubtree(key: ValueKey(_step), child: _body()),
                    ),
                  ),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _body() => switch (_step) {
        _Step.consent => _consent(),
        _Step.connecting => _working(FacebookLoginText.connecting),
        _Step.done => _done(),
        _Step.failed => _failed(),
      };

  Widget _header() => Column(children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
              color: facebookBlue.withValues(alpha: .1),
              shape: BoxShape.circle),
          child:
              const Icon(Icons.facebook_rounded, size: 40, color: facebookBlue),
        ),
        const SizedBox(height: AppSpacing.md),
        Semantics(
          header: true,
          child: const Text(FacebookLoginText.title,
              textAlign: TextAlign.center, style: AppText.sectionTitle),
        ),
        const SizedBox(height: AppSpacing.sm),
        const Text(FacebookLoginText.subtitle,
            textAlign: TextAlign.center, style: AppText.bodySecondary),
      ]);

  Widget _consent() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(),
          const SizedBox(height: AppSpacing.lg),
          const _Note(FacebookLoginText.mockNote, icon: Icons.science_outlined),
          const SizedBox(height: AppSpacing.xl),
          const Text(FacebookLoginText.consentTitle,
              style: AppText.sectionTitle),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.input),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(children: [
              for (final (index, (icon, text))
                  in FacebookLoginText.consentGets.indexed) ...[
                if (index > 0)
                  const Divider(height: 1, indent: 56, color: AppColors.border),
                ListTile(
                  leading: Icon(icon, color: AppColors.primaryAction),
                  title: Text(text, style: AppText.body),
                  trailing: const Icon(Icons.check_circle_rounded,
                      color: AppColors.primaryAction),
                ),
              ],
            ]),
          ),
          const SizedBox(height: 12),
          const _Note(FacebookLoginText.consentNever,
              icon: Icons.lock_outline_rounded),
          const SizedBox(height: AppSpacing.lg),
          AppPrimaryButton(
              label: FacebookLoginText.allowLabel,
              compact: true,
              onPressed: _connect),
          const SizedBox(height: AppSpacing.sm),
          AppSecondaryButton(
            label: FacebookLoginText.denyLabel,
            compact: true,
            onPressed: () => _finish(false),
          ),
          // Only in the test version: to see the failed state.
          TextButton(
            onPressed: () => _connect(fail: true),
            style: TextButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                minimumSize: const Size.fromHeight(44)),
            child: const Text(FacebookLoginText.simulateFailure),
          ),
        ],
      );

  Widget _working(String text) => Padding(
        padding: const EdgeInsets.only(top: 120),
        child: Semantics(
          liveRegion: true,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const SizedBox.square(
                dimension: 36,
                child: CircularProgressIndicator(strokeWidth: 3)),
            const SizedBox(height: AppSpacing.md),
            Text(text, textAlign: TextAlign.center, style: AppText.body),
          ]),
        ),
      );

  Widget _done() {
    final friends = _session?.friends ?? const <AppFriend>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.xl),
        const Center(
          child: CircleAvatar(
            radius: 32,
            backgroundColor: AppColors.primaryLight,
            child: Icon(Icons.check_rounded,
                size: 36, color: AppColors.primaryAction),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Semantics(
          liveRegion: true,
          child: const Text(FacebookLoginText.doneTitle,
              textAlign: TextAlign.center, style: AppText.sectionTitle),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(FacebookLoginText.doneBody(friends.length),
            textAlign: TextAlign.center, style: AppText.bodySecondary),
        const SizedBox(height: AppSpacing.lg),
        FriendAvatars(friends: friends.take(5).toList()),
        const SizedBox(height: AppSpacing.xl),
        AppPrimaryButton(
            label: FacebookLoginText.continueLabel,
            onPressed: () => _finish(true)),
      ],
    );
  }

  Widget _failed() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.xl),
          const Center(
            child: CircleAvatar(
              radius: 32,
              backgroundColor: AppColors.surface,
              child: Icon(Icons.wifi_off_rounded,
                  size: 32, color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Semantics(
            liveRegion: true,
            child: const Text(FacebookLoginText.failedTitle,
                textAlign: TextAlign.center, style: AppText.sectionTitle),
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text(FacebookLoginText.failedBody,
              textAlign: TextAlign.center, style: AppText.bodySecondary),
          const SizedBox(height: AppSpacing.xl),
          AppPrimaryButton(
              label: FacebookLoginText.retryLabel,
              compact: true,
              onPressed: _connect),
          const SizedBox(height: AppSpacing.sm),
          TextButton(
            onPressed: () => _finish(false),
            style: TextButton.styleFrom(
                foregroundColor: AppColors.textPrimary,
                minimumSize: const Size.fromHeight(48)),
            child: const Text(FacebookLoginText.laterLabel),
          ),
        ],
      );
}

/// A friend's initials on a soft circle, the same colour for them each time.
class FriendAvatar extends StatelessWidget {
  const FriendAvatar(this.friend,
      {super.key, this.size = 44, this.muted = false});

  final AppFriend friend;
  final double size;

  /// Restricted: greyed.
  final bool muted;

  static const _tints = [
    Color(0xFFDCEBE7),
    Color(0xFFF1E4CE),
    Color(0xFFECDDE4),
    Color(0xFFE4E5F1),
    Color(0xFFDDE5D1),
  ];

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: muted
              ? AppColors.background
              : _tints[friend.id.hashCode.abs() % _tints.length],
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.surface, width: 2),
        ),
        alignment: Alignment.center,
        child: Text(friend.initials,
            style: AppText.label.copyWith(
                fontSize: size * .32,
                color:
                    muted ? AppColors.textSecondary : AppColors.textPrimary)),
      );
}

/// Friends' initials in overlapping circles, with their names under them.
class FriendAvatars extends StatelessWidget {
  const FriendAvatars({super.key, required this.friends});

  final List<AppFriend> friends;

  @override
  Widget build(BuildContext context) => Column(children: [
        SizedBox(
          height: 48,
          width: 48 + 42.0 * (friends.length - 1).clamp(0, 99),
          child: Stack(children: [
            for (final (i, friend) in friends.indexed)
              Positioned(left: 42.0 * i, child: FriendAvatar(friend, size: 48)),
          ]),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text([for (final f in friends) f.name].join(', '),
            textAlign: TextAlign.center, style: AppText.meta),
      ]);
}

class _Note extends StatelessWidget {
  const _Note(this.text, {required this.icon});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(text, style: AppText.meta)),
        ]),
      );
}
