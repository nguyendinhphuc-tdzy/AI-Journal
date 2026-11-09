import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/widgets/app_delete_dialog.dart';
import '../../../core/widgets/app_ui.dart';
import '../../auth/data/auth_service.dart';
import '../../messages/data/messages_repository.dart';
import '../../messages/messages_scope.dart';
import '../../messages/presentation/chat_screen.dart';
import '../../messages/presentation/messages_screen.dart';
import '../data/app_friend.dart';
import 'friend_avatar.dart';

/// Buttons beside a name: the theme's are full width.
const _inRow = Size(48, 44);

abstract final class FriendsText {
  static const title = 'Bạn bè';
  static String summary(int friends, int incoming) => [
        '$friends bạn bè',
        if (incoming > 0) '$incoming lời mời mới',
      ].join(' · ');
  static const loadFailed =
      'Không tải được hồ sơ và bạn bè. Kiểm tra kết nối rồi kéo xuống để thử lại.';

  // Profile.
  static const profileTitle = 'Hồ sơ của bạn';
  static const noUsername = 'Chưa có username';
  static const setUpHint =
      'Đặt username và bật "Cho phép tìm thấy tôi" để bạn bè tìm được bạn.';
  static const visible = 'Người khác tìm thấy bạn';
  static const hidden = 'Đang ẩn khỏi tìm kiếm';
  static const edit = 'Sửa';
  static const editTitle = 'Sửa hồ sơ';
  static const nameLabel = 'Tên hiển thị';
  static const usernameLabel = 'Username';
  static const usernameHelp = '3–24 ký tự: chữ thường a-z, số 0-9 và dấu _';
  static const usernameInvalid =
      'Username chỉ gồm a-z, 0-9, _ và dài 3–24 ký tự.';
  static const discoverTitle = 'Cho phép tìm thấy tôi';
  static const discoverBody =
      'Người khác tìm được bạn bằng username hoặc tên. Nhật ký, album và vị '
      'trí không bao giờ công khai.';
  static const discoverNeedsName = 'Cần tên hoặc username để bật.';
  static const save = 'Lưu';
  static const saved = 'Đã lưu hồ sơ';
  static const usernameTaken =
      'Username này đã có người dùng. Bạn chọn tên khác nhé.';

  // Search.
  static const searchHint = 'Tìm theo @username hoặc tên';
  static const searchClear = 'Xóa ô tìm';
  static const searchShort = 'Nhập ít nhất 3 ký tự để tìm.';
  static const searchNone =
      'Không thấy ai khớp. Người đó cần bật "Cho phép tìm thấy tôi" trong mục '
      'Bạn bè.';
  static const searchFailed = 'Tìm kiếm chưa được, bạn thử lại sau.';
  static const searchKnown =
      'Người khớp đã có trong danh sách bạn bè hoặc lời mời bên dưới.';
  static const addFriend = 'Kết bạn';
  static const requested = 'Đã gửi';
  static const requestSent = 'Đã gửi lời mời kết bạn';
  static const alreadyAsked = 'Lời mời đã có rồi.';

  // Lists.
  static String incomingTitle(int n) => 'Lời mời kết bạn · $n';
  static String friendsTitle(int n) => 'Bạn bè · $n';
  static String outgoingTitle(int n) => 'Đã gửi lời mời · $n';
  static const noFriends =
      'Chưa có bạn bè. Tìm bạn bằng username ở ô phía trên.';
  static const wantsToBeFriends = 'muốn kết bạn với bạn';
  static const accept = 'Chấp nhận';
  static const decline = 'Từ chối';
  static const accepted = 'Hai bạn đã là bạn bè';
  static const declined = 'Đã từ chối lời mời';
  static const cancelRequest = 'Hủy lời mời';
  static const requestCanceled = 'Đã hủy lời mời';
  static String messageTooltip(String name) => 'Nhắn tin cho $name';
  static String moreTooltip(String name) => 'Tùy chọn cho $name';
  static const unfriend = 'Hủy kết bạn';
  static String unfriendTitle(String name) => 'Hủy kết bạn với $name?';
  static const unfriendBody =
      'Hai bạn sẽ không thấy bài chia sẻ mới của nhau và không nhắn thêm '
      'được. Tin nhắn cũ vẫn xem được.';
  static const unfriendFailed = 'Chưa hủy được. Bạn thử lại nhé.';
  static const unfriended = 'Đã hủy kết bạn';
  static const offline = 'Không kết nối được. Bạn thử lại nhé.';
}

