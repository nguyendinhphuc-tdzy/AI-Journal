import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/widgets/app_ui.dart';
import '../../social/data/app_friend.dart';
import '../../social/presentation/friend_avatar.dart';
import '../data/chat_message.dart';
import '../data/messages_repository.dart';
import '../messages_scope.dart';
import 'chat_screen.dart';

abstract final class MessagesText {
  static const title = 'Tin nhắn';
  static const subtitle = 'Trò chuyện với bạn bè trên app';
  static String unreadSubtitle(int count) => '$count tin chưa đọc';
  static const needsAccount =
      'Nhắn tin cần tài khoản, vì chỉ bạn bè đã kết bạn bằng username mới '
      'nhắn cho nhau được. Ở chế độ khách, vào Hồ sơ, chọn Đăng xuất rồi đăng '
      'nhập.';
  static const unavailable =
      'Tin nhắn sẽ mở khi máy chủ sẵn sàng. Bạn bè và kỷ niệm của bạn vẫn ở '
      'nguyên.';
  static const failed = 'Chưa tải được tin nhắn. Kiểm tra kết nối rồi thử lại.';
  static const retry = 'Thử lại';
  static const emptyTitle = 'Chưa có cuộc trò chuyện nào';
  static const empty =
      'Bấm "Tin nhắn mới" để nhắn cho một người bạn, hoặc gửi họ một địa '
      'điểm từ Khám phá.';
  static const newMessage = 'Tin nhắn mới';
  static const pickFriend = 'Nhắn cho ai?';
  static const noFriends =
      'Bạn chưa có bạn bè trên app. Kết bạn bằng username ở Khám phá, mục '
      'Bạn bè.';
  static const readOnly = 'Chỉ xem';
  static const placePreview = 'Đã gửi một địa điểm';
  static const memoryPreview = 'Đã chia sẻ một kỷ niệm 24 giờ';
  static const mascot = 'Nudaeng ngồi bàn viết thư';
  static String unread(int count) => '$count tin chưa đọc';

  /// "Bạn: …" for the user's own last message.
  static String preview(ChatMessage message, String myId) {
    final what = switch (message.kind) {
      MessageKind.text => message.text ?? '',
      MessageKind.place => '$placePreview: ${message.place?.name ?? ''}',
      MessageKind.memory => memoryPreview,
    };
    return message.senderId == myId ? 'Bạn: $what' : what;
  }

  /// "14:05" today, "Hôm qua", "30/10" before.
  static String when(DateTime at, DateTime now) {
    final t = at.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    final day = DateTime(t.year, t.month, t.day);
    final today = DateTime(now.year, now.month, now.day);
    final days = today.difference(day).inDays;
    return days == 0
        ? '${two(t.hour)}:${two(t.minute)}'
        : days == 1
            ? 'Hôm qua'
            : '${two(t.day)}/${two(t.month)}';
  }
}

