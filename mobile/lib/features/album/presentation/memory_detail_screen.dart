import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/widgets/app_delete_dialog.dart';
import '../../../core/widgets/app_ui.dart';
import '../../onboarding/presentation/frame_sequence.dart';
import '../album_scope.dart';
import '../data/album.dart';
import '../data/album_repository.dart';
import '../data/memory.dart';
import '../data/memory_share.dart';
import 'album_backdrop.dart';
import 'album_form_parts.dart';

/// A08: one memory on a sheet of paper over the Album scene.
///
/// - Back and a "More" sheet (Sửa, Chia sẻ, Xóa). Title when there is one (display
///   font), the date as a chip, the photo whole (its own proportions, never
///   cropped, never anything drawn over it), the note in the body font, the
///   place as a chip (E04), and "Chia sẻ trong 24 giờ" (A10) unless the album
///   is locked, which says why instead.
/// - Note-only memories get a text layout with a small tape strip, never a
///   stand-in photo.
/// - The page scrolls; long notes are never squeezed into a fixed card.
/// - ND11 (Nudaeng hugging a book, 80 dp, in the header corner outside the
///   reading card) plays once (about 1.6 s) only right after a save; reopening
///   shows it still. Card entrance 320 ms; reduced motion: a fade.
class MemoryDetailScreen extends StatefulWidget {
  const MemoryDetailScreen({
    super.key,
    required this.album,
    required this.memoryId,
    this.justSaved = false,
    required this.onEdit,
    required this.onDelete,
    required this.onShare,
    required this.onPlace,
    this.onManagePost,
  });

  final Album album;
  final String memoryId;

  /// Opened right after a save (A06): ND11 plays once.
  final bool justSaved;

  /// A06 for this memory; completes when the editor is gone.
  final Future<void> Function() onEdit;

  /// A11; true once deleted: the page fades out (180 ms) and closes.
  final Future<bool> Function(Memory memory) onDelete;

  /// A12 for the memory's active post; true once taken off the map.
  final Future<bool> Function(SharedMemoryPost post)? onManagePost;

  /// A10 for the memory as shown.
  final ValueChanged<Memory> onShare;
  final ValueChanged<MemoryPlace> onPlace;

  static const moreTooltip = 'Tùy chọn kỷ niệm';
  static const editLabel = 'Sửa kỷ niệm';
  static const deleteLabel = 'Xóa kỷ niệm';
  static const shareLabel = 'Chia sẻ trong 24 giờ';
  static const lockedShare =
      'Album đang khóa nên kỷ niệm này không chia sẻ được. Tắt khóa trong '
      'Cài đặt album nếu muốn chia sẻ.';
  static const lockedShareShort =
      'Album đang khóa. Tắt khóa trong Cài đặt album để chia sẻ.';
  static const gone = 'Kỷ niệm này không còn nữa.';
  static String sharedUntil(DateTime at) {
    final t = at.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return 'Đang chia sẻ đến ${two(t.hour)}:${two(t.minute)}, '
        '${formatDate(t)}';
  }

  static const manageLabel = 'Quản lý bài chia sẻ';
  static const revoked = 'Đã gỡ bài khỏi bản đồ. Kỷ niệm vẫn ở Album.';
  static const loadFailed = 'Chưa tải được kỷ niệm.';
  static const photoFailed = 'Không mở được ảnh này. Ghi chú vẫn ở dưới.';

  static final savedFrames = [
    for (var i = 1; i <= 9; i++)
      'assets/Deimage/album-saved-frame-${i.toString().padLeft(2, '0')}.png',
  ];

  /// The GIF's own pace: 9 × 180 ms ≈ 1.6 s.
  static final savedDurations = [
    for (var i = 0; i < 9; i++) const Duration(milliseconds: 180),
  ];

  static String formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  State<MemoryDetailScreen> createState() => _MemoryDetailScreenState();
}