/// Friends on the app: find people by @username, answer requests, talk to
/// friends, and the user's own profile (name, @username, whether others
/// can find them). Real accounts only (`/me`, `/friends`); never sample
/// friends.
///
/// - Most used first: search, then requests waiting for an answer, then
///   friends (message; unfriend behind ⋮ after a confirm), then requests
///   the user sent.
/// - The profile is one card; "Sửa" opens a sheet that saves name,
///   @username and "Cho phép tìm thấy tôi" together, so nothing typed is
///   lost to a reload.
/// - Each action shows its own progress on its own row; the rest of the
///   screen stays usable. Rows come in softly (none with reduced motion).
class RealFriendsScreen extends StatefulWidget {
  const RealFriendsScreen({super.key, required this.auth, this.api});

  final SupabaseAuthService? auth;

  /// Tests pass their own; otherwise one from [auth]'s session.
  final ApiClient? api;

  @override
  State<RealFriendsScreen> createState() => _RealFriendsScreenState();
}

class _RealFriendsScreenState extends State<RealFriendsScreen> {
  late final bool _ownsApi = widget.api == null;
  late final ApiClient _api = widget.api ??
      ApiClient(
        accessTokenProvider: () async =>
            widget.auth?.client.auth.currentSession?.accessToken,
        accessTokenRefresher: () async =>
            (await widget.auth!.client.auth.refreshSession())
                .session
                ?.accessToken,
      );
  final _search = TextEditingController();
  Timer? _debounce;
  int _searchVersion = 0;
  bool _loading = true;
  bool _loadFailed = false;
  bool _searching = false;
  bool _searchFailed = false;

  /// Rows with an action on its way, by user id.
  final _working = <String>{};

  /// People asked from search in this visit (the button says so).
  final _asked = <String>{};