/// The "Tin nhắn" tab: one card per friend talked to, newest first. Unread
/// ones stand out (tinted card, bold name and preview, a count). Rows come
/// in one after another the first time (none with reduced motion). Asked
/// again when the unread count changes and on pull.
class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  MessagesController? _controller;
  List<Conversation>? _list;
  var _failed = false;
  var _unavailable = false;
  int? _seenUnread;

  /// Rows already shown: only new ones animate in.
  final _shown = <String>{};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = MessagesScope.maybeOf(context);
    if (controller != _controller) {
      _controller = controller;
      controller?.start();
      _seenUnread = controller?.unread;
      _load();
    } else if (controller != null && controller.unread != _seenUnread) {
      // New messages counted by the poll: the rows change too.
      _seenUnread = controller.unread;
      _load();
    }
  }

  Future<void> _load() async {
    final controller = _controller;
    if (controller == null) return;
    try {
      final list = await controller.repository.conversations();
      if (!mounted) return;
      setState(() {
        _list = list;
        _failed = false;
        _unavailable = false;
      });
    } on MessagesUnavailable {
      if (mounted) setState(() => _unavailable = true);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _open(Conversation conversation) async {
    final controller = _controller!;
    await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => ChatScreen(
            repository: controller.repository,
            conversation: conversation,
            onSeen: controller.seen,
            onIncoming: controller.chime)));
    if (mounted) _load();
  }

  Future<void> _newMessage() async {
    final controller = _controller!;
    List<AppFriend> friends;
    try {
      friends = await controller.repository.friends();
    } catch (_) {
      if (mounted) _toast(MessagesText.failed);
      return;
    }
    if (!mounted) return;
    final friend = await showAppSheet<AppFriend>(context,
        builder: (sheet) => _FriendPicker(friends: friends));
    if (friend == null || !mounted) return;
    try {
      final conversation = await controller.repository.open(friend.id);
      if (mounted) await _open(conversation);
    } on MessagesUnavailable {
      if (mounted) setState(() => _unavailable = true);
    } catch (_) {
      if (mounted) _toast(MessagesText.failed);
    }
  }

  void _toast(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final list = _list;
    final ready = controller != null && !_unavailable && !_failed;
    final unread = controller?.unread ?? 0;
    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: ready && list != null && list.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _newMessage,
              backgroundColor: AppColors.primaryAction,
              foregroundColor: AppColors.surface,
              icon: const Icon(Icons.edit_outlined),
              label: const Text(MessagesText.newMessage),
            )
          : null,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 12),
              child: AppPageHeader(
                  title: MessagesText.title,
                  subtitle: ready && unread > 0
                      ? MessagesText.unreadSubtitle(unread)
                      : MessagesText.subtitle),
            ),
            Expanded(child: _body(controller, list)),
          ],
        ),
      ),
    );
  }

  Widget _body(MessagesController? controller, List<Conversation>? list) {
    if (controller == null) {
      return const _Note(MessagesText.needsAccount,
          icon: Icons.lock_outline_rounded);
    }
    if (_unavailable) {
      return const _Note(MessagesText.unavailable,
          icon: Icons.cloud_off_outlined);
    }
    if (_failed) {
      return _Note(MessagesText.failed,
          icon: Icons.wifi_off_rounded,
          action: TextButton(
              onPressed: () {
                setState(() => _failed = false);
                _load();
              },
              child: const Text(MessagesText.retry)));
    }
    if (list == null) return const Center(child: CircularProgressIndicator());
    final reduced = MediaQuery.disableAnimationsOf(context);
    return RefreshIndicator(
      color: AppColors.primaryAction,
      onRefresh: () async {
        await _load();
        controller.seen();
      },
      child: list.isEmpty
          ? ListView(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              children: [
                _Empty(onNew: _newMessage),
              ],
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md, AppSpacing.xs, AppSpacing.md, 104),
              itemCount: list.length,
              itemBuilder: (context, i) {
                final conversation = list[i];
                final tile = Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ConversationCard(
                    conversation: conversation,
                    myId: controller.repository.myId,
                    onTap: () => _open(conversation),
                  ),
                );
                final isNew = _shown.add(conversation.id);
                return reduced || !isNew
                    ? tile
                    : _EnterFromBelow(
                        delay: Duration(milliseconds: 40 * i.clamp(0, 8)),
                        child: tile);
              },
            ),
    );
  }
}

/// Fades and rises into place once, after [delay].
class _EnterFromBelow extends StatefulWidget {
  const _EnterFromBelow({required this.delay, required this.child});

  final Duration delay;
  final Widget child;

  @override
  State<_EnterFromBelow> createState() => _EnterFromBelowState();
}

class _EnterFromBelowState extends State<_EnterFromBelow>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 260));
  late final _curve =
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: _curve,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, .15), end: Offset.zero)
              .animate(_curve),
          child: widget.child,
        ),
      );
}

class _ConversationCard extends StatelessWidget {
  const _ConversationCard(
      {required this.conversation, required this.myId, required this.onTap});