class _MemoryDetailScreenState extends State<MemoryDetailScreen>
    with WidgetsBindingObserver {
  AlbumRepository? _repository;
  Memory? _memory;
  var _loading = true;
  var _failed = false;

  /// The memory's 24-hour post while it is on the map.
  SharedMemoryPost? _active;

  /// Deleting: what is shown stays until it fades out; deleted: fading.
  var _deleting = false;
  var _deleted = false;
  Timer? _leave;

  /// ND11 runs: one per successful save shown here.
  late var _celebrate = widget.justSaved ? 1 : 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final repository = AlbumScope.of(context);
    if (repository == _repository) return;
    _repository?.removeListener(_load);
    _repository = repository..addListener(_load);
    _load();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  /// Back in the app: the post may have expired meanwhile (server's word).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _loadPost();
  }

  Future<void> _loadPost() async {
    SharedMemoryPost? active;
    try {
      active =
          await AlbumScope.memorySharingOf(context).activePost(widget.memoryId);
    } catch (_) {
      // Unknown: say nothing rather than a state that may be wrong.
    }
    if (!mounted) return;
    final shown =
        active != null && active.isActive(DateTime.now()) ? active : null;
    if (shown?.id != _active?.id) setState(() => _active = shown);
  }

  Future<void> _delete() async {
    final memory = _memory;
    if (memory == null) return;
    _deleting = true;
    final deleted = await widget.onDelete(memory);
    if (!mounted) return;
    if (!deleted) {
      _deleting = false;
      _load();
      return;
    }
    // Committed: only now does it leave the screen.
    setState(() => _deleted = true);
    _leave = Timer(
        MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 180), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  Future<void> _manage(SharedMemoryPost post) async {
    final revoked = await widget.onManagePost?.call(post) ?? false;
    if (!mounted) return;
    await _loadPost();
    if (revoked && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(MemoryDetailScreen.revoked)));
    }
  }

  Future<void> _load() async {
    if (_deleting) return;
    _loadPost();
    try {
      final memory =
          await _repository!.memory(widget.album.id, widget.memoryId);
      if (!mounted || _deleting) return;
      setState(() {
        _memory = memory;
        _loading = false;
        _failed = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _leave?.cancel();
    _repository?.removeListener(_load);
    super.dispose();
  }

  Future<void> _edit() async {
    final before = _memory?.updatedAt;
    await widget.onEdit();
    if (!mounted) return;
    await _load();
    // Saved in the editor: Nudaeng hugs the book once more.
    if (mounted && _memory != null && _memory!.updatedAt != before) {
      setState(() => _celebrate++);
    }
  }

  /// Sửa, Chia sẻ, Xóa in the app's sheet, as the photo's options. In a
  /// locked album sharing is shown off, saying why.
  Future<void> _options(Memory memory) async {
    final active = _active;
    final locked = widget.album.locked;
    final choice = await showAppSheet<String>(
      context,
      builder: (sheet) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(MemoryDetailScreen.moreTooltip,
              style: AppText.sectionTitle),
          const SizedBox(height: AppSpacing.md),
          AlbumSheetAction(
            icon: Icons.edit_outlined,
            label: MemoryDetailScreen.editLabel,
            onTap: () => Navigator.pop(sheet, 'edit'),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (active != null && widget.onManagePost != null)
            AlbumSheetAction(
              icon: Icons.public_rounded,
              label: MemoryDetailScreen.manageLabel,
              note: MemoryDetailScreen.sharedUntil(active.expiresAt),
              onTap: () => Navigator.pop(sheet, 'manage'),
            )
          else
            AlbumSheetAction(
              icon: Icons.share_location_outlined,
              label: MemoryDetailScreen.shareLabel,
              note: locked ? MemoryDetailScreen.lockedShareShort : null,
              onTap: locked ? null : () => Navigator.pop(sheet, 'share'),
            ),
          const SizedBox(height: AppSpacing.sm),
          AlbumSheetAction(
            icon: Icons.delete_outline_rounded,
            label: MemoryDetailScreen.deleteLabel,
            color: AppDeleteDialog.destructive,
            onTap: () => Navigator.pop(sheet, 'delete'),
          ),
        ],
      ),
    );
    if (!mounted || _deleted) return;
    switch (choice) {
      case 'edit':
        _edit();
      case 'share':
        widget.onShare(memory);
      case 'manage':
        if (active != null) _manage(active);
      case 'delete':
        _delete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final memory = _memory;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primaryLight,
        surfaceTintColor: Colors.transparent,
        title: Text(widget.album.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AlbumFormText.title),
        actions: [
          if (memory != null)
            IconButton(
              tooltip: MemoryDetailScreen.moreTooltip,
              icon: const Icon(Icons.more_vert_rounded),
              onPressed: _deleted ? null : () => _options(memory),
            ),
        ],
      ),
      body: Stack(fit: StackFit.expand, children: [
        const AlbumBackdrop(),
        if (_loading)
          const Center(child: CircularProgressIndicator())
        else if (memory == null)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: AlbumFormMessage(_failed
                  ? MemoryDetailScreen.loadFailed
                  : MemoryDetailScreen.gone),
            ),
          )
        else
          AnimatedOpacity(
            opacity: _deleted ? 0 : 1,
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 180),
            child: IgnorePointer(
              ignoring: _deleted,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.xl),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ND11 outside the reading card, header corner.
                        Align(
                          alignment: Alignment.centerRight,
                          child: _Nudaeng(run: _celebrate),
                        ),
                        _Entrance(
                          child: _Page(
                            memory: memory,
                            locked: widget.album.locked,
                            active: _active,
                            onShare: widget.onShare,
                            onPlace: widget.onPlace,
                            onManage:
                                widget.onManagePost == null ? null : _manage,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ]),
    );
  }
}

