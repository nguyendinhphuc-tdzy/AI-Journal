import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../data/album.dart';
import '../data/album_repository.dart';
import '../data/album_unlocks.dart';
import '../data/memory.dart';
import '../data/memory_share.dart';
import '../../social/data/app_friend.dart';
import '../../social/data/friends_sharing.dart';
import '../../social/presentation/friend_avatar.dart';
import 'album_form_parts.dart';

/// A10: preview a memory and share it on the map for 24 hours.
///
/// - One solid Surface sheet (no see-through layers over the map), 88 % of
///   the screen to start, up to 95 %; the content scrolls, the CTA stays
///   docked. Order: title and Close, the exact preview, who sees it, place
///   (→ E05), category, the post's own description, the 24-hour line, CTA.
/// - The preview is the payload: photo, title, description, place and
///   category as they will be posted. The private note is never copied in;
///   the user may pick a passage of it. A note-only memory needs text.
/// - "Chia sẻ trong 24 giờ" is enabled only with an audience the service
///   offers, a confirmed place and something to show. Choosing a place or
///   opening the sheet posts nothing; Close keeps the choices for the
///   session ([MemoryShareDraft]).
/// - Publishing ignores repeated taps and keeps the form; a failure says so
///   and offers "Thử lại". Without a share service nothing is said to be
///   shared. Success: a check and the server's expiry, then the sheet closes
///   with the post (the caller goes to the map). No mascot here.
/// - A memory with an active post: sharing again replaces it with a new
///   24-hour post, and the sheet says so first. Opening the sheet or editing
///   the memory changes nothing about the post.
class ShareMemorySheet extends StatefulWidget {
  const ShareMemorySheet({
    super.key,
    required this.album,
    required this.memory,
    required this.repository,
    required this.sharing,
    required this.onPickPlace,
  });

  final Album album;

  /// The memory as it is now; the post is a snapshot of it.
  final Memory memory;
  final AlbumRepository repository;
  final MemorySharing sharing;

  /// E05 from the place chosen so far; null keeps it.
  final Future<MemoryPlace?> Function(MemoryPlace? current) onPickPlace;

  static const title = 'Chia sẻ kỷ niệm trong 24 giờ';
  static const closeTooltip = 'Đóng';
  static const previewLabel = 'Bản xem trước';
  static const previewEmpty =
      'Chưa có nội dung để chia sẻ. Viết mô tả hoặc chọn một đoạn từ ghi chú.';
  static const audienceLabel = 'Ai sẽ thấy bài này';
  static const audienceNone =
      'Bài chia sẻ chỉ bạn bè trên app thấy, trong 24 giờ. Bạn bè trên app là '
      'những người bạn đã kết bạn bằng username. Tính năng sẽ mở khi bạn đăng '
      'nhập tài khoản.';

