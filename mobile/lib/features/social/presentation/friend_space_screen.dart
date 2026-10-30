import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/data/auth_service.dart';
import '../../auth/presentation/auth_gate.dart';
import 'real_friends_screen.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/widgets/app_delete_dialog.dart';
import '../../../core/widgets/app_ui.dart';
import '../data/friend_space.dart';
import '../data/friends_account.dart';
import 'facebook_login_screen.dart';

abstract final class FriendSpaceText {
  static const title = 'Space của bạn';
  static const subtitle =
      'Mời bạn bè vào Space; khi họ đồng ý, bạn chọn được họ để xem bài chia '
      'sẻ 24 giờ.';
  static const closeTooltip = 'Đóng';
  static const searchHint = 'Tìm bạn bè';
  static String invitesTitle(int count) => 'Lời mời vào Space · $count';
  static const invitesDetail = 'Mời bạn vào Space';
  static const acceptLabel = 'Đồng ý';
  static const declineLabel = 'Từ chối';
  static String acceptTooltip(String name) => 'Đồng ý lời mời của $name';
  static String declineTooltip(String name) => 'Từ chối lời mời của $name';
  static String inSpace(int count) => 'Trong Space · $count';
  static String pendingTitle(int count) => 'Đang chờ đồng ý · $count';
  static const pendingDetail = 'Đã gửi lời mời';
  static String onApp(int count) => 'Bạn bè Facebook dùng app · $count';
  static const emptySpace =
      'Space của bạn chưa có ai. Mời bạn bè ở bên dưới; họ vào khi đồng ý.';
  static const allAdded = 'Bạn đã mời hết bạn bè dùng app.';
  static const noMatch = 'Không có ai khớp tên này.';
  static const addLabel = 'Mời';
  static String addTooltip(String name) => 'Mời $name vào Space';
  static const cancelInviteLabel = 'Hủy lời mời';
  static const simulateAccept = 'Bản thử: giả lập họ đồng ý';
  static String invited(String name) =>
      'Đã gửi lời mời cho $name. Họ vào Space khi đồng ý.';
  static String canceled(String name) => 'Đã hủy lời mời gửi $name';
  static String joined(String name) => '$name đã vào Space của bạn';
  static String declined(String name) =>
      'Đã từ chối lời mời của $name. Họ không được báo.';
  static String optionsTooltip(String name) => 'Tùy chọn cho $name';
  static const seesShares = 'Thấy được bài chia sẻ của bạn';
  static const restrictedNote = 'Đã hạn chế · không thấy bài mới';
  static const restrictLabel = 'Hạn chế';
  static const restrictHelp =
      'Vẫn ở trong Space nhưng không thấy bài chia sẻ mới của bạn. Họ không '
      'được báo.';
  static const unrestrictLabel = 'Bỏ hạn chế';
  static const removeLabel = 'Xóa khỏi Space';
  static String removeTitle(String name) => 'Xóa $name khỏi Space?';
  static const removeBody =
      'Họ sẽ không thấy bài chia sẻ mới của bạn và không được báo. Muốn có họ '
      'lại, bạn gửi lời mời mới.';
  static String removed(String name) => 'Đã xóa $name khỏi Space';
  static const signedOutTitle = 'Bạn bè trên app';
  static const signedOutBody =
      'Đăng nhập Facebook để thấy bạn bè cũng dùng app, rồi chọn ai được vào '
      'Space của bạn.';
  static const signInLabel = 'Đăng nhập bằng Facebook';
  static const sample = 'Bản thử: bạn bè hiện ra là bạn bè mẫu.';
}

/// Opens "Space của bạn" over Explore.
Future<void> openFriendSpace(BuildContext context,
    {required FriendsAccount account, required FriendSpace space}) {
  final auth = AuthScope.maybeOf(context);
  // Signed-in accounts must NEVER be shown simulated Facebook friends.
  return Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => auth is SupabaseAuthService
        ? RealFriendsScreen(auth: auth)
        : FriendSpaceScreen(account: account, space: space),
  ));
}

/// "Space của bạn": the friends on the app the user shares with. Joining
/// takes both: invitations to the user first ("Đồng ý" / "Từ chối"), then
/// members (each can be restricted, or removed after a confirm), the user's
/// invitations still waiting (can be taken back), and the other friends
/// from Facebook who use the app, each with "Mời". Signed out: an
/// invitation to sign in with Facebook.
class FriendSpaceScreen extends StatefulWidget {
  const FriendSpaceScreen(
      {super.key, required this.account, required this.space});

