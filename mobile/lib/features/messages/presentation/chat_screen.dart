import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text.dart';
import '../../social/presentation/friend_avatar.dart';
import '../../sound/app_sound.dart';
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
    this.onIncoming,
    this.poll = const Duration(seconds: 5),
  });

  final MessagesRepository repository;
  final Conversation conversation;

  /// Messages were read here: the tab's count changes.
  final VoidCallback? onSeen;

  /// A friend's message arrived while open (the chime).
  final VoidCallback? onIncoming;
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

  /// The newest message the server sent, shown or not: polling asks for
  /// what came after it, and reading marks up to it.
  String? _cursor;

  /// 24-hour moments live on the map and in Khoảnh khắc, not in a chat;
  /// older ones the server put here are left out.
  static bool _inChat(ChatMessage m) => m.kind != MessageKind.memory;

  /// Messages there when the screen opened: they do not animate in.
  final _initial = <String>{};

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
      if (list.isNotEmpty) _cursor = list.last.id;
      setState(() {
        _messages = [...list.where(_inChat)];
        _initial.addAll([for (final m in list) m.clientId ?? m.id]);
        _loadFailed = false;
      });
      _markRead();
      _startPolling();
    } catch (_) {
      if (mounted) setState(() => _loadFailed = true);
    }
  }


  Future<void> _poll() async {
    final current = _messages;
    if (current == null) return;
    try {
      final all = await _repo.messages(_conversation.id, after: _cursor);
      if (!mounted || all.isEmpty) return;
      _cursor = all.last.id;
      final fresh = all.where(_inChat).toList();
      final before = _messages!.length;
      setState(() {
        for (final message in fresh) {
          _merge(message);
        }
      });
      if (_messages!.length > before &&
          fresh.any((m) => m.senderId != _repo.myId)) {
        widget.onIncoming?.call();
      }
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
    final newest = _cursor;
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
      AppSound.instance.play(SoundCue.messageOut);
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

  /// The list from newest (index 0, at the bottom) to oldest, with a day
  /// line where the day changes.
  List<Object> _rows(List<ChatMessage> messages) {
    final rows = <Object>[];
    DateTime? day;
    for (final m in messages) {
      final t = m.sentAt.toLocal();
      final d = DateTime(t.year, t.month, t.day);
      if (day != d) rows.add(d);
      day = d;
      rows.add(m);
    }
    return rows.reversed.toList();
  }

  /// Same sender, same day, within 3 minutes: one group.
  static bool _together(ChatMessage a, ChatMessage b) {
    final ta = a.sentAt.toLocal(), tb = b.sentAt.toLocal();
    return a.senderId == b.senderId &&
        ta.year == tb.year &&
        ta.month == tb.month &&
        ta.day == tb.day &&
        ta.difference(tb).abs() < const Duration(minutes: 3);
  }

  @override
  Widget build(BuildContext context) {
    final messages = _messages;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        shape: const Border(bottom: BorderSide(color: AppColors.border)),
        leading: IconButton(
          tooltip: ChatText.backTooltip,
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: Row(children: [
          FriendAvatar(_conversation.friend, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_conversation.friend.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.label),
                if (_conversation.username != null)
                  Text('@${_conversation.username}',
                      style: AppText.meta.copyWith(fontSize: 13)),
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
                        ? _empty()
                        : _list(messages),
          ),
          if (_conversation.canSend) _composer() else _readOnly(),
        ]),
      ),
    );
  }

  Widget _empty() => Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Image.asset('assets/Deimage/Nudaeng writing-transparent.png',
                height: 110, excludeFromSemantics: true),
            const SizedBox(height: AppSpacing.md),
            const Text(ChatText.empty,
                textAlign: TextAlign.center, style: AppText.bodySecondary),
          ]),
        ),
      );

  Widget _list(List<ChatMessage> messages) {
    final rows = _rows(messages);
    final reduced = MediaQuery.disableAnimationsOf(context);
    final myId = _repo.myId;
    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.sm, AppSpacing.sm, AppSpacing.md, AppSpacing.md),
      itemCount: rows.length,
      itemBuilder: (context, i) {
        final row = rows[i];
        if (row is DateTime) return _DayLine(row);
        final m = row as ChatMessage;
        // Neighbours on screen: i - 1 is newer (below), i + 1 older (above).
        final below = i > 0 && rows[i - 1] is ChatMessage
            ? rows[i - 1] as ChatMessage
            : null;
        final above = i + 1 < rows.length && rows[i + 1] is ChatMessage
            ? rows[i + 1] as ChatMessage
            : null;
        final key = m.clientId ?? m.id;
        final bubble = _Bubble(
          key: ValueKey(key),
          message: m,
          friend: _conversation,
          mine: m.senderId == myId,
          first: above == null || !_together(above, m),
          last: below == null || !_together(m, below),
          onRetry: m.state == SendState.failed ? () => _retry(m) : null,
        );
        // Only messages that arrive or are sent while open come in moving.
        return reduced || _initial.contains(key)
            ? bubble
            : _Arrive(key: ValueKey('arrive-$key'), child: bubble);
      },
    );
  }

  Widget _readOnly() => Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
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
    final reduced = MediaQuery.disableAnimationsOf(context);
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, 10, AppSpacing.sm, 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Expanded(
          child: TextField(
            controller: _input,
            minLines: 1,
            maxLines: 5,
            maxLength: ChatText.maxLength,
            textCapitalization: TextCapitalization.sentences,
            style: AppText.body.copyWith(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: ChatText.hint,
              hintStyle: AppText.bodySecondary,
              counterText: '',
              filled: true,
              fillColor: AppColors.background,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 18, vertical: 12),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: AppColors.border)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(
                      color: AppColors.primaryAction, width: 1.5)),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        AnimatedScale(
          scale: canSend ? 1 : .88,
          duration: reduced ? Duration.zero : const Duration(milliseconds: 160),
          curve: Curves.easeOutBack,
          child: IconButton.filled(
            tooltip: ChatText.sendTooltip,
            onPressed: canSend ? _send : null,
            style: IconButton.styleFrom(
                backgroundColor: AppColors.primaryAction,
                foregroundColor: AppColors.surface,
                disabledBackgroundColor: AppColors.border,
                disabledForegroundColor: AppColors.textSecondary,
                minimumSize: const Size(48, 48)),
            icon: const Icon(Icons.send_rounded),
          ),
        ),
      ]),
    );
  }
}