  /// The audience sharing will have (planned, not selectable yet).
  static const friendsLabel = 'Bạn bè trên app';
  static const friendsDetail = 'Những người bạn đã kết bạn trên app';
  static const soonLabel = 'Sắp có';
  static const audienceFailed = 'Chưa tải được danh sách người xem.';
  static const retryLabel = 'Thử lại';
  static const placeLabel = 'Địa điểm';
  static const placeNone = 'Chưa chọn địa điểm';
  static const pickPlace = 'Chọn địa điểm';
  static const changePlace = 'Đổi địa điểm';
  static String useMemoryPlace(String label) =>
      'Dùng địa điểm của kỷ niệm: $label';
  static const placeUnnamed =
      'Vị trí này chưa có tên: người xem sẽ thấy "${MemoryPlace.unnamed}" '
      'và tọa độ. Bạn có thể đặt tên khi chọn địa điểm.';
  static const placeHelp =
      'Bài hiện ở nơi bạn chọn, không tự lấy vị trí hiện tại của máy.';
  static const categoryLabel = 'Phân loại';
  static const categoryHelp =
      'Không chọn thì bài được để là "${ShareCategory.uncategorized}".';
  static const textLabel = 'Mô tả chia sẻ';
  static const textHintPhoto = 'Vài dòng cho người xem (không bắt buộc)';
  static const textHintNote = 'Viết hoặc chọn đoạn bạn muốn chia sẻ';
  static const textMax = 300;
  static const notePick = 'Chọn một đoạn từ ghi chú';
  static const noteHide = 'Ẩn ghi chú';
  static const notePrivate =
      'Ghi chú riêng, không được chia sẻ. Bôi chọn đoạn bạn muốn rồi bấm '
      '"Thêm đoạn đã chọn".';
  static const noteAdd = 'Thêm đoạn đã chọn';
  static const expiry =
      'Bản chia sẻ sẽ hết hạn sau 24 giờ. Kỷ niệm gốc vẫn ở Album.';
  static String replaces(DateTime expiresAt) =>
      'Kỷ niệm này đang được chia sẻ đến ${formatTime(expiresAt)}. Chia sẻ '
      'lại sẽ gỡ bài đó và thay bằng bài mới, hết hạn sau 24 giờ kể từ lúc '
      'chia sẻ lại.';
  static const publishLabel = 'Chia sẻ trong 24 giờ';
  static const noService =
      'Chưa chia sẻ được: cần đăng nhập tài khoản để có bạn bè trên app.';
  static const friendsEmpty =
      'Bạn chưa có bạn bè trên app. Kết bạn bằng username ở Khám phá, mục '
      'Bạn bè, rồi quay lại chia sẻ nhé.';
  static const friendsBlocker = 'Kết bạn trên app để chia sẻ.';
  static const notDelivered =
      'Chưa gửi được cho bạn bè: máy chủ chưa hỗ trợ chia sẻ bài. Người bạn '
      'chọn và nội dung vẫn được giữ.';
  static const pickHelp = 'Chỉ những người bạn chọn mới thấy bài này.';
  static const pickAll = 'Chọn tất cả';
  static const pickNone = 'Bỏ chọn';
  static const needPeople = 'chọn ít nhất một người';
  static String picked(int count, int total) => 'Đã chọn $count/$total người';
  static const unavailable =
      'Chưa kết nối được dịch vụ chia sẻ nên kỷ niệm chưa được chia sẻ. Nội '
      'dung bạn chọn vẫn còn.';
  static const failed =
      'Chưa chia sẻ được. Nội dung bạn chọn vẫn còn, bạn thử lại nhé.';
  static const lockedNow =
      'Album đang khóa nên kỷ niệm này không chia sẻ được.';
  static const published = 'Đã chia sẻ trong 24 giờ';
  static const replaced = 'Đã thay bài chia sẻ cũ bằng bài mới';
  static String expiresLabel(DateTime at) => 'Hết hạn lúc ${formatTime(at)}';
  static const away = 'Quay lại ứng dụng để tiếp tục.';

  /// The check shows this long before the map takes over.
  static const successHold = Duration(milliseconds: 900);

  /// "14:05, 21/10/2026", local time.
  static String formatTime(DateTime at) {
    final t = at.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(t.hour)}:${two(t.minute)}, '
        '${two(t.day)}/${two(t.month)}/${t.year}';
  }

  /// "Để chia sẻ, hãy a, b và c."
  static String needs(List<String> steps) {
    final list = steps.length < 2
        ? steps.join()
        : '${steps.sublist(0, steps.length - 1).join(', ')} và ${steps.last}';
    return 'Để chia sẻ, hãy $list.';
  }

  static const needAudience = 'chọn người xem';
  static const needPlace = 'chọn địa điểm';
  static const needText = 'thêm mô tả chia sẻ';

  /// Opens A10 on the root navigator. The post, or null when closed without
  /// sharing.
  static Future<SharedMemoryPost?> show(
    BuildContext context, {
    required Album album,
    required Memory memory,
    required AlbumRepository repository,
    required MemorySharing sharing,
    required Future<MemoryPlace?> Function(MemoryPlace? current) onPickPlace,
  }) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    return showModalBottomSheet<SharedMemoryPost>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      barrierColor: Colors.black.withValues(alpha: .35),
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      sheetAnimationStyle: reduced
          ? AnimationStyle.noAnimation
          : const AnimationStyle(
              duration: Duration(milliseconds: 300),
              reverseDuration: Duration(milliseconds: 220)),
      builder: (_) => ShareMemorySheet(
        album: album,
        memory: memory,
        repository: repository,
        sharing: sharing,
        onPickPlace: onPickPlace,
      ),
    );
  }

  @override
  State<ShareMemorySheet> createState() => _ShareMemorySheetState();
}

