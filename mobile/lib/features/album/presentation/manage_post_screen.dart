import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../album_scope.dart';
import '../data/album.dart';
import '../data/memory.dart';
import '../data/memory_share.dart';
import 'album_backdrop.dart';
import 'album_form_parts.dart';
import 'confirm_delete_dialog.dart';
import 'memory_detail_screen.dart';
import 'share_memory_sheet.dart';

/// A12: one 24-hour post of a memory.
///
/// - The snapshot as posted (A10's preview), who sees it, the place, the
///   state (Đang chia sẻ / Đã hết hạn / Đã gỡ khỏi bản đồ) as text and icon,
///   and when it ends or ended; no countdown, no pulse, no mascot.
/// - The state is the server's: fetched on open, when the app comes back
///   and once at the expiry time; the device clock alone never decides it.
/// - Active: "Gỡ khỏi bản đồ" (confirmed first) takes it off the map; the
///   memory and its private place stay. Success returns to the source with
///   true. Expired or revoked: "Chia sẻ lại" opens A10 (nothing is posted
///   until its CTA).
/// - "Về kỷ niệm gốc" goes to the memory (A08, through the album guard).
class ManagePostScreen extends StatefulWidget {
  const ManagePostScreen({
    super.key,
    required this.album,
    required this.post,
    required this.onOpenMemory,
    required this.onShareAgain,
  });

  final Album album;

  /// The post as last known; refreshed from the server here.
  final SharedMemoryPost post;
  final VoidCallback onOpenMemory;

  /// A10 for [memory]; completes when the sheet is gone.
  final Future<void> Function(Memory memory) onShareAgain;

  static const title = 'Bài chia sẻ';
  static const activeLabel = 'Đang chia sẻ';
  static const expiredLabel = 'Đã hết hạn';
  static const revokedLabel = 'Đã gỡ khỏi bản đồ';
  static const goneLabel = 'Không còn trên bản đồ';
  static String activeUntil(DateTime at) =>
      'Hết hạn lúc ${ShareMemorySheet.formatTime(at)}';
  static String expiredAt(DateTime at) =>
      'Đã hết hạn lúc ${ShareMemorySheet.formatTime(at)}';
  static String revokedAt(DateTime at) =>
      'Đã gỡ lúc ${ShareMemorySheet.formatTime(at)}';
  static const activeHelp =
      'Người xem thấy bài này trên bản đồ đến khi hết hạn. Kỷ niệm gốc vẫn '
      'ở Album.';
  static const endedHelp =
      'Người khác không còn thấy bài này. Kỷ niệm gốc vẫn ở Album.';
  static const snapshotLabel = 'Nội dung đã chia sẻ';
  static const audienceLabel = 'Người xem';
  static const placeLabel = 'Địa điểm';
  static const refreshFailed =
      'Chưa cập nhật được trạng thái mới nhất. Đang hiện lần cập nhật trước.';
  static const retryLabel = 'Thử lại';
  static const revokeLabel = 'Gỡ khỏi bản đồ';
  static const revokeTitle = 'Gỡ bài khỏi bản đồ?';
  static const revokeBody =
      'Người xem sẽ không còn thấy bài này. Kỷ niệm, ảnh và địa điểm riêng '
      'của bạn vẫn còn trong Album.';
  static const revokeFailed =
      'Chưa gỡ được bài. Bài vẫn đang hiện trên bản đồ, bạn thử lại nhé.';
  static const shareAgainLabel = 'Chia sẻ lại';
  static const memoryLabel = 'Về kỷ niệm gốc';
  static const memoryGone = 'Kỷ niệm gốc không còn trong Album.';

  @override
  State<ManagePostScreen> createState() => _ManagePostScreenState();
}