  final Conversation conversation;
  final String myId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final last = conversation.lastMessage;
    final unread = conversation.unread;
    final fresh = unread > 0;
    final preview = [
      if (!conversation.canSend) MessagesText.readOnly,
      if (last != null) MessagesText.preview(last, myId),
    ].join(' · ');
    return Material(
      key: ValueKey('conversation-${conversation.id}'),
      color: fresh ? AppColors.primaryLight : AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: BorderSide(
            color: fresh
                ? AppColors.primaryAction.withValues(alpha: .35)
                : AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, AppSpacing.md, 12),
          child: Row(children: [
            Stack(clipBehavior: Clip.none, children: [
              FriendAvatar(conversation.friend, size: 52),
              if (fresh)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: AppColors.primaryAction,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.surface, width: 2),
                    ),
                  ),
                ),
            ]),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(conversation.friend.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.label.copyWith(
                              fontWeight:
                                  fresh ? FontWeight.w700 : FontWeight.w600)),
                    ),
                    if (last != null) ...[
                      const SizedBox(width: AppSpacing.sm),
                      Text(MessagesText.when(last.sentAt, DateTime.now()),
                          style: AppText.meta.copyWith(
                              fontSize: 13,
                              color: fresh
                                  ? AppColors.primaryAction
                                  : AppColors.textSecondary,
                              fontWeight:
                                  fresh ? FontWeight.w700 : FontWeight.w400)),
                    ],
                  ]),
                  const SizedBox(height: 3),
                  Row(children: [
                    if (conversation.username != null && preview.isEmpty)
                      Text('@${conversation.username}', style: AppText.meta),
                    Expanded(
                      child: Text(preview,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.meta.copyWith(
                              color: fresh
                                  ? AppColors.textPrimary
                                  : AppColors.textSecondary,
                              fontWeight:
                                  fresh ? FontWeight.w600 : FontWeight.w400)),
                    ),
                    if (fresh) ...[
                      const SizedBox(width: AppSpacing.sm),
                      Semantics(
                        label: MessagesText.unread(unread),
                        excludeSemantics: true,
                        child: Container(
                          constraints:
                              const BoxConstraints(minWidth: 22, minHeight: 22),
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.primaryAction,
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: Text(unread > 99 ? '99+' : '$unread',
                              style: AppText.meta.copyWith(
                                  fontSize: 12,
                                  height: 1.2,
                                  color: AppColors.surface,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ],
                  ]),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// No conversation yet: Nudaeng writing a letter, and the way to start one.
class _Empty extends StatelessWidget {
  const _Empty({required this.onNew});

  final VoidCallback onNew;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: AppSpacing.xl),
        child: Column(children: [
          Image.asset('assets/Deimage/Nudaeng writing-transparent.png',
              height: 150, semanticLabel: MessagesText.mascot),
          const SizedBox(height: AppSpacing.lg),
          const Text(MessagesText.emptyTitle,
              textAlign: TextAlign.center, style: AppText.cardTitle),
          const SizedBox(height: AppSpacing.sm),
          const Text(MessagesText.empty,
              textAlign: TextAlign.center, style: AppText.bodySecondary),
          const SizedBox(height: AppSpacing.lg),
          AppPrimaryButton(
            label: MessagesText.newMessage,
            icon: Icons.edit_outlined,
            compact: true,
            onPressed: onNew,
          ),
        ]),
      );
}

/// The friends to start a conversation with.
class _FriendPicker extends StatelessWidget {
  const _FriendPicker({required this.friends});

  final List<AppFriend> friends;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(MessagesText.pickFriend, style: AppText.sectionTitle),
          const SizedBox(height: AppSpacing.sm),
          if (friends.isEmpty)
            const Text(MessagesText.noFriends, style: AppText.bodySecondary)
          else
            Flexible(
              child: ListView(shrinkWrap: true, children: [
                for (final friend in friends)
                  ListTile(
                    key: ValueKey('message-to-${friend.id}'),
                    contentPadding: EdgeInsets.zero,
                    minTileHeight: 56,
                    leading: FriendAvatar(friend, size: 44),
                    title: Text(friend.name, style: AppText.label),
                    trailing: const Icon(Icons.chevron_right_rounded,
                        color: AppColors.textSecondary),
                    onTap: () => Navigator.pop(context, friend),
                  ),
              ]),
            ),
        ],
      );
}

class _Note extends StatelessWidget {
  const _Note(this.text, {required this.icon, this.action});

  final String text;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(children: [
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                    color: AppColors.primaryLight, shape: BoxShape.circle),
                child: Icon(icon, size: 28, color: AppColors.primaryAction),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(text,
                  textAlign: TextAlign.center,
                  style: AppText.body.copyWith(color: AppColors.textPrimary)),
              if (action != null) ...[
                const SizedBox(height: AppSpacing.sm),
                action!,
              ],
            ]),
          ),
        ],
      );
}
