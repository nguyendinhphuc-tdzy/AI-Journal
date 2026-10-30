import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text.dart';
import '../../social/presentation/friend_avatar.dart';
import '../data/chat_message.dart';
import '../data/messages_repository.dart';
import 'messages_screen.dart';

abstract final class ChatText {
  static const hint = 'Nhắn tin';
  static const sendTooltip = 'Gửi';
  static const backTooltip = 'Quay lại';
  static const sending = 'Đang gửi…';
  static const failed = 'Chưa gửi được · Bấm để thử lại';
  static const loadFailed = 'Chưa tải được tin nhắn.';
  static const retry = 'Thử lại';
  static const empty = 'Chưa có tin nhắn. Gửi lời chào đầu tiên nhé.';
  static const readOnly =
      'Hai bạn không còn là bạn bè trên app. Bạn vẫn xem được tin nhắn cũ '
      'nhưng không gửi thêm được.';
  static const placeLabel = 'Địa điểm';
  static const memoryLabel = 'Kỷ niệm 24 giờ';
  static const memoryExpired =
      'Bài chia sẻ đã hết hạn sau 24 giờ nên không còn xem được.';
  static String expiresAt(DateTime at) {
    final t = at.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return 'Hết hạn lúc ${two(t.hour)}:${two(t.minute)}, '
        '${two(t.day)}/${two(t.month)}/${t.year}';
  }

  static const maxLength = 2000;
}