  Map<String, dynamic> _profile = const {};
  List<Map<String, dynamic>> _friends = [];
  List<Map<String, dynamic>>? _results;

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
    _reload();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    if (_ownsApi) _api.close();
    super.dispose();
  }

  void _say(String text, {bool good = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Row(children: [
          Icon(good ? Icons.check_circle_rounded : Icons.info_outline_rounded,
              color: AppColors.surface, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(text)),
        ]),
      ));
  }

  static String _name(Map<String, dynamic> item) {
    final name = item['display_name'];
    final username = item['username'];
    if (name is String && name.trim().isNotEmpty) return name.trim();
    if (username is String && username.isNotEmpty) return '@$username';
    return 'Người dùng AI-Journal';
  }

  static String? _handle(Map<String, dynamic> item) {
    final handle = item['username'];
    return handle is String && handle.isNotEmpty ? '@$handle' : null;
  }

  static AppFriend _asFriend(Map<String, dynamic> item) =>
      AppFriend('${item['user_id']}', _name(item));

  Future<void> _reload() async {
    try {
      final profile = await _api.getJson('/me', requireAuth: true);
      final friends = await _api.getList('/friends', requireAuth: true);
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _friends = friends.whereType<Map<String, dynamic>>().toList();
        _loading = false;
        _loadFailed = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadFailed = true;
      });
    }
  }

  /// [action] for [userId]'s row, then the lists again.
  Future<void> _act(String userId, Future<void> Function() action,
      {required String done}) async {
    if (_working.contains(userId)) return;
    setState(() => _working.add(userId));
    try {
      await action();
      _say(done);
      await _reload();
    } on ApiException catch (error) {
      _say(
          error.statusCode == 409
              ? FriendsText.alreadyAsked
              : FriendsText.offline,
          good: false);
    } catch (_) {
      _say(FriendsText.offline, good: false);
    } finally {
      if (mounted) setState(() => _working.remove(userId));
    }
  }

  Future<void> _request(String userId) async {
    await _act(userId, () async {
      await _api.postJson('/friends/requests', {'user_id': userId},
          requireAuth: true);
      _asked.add(userId);
    }, done: FriendsText.requestSent);
  }

  Future<void> _accept(String userId) => _act(userId, () async {
        await _api.postJson('/friends/$userId/accept', {}, requireAuth: true);
      }, done: FriendsText.accepted);

  Future<void> _decline(String userId) => _act(userId, () async {
        await _api.deleteNoContent('/friends/$userId', requireAuth: true);
      }, done: FriendsText.declined);

  Future<void> _cancel(String userId) => _act(userId, () async {
        await _api.deleteNoContent('/friends/$userId', requireAuth: true);
        _asked.remove(userId);
      }, done: FriendsText.requestCanceled);

  Future<void> _unfriend(Map<String, dynamic> person) async {
    final userId = '${person['user_id']}';
    final done = await AppDeleteDialog.present(context,
        builder: (_) => AppDeleteDialog(
              title: FriendsText.unfriendTitle(_name(person)),
              body: FriendsText.unfriendBody,
              confirmLabel: FriendsText.unfriend,
              failed: FriendsText.unfriendFailed,
              onConfirm: () =>
                  _api.deleteNoContent('/friends/$userId', requireAuth: true),
            ));
    if (!done || !mounted) return;
    _say(FriendsText.unfriended);
    await _reload();
  }

  void _queueSearch(String text) {
    _debounce?.cancel();
    if (text.trim().length < 3) {
      _searchVersion++;
      setState(() {
        _results = null;
        _searching = false;
        _searchFailed = false;
      });
      return;
    }
    setState(() => _searching = true);
    _debounce = Timer(const Duration(milliseconds: 350), _find);
  }

  Future<void> _find() async {
    final q = _search.text.trim();
    final version = ++_searchVersion;
    if (q.length < 3) return;
    try {
      final items = await _api.getList(
          '/friends/discover?q=${Uri.encodeQueryComponent(q)}',
          requireAuth: true);
      if (!mounted || version != _searchVersion) return;
      setState(() {
        _results = items.whereType<Map<String, dynamic>>().toList();
        _searching = false;
        _searchFailed = false;
      });
    } catch (_) {
      if (!mounted || version != _searchVersion) return;
      setState(() {
        _results = null;
        _searching = false;
        _searchFailed = true;
      });
    }
  }

  Future<void> _editProfile() async {
    final saved = await showAppSheet<bool>(context,
        builder: (_) => _ProfileSheet(api: _api, profile: _profile));
    if (saved == true && mounted) {
      _say(FriendsText.saved);
      await _reload();
    }
  }

  /// The conversation with a friend, from the "Tin nhắn" feature.
  Future<void> _openChat(String userId) async {
    final messages = MessagesScope.maybeOf(context);
    if (messages == null) return;
    try {
      final conversation = await messages.repository.open(userId);
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => ChatScreen(
              repository: messages.repository,
              conversation: conversation,
              onSeen: messages.seen,
              onIncoming: messages.chime)));
    } on MessagesUnavailable {
      _say(MessagesText.unavailable, good: false);
    } catch (_) {
      _say(MessagesText.failed, good: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final incoming = [
      for (final f in _friends)
        if (f['status'] == 'pending' && f['direction'] == 'incoming') f
    ];
    final outgoing = [
      for (final f in _friends)
        if (f['status'] == 'pending' && f['direction'] != 'incoming') f
    ];
    final friends = [
      for (final f in _friends)
        if (f['status'] == 'accepted') f
    ];
    final canMessage = MessagesScope.maybeOf(context) != null;
    final reduced = MediaQuery.disableAnimationsOf(context);
    var order = 0;
    Widget enter(Widget child) => reduced
        ? child
        : _Enter(
            delay: Duration(milliseconds: 35 * (order++).clamp(0, 10)),
            child: child);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        title: const Text(FriendsText.title, style: AppText.sectionTitle),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              color: AppColors.primaryAction,
              onRefresh: _reload,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md, 0, AppSpacing.md, AppSpacing.xxl),
                children: [
                  if (_loadFailed)
                    enter(const _Banner(FriendsText.loadFailed))
                  else ...[
                    Padding(
                      padding: const EdgeInsets.only(
                          left: AppSpacing.xs, bottom: 12),
                      child: Text(
                          FriendsText.summary(friends.length, incoming.length),
                          style: AppText.meta),
                    ),
                    enter(
                        _ProfileCard(profile: _profile, onEdit: _editProfile)),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  enter(_searchBox()),
                  _searchResults(),
                  if (incoming.isNotEmpty) ...[
                    _Section(FriendsText.incomingTitle(incoming.length),
                        accent: true),
                    for (final person in incoming)
                      enter(_PersonCard(
                        key: ValueKey('incoming-${person['user_id']}'),
                        friend: _asFriend(person),
                        handle: _handle(person),
                        note: FriendsText.wantsToBeFriends,
                        highlight: true,
                        busy: _working.contains('${person['user_id']}'),
                        actions: [
                          OutlinedButton(
                            onPressed: () => _decline('${person['user_id']}'),
                            child: const Text(FriendsText.decline),
                          ),
                          FilledButton(
                            onPressed: () => _accept('${person['user_id']}'),
                            style: FilledButton.styleFrom(
                                backgroundColor: AppColors.primaryAction),
                            child: const Text(FriendsText.accept),
                          ),
                        ],
                      )),
                  ],
                  _Section(FriendsText.friendsTitle(friends.length)),
                  if (friends.isEmpty)
                    enter(const _Banner(FriendsText.noFriends,
                        icon: Icons.group_add_outlined))
                  else
                    for (final person in friends)
                      enter(_PersonCard(
                        key: ValueKey('friend-${person['user_id']}'),
                        friend: _asFriend(person),
                        handle: _handle(person),
                        busy: _working.contains('${person['user_id']}'),
                        trailing: [
                          if (canMessage)
                            IconButton.filledTonal(
                              tooltip:
                                  FriendsText.messageTooltip(_name(person)),
                              onPressed: () =>
                                  _openChat('${person['user_id']}'),
                              style: IconButton.styleFrom(
                                  backgroundColor: AppColors.primaryLight,
                                  foregroundColor: AppColors.primaryAction),
                              icon:
                                  const Icon(Icons.chat_bubble_outline_rounded),
                            ),
                          PopupMenuButton<String>(
                            tooltip: FriendsText.moreTooltip(_name(person)),
                            icon: const Icon(Icons.more_vert_rounded,
                                color: AppColors.textSecondary),
                            onSelected: (_) => _unfriend(person),
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: 'unfriend',
                                child: Row(children: [
                                  Icon(Icons.person_remove_outlined,
                                      color: AppDeleteDialog.destructive),
                                  SizedBox(width: AppSpacing.sm),
                                  Text(FriendsText.unfriend),
                                ]),
                              ),
                            ],
                          ),
                        ],
                      )),
                  if (outgoing.isNotEmpty) ...[
                    _Section(FriendsText.outgoingTitle(outgoing.length)),
                    for (final person in outgoing)
                      enter(_PersonCard(
                        key: ValueKey('outgoing-${person['user_id']}'),
                        friend: _asFriend(person),
                        handle: _handle(person),
                        busy: _working.contains('${person['user_id']}'),
                        trailing: [
                          TextButton(
                            style: TextButton.styleFrom(minimumSize: _inRow),
                            onPressed: () => _cancel('${person['user_id']}'),
                            child: const Text(FriendsText.cancelRequest),
                          ),
                        ],
                      )),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _searchBox() => TextField(
        controller: _search,
        onChanged: _queueSearch,
        autocorrect: false,
        textInputAction: TextInputAction.search,
        style: AppText.body.copyWith(color: AppColors.textPrimary),
        decoration: InputDecoration(
          hintText: FriendsText.searchHint,
          hintStyle: AppText.bodySecondary,
          filled: true,
          fillColor: AppColors.surface,
          prefixIcon:
              const Icon(Icons.search_rounded, color: AppColors.textSecondary),
          suffixIcon: _search.text.isEmpty
              ? null
              : IconButton(
                  tooltip: FriendsText.searchClear,
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () {
                    _search.clear();
                    _queueSearch('');
                  },
                ),
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.input),
              borderSide: const BorderSide(color: AppColors.border)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.input),
              borderSide:
                  const BorderSide(color: AppColors.primaryAction, width: 1.5)),
        ),
      );

  /// What the search says now: typing, searching, nobody, people.
  Widget _searchResults() {
    final query = _search.text.trim();
    final known = {for (final f in _friends) '${f['user_id']}'};
    final results = [
      for (final p in _results ?? const <Map<String, dynamic>>[])
        if (!known.contains('${p['user_id']}') ||
            _asked.contains('${p['user_id']}'))
          p
    ];
    final Widget child;
    if (query.isEmpty) {
      child = const SizedBox(key: ValueKey('idle'), width: double.infinity);
    } else if (query.length < 3) {
      child = const _Hint(FriendsText.searchShort, key: ValueKey('short'));
    } else if (_searching) {
      child = const Padding(
        key: ValueKey('searching'),
        padding: EdgeInsets.symmetric(vertical: 12),
        child: LinearProgressIndicator(
            minHeight: 3, color: AppColors.primaryAction),
      );
    } else if (_searchFailed) {
      child = const _Hint(FriendsText.searchFailed, key: ValueKey('failed'));
    } else if (results.isEmpty && (_results ?? const []).isNotEmpty) {
      child = const _Hint(FriendsText.searchKnown, key: ValueKey('known'));
    } else if (results.isEmpty) {
      child = const _Hint(FriendsText.searchNone, key: ValueKey('none'));
    } else {
      child = Column(
        key: ValueKey('results-${results.length}'),
        children: [
          const SizedBox(height: AppSpacing.sm),
          for (final person in results)
            _PersonCard(
              key: ValueKey('result-${person['user_id']}'),
              friend: _asFriend(person),
              handle: _handle(person),
              busy: _working.contains('${person['user_id']}'),
              trailing: [_requestButton('${person['user_id']}')],
            ),
        ],
      );
    }
    final reduced = MediaQuery.disableAnimationsOf(context);
    return AnimatedSize(
      duration: reduced ? Duration.zero : const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: reduced ? Duration.zero : const Duration(milliseconds: 180),
        child: child,
      ),
    );
  }

  /// "Kết bạn", then "Đã gửi ✓" once asked.
  Widget _requestButton(String userId) {
    final asked = _asked.contains(userId);
    final reduced = MediaQuery.disableAnimationsOf(context);
    return AnimatedSwitcher(
      duration: reduced ? Duration.zero : const Duration(milliseconds: 220),
      transitionBuilder: (child, animation) =>
          ScaleTransition(scale: animation, child: child),
      child: asked
          ? FilledButton.tonalIcon(
              key: const ValueKey('asked'),
              onPressed: null,
              style: FilledButton.styleFrom(minimumSize: _inRow),
              icon: const Icon(Icons.check_rounded, size: 18),
              label: const Text(FriendsText.requested),
            )
          : FilledButton.icon(
              key: const ValueKey('ask'),
              onPressed: () => _request(userId),
              style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryAction,
                  minimumSize: _inRow),
              icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
              label: const Text(FriendsText.addFriend),
            ),
    );
  }
}