/// "Hôm nay", "Hôm qua" or the date, centred between messages.
class _DayLine extends StatelessWidget {
  const _DayLine(this.day);

  final DateTime day;

  static String label(DateTime day, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final days = today.difference(day).inDays;
    String two(int n) => n.toString().padLeft(2, '0');
    return days == 0
        ? 'Hôm nay'
        : days == 1
            ? 'Hôm qua'
            : '${two(day.day)}/${two(day.month)}/${day.year}';
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(label(day, DateTime.now()),
                style: AppText.meta.copyWith(fontSize: 12)),
          ),
        ),
      );
}

/// A message that has just come in or gone: rises, fades and settles.
class _Arrive extends StatefulWidget {
  const _Arrive({super.key, required this.child});

  final Widget child;

  @override
  State<_Arrive> createState() => _ArriveState();
}

class _ArriveState extends State<_Arrive> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 240))
    ..forward();
  late final _curve =
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);

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
          position: Tween(begin: const Offset(0, .35), end: Offset.zero)
              .animate(_curve),
          child: ScaleTransition(
              scale: Tween(begin: .96, end: 1.0).animate(_curve),
              child: widget.child),
        ),
      );
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    super.key,
    required this.message,
    required this.friend,
    required this.mine,
    required this.first,
    required this.last,
    this.onRetry,
  });

  final ChatMessage message;
  final Conversation friend;
  final bool mine;

  /// The first (top) and last (bottom) of a run from the same sender.
  final bool first;
  final bool last;
  final VoidCallback? onRetry;

  static const _avatar = 28.0;

  @override
  Widget build(BuildContext context) {
    final text = message.kind == MessageKind.text;
    final body = switch (message.kind) {
      MessageKind.text => Text(message.text ?? '',
          style: AppText.body.copyWith(
              height: 1.35,
              color: mine ? AppColors.surface : AppColors.textPrimary)),
      MessageKind.place => _PlaceCard(message.place!),
      MessageKind.memory => _MemoryCard(message.memory!),
    };
    final status = switch (message.state) {
      SendState.sent => last ? MessagesText.when(message.sentAt, DateTime.now()) : null,
      SendState.sending => ChatText.sending,
      SendState.failed => ChatText.failed,
    };
    const big = Radius.circular(20);
    const joined = Radius.circular(6);
    final radius = mine
        ? BorderRadius.only(
            topLeft: big,
            bottomLeft: big,
            topRight: first ? big : joined,
            bottomRight: last ? const Radius.circular(4) : joined)
        : BorderRadius.only(
            topRight: big,
            bottomRight: big,
            topLeft: first ? big : joined,
            bottomLeft: last ? const Radius.circular(4) : joined);
    final mineText = mine && text;
    final bubble = ConstrainedBox(
      constraints:
          BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * .74),
      child: Material(
        color: mineText ? AppColors.primaryAction : AppColors.surface,
        elevation: mineText ? 0 : .6,
        shadowColor: Colors.black26,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: mineText
              ? BorderSide.none
              : BorderSide(
                  color: mine
                      ? AppColors.primaryAction.withValues(alpha: .4)
                      : AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onRetry,
          child: Padding(
            padding: text
                ? const EdgeInsets.symmetric(horizontal: 14, vertical: 10)
                : const EdgeInsets.all(4),
            child: body,
          ),
        ),
      ),
    );
    return Padding(
      padding: EdgeInsets.only(top: first ? 8 : 2),
      child: Row(
        mainAxisAlignment:
            mine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!mine)
            Padding(
              padding: EdgeInsets.only(
                  right: AppSpacing.sm, bottom: status == null ? 0 : 20),
              child: last
                  ? FriendAvatar(friend.friend, size: _avatar)
                  : const SizedBox(width: _avatar),
            ),
          Flexible(
            child: Column(
              crossAxisAlignment:
                  mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                bubble,
                if (status != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 3, left: 6, right: 6),
                    child: Text(status,
                        style: AppText.meta.copyWith(
                            fontSize: 12,
                            color: message.state == SendState.failed
                                ? Theme.of(context).colorScheme.error
                                : AppColors.textSecondary)),
                  ),
              ],
            ),
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