/// One conversation: messages oldest at the top, the newest by the input.
/// New messages are asked for every [poll] while the screen is open and the
/// app in front. A message that could not be sent stays, marked, and is
/// sent again (same client id, never twice) when tapped.
class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.repository,
    required this.conversation,
    this.onSeen,
    this.poll = const Duration(seconds: 5),
  });

  final MessagesRepository repository;
  final Conversation conversation;

  /// Messages were read here: the tab's count changes.
  final VoidCallback? onSeen;
  final Duration poll;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final _input = TextEditingController();
  final _random = Random.secure();
  List<ChatMessage>? _messages;
  var _loadFailed = false;
  Timer? _timer;
  String? _lastRead;

  MessagesRepository get _repo => widget.repository;
  Conversation get _conversation => widget.conversation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _input.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _input.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startPolling();
      _poll();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _timer?.cancel();
    }
  }

  void _startPolling() {
    _timer?.cancel();
    _timer = Timer.periodic(widget.poll, (_) => _poll());
  }

  Future<void> _load() async {
    try {
      final list = await _repo.messages(_conversation.id);
      if (!mounted) return;
      setState(() {
        _messages = [...list];
        _loadFailed = false;
      });
      _markRead();
      _startPolling();
    } catch (_) {
      if (mounted) setState(() => _loadFailed = true);
    }
  }

  /// The newest message the server has, to ask only for what came after.
  String? get _lastServerId {
    for (final m in (_messages ?? const <ChatMessage>[]).reversed) {
      if (m.state == SendState.sent) return m.id;
    }
    return null;
  }

  Future<void> _poll() async {
    final current = _messages;
    if (current == null) return;
    try {
      final fresh = await _repo.messages(_conversation.id, after: _lastServerId);
      if (!mounted || fresh.isEmpty) return;
      setState(() {
        for (final message in fresh) {
          _merge(message);
        }
      });
      _markRead();
    } catch (_) {
      // Offline for now: the next poll asks again.
    }
  }

  /// Puts a message from the server in place: replaces the local copy of
  /// one the user sent (same client id), and never shows it twice.
  void _merge(ChatMessage message) {
    final list = _messages!;
    if (list.any((m) => m.id == message.id)) return;
    final local = message.clientId == null
        ? -1
        : list.indexWhere((m) => m.clientId == message.clientId);
    if (local >= 0) {
      list[local] = message;
    } else {
      list.add(message);
    }
  }

  void _markRead() {
    final list = _messages;
    if (list == null) return;
    String? newest;
    for (final m in list.reversed) {
      if (m.state == SendState.sent) {
        newest = m.id;
        break;
      }
    }
    if (newest == null || newest == _lastRead) return;
    _lastRead = newest;
    _repo
        .markRead(_conversation.id, newest)
        .then((_) => widget.onSeen?.call())
        .catchError((Object _) {});
  }

  String _clientId() =>
      List.generate(16, (_) => _random.nextInt(256).toRadixString(16).padLeft(2, '0'))
          .join();

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _messages == null) return;
    final clientId = _clientId();
    final local = ChatMessage(
      id: 'local:$clientId',
      senderId: _repo.myId,
      sentAt: DateTime.now(),
      text: text,
      clientId: clientId,
      state: SendState.sending,
    );
    _input.clear();
    setState(() => _messages!.add(local));
    await _deliver(local);
  }

  Future<void> _deliver(ChatMessage local) async {
    try {
      final sent = await _repo.send(_conversation.id, local.text!,
          clientId: local.clientId!);
      if (!mounted) return;
      setState(() => _merge(sent));
      _markRead();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        final list = _messages!;
        final at = list.indexWhere((m) => m.clientId == local.clientId);
        if (at >= 0 && list[at].state != SendState.sent) {
          list[at] = list[at].copyWith(state: SendState.failed);
        }
      });
    }
  }

  void _retry(ChatMessage failed) {
    setState(() {
      final list = _messages!;
      final at = list.indexOf(failed);
      if (at >= 0) list[at] = failed.copyWith(state: SendState.sending);
    });
    _deliver(failed);
  }

  @override
  Widget build(BuildContext context) {
    final messages = _messages;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        leading: IconButton(
          tooltip: ChatText.backTooltip,
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: Row(children: [
          FriendAvatar(_conversation.friend, size: 36),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_conversation.friend.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.label),
                if (_conversation.username != null)
                  Text('@${_conversation.username}', style: AppText.meta),
              ],
            ),
          ),
        ]),
      ),
      body: SafeArea(
        top: false,
        child: Column(children: [
          Expanded(
            child: _loadFailed
                ? Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Text(ChatText.loadFailed,
                          style: AppText.bodySecondary),
                      TextButton(
                          onPressed: () {
                            setState(() => _loadFailed = false);
                            _load();
                          },
                          child: const Text(ChatText.retry)),
                    ]),
                  )
                : messages == null
                    ? const Center(child: CircularProgressIndicator())
                    : messages.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(AppSpacing.xl),
                              child: Text(ChatText.empty,
                                  textAlign: TextAlign.center,
                                  style: AppText.bodySecondary),
                            ),
                          )
                        : ListView.builder(
                            reverse: true,
                            padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                                vertical: AppSpacing.sm),
                            itemCount: messages.length,
                            itemBuilder: (context, i) {
                              final m = messages[messages.length - 1 - i];
                              return _Bubble(
                                key: ValueKey(m.clientId ?? m.id),
                                message: m,
                                mine: m.senderId == _repo.myId,
                                onRetry: m.state == SendState.failed
                                    ? () => _retry(m)
                                    : null,
                              );
                            },
                          ),
          ),
          if (_conversation.canSend) _composer() else _readOnly(),
        ]),
      ),
    );
  }

  Widget _readOnly() => Container(
        width: double.infinity,
        color: AppColors.surface,
        padding: const EdgeInsets.all(AppSpacing.md),
        child: const Row(children: [
          Icon(Icons.lock_outline_rounded,
              size: 18, color: AppColors.textSecondary),
          SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(ChatText.readOnly, style: AppText.meta)),
        ]),
      );

  Widget _composer() {
    final canSend = _input.text.trim().isNotEmpty && _messages != null;
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.sm, AppSpacing.sm, AppSpacing.sm),
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Expanded(
          child: TextField(
            controller: _input,
            minLines: 1,
            maxLines: 5,
            maxLength: ChatText.maxLength,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: ChatText.hint,
              counterText: '',
              filled: true,
              fillColor: AppColors.background,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: 12),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        IconButton.filled(
          tooltip: ChatText.sendTooltip,
          onPressed: canSend ? _send : null,
          style: IconButton.styleFrom(
              backgroundColor: AppColors.primaryAction,
              foregroundColor: AppColors.surface,
              minimumSize: const Size(48, 48)),
          icon: const Icon(Icons.send_rounded),
        ),
      ]),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble(
      {super.key, required this.message, required this.mine, this.onRetry});

  final ChatMessage message;
  final bool mine;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final body = switch (message.kind) {
      MessageKind.text => Text(message.text ?? '',
          style: AppText.body
              .copyWith(color: mine ? AppColors.surface : AppColors.textPrimary)),
      MessageKind.place => _PlaceCard(message.place!),
      MessageKind.memory => _MemoryCard(message.memory!),
    };
    final status = switch (message.state) {
      SendState.sent => MessagesText.when(message.sentAt, DateTime.now()),
      SendState.sending => ChatText.sending,
      SendState.failed => ChatText.failed,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Column(
        crossAxisAlignment:
            mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * .78),
            child: InkWell(
              onTap: onRetry,
              borderRadius: BorderRadius.circular(18),
              child: Container(
                padding: message.kind == MessageKind.text
                    ? const EdgeInsets.symmetric(horizontal: 14, vertical: 10)
                    : const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: message.kind != MessageKind.text
                      ? AppColors.surface
                      : mine
                          ? AppColors.primaryAction
                          : AppColors.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: mine && message.kind == MessageKind.text
                      ? null
                      : Border.all(color: AppColors.border),
                ),
                child: body,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 2, left: 6, right: 6),
            child: Text(status,
                style: AppText.meta.copyWith(
                    color: message.state == SendState.failed
                        ? Theme.of(context).colorScheme.error
                        : AppColors.textSecondary)),
          ),
        ],
      ),
    );
  }
}

