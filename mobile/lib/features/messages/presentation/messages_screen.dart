import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
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
  static const needsAccount =
      'Nhắn tin cần tài khoản, vì chỉ bạn bè đã kết bạn bằng username mới '
      'nhắn cho nhau được. Ở chế độ khách, vào Hồ sơ, chọn Đăng xuất rồi đăng '
      'nhập.';
  static const unavailable =
      'Tin nhắn sẽ mở khi máy chủ sẵn sàng. Bạn bè và kỷ niệm của bạn vẫn ở '
      'nguyên.';
  static const failed = 'Chưa tải được tin nhắn. Kiểm tra kết nối rồi thử lại.';
  static const retry = 'Thử lại';
  static const empty =
      'Chưa có cuộc trò chuyện nào. Bấm "Tin nhắn mới" để nhắn cho một người '
      'bạn, hoặc gửi họ một địa điểm từ Khám phá.';
  static const newMessage = 'Tin nhắn mới';
  static const pickFriend = 'Nhắn cho ai?';
  static const noFriends =
      'Bạn chưa có bạn bè trên app. Kết bạn bằng username ở Khám phá, mục '
      'Bạn bè.';
  static const readOnly = 'Chỉ xem';
  static const placePreview = 'Đã gửi một địa điểm';
  static const memoryPreview = 'Đã chia sẻ một kỷ niệm 24 giờ';
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

  /// "14:05" today, "30/10" before.
  static String when(DateTime at, DateTime now) {
    final t = at.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return t.year == now.year && t.month == now.month && t.day == now.day
        ? '${two(t.hour)}:${two(t.minute)}'
        : '${two(t.day)}/${two(t.month)}';
  }
}

/// The "Tin nhắn" tab: one row per friend talked to, newest first, with
/// unread counts. Asked again when the unread count changes and on pull.
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
    await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => ChatScreen(
            repository: _controller!.repository,
            conversation: conversation,
            onSeen: _controller!.seen)));
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
    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: ready && list != null
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
            const Padding(
              padding: EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 12),
              child: AppPageHeader(
                  title: MessagesText.title, subtitle: MessagesText.subtitle),
            ),
            Expanded(
              child: controller == null
                  ? const _Note(MessagesText.needsAccount,
                      icon: Icons.lock_outline_rounded)
                  : _unavailable
                      ? const _Note(MessagesText.unavailable,
                          icon: Icons.cloud_off_outlined)
                      : _failed
                          ? _Note(MessagesText.failed,
                              icon: Icons.wifi_off_rounded,
                              action: TextButton(
                                  onPressed: () {
                                    setState(() => _failed = false);
                                    _load();
                                  },
                                  child: const Text(MessagesText.retry)))
                          : list == null
                              ? const Center(
                                  child: CircularProgressIndicator())
                              : RefreshIndicator(
                                  onRefresh: () async {
                                    await _load();
                                    controller.seen();
                                  },
                                  child: list.isEmpty
                                      ? ListView(children: const [
                                          _Note(MessagesText.empty,
                                              icon: Icons
                                                  .chat_bubble_outline_rounded),
                                        ])
                                      : ListView.separated(
                                          padding: const EdgeInsets.only(
                                              bottom: 96),
                                          itemCount: list.length,
                                          separatorBuilder: (_, __) =>
                                              const Divider(
                                                  height: 1, indent: 76),
                                          itemBuilder: (context, i) =>
                                              _ConversationTile(
                                            conversation: list[i],
                                            myId: controller.repository.myId,
                                            onTap: () => _open(list[i]),
                                          ),
                                        ),
                                ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile(
      {required this.conversation, required this.myId, required this.onTap});

  final Conversation conversation;
  final String myId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final last = conversation.lastMessage;
    final unread = conversation.unread;
    return ListTile(
      key: ValueKey('conversation-${conversation.id}'),
      onTap: onTap,
      minTileHeight: 72,
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      leading: FriendAvatar(conversation.friend, size: 48),
      title: Text(conversation.friend.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: unread > 0
              ? AppText.body.copyWith(fontWeight: FontWeight.w700)
              : AppText.body),
      subtitle: Text(
          [
            if (!conversation.canSend) MessagesText.readOnly,
            if (last != null) MessagesText.preview(last, myId),
          ].join(' · '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppText.meta),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (last != null)
            Text(MessagesText.when(last.sentAt, DateTime.now()),
                style: AppText.meta),
          if (unread > 0) ...[
            const SizedBox(height: 4),
            Semantics(
              label: MessagesText.unread(unread),
              child: Badge(
                  label: Text('$unread'),
                  backgroundColor: AppColors.primaryAction),
            ),
          ],
        ],
      ),
    );
  }
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
                    leading: FriendAvatar(friend, size: 40),
                    title: Text(friend.name, style: AppText.body),
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
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 40, color: AppColors.textSecondary),
          const SizedBox(height: AppSpacing.md),
          Text(text, textAlign: TextAlign.center, style: AppText.bodySecondary),
          if (action != null) ...[
            const SizedBox(height: AppSpacing.sm),
            action!,
          ],
        ]),
      );
}