/// The user's own card: who they are to friends, and "Sửa".
class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.profile, required this.onEdit});

  final Map<String, dynamic> profile;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final name = profile['display_name'];
    final username = profile['username'];
    final hasUsername = username is String && username.isNotEmpty;
    final visible = profile['discoverable'] == true;
    final shown = name is String && name.trim().isNotEmpty
        ? name.trim()
        : hasUsername
            ? '@$username'
            : 'Bạn';
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            FriendAvatar(AppFriend('${profile['user_id']}', shown), size: 52),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(FriendsText.profileTitle,
                      style: AppText.meta.copyWith(fontSize: 13)),
                  Text(shown,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.cardTitle),
                  Text(hasUsername ? '@$username' : FriendsText.noUsername,
                      style: AppText.meta.copyWith(
                          color: hasUsername
                              ? AppColors.primaryAction
                              : AppColors.textSecondary)),
                ],
              ),
            ),
            OutlinedButton.icon(
              onPressed: onEdit,
              style: OutlinedButton.styleFrom(minimumSize: _inRow),
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text(FriendsText.edit),
            ),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Flexible(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color:
                      visible ? AppColors.primaryLight : AppColors.background,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(
                      visible
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 16,
                      color: visible
                          ? AppColors.primaryAction
                          : AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                        visible ? FriendsText.visible : FriendsText.hidden,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.meta.copyWith(
                            fontSize: 13,
                            color: visible
                                ? AppColors.primaryAction
                                : AppColors.textSecondary)),
                  ),
                ]),
              ),
            ),
          ]),
          if (!hasUsername || !visible) ...[
            const SizedBox(height: AppSpacing.sm),
            const Text(FriendsText.setUpHint, style: AppText.meta),
          ],
        ],
      ),
    );
  }
}