class _ShareMemorySheetState extends State<ShareMemorySheet> {
  late final MemoryShareDraft _draft = MemoryShareDraft.of(widget.memory.id);
  late final _text = TextEditingController(text: _draft.text);

  /// Null while loading.
  List<ShareAudience>? _audiences;
  var _serviceFailed = false;
  SharedMemoryPost? _active;

  var _showNote = false;

  /// The passage of the note selected right now, if any.
  String? _excerpt;

  var _publishing = false;
  var _failedOnce = false;
  String? _error;
  SharedMemoryPost? _post;
  Timer? _leave;

  MemoryContent get _content => widget.memory.content;
  bool get _busy => _publishing || _post != null;

  /// Large text: the hint about what is missing goes at the end of the form
  /// instead of the dock, so a short screen keeps room for the form.
  bool _bigText(BuildContext context) =>
      MediaQuery.textScalerOf(context).scale(16) > 20;

  ShareAudience? get _audience {
    final sharing = widget.sharing;
    if (sharing is FriendsSharing) {
      // The people picked among the friends: an audience made for them.
      final picked = _picked(sharing);
      return picked.isEmpty ? null : friendsAudience(picked);
    }
    for (final audience in _audiences ?? const <ShareAudience>[]) {
      if (audience.id == _draft.audienceId) return audience;
    }
    return null;
  }

  /// Which friends are picked (the draft keeps their ids); everyone the
  /// first time.
  List<AppFriend> _picked(FriendsSharing sharing) {
    final pickable = sharing.pickable;
    final kept = _draft.audienceId;
    if (kept == null) return pickable;
    final ids = friendsAudienceIds(kept).toSet();
    return [
      for (final friend in pickable)
        if (ids.contains(friend.id)) friend
    ];
  }

  /// Keeps [friends] as the people picked (none is allowed: nothing posts).
  void _pick(List<AppFriend> friends) =>
      _changed(() => _draft.audienceId = friendsAudience(friends).id);

  String? get _sharedText {
    final text = _text.text.trim();
    return text.isEmpty ? null : text;
  }

  /// The server needs a description on every post
  /// ([FriendsSharing.needsText]), photo or not.
  bool get _needsText =>
      widget.sharing is FriendsSharing &&
      (widget.sharing as FriendsSharing).needsText;

  bool get _hasContent =>
      _sharedText != null || (!_needsText && _content.photoPath != null);

  /// What would be posted, or null while something is missing or the
  /// service cannot send it yet.
  SharePayload? get _payload {
    final audience = _audience;
    final place = _draft.place;
    if (audience == null || place == null || !_hasContent) return null;
    final sharing = widget.sharing;
    if (sharing is FriendsSharing && !sharing.canPublish) return null;
    return SharePayload(
      albumId: widget.album.id,
      memoryId: widget.memory.id,
      audience: audience,
      place: place,
      category: _draft.category,
      title: _content.title,
      photoPath: _content.photoPath,
      text: _sharedText,
    );
  }

  @override
  void initState() {
    super.initState();
    _text.addListener(() => _draft.text = _text.text);
    _loadService();
  }

  @override
  void dispose() {
    _leave?.cancel();
    _text.dispose();
    super.dispose();
  }