class _CardShell extends StatelessWidget {
  const _CardShell(
      {required this.icon, required this.label, required this.children});

  final IconData icon;
  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 16, color: AppColors.primaryAction),
              const SizedBox(width: 6),
              Text(label,
                  style: AppText.meta.copyWith(color: AppColors.primaryAction)),
            ]),
            const SizedBox(height: 6),
            ...children,
          ],
        ),
      );
}

class _PlaceCard extends StatelessWidget {
  const _PlaceCard(this.place);

  final SharedPlace place;

  @override
  Widget build(BuildContext context) => _CardShell(
        icon: Icons.place_outlined,
        label: ChatText.placeLabel,
        children: [
          Text(place.name, style: AppText.label),
          if (place.category != null)
            Text(place.category!, style: AppText.meta),
          if (place.note != null) ...[
            const SizedBox(height: 4),
            Text(place.note!, style: AppText.body),
          ],
          const SizedBox(height: 4),
          Text(
              '${place.latitude.toStringAsFixed(5)}, '
              '${place.longitude.toStringAsFixed(5)}',
              style: AppText.meta),
        ],
      );
}

class _MemoryCard extends StatelessWidget {
  const _MemoryCard(this.memory);

  final SharedMemoryCard memory;

  @override
  Widget build(BuildContext context) {
    final active = memory.isActive(DateTime.now());
    return _CardShell(
      icon: Icons.photo_album_outlined,
      label: ChatText.memoryLabel,
      children: active
          ? [
              if (memory.title != null)
                Text(memory.title!, style: AppText.label),
              if (memory.text != null) Text(memory.text!, style: AppText.body),
              if (memory.placeLabel != null)
                Text(memory.placeLabel!, style: AppText.meta),
              const SizedBox(height: 4),
              Text(ChatText.expiresAt(memory.expiresAt), style: AppText.meta),
            ]
          : const [Text(ChatText.memoryExpired, style: AppText.bodySecondary)],
    );
  }
}