/// Name, @username and "Cho phép tìm thấy tôi", saved together.
class _ProfileSheet extends StatefulWidget {
  const _ProfileSheet({required this.api, required this.profile});

  final ApiClient api;
  final Map<String, dynamic> profile;

  @override
  State<_ProfileSheet> createState() => _ProfileSheetState();
}

class _ProfileSheetState extends State<_ProfileSheet> {
  late final _name =
      TextEditingController(text: '${widget.profile['display_name'] ?? ''}');
  late final _username =
      TextEditingController(text: '${widget.profile['username'] ?? ''}');
  late bool _discoverable = widget.profile['discoverable'] == true;
  var _saving = false;
  String? _usernameError;
  String? _error;

  static final _valid = RegExp(r'^[a-z0-9_]{3,24}$');

  String get _handle =>
      _username.text.trim().replaceFirst(RegExp(r'^@'), '').toLowerCase();

  bool get _hasName => _name.text.trim().isNotEmpty || _handle.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() {}));
    // Only a change of the words clears the error (focus and selection
    // changes notify too).
    var typed = _username.text;
    _username.addListener(() {
      if (_username.text == typed) return;
      typed = _username.text;
      setState(() => _usernameError = null);
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final handle = _handle;
    if (handle.isNotEmpty && !_valid.hasMatch(handle)) {
      setState(() => _usernameError = FriendsText.usernameInvalid);
      return;
    }
    final name = _name.text.trim();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.api.patchJson(
          '/me',
          {
            'display_name': name.isEmpty ? null : name,
            'username': handle.isEmpty ? null : handle,
            'discoverable':
                _discoverable && (name.isNotEmpty || handle.isNotEmpty),
          },
          requireAuth: true);
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        if (error.statusCode == 409) {
          _usernameError = FriendsText.usernameTaken;
        } else if (error.statusCode == 422) {
          _usernameError = FriendsText.usernameInvalid;
        } else {
          _error = FriendsText.offline;
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = FriendsText.offline;
        });
      }
    }
  }

  InputDecoration _field(String label,
          {String? helper, String? error, String? prefix}) =>
      InputDecoration(
        labelText: label,
        helperText: helper,
        errorText: error,
        prefixText: prefix,
        counterText: '',
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.input)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.input),
            borderSide:
                const BorderSide(color: AppColors.primaryAction, width: 1.5)),
      );

  @override
  Widget build(BuildContext context) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(FriendsText.editTitle, style: AppText.sectionTitle),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _name,
                maxLength: 30,
                enabled: !_saving,
                textCapitalization: TextCapitalization.words,
                decoration: _field(FriendsText.nameLabel),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _username,
                maxLength: 24,
                enabled: !_saving,
                autocorrect: false,
                decoration: _field(FriendsText.usernameLabel,
                    helper: FriendsText.usernameHelp,
                    error: _usernameError,
                    prefix: '@'),
              ),
              const SizedBox(height: AppSpacing.sm),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeThumbColor: AppColors.surface,
                activeTrackColor: AppColors.primaryAction,
                title:
                    const Text(FriendsText.discoverTitle, style: AppText.label),
                subtitle: Text(
                    _hasName
                        ? FriendsText.discoverBody
                        : FriendsText.discoverNeedsName,
                    style: AppText.meta),
                value: _discoverable && _hasName,
                onChanged: _saving || !_hasName
                    ? null
                    : (value) => setState(() => _discoverable = value),
              ),
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(_error!,
                    style: AppText.meta
                        .copyWith(color: Theme.of(context).colorScheme.error)),
              ],
              const SizedBox(height: AppSpacing.md),
              AppPrimaryButton(
                label: FriendsText.save,
                busy: _saving,
                onPressed: _saving ? null : _save,
              ),
            ],
          ),
        ),
      );
}