  final FriendsAccount account;
  final FriendSpace space;

  @override
  State<FriendSpaceScreen> createState() => _FriendSpaceScreenState();
}

class _FriendSpaceScreenState extends State<FriendSpaceScreen> {
  final _search = TextEditingController();
  var _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// No tab bar here: the note sits at the very bottom, off the rows.
  void _toast(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(text),
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    ));

  Future<void> _invite(AppFriend friend) async {
    await widget.space.invite(friend.id);
    if (mounted) _toast(FriendSpaceText.invited(friend.name));
  }

  Future<void> _accept(AppFriend friend) async {
    await widget.space.accept(friend.id);
    if (mounted) _toast(FriendSpaceText.joined(friend.name));
  }

  Future<void> _decline(AppFriend friend) async {
    await widget.space.decline(friend.id);
    if (mounted) _toast(FriendSpaceText.declined(friend.name));
  }

  /// A waiting invitation: take it back, or (test version) have them accept.
  Future<void> _pendingOptions(AppFriend friend) async {
    final choice = await showAppSheet<String>(
      context,
      builder: (sheet) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            FriendAvatar(friend, size: 48),
            const SizedBox(width: 12),
            Expanded(child: Text(friend.name, style: AppText.sectionTitle)),
          ]),
          const SizedBox(height: AppSpacing.md),
          _Action(
            icon: Icons.undo_rounded,
            label: FriendSpaceText.cancelInviteLabel,
            onTap: () => Navigator.pop(sheet, 'cancel'),
          ),
          const SizedBox(height: AppSpacing.sm),
          _Action(
            icon: Icons.science_outlined,
            label: FriendSpaceText.simulateAccept,
            onTap: () => Navigator.pop(sheet, 'accepted'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    switch (choice) {
      case 'cancel':
        await widget.space.cancelInvite(friend.id);
        if (mounted) _toast(FriendSpaceText.canceled(friend.name));
      case 'accepted':
        await widget.space.acceptedBy(friend.id);
        if (mounted) _toast(FriendSpaceText.joined(friend.name));
    }
  }

  Future<void> _options(AppFriend friend, SpaceMember member) async {
    final choice = await showAppSheet<String>(
      context,
      builder: (sheet) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            FriendAvatar(friend, size: 48, muted: member.restricted),
            const SizedBox(width: 12),
            Expanded(child: Text(friend.name, style: AppText.sectionTitle)),
          ]),
          const SizedBox(height: AppSpacing.md),
          _Action(
            icon: member.restricted
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
            label: member.restricted
                ? FriendSpaceText.unrestrictLabel
                : FriendSpaceText.restrictLabel,
            note: member.restricted ? null : FriendSpaceText.restrictHelp,
            onTap: () => Navigator.pop(sheet, 'restrict'),
          ),
          const SizedBox(height: AppSpacing.sm),
          _Action(
            icon: Icons.person_remove_outlined,
            label: FriendSpaceText.removeLabel,
            color: AppDeleteDialog.destructive,
            onTap: () => Navigator.pop(sheet, 'remove'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    switch (choice) {
      case 'restrict':
        await widget.space.restrict(friend.id, !member.restricted);
      case 'remove':
        final removed = await showAppSheet<bool>(
          context,
          builder: (sheet) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(FriendSpaceText.removeTitle(friend.name),
                  style: AppText.sectionTitle),
              const SizedBox(height: AppSpacing.sm),
              const Text(FriendSpaceText.removeBody,
                  style: AppText.bodySecondary),
              const SizedBox(height: AppSpacing.lg),
              AppPrimaryButton(
                  label: AppDeleteDialog.cancelLabel,
                  compact: true,
                  onPressed: () => Navigator.pop(sheet, false)),
              const SizedBox(height: AppSpacing.sm),
              TextButton(
                onPressed: () => Navigator.pop(sheet, true),
                style: TextButton.styleFrom(
                    foregroundColor: AppDeleteDialog.destructive,
                    minimumSize: const Size.fromHeight(48)),
                child: const Text(FriendSpaceText.removeLabel),
              ),
            ],
          ),
        );
        if (removed != true || !mounted) return;
        await widget.space.remove(friend.id);
        if (mounted) _toast(FriendSpaceText.removed(friend.name));
    }
  }

  bool _matches(AppFriend friend) {
    final query = _query.trim().toLowerCase();
    return query.isEmpty || friend.name.toLowerCase().contains(query);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 12),
              child: AppPageHeader(
                title: FriendSpaceText.title,
                subtitle: FriendSpaceText.subtitle,
                trailing: [
                  AppIconAction(
                    icon: Icons.close_rounded,
                    tooltip: FriendSpaceText.closeTooltip,
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.border),
            Expanded(
              child: ValueListenableBuilder<FriendsSession?>(
                valueListenable: widget.account.session,
                builder: (context, session, _) => session == null
                    ? _signedOut()
                    : ListenableBuilder(
                        listenable: Listenable.merge(
                            [widget.space.members, widget.space.incoming]),
                        builder: (context, _) => _lists(session),
                      ),
              ),
            ),
          ]),
        ),
      );

  Widget _signedOut() => ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          const SizedBox(height: AppSpacing.xl),
          Center(
            child: Image.asset('assets/images/map-moods/nudaeng-happy.png',
                height: 104,
                cacheWidth: 320,
                excludeFromSemantics: true,
                errorBuilder: (_, __, ___) => const SizedBox.shrink()),
          ),
          const SizedBox(height: AppSpacing.md),
          const Text(FriendSpaceText.signedOutTitle,
              textAlign: TextAlign.center, style: AppText.sectionTitle),
          const SizedBox(height: AppSpacing.sm),
          const Text(FriendSpaceText.signedOutBody,
              textAlign: TextAlign.center, style: AppText.bodySecondary),
          const SizedBox(height: AppSpacing.lg),
          FilledButton.icon(
            onPressed: () => openFacebookLogin(context, widget.account),
            icon: const Icon(Icons.facebook_rounded, size: 22),
            label: const Text(FriendSpaceText.signInLabel),
            style: FilledButton.styleFrom(
              backgroundColor: facebookBlue,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(52),
              shape: const StadiumBorder(),
              textStyle: AppText.label,
            ),
          ),
        ],
      );

  Widget _lists(FriendsSession session) {
    final known = widget.space.of(session.friends);
    final members = [
      for (final entry in known)
        if (entry.$2.isMember) entry
    ];
    final pending = [
      for (final (friend, member) in known)
        if (!member.isMember) friend
    ];
    final invites = widget.space.invitesFrom(session.friends);
    final taken = {
      for (final (friend, _) in known) friend.id,
      for (final friend in invites) friend.id,
    };
    final others = [
      for (final friend in session.friends)
        if (!taken.contains(friend.id)) friend,
    ];
    final shownMembers = [
      for (final entry in members)
        if (_matches(entry.$1)) entry
    ];
    final shownInvites = invites.where(_matches).toList();
    final shownPending = pending.where(_matches).toList();
    final shownOthers = others.where(_matches).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xl),
      children: [
        TextField(
          controller: _search,
          onChanged: (value) => setState(() => _query = value),
          style: AppText.body,
          decoration: InputDecoration(
            hintText: FriendSpaceText.searchHint,
            hintStyle: AppText.bodySecondary,
            prefixIcon: const Icon(Icons.search_rounded,
                color: AppColors.textSecondary),
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.input),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.input),
              borderSide: const BorderSide(color: AppColors.border),
            ),
          ),
        ),
        // Waiting for the user's answer: first, so they are not missed.
        if (shownInvites.isNotEmpty) ...[
          _Title(FriendSpaceText.invitesTitle(invites.length)),
          _Group(children: [
            for (final friend in shownInvites)
              _Row(
                key: ValueKey('invite-${friend.id}'),
                friend: friend,
                detail: FriendSpaceText.invitesDetail,
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  Tooltip(
                    message: FriendSpaceText.declineTooltip(friend.name),
                    child: TextButton(
                      onPressed: () => _decline(friend),
                      style: TextButton.styleFrom(
                          foregroundColor: AppColors.textSecondary,
                          minimumSize: const Size(48, 40)),
                      child: const Text(FriendSpaceText.declineLabel),
                    ),
                  ),
                  Tooltip(
                    message: FriendSpaceText.acceptTooltip(friend.name),
                    child: FilledButton(
                      onPressed: () => _accept(friend),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primaryAction,
                        minimumSize: const Size(48, 40),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        shape: const StadiumBorder(),
                        textStyle:
                            AppText.meta.copyWith(fontWeight: FontWeight.w600),
                      ),
                      child: const Text(FriendSpaceText.acceptLabel),
                    ),
                  ),
                ]),
              ),
          ]),
        ],
        _Title(FriendSpaceText.inSpace(members.length)),
        shownMembers.isEmpty
            ? _Empty(members.isEmpty
                ? FriendSpaceText.emptySpace
                : FriendSpaceText.noMatch)
            : _Group(children: [
                for (final (friend, member) in shownMembers)
                  _Row(
                    key: ValueKey('space-${friend.id}'),
                    friend: friend,
                    muted: member.restricted,
                    detail: member.restricted
                        ? FriendSpaceText.restrictedNote
                        : FriendSpaceText.seesShares,
                    trailing: IconButton(
                      tooltip: FriendSpaceText.optionsTooltip(friend.name),
                      onPressed: () => _options(friend, member),
                      icon: const Icon(Icons.more_horiz_rounded,
                          color: AppColors.textSecondary),
                    ),
                  ),
              ]),
        if (shownPending.isNotEmpty) ...[
          _Title(FriendSpaceText.pendingTitle(pending.length)),
          _Group(children: [
            for (final friend in shownPending)
              _Row(
                key: ValueKey('pending-${friend.id}'),
                friend: friend,
                muted: true,
                detail: FriendSpaceText.pendingDetail,
                trailing: IconButton(
                  tooltip: FriendSpaceText.optionsTooltip(friend.name),
                  onPressed: () => _pendingOptions(friend),
                  icon: const Icon(Icons.schedule_rounded,
                      color: AppColors.textSecondary),
                ),
              ),
          ]),
        ],
        _Title(FriendSpaceText.onApp(others.length)),
        shownOthers.isEmpty
            ? _Empty(others.isEmpty
                ? FriendSpaceText.allAdded
                : FriendSpaceText.noMatch)
            : _Group(children: [
                for (final friend in shownOthers)
                  _Row(
                    key: ValueKey('friend-${friend.id}'),
                    friend: friend,
                    trailing: Tooltip(
                      message: FriendSpaceText.addTooltip(friend.name),
                      child: FilledButton.tonalIcon(
                        onPressed: () => _invite(friend),
                        icon: const Icon(Icons.person_add_alt_1_rounded,
                            size: 18),
                        label: const Text(FriendSpaceText.addLabel),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primaryLight,
                          foregroundColor: AppColors.primaryAction,
                          minimumSize: const Size(48, 40),
                          shape: const StadiumBorder(),
                          textStyle: AppText.meta
                              .copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ),
              ]),
        if (session.sample) ...[
          const SizedBox(height: AppSpacing.md),
          const Text(FriendSpaceText.sample,
              textAlign: TextAlign.center, style: AppText.meta),
        ],
      ],
    );
  }
}