/// Paper rising into place (320 ms); reduced motion: a fade.
class _Entrance extends StatelessWidget {
  const _Entrance({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: reduced
            ? child
            : Transform.translate(
                offset: Offset(0, 16 * (1 - t)), child: child),
      ),
      child: child,
    );
  }
}

/// ND11: still pose (hugging the book); after a save, the 1.6 s sequence once.
class _Nudaeng extends StatelessWidget {
  const _Nudaeng({required this.run});

  /// Bumped for each save to celebrate; 0 shows the still pose.
  final int run;

  static const size = 88.0;

  @override
  Widget build(BuildContext context) {
    final still = run == 0 || MediaQuery.disableAnimationsOf(context);
    return ExcludeSemantics(
      child: SizedBox(
        width: size * 344 / 355,
        height: size,
        child: still
            ? Image.asset(MemoryDetailScreen.savedFrames.last)
            : FrameSequence(
                key: ValueKey(run),
                frames: MemoryDetailScreen.savedFrames,
                durations: MemoryDetailScreen.savedDurations,
              ),
      ),
    );
  }
}

class _Page extends StatelessWidget {
  const _Page({
    required this.memory,
    required this.locked,
    required this.active,
    required this.onShare,
    required this.onPlace,
    required this.onManage,
  });

  final Memory memory;
  final bool locked;
  final SharedMemoryPost? active;
  final ValueChanged<Memory> onShare;
  final ValueChanged<MemoryPlace> onPlace;
  final ValueChanged<SharedMemoryPost>? onManage;