/// A person: avatar, name, @username, a line about them, and actions.
class _PersonCard extends StatelessWidget {
  const _PersonCard({
    super.key,
    required this.friend,
    this.handle,
    this.note,
    this.highlight = false,
    this.busy = false,
    this.trailing = const [],
    this.actions = const [],
  });

  final AppFriend friend;
  final String? handle;
  final String? note;
  final bool highlight;
  final bool busy;

  /// Beside the name (icons, one short button).
  final List<Widget> trailing;

  /// Under the name, full width (accept / decline).
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.fromLTRB(14, 12, AppSpacing.sm, 12),
          decoration: BoxDecoration(
            color: highlight ? AppColors.primaryLight : AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(
                color: highlight
                    ? AppColors.primaryAction.withValues(alpha: .35)
                    : AppColors.border),
          ),
          child: Column(children: [
            Row(children: [
              FriendAvatar(friend, size: 48),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(friend.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.label),
                    if (handle != null || note != null)
                      Text(
                          [if (handle != null) handle!, if (note != null) note!]
                              .join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.meta.copyWith(fontSize: 13)),
                  ],
                ),
              ),
              if (busy)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.4)),
                )
              else
                ...trailing,
            ]),
            if (actions.isNotEmpty && !busy) ...[
              const SizedBox(height: 10),
              Row(children: [
                const SizedBox(width: 60),
                for (final (i, action) in actions.indexed) ...[
                  if (i > 0) const SizedBox(width: AppSpacing.sm),
                  Expanded(child: action),
                ],
                const SizedBox(width: AppSpacing.xs),
              ]),
            ],
          ]),
        ),
      );
}