/// Rows on one card, with hairlines between them.
class _Group extends StatelessWidget {
  const _Group({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => AppCard(
        padding: EdgeInsets.zero,
        child: Column(children: [
          for (final (index, child) in children.indexed) ...[
            if (index > 0)
              const Divider(height: 1, indent: 72, color: AppColors.border),
            child,
          ],
        ]),
      );
}

class _Empty extends StatelessWidget {
  const _Empty(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => AppCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Text(text, style: AppText.meta),
      );
}

class _Title extends StatelessWidget {
  const _Title(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(
            top: AppSpacing.lg, bottom: AppSpacing.sm, left: AppSpacing.xs),
        child: Semantics(
          header: true,
          child: Text(text,
              style: AppText.label.copyWith(color: AppColors.textSecondary)),
        ),
      );
}

class _Row extends StatelessWidget {
  const _Row({
    super.key,
    required this.friend,
    required this.trailing,
    this.detail,
    this.muted = false,
  });

  final AppFriend friend;
  final Widget trailing;
  final String? detail;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final detail = this.detail;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 64),
      child: Padding(
        padding:
            const EdgeInsets.fromLTRB(AppSpacing.md, 10, AppSpacing.sm, 10),
        child: Row(children: [
          FriendAvatar(friend, muted: muted),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(friend.name,
                    style: AppText.body.copyWith(
                        color: muted
                            ? AppColors.textSecondary
                            : AppColors.textPrimary)),
                if (detail != null)
                  Text(detail, style: AppText.meta.copyWith(fontSize: 12)),
              ],
            ),
          ),
          trailing,
        ]),
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.icon,
    required this.label,
    required this.onTap,
    this.note,
    this.color = AppColors.primaryAction,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final String? note;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final note = this.note;
    return Material(
      color: AppColors.background,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.input))),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: 10),
            child: Row(children: [
              Icon(icon, color: color),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: AppText.body.copyWith(
                            color: color == AppColors.primaryAction
                                ? AppColors.textPrimary
                                : color)),
                    if (note != null) ...[
                      const SizedBox(height: 2),
                      Text(note, style: AppText.meta.copyWith(fontSize: 12)),
                    ],
                  ],
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