  Future<void> _loadService() async {
    setState(() {
      _audiences = null;
      _serviceFailed = false;
    });
    try {
      final (audiences, active) = await (
        widget.sharing.audiences(),
        widget.sharing.activePost(widget.memory.id),
      ).wait;
      if (!mounted) return;
      setState(() {
        _audiences = audiences;
        _active =
            active != null && active.isActive(DateTime.now()) ? active : null;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _audiences = const [];
          _serviceFailed = true;
        });
      }
    }
  }

  void _changed(VoidCallback change) => setState(() {
        change();
        _error = null;
      });

  Future<void> _pickPlace() async {
    final place = await widget.onPickPlace(_draft.place);
    if (!mounted || place == null) return;
    _changed(() => _draft.place = place);
  }

  void _addExcerpt() {
    final excerpt = _excerpt?.trim();
    if (excerpt == null || excerpt.isEmpty) return;
    final current = _text.text.trimRight();
    var next = current.isEmpty ? excerpt : '$current\n$excerpt';
    if (next.length > ShareMemorySheet.textMax) {
      next = next.substring(0, ShareMemorySheet.textMax);
    }
    _text.value = TextEditingValue(
        text: next, selection: TextSelection.collapsed(offset: next.length));
    _changed(() {});
  }

  /// Why the CTA is off, said next to it; null when it is on.
  String? get _blocker {
    final audiences = _audiences;
    if (audiences == null || _serviceFailed) return null;
    final sharing = widget.sharing;
    if (audiences.isEmpty) {
      return sharing is FriendsSharing
          ? ShareMemorySheet.friendsBlocker
          : ShareMemorySheet.noService;
    }
    final steps = [
      if (_audience == null)
        sharing is FriendsSharing
            ? ShareMemorySheet.needPeople
            : ShareMemorySheet.needAudience,
      if (_draft.place == null) ShareMemorySheet.needPlace,
      if (!_hasContent) ShareMemorySheet.needText,
    ];
    if (steps.isNotEmpty) return ShareMemorySheet.needs(steps);
    // Everything chosen, but the server cannot send it to friends yet.
    return sharing is FriendsSharing && !sharing.canPublish
        ? ShareMemorySheet.notDelivered
        : null;
  }

  Future<void> _publish() async {
    final payload = _payload;
    if (_busy || payload == null) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _publishing = true;
      _error = null;
    });
    String? error;
    try {
      // Locked since the sheet opened: never post from a locked album.
      final album = await widget.repository.album(widget.album.id);
      if (album == null || album.locked) {
        error = ShareMemorySheet.lockedNow;
      } else {
        final post =
            await widget.sharing.publish(payload, replacing: _active?.id);
        if (!mounted) return;
        MemoryShareDraft.discard(widget.memory.id);
        setState(() {
          _publishing = false;
          _post = post;
        });
        _leave = Timer(ShareMemorySheet.successHold, () {
          if (mounted) Navigator.of(context).pop(post);
        });
        return;
      }
    } on ShareUnavailable {
      error = ShareMemorySheet.unavailable;
    } catch (_) {
      error = ShareMemorySheet.failed;
    }
    if (mounted) {
      setState(() {
        _publishing = false;
        _failedOnce = true;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.viewInsetsOf(context).bottom;
    return PopScope(
      // Publishing, or published and about to go to the map.
      canPop: !_busy,
      child: Padding(
        padding: EdgeInsets.only(bottom: insets),
        // While busy, a drag on the sheet does not dismiss it.
        child: GestureDetector(
          onVerticalDragUpdate: _busy ? (_) {} : null,
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: .88,
            minChildSize: .5,
            maxChildSize: .95,
            builder: (context, scroll) => ListenableBuilder(
              listenable: AlbumUnlocks.instance,
              builder: (context, child) {
                // Hidden behind system overlays and in the app switcher, as
                // album screens are; the form stays mounted.
                final shown = AlbumUnlocks.instance.foreground;
                return Stack(fit: StackFit.expand, children: [
                  Offstage(
                      offstage: !shown,
                      child: TickerMode(enabled: shown, child: child!)),
                  if (!shown)
                    const Center(
                        child: Text(ShareMemorySheet.away,
                            style: AlbumFormText.body)),
                ]);
              },
              child: Column(children: [
                const _Grip(),
                _header(),
                Expanded(
                  child: _post == null
                      ? _form(scroll)
                      : _Published(post: _post!, replaced: _active != null),
                ),
                if (_post == null) _dock(context, insets),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() => Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl, 0, AppSpacing.sm, AppSpacing.xs),
        child: Row(children: [
          Expanded(
            // Large text: the title stays readable without taking the
            // room the form and the CTA need on a short screen.
            child: MediaQuery.withClampedTextScaling(
              maxScaleFactor: 1.5,
              child: Semantics(
                header: true,
                child: const Text(ShareMemorySheet.title,
                    style: AlbumFormText.title),
              ),
            ),
          ),
          IconButton(
            tooltip: ShareMemorySheet.closeTooltip,
            onPressed: _busy ? null : () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded, color: AppColors.textPrimary),
          ),
        ]),
      );

  Widget _form(ScrollController scroll) {
    final memoryPlace = _content.place;
    final place = _draft.place;
    final note = _content.hasNote ? _content.note! : null;
    return SingleChildScrollView(
      controller: scroll,
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl, AppSpacing.sm, AppSpacing.xl, AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AlbumFormSection(
            title: ShareMemorySheet.previewLabel,
            child: SharePreview(
              title: _content.title,
              photoPath: _content.photoPath,
              text: _sharedText,
              place: place,
              category: _draft.category,
            ),
          ),
          const SizedBox(height: 12),
          AlbumFormSection(
            title: ShareMemorySheet.audienceLabel,
            child: _audienceChoice(),
          ),
          const SizedBox(height: 12),
          AlbumFormSection(
            title: ShareMemorySheet.placeLabel,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  Icon(
                      place == null
                          ? Icons.location_off_outlined
                          : Icons.place_rounded,
                      size: 20,
                      color: AppColors.textPrimary),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(place?.label ?? ShareMemorySheet.placeNone,
                        style: place == null
                            ? AlbumFormText.body
                            : AlbumFormText.bodyStrong),
                  ),
                ]),
                const SizedBox(height: AppSpacing.xs),
                Text(
                    place != null && !place.named
                        ? ShareMemorySheet.placeUnnamed
                        : ShareMemorySheet.placeHelp,
                    style: AlbumFormText.note),
                if (memoryPlace != null && memoryPlace != place) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _busy
                          ? null
                          : () => _changed(() => _draft.place = memoryPlace),
                      icon: const Icon(Icons.check_circle_outline_rounded),
                      label: Text(
                          ShareMemorySheet.useMemoryPlace(memoryPlace.label)),
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _pickPlace,
                  icon: const Icon(Icons.map_outlined),
                  label: Text(place == null
                      ? ShareMemorySheet.pickPlace
                      : ShareMemorySheet.changePlace),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(color: AppColors.primary),
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AlbumFormSection(
            title: ShareMemorySheet.categoryLabel,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final category in ShareCategory.values)
                      ChoiceChip(
                        label: Text(category.label),
                        labelStyle: AlbumFormText.chip,
                        backgroundColor: AppColors.surface,
                        selectedColor: AppColors.primaryLight,
                        checkmarkColor: AppColors.textPrimary,
                        side: BorderSide(
                            color: _draft.category == category
                                ? AppColors.primary
                                : AppColors.border),
                        selected: _draft.category == category,
                        // Tapping the chosen one again: no category.
                        onSelected: _busy
                            ? null
                            : (on) => _changed(
                                () => _draft.category = on ? category : null),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                const Text(ShareMemorySheet.categoryHelp,
                    style: AlbumFormText.note),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AlbumFormSection(
            title: ShareMemorySheet.textLabel,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _text,
                  enabled: !_busy,
                  minLines: 2,
                  maxLines: 5,
                  maxLength: ShareMemorySheet.textMax,
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: (_) => _changed(() {}),
                  decoration: InputDecoration(
                    hintText: _content.photoPath == null || _needsText
                        ? ShareMemorySheet.textHintNote
                        : ShareMemorySheet.textHintPhoto,
                  ),
                ),
                if (note != null) ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _busy
                          ? null
                          : () => setState(() {
                                _showNote = !_showNote;
                                _excerpt = null;
                              }),
                      icon: Icon(_showNote
                          ? Icons.visibility_off_outlined
                          : Icons.format_quote_rounded),
                      label: Text(_showNote
                          ? ShareMemorySheet.noteHide
                          : ShareMemorySheet.notePick),
                    ),
                  ),
                  if (_showNote) _notePicker(note),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          const AlbumFormMessage(ShareMemorySheet.expiry,
              icon: Icons.schedule_rounded),
          if (_active case final active?) ...[
            const SizedBox(height: AppSpacing.sm),
            AlbumFormMessage(ShareMemorySheet.replaces(active.expiresAt),
                icon: Icons.swap_horiz_rounded),
          ],
          if (_bigText(context) && _error == null && _blocker != null) ...[
            const SizedBox(height: AppSpacing.md),
            _Hint(_blocker!),
          ],
        ],
      ),
    );
  }

  Widget _audienceChoice() {
    final audiences = _audiences;
    if (audiences == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Center(
            child: SizedBox.square(
                dimension: 24,
                child: CircularProgressIndicator(strokeWidth: 2.4))),
      );
    }
    if (_serviceFailed) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AlbumFormMessage(ShareMemorySheet.audienceFailed),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
                onPressed: _loadService,
                child: const Text(ShareMemorySheet.retryLabel)),
          ),
        ],
      );
    }
    final sharing = widget.sharing;
    if (sharing is FriendsSharing) {
      if (audiences.isEmpty) {
        // No friends on the app yet: where to go for them.
        return const AlbumFormMessage(ShareMemorySheet.friendsEmpty,
            icon: Icons.people_outline_rounded);
      }
      return _peoplePicker(sharing);
    }
    if (audiences.isEmpty) {
      // Who will see it once sign-in exists, shown but not selectable.
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Opacity(
            opacity: .6,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              minTileHeight: 48,
              enabled: false,
              leading: const Icon(Icons.radio_button_unchecked_rounded,
                  color: AppColors.textSecondary),
              title: const Text(ShareMemorySheet.friendsLabel,
                  style: AlbumFormText.bodyStrong),
              subtitle: const Text(ShareMemorySheet.friendsDetail,
                  style: AlbumFormText.note),
              trailing: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: AppSpacing.xs),
                decoration: const ShapeDecoration(
                    color: AppColors.primaryLight, shape: StadiumBorder()),
                child: Text(ShareMemorySheet.soonLabel,
                    style: AlbumFormText.note
                        .copyWith(color: AppColors.primaryAction)),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          const AlbumFormMessage(ShareMemorySheet.audienceNone,
              icon: Icons.people_outline_rounded),
        ],
      );
    }
    return Column(children: [
      for (final audience in audiences)
        _AudienceTile(
          audience: audience,
          selected: audience.id == _draft.audienceId,
          onTap: _busy
              ? null
              : () => _changed(() => _draft.audienceId = audience.id),
        ),
    ]);
  }

  /// Every friend on the app, each with a tick; all are ticked to start
  /// with.
  Widget _peoplePicker(FriendsSharing sharing) {
    final pickable = sharing.pickable;
    final picked = {for (final f in _picked(sharing)) f.id};
    final all = picked.length == pickable.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          Expanded(
            child: Text(ShareMemorySheet.picked(picked.length, pickable.length),
                style: AlbumFormText.bodyStrong),
          ),
          TextButton(
            onPressed: _busy ? null : () => _pick(all ? const [] : pickable),
            style: TextButton.styleFrom(
                foregroundColor: AppColors.primaryAction,
                minimumSize: const Size(48, 40)),
            child: Text(
                all ? ShareMemorySheet.pickNone : ShareMemorySheet.pickAll),
          ),
        ]),
        const Text(ShareMemorySheet.pickHelp, style: AlbumFormText.note),
        const SizedBox(height: AppSpacing.sm),
        for (final friend in pickable)
          CheckboxListTile(
            key: ValueKey('share-to-${friend.id}'),
            value: picked.contains(friend.id),
            onChanged: _busy
                ? null
                : (on) => _pick([
                      for (final f in pickable)
                        if (f.id == friend.id
                            ? on == true
                            : picked.contains(f.id))
                          f
                    ]),
            contentPadding: EdgeInsets.zero,
            activeColor: AppColors.primaryAction,
            controlAffinity: ListTileControlAffinity.trailing,
            secondary: FriendAvatar(friend, size: 40),
            title: Text(friend.name, style: AlbumFormText.body),
          ),
      ],
    );
  }

  Widget _notePicker(String note) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.lock_outline_rounded,
                  size: 16, color: AppColors.textPrimary),
              SizedBox(width: AppSpacing.xs),
              Expanded(
                  child: Text(ShareMemorySheet.notePrivate,
                      style: AlbumFormText.note)),
            ]),
            const SizedBox(height: AppSpacing.sm),
            SelectableText(
              note,
              style: AlbumFormText.body,
              onSelectionChanged: (selection, _) {
                final excerpt = selection.isCollapsed || !selection.isValid
                    ? null
                    : selection.textInside(note);
                if (excerpt != _excerpt) setState(() => _excerpt = excerpt);
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonalIcon(
                onPressed: (_excerpt ?? '').trim().isEmpty || _busy
                    ? null
                    : _addExcerpt,
                icon: const Icon(Icons.add_rounded),
                label: const Text(ShareMemorySheet.noteAdd),
              ),
            ),
          ],
        ),
      );

  Widget _dock(BuildContext context, double insets) {
    final blocker = _bigText(context) ? null : _blocker;
    final payload = _payload;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.sm,
          AppSpacing.xl,
          AppSpacing.md +
              (insets > 0 ? 0 : MediaQuery.paddingOf(context).bottom)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null || blocker != null) ...[
            // Scrolls on its own when large text makes it long, so the
            // form above keeps its room.
            ConstrainedBox(
              constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * .18),
              child: SingleChildScrollView(
                child: _error != null
                    ? AlbumFormMessage(_error!)
                    : _Hint(blocker!),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          // At most one and a half times: a docked CTA that grows to a
          // quarter of a short screen would leave no room for the form.
          MediaQuery.withClampedTextScaling(
            maxScaleFactor: 1.5,
            child: AlbumPrimaryButton(
              label: _failedOnce
                  ? ShareMemorySheet.retryLabel
                  : ShareMemorySheet.publishLabel,
              onPressed: payload == null ? null : _publish,
              busy: _publishing,
            ),
          ),
        ],
      ),
    );
  }
}