class _Section extends StatelessWidget {
  const _Section(this.title, {this.accent = false});

  final String title;
  final bool accent;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.xs, AppSpacing.lg, AppSpacing.xs, 10),
        child: Semantics(
          header: true,
          child: Text(title,
              style: AppText.label.copyWith(
                  color: accent
                      ? AppColors.primaryAction
                      : AppColors.textSecondary)),
        ),
      );
}

class _Hint extends StatelessWidget {
  const _Hint(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.xs, AppSpacing.sm, AppSpacing.xs, 0),
        child: Text(text, style: AppText.meta),
      );
}

class _Banner extends StatelessWidget {
  const _Banner(this.text, {this.icon = Icons.wifi_off_rounded});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(children: [
          Icon(icon, color: AppColors.primaryAction),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: AppText.body)),
        ]),
      );
}

/// Fades and rises into place once, after [delay].
class _Enter extends StatefulWidget {
  const _Enter({required this.delay, required this.child});

  final Duration delay;
  final Widget child;

  @override
  State<_Enter> createState() => _EnterState();
}

class _EnterState extends State<_Enter> with SingleTickerProviderStateMixin {
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
          position: Tween(begin: const Offset(0, .08), end: Offset.zero)
              .animate(_curve),
          child: widget.child,
        ),
      );
}