class _ManagePostScreenState extends State<ManagePostScreen>
    with WidgetsBindingObserver {
  late SharedMemoryPost _post = widget.post;

  /// The server no longer knows the post.
  var _gone = false;
  var _refreshing = false;
  var _refreshFailed = false;
  Timer? _atExpiry;

  /// Null while loading; false when the memory was deleted.
  bool? _memoryThere;
  Memory? _memory;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scheduleExpiry();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_memoryThere == null && !_refreshing) {
      _refresh();
      _loadMemory();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _atExpiry?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  PostState get _state =>
      _gone ? PostState.revoked : _post.stateAt(DateTime.now());

  /// One timer at the expiry time, to ask the server; nothing ticks.
  void _scheduleExpiry() {
    _atExpiry?.cancel();
    final left = _post.expiresAt.difference(DateTime.now());
    if (_post.revokedAt != null || left.isNegative) return;
    _atExpiry = Timer(left + const Duration(seconds: 1), _refresh);
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      final latest = await AlbumScope.memorySharingOf(context).post(_post.id);
      if (!mounted) return;
      setState(() {
        if (latest == null) {
          _gone = true;
        } else {
          _post = latest;
        }
        _refreshFailed = false;
      });
      _scheduleExpiry();
    } catch (_) {
      if (mounted) setState(() => _refreshFailed = true);
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _loadMemory() async {
    try {
      final memory =
          await AlbumScope.of(context).memory(widget.album.id, _post.memoryId);
      if (!mounted) return;
      setState(() {
        _memory = memory;
        _memoryThere = memory != null;
      });
    } catch (_) {
      if (mounted) setState(() => _memoryThere = false);
    }
  }

  Future<void> _revoke() async {
    final sharing = AlbumScope.memorySharingOf(context);
    SharedMemoryPost? revoked;
    final done = await ConfirmDeleteDialog.show(
      context,
      title: ManagePostScreen.revokeTitle,
      body: ManagePostScreen.revokeBody,
      confirmLabel: ManagePostScreen.revokeLabel,
      failed: ManagePostScreen.revokeFailed,
      onConfirm: () async => revoked = await sharing.revoke(_post.id),
    );
    if (!done || !mounted) return;
    setState(() => _post = revoked ?? _post);
    Navigator.of(context).pop(true);
  }

  Future<void> _shareAgain() async {
    final memory = _memory;
    if (memory == null) return;
    await widget.onShareAgain(memory);
    if (mounted) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final state = _state;
    final payload = _post.payload;
    final audienceDetail = payload.audience.detail;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primaryLight,
        surfaceTintColor: Colors.transparent,
        title: const Text(ManagePostScreen.title, style: AlbumFormText.title),
      ),
      body: Stack(fit: StackFit.expand, children: [
        const AlbumBackdrop(),
        SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.xl),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Status(state: state, post: _post, gone: _gone),
                  if (_refreshFailed) ...[
                    const SizedBox(height: AppSpacing.sm),
                    const AlbumFormMessage(ManagePostScreen.refreshFailed),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                          onPressed: _refreshing ? null : _refresh,
                          child: const Text(ManagePostScreen.retryLabel)),
                    ),
                  ],
                  const SizedBox(height: 12),
                  AlbumFormSection(
                    title: ManagePostScreen.snapshotLabel,
                    child: SharePreview(
                      title: payload.title,
                      photoPath: payload.photoPath,
                      text: payload.text,
                      place: payload.place,
                      category: payload.category,
                    ),
                  ),
                  const SizedBox(height: 12),
                  AlbumFormSection(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _Row(
                          icon: Icons.group_outlined,
                          label: ManagePostScreen.audienceLabel,
                          value: audienceDetail == null
                              ? payload.audience.label
                              : '${payload.audience.label} · $audienceDetail',
                        ),
                        const SizedBox(height: 12),
                        _Row(
                          icon: Icons.place_outlined,
                          label: ManagePostScreen.placeLabel,
                          value: payload.place.label,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  if (state == PostState.active)
                    _RevokeButton(onPressed: _revoke)
                  else if (widget.album.locked)
                    const AlbumFormMessage(MemoryDetailScreen.lockedShare,
                        icon: Icons.lock_outline_rounded)
                  else if (_memoryThere == true)
                    AlbumPrimaryButton(
                      label: ManagePostScreen.shareAgainLabel,
                      onPressed: _shareAgain,
                    ),
                  const SizedBox(height: AppSpacing.sm),
                  if (_memoryThere == false)
                    const AlbumFormMessage(ManagePostScreen.memoryGone)
                  else
                    TextButton.icon(
                      onPressed:
                          _memoryThere == true ? widget.onOpenMemory : null,
                      icon: const Icon(Icons.photo_album_outlined),
                      label: const Text(ManagePostScreen.memoryLabel),
                      style: TextButton.styleFrom(
                          foregroundColor: AppColors.textPrimary,
                          minimumSize: const Size.fromHeight(48)),
                    ),
                ],
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

/// The state in words with an icon, and when it ends or ended.
class _Status extends StatelessWidget {
  const _Status({required this.state, required this.post, required this.gone});

  final PostState state;
  final SharedMemoryPost post;
  final bool gone;

  @override
  Widget build(BuildContext context) {
    final (icon, label, time, help) = switch (state) {
      PostState.active => (
          Icons.public_rounded,
          ManagePostScreen.activeLabel,
          ManagePostScreen.activeUntil(post.expiresAt),
          ManagePostScreen.activeHelp,
        ),
      PostState.expired => (
          Icons.timer_off_outlined,
          ManagePostScreen.expiredLabel,
          ManagePostScreen.expiredAt(post.expiresAt),
          ManagePostScreen.endedHelp,
        ),
      PostState.revoked => (
          Icons.public_off_rounded,
          gone ? ManagePostScreen.goneLabel : ManagePostScreen.revokedLabel,
          post.revokedAt == null
              ? null
              : ManagePostScreen.revokedAt(post.revokedAt!),
          ManagePostScreen.endedHelp,
        ),
    };
    return Semantics(
      liveRegion: true,
      child: AlbumFormSection(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: ShapeDecoration(
                color: state == PostState.active
                    ? AppColors.primaryLight
                    : AppColors.background,
                shape: const StadiumBorder(
                    side: BorderSide(color: AppColors.border)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(icon, size: 18, color: AppColors.textPrimary),
                const SizedBox(width: 6),
                Flexible(child: Text(label, style: AlbumFormText.chip)),
              ]),
            ),
            if (time != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(time, style: AlbumFormText.bodyStrong),
            ],
            const SizedBox(height: AppSpacing.xs),
            Text(help, style: AlbumFormText.body),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.textPrimary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AlbumFormText.note),
                Text(value, style: AlbumFormText.bodyStrong),
              ],
            ),
          ),
        ],
      );
}

/// Destructive, in the theme's error colour; not the primary.
class _RevokeButton extends StatelessWidget {
  const _RevokeButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final destructive = Theme.of(context).colorScheme.error;
    return OutlinedButton.icon(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: destructive,
        side: BorderSide(color: destructive.withValues(alpha: .5)),
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        textStyle: AlbumFormText.section,
      ),
      icon: const Icon(Icons.public_off_rounded),
      label: const Text(ManagePostScreen.revokeLabel),
    );
  }
}