/// What is still missing before the CTA turns on.
class _Hint extends StatelessWidget {
  const _Hint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Semantics(
        liveRegion: true,
        child:
            Text(text, textAlign: TextAlign.center, style: AlbumFormText.note),
      );
}

/// The post as viewers will see it (A10's preview, A12's snapshot).
class SharePreview extends StatelessWidget {
  const SharePreview({
    super.key,
    required this.title,
    required this.photoPath,
    required this.text,
    required this.place,
    required this.category,
  });

  final String? title;
  final String? photoPath;
  final String? text;
  final MemoryPlace? place;
  final ShareCategory? category;

  @override
  Widget build(BuildContext context) {
    final title = this.title;
    final photo = photoPath;
    final text = this.text;
    final empty = photo == null && text == null;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.softAccent),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (photo != null) ...[
            Semantics(
              image: true,
              label: 'Ảnh sẽ được chia sẻ',
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 220),
                  child: Image.file(
                    File(photo),
                    fit: BoxFit.contain,
                    width: double.infinity,
                    errorBuilder: (_, __, ___) => const Padding(
                      padding: EdgeInsets.all(AppSpacing.md),
                      child: Row(children: [
                        Icon(Icons.broken_image_outlined,
                            color: AppColors.textPrimary),
                        SizedBox(width: AppSpacing.sm),
                        Expanded(
                            child: Text('Không mở được ảnh này để xem trước.',
                                style: AlbumFormText.body)),
                      ]),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (title != null) ...[
            Text(title, style: _Text.title),
            const SizedBox(height: AppSpacing.xs),
          ],
          if (text != null)
            Text(text, style: _Text.body)
          else if (empty)
            const Text(ShareMemorySheet.previewEmpty, style: _Text.empty),
          const SizedBox(height: 12),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _Tag(
                  icon: place == null
                      ? Icons.location_off_outlined
                      : Icons.place_outlined,
                  label: place?.label ?? ShareMemorySheet.placeNone),
              _Tag(
                  icon: Icons.sell_outlined,
                  label: category?.label ?? ShareCategory.uncategorized),
            ],
          ),
        ],
      ),
    );
  }
}