  @override
  Widget build(BuildContext context) {
    final content = memory.content;
    final title = content.title;
    final photo = content.photoPath;
    final note = content.note;
    final place = content.place;
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.softAccent),
      ),
      child: Stack(clipBehavior: Clip.none, children: [
        // Note-only: a small strip of tape on the paper, nothing pretending
        // to be a photo.
        if (photo == null)
          Positioned(
            top: -8,
            left: 28,
            child: Transform.rotate(
              angle: -.08,
              child: Container(
                  width: 64,
                  height: 18,
                  color: AppColors.softAccent.withValues(alpha: .7)),
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  _Chip(
                      icon: Icons.calendar_today_outlined,
                      label:
                          MemoryDetailScreen.formatDate(content.displayDate)),
                  if (place != null)
                    _Chip(
                        icon: Icons.place_outlined,
                        label: place.label,
                        onTap: () => onPlace(place)),
                ],
              ),
              if (title != null) ...[
                const SizedBox(height: 12),
                Semantics(header: true, child: Text(title, style: _Text.title)),
              ],
              if (photo != null) ...[
                const SizedBox(height: AppSpacing.md),
                _Photo(path: photo),
              ],
              if (note != null) ...[
                SizedBox(height: photo == null ? 12 : AppSpacing.md),
                SelectableText(note, style: _Text.note),
              ],
              const SizedBox(height: AppSpacing.xl),
              if (active case final post?) ...[
                _SharedStatus(post: post, onManage: onManage),
                const SizedBox(height: 12),
              ],
              if (locked)
                const AlbumFormMessage(MemoryDetailScreen.lockedShare,
                    icon: Icons.lock_outline_rounded)
              else
                OutlinedButton.icon(
                  onPressed: () => onShare(memory),
                  icon: const Icon(Icons.share_location_outlined),
                  label: const Text(MemoryDetailScreen.shareLabel),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(color: AppColors.primary),
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(26)),
                    textStyle: AlbumFormText.button,
                  ),
                ),
            ],
          ),
        ),
      ]),
    );
  }
}

/// The post on the map: until when (text and icon, no countdown) and A12.
class _SharedStatus extends StatelessWidget {
  const _SharedStatus({required this.post, required this.onManage});

  final SharedMemoryPost post;
  final ValueChanged<SharedMemoryPost>? onManage;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
        decoration: BoxDecoration(
          color: AppColors.primaryLight,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.public_rounded,
                  size: 20, color: AppColors.textPrimary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(MemoryDetailScreen.sharedUntil(post.expiresAt),
                    style: AlbumFormText.bodyStrong),
              ),
            ]),
            if (onManage case final manage?)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => manage(post),
                  style: TextButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      minimumSize: const Size(48, 48)),
                  child: const Text(MemoryDetailScreen.manageLabel),
                ),
              )
            else
              const SizedBox(height: 6),
          ],
        ),
      );
}

/// The photo whole, at its own proportions (never cropped); very tall photos
/// are fitted inside a cap instead of filling the screen.
class _Photo extends StatelessWidget {
  const _Photo({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    final cap = MediaQuery.sizeOf(context).height * .7;
    return Semantics(
      image: true,
      label: 'Ảnh của kỷ niệm',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: cap),
          child: Image.file(
            File(path),
            fit: BoxFit.contain,
            width: double.infinity,
            errorBuilder: (_, __, ___) => Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              color: AppColors.background,
              child: const Row(children: [
                Icon(Icons.broken_image_outlined, color: AppColors.textPrimary),
                SizedBox(width: AppSpacing.sm),
                Expanded(
                    child: Text(MemoryDetailScreen.photoFailed,
                        style: AlbumFormText.body)),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: AppColors.primaryLight,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 36),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(icon, size: 16, color: AppColors.textPrimary),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AlbumFormText.bodyStrong),
                ),
              ]),
            ),
          ),
        ),
      );
}

abstract final class _Text {
  static const title = TextStyle(
    fontFamily: 'Nunito',
    fontSize: 24,
    fontWeight: FontWeight.w700,
    height: 1.3,
    color: AppColors.textPrimary,
  );
  static const note = TextStyle(
    fontFamily: 'BeVietnamPro',
    fontSize: 16,
    height: 1.5,
    color: AppColors.textPrimary,
  );
}