class _AudienceTile extends StatelessWidget {
  const _AudienceTile(
      {required this.audience, required this.selected, required this.onTap});

  final ShareAudience audience;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final detail = audience.detail;
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        minTileHeight: 48,
        selected: selected,
        selectedColor: AppColors.textPrimary,
        onTap: onTap,
        leading: Icon(
            selected
                ? Icons.radio_button_checked_rounded
                : Icons.radio_button_unchecked_rounded,
            color:
                selected ? AppColors.primaryAction : AppColors.textSecondary),
        title: Text(audience.label, style: AlbumFormText.bodyStrong),
        subtitle:
            detail == null ? null : Text(detail, style: AlbumFormText.note),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: const ShapeDecoration(
            color: AppColors.primaryLight, shape: StadiumBorder()),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: AppColors.textPrimary),
          const SizedBox(width: 6),
          Flexible(
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AlbumFormText.chip),
          ),
        ]),
      );
}

/// Success: a check (180 ms) and the server's expiry, then the map.
class _Published extends StatelessWidget {
  const _Published({required this.post, required this.replaced});

  final SharedMemoryPost post;
  final bool replaced;

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Semantics(
          liveRegion: true,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: reduced ? 1 : .6, end: 1),
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutBack,
              builder: (context, t, child) =>
                  Transform.scale(scale: t, child: child),
              child: const DecoratedBox(
                decoration: BoxDecoration(
                    color: AppColors.primaryAction, shape: BoxShape.circle),
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Icon(Icons.check_rounded,
                      size: 32, color: AppColors.surface),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
                replaced
                    ? ShareMemorySheet.replaced
                    : ShareMemorySheet.published,
                textAlign: TextAlign.center,
                style: AlbumFormText.section),
            const SizedBox(height: AppSpacing.xs),
            Text(ShareMemorySheet.expiresLabel(post.expiresAt),
                textAlign: TextAlign.center, style: AlbumFormText.body),
          ]),
        ),
      ),
    );
  }
}

class _Grip extends StatelessWidget {
  const _Grip();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: AppSpacing.sm),
        child: Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: AppColors.border,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );
}

abstract final class _Text {
  static const title = TextStyle(
    fontFamily: 'Nunito',
    fontSize: 18,
    fontWeight: FontWeight.w700,
    height: 1.3,
    color: AppColors.textPrimary,
  );
  static const body = TextStyle(
    fontFamily: 'BeVietnamPro',
    fontSize: 15,
    height: 1.5,
    color: AppColors.textPrimary,
  );
  static const empty = TextStyle(
    fontFamily: 'BeVietnamPro',
    fontSize: 14,
    fontStyle: FontStyle.italic,
    height: 20 / 14,
    color: AppColors.textSecondary,
  );
}
