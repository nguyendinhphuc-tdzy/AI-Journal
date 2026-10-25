import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../album_scope.dart';
import '../data/album.dart';
import '../data/album_repository.dart';
import '../data/memory.dart';
import 'album_backdrop.dart';
import 'album_form_parts.dart';
import 'memory_detail_screen.dart';

/// A09: an album's memories, as a scrapbook stack or a timeline.
///
/// - Back, the album name and its menu (A03). "Thêm kỷ niệm" (A06) docked
///   at the bottom.
/// - Stack: one card in front (photo, title, date, a 2–3 line excerpt;
///   note-only cards are text) and at most two behind it, of which only a
///   strip shows (thumbnail, title, date): never several notes on top of
///   each other. Dragging up or down on the stack more than 48 px moves to
///   the next or previous card (the card follows the finger, limited, no
///   3D turn) and snaps in 320 ms. "Trước" / "Sau" and "Xem tất cả" always do
///   the same without a gesture; at either end the button is disabled and
///   says so.
/// - "Xem tất cả": a static timeline by month, 20 at a time.
/// - Order: the memory's date, newest first, then creation time, then id
///   (from the repository, never the loading order).
/// - Back from A08 keeps the selected card, the mode and the scroll.
/// - Reduced motion: cards change at once.
class AlbumBrowseScreen extends StatefulWidget {
  const AlbumBrowseScreen({
    super.key,
    required this.album,
    required this.onOpen,
    required this.onAdd,
    required this.onSettings,
  });

  final Album album;

  /// A08 for a memory; completes when the user comes back.
  final Future<void> Function(Memory memory) onOpen;
  final VoidCallback onAdd;
  final VoidCallback onSettings;

  static const addLabel = 'Thêm kỷ niệm';
  static const seeAllLabel = 'Xem tất cả';
  static const stackLabel = 'Xếp chồng';
  static const previousLabel = 'Trước';
  static const nextLabel = 'Sau';
  static const firstNote = 'Đây là kỷ niệm mới nhất';
  static const lastNote = 'Đây là kỷ niệm cũ nhất';
  static const settingsTooltip = 'Cài đặt album';
  static const dragHint = 'Kéo lên hoặc xuống để xem';
  static const loadFailed = 'Chưa tải được kỷ niệm.';
  static const retryLabel = 'Thử lại';
  static const pageSize = 20;

  /// How far a drag must go to move to another card.
  static const dragThreshold = 48.0;

  static String countLabel(int n) => '$n kỷ niệm';
  static String position(int index, int total) => '${index + 1} / $total';
  static String month(DateTime d) => 'Tháng ${d.month}, ${d.year}';

  @override
  State<AlbumBrowseScreen> createState() => _AlbumBrowseScreenState();
}

class _AlbumBrowseScreenState extends State<AlbumBrowseScreen> {
  AlbumRepository? _repository;
  late Album _album = widget.album;
  List<Memory>? _memories;
  var _failed = false;

  /// The memory in front of the stack; kept by id across reloads.
  var _index = 0;
  String? _selectedId;
  var _list = false;
  var _shown = AlbumBrowseScreen.pageSize;
  final _listScroll = ScrollController();

  /// +1 moving to older memories, -1 to newer: the snap direction.
  var _direction = 1;
  var _drag = 0.0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final repository = AlbumScope.of(context);
    if (repository == _repository) return;
    _repository?.removeListener(_load);
    _repository = repository..addListener(_load);
    _load();
  }

  Future<void> _load() async {
    final repository = _repository!;
    try {
      final album = await repository.album(widget.album.id);
      final memories = await repository.memories(widget.album.id);
      if (!mounted) return;
      setState(() {
        if (album != null) _album = album;
        _memories = memories;
        _failed = false;
        // The same memory stays in front when it is still there.
        final at = memories.indexWhere((m) => m.id == _selectedId);
        _index =
            at >= 0 ? at : math.min(_index, math.max(0, memories.length - 1));
        _selectedId = memories.isEmpty ? null : memories[_index].id;
      });
    } catch (_) {
      // What was shown stays; a failed refresh is not an empty album.
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _repository?.removeListener(_load);
    _listScroll.dispose();
    super.dispose();
  }

  void _go(int delta) {
    final memories = _memories;
    if (memories == null) return;
    final next = _index + delta;
    if (next < 0 || next >= memories.length) return;
    setState(() {
      _direction = delta.sign;
      _index = next;
      _selectedId = memories[next].id;
      _drag = 0;
    });
  }

  void _dragUpdate(DragUpdateDetails details) =>
      setState(() => _drag = (_drag + details.delta.dy).clamp(-80.0, 80.0));

  void _dragEnd(DragEndDetails details) {
    final drag = _drag;
    if (drag <= -AlbumBrowseScreen.dragThreshold) {
      _go(1);
    } else if (drag >= AlbumBrowseScreen.dragThreshold) {
      _go(-1);
    }
    if (_drag != 0) setState(() => _drag = 0);
  }

  @override
  Widget build(BuildContext context) {
    final memories = _memories;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primaryLight,
        surfaceTintColor: Colors.transparent,
        title: Text(_album.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AlbumFormText.title),
        actions: [
          IconButton(
            tooltip: AlbumBrowseScreen.settingsTooltip,
            icon: const Icon(Icons.more_vert_rounded),
            onPressed: widget.onSettings,
          ),
        ],
      ),
      body: Stack(fit: StackFit.expand, children: [
        // Static: it never moves with the stack.
        const AlbumBackdrop(),
        Column(children: [
          Expanded(
            child: memories == null
                ? (_failed
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.xl),
                          child:
                              Column(mainAxisSize: MainAxisSize.min, children: [
                            const AlbumFormMessage(
                                AlbumBrowseScreen.loadFailed),
                            TextButton(
                                onPressed: _load,
                                child:
                                    const Text(AlbumBrowseScreen.retryLabel)),
                          ]),
                        ),
                      )
                    : const Center(child: CircularProgressIndicator()))
                : Column(children: [
                    _Header(
                      count: memories.length,
                      list: _list,
                      onToggle: () => setState(() => _list = !_list),
                    ),
                    Expanded(
                      child: memories.isEmpty
                          ? const SizedBox.shrink()
                          : _list
                              ? _Timeline(
                                  memories: memories,
                                  shown: _shown,
                                  controller: _listScroll,
                                  onMore: () => setState(() =>
                                      _shown += AlbumBrowseScreen.pageSize),
                                  onOpen: widget.onOpen,
                                )
                              : _StackView(
                                  memories: memories,
                                  index: _index,
                                  direction: _direction,
                                  drag: _drag,
                                  onOpen: widget.onOpen,
                                  onDragUpdate: _dragUpdate,
                                  onDragEnd: _dragEnd,
                                  onGo: _go,
                                ),
                    ),
                  ]),
          ),
          _Dock(onAdd: widget.onAdd),
        ]),
      ]),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(
      {required this.count, required this.list, required this.onToggle});

  final int count;
  final bool list;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    // A small still Nudaeng when there is room; never a large one.
    final room = MediaQuery.sizeOf(context).width >= 360 &&
        MediaQuery.textScalerOf(context).scale(16) <= 20;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.sm, AppSpacing.sm, 0),
      child: Row(children: [
        if (room) ...[
          ExcludeSemantics(
            child: SizedBox(
              height: 44,
              child: Image.asset(MemoryDetailScreen.savedFrames.last),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
        Expanded(
          child: Text(AlbumBrowseScreen.countLabel(count),
              style: AlbumFormText.bodyStrong),
        ),
        Flexible(
          child: TextButton(
            onPressed: onToggle,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primaryAction,
              minimumSize: const Size(48, 48),
              textStyle: AlbumFormText.bodyStrong,
            ),
            child: _IconLabel(
              icon: list ? Icons.layers_outlined : Icons.view_agenda_outlined,
              label: list
                  ? AlbumBrowseScreen.stackLabel
                  : AlbumBrowseScreen.seeAllLabel,
            ),
          ),
        ),
      ]),
    );
  }
}

class _StackView extends StatelessWidget {
  const _StackView({
    required this.memories,
    required this.index,
    required this.direction,
    required this.drag,
    required this.onOpen,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.onGo,
  });

  final List<Memory> memories;
  final int index;
  final int direction;
  final double drag;
  final Future<void> Function(Memory) onOpen;
  final GestureDragUpdateCallback onDragUpdate;
  final GestureDragEndCallback onDragEnd;
  final ValueChanged<int> onGo;

  /// How much of each card behind shows under the one in front.
  static const peek = 56.0;

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    final behind = [
      for (var k = 1; k <= 2 && index + k < memories.length; k++)
        memories[index + k],
    ];
    final atFirst = index == 0;
    final atLast = index == memories.length - 1;
    return LayoutBuilder(builder: (context, box) {
      const controls = 112.0;
      // Short screens and large text: the page scrolls instead.
      final cardHeight =
          math.max(280.0, box.maxHeight - controls - peek * 2 - AppSpacing.md);
      final stack = SizedBox(
        height: cardHeight + peek * behind.length,
        child: GestureDetector(
          key: const ValueKey('album-stack'),
          // Only on the stack; the buttons below do the same.
          onVerticalDragUpdate: onDragUpdate,
          onVerticalDragEnd: onDragEnd,
          child: Stack(clipBehavior: Clip.none, children: [
            for (var k = behind.length; k >= 1; k--)
              Positioned(
                left: 10.0 * k,
                right: 10.0 * k,
                top: 0,
                height: cardHeight + peek * k,
                child: _BehindCard(memory: behind[k - 1]),
              ),
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: cardHeight,
              child: TweenAnimationBuilder<double>(
                // Follows the finger while dragging; eases back (200 ms) when let go.
                tween: Tween(end: drag),
                duration: drag == 0 && !reduced
                    ? const Duration(milliseconds: 200)
                    : Duration.zero,
                curve: Curves.easeOut,
                builder: (context, dy, child) =>
                    Transform.translate(offset: Offset(0, dy), child: child),
                child: AnimatedSwitcher(
                  duration: reduced
                      ? Duration.zero
                      : const Duration(milliseconds: 320),
                  switchInCurve: Curves.easeOutCubic,
                  transitionBuilder: (child, animation) {
                    final incoming = child.key == ValueKey(memories[index].id);
                    final from = incoming ? .15 * direction : -.15 * direction;
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween(
                                begin: Offset(0, incoming ? from : 0),
                                end: Offset(0, incoming ? 0 : from))
                            .animate(animation),
                        child: child,
                      ),
                    );
                  },
                  child: _FrontCard(
                    key: ValueKey(memories[index].id),
                    memory: memories[index],
                    onOpen: () => onOpen(memories[index]),
                  ),
                ),
              ),
            ),
          ]),
        ),
      );
      final buttons = Padding(
        padding: const EdgeInsets.only(top: AppSpacing.md),
        child: Column(children: [
          Row(children: [
            Expanded(
              child: Semantics(
                hint: atFirst ? AlbumBrowseScreen.firstNote : null,
                child: OutlinedButton(
                  onPressed: atFirst ? null : () => onGo(-1),
                  style: _navStyle,
                  child: const _IconLabel(
                      icon: Icons.keyboard_arrow_up_rounded,
                      label: AlbumBrowseScreen.previousLabel),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              child: Text(AlbumBrowseScreen.position(index, memories.length),
                  style: AlbumFormText.bodyStrong),
            ),
            Expanded(
              child: Semantics(
                hint: atLast ? AlbumBrowseScreen.lastNote : null,
                child: OutlinedButton(
                  onPressed: atLast ? null : () => onGo(1),
                  style: _navStyle,
                  child: const _IconLabel(
                      icon: Icons.keyboard_arrow_down_rounded,
                      label: AlbumBrowseScreen.nextLabel),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 6),
          Text(
            atFirst && atLast
                ? AlbumBrowseScreen.firstNote
                : atFirst
                    ? '${AlbumBrowseScreen.firstNote} · ${AlbumBrowseScreen.dragHint}'
                    : atLast
                        ? '${AlbumBrowseScreen.lastNote} · ${AlbumBrowseScreen.dragHint}'
                        : AlbumBrowseScreen.dragHint,
            textAlign: TextAlign.center,
            style: AlbumFormText.note,
          ),
        ]),
      );
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.md),
        child: Column(children: [stack, buttons]),
      );
    });
  }

  static final _navStyle = OutlinedButton.styleFrom(
    foregroundColor: AppColors.textPrimary,
    side: const BorderSide(color: AppColors.primary),
    minimumSize: const Size(48, 48),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    textStyle: AlbumFormText.bodyStrong,
  );
}

/// The card in front: photo (or a text layout), title, date, a short excerpt.
class _FrontCard extends StatelessWidget {
  const _FrontCard({super.key, required this.memory, required this.onOpen});

  final Memory memory;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final content = memory.content;
    final photo = content.photoPath;
    final note = content.note;
    final title = content.title;
    return Semantics(
      button: true,
      label: [
        if (title != null) title,
        MemoryDetailScreen.formatDate(content.displayDate),
        if (note != null) note,
      ].join(', '),
      excludeSemantics: true,
      child: Material(
        color: AppColors.surface,
        elevation: 2,
        shadowColor: AppColors.textPrimary.withValues(alpha: .25),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.softAccent),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (photo != null)
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(File(photo),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                              color: AppColors.background,
                              child: const Icon(Icons.broken_image_outlined,
                                  color: AppColors.textPrimary))),
                    ),
                  )
                else
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Transform.rotate(
                      angle: -.06,
                      child: Container(
                          width: 56,
                          height: 14,
                          color: AppColors.softAccent.withValues(alpha: .7)),
                    ),
                  ),
                const SizedBox(height: 12),
                Row(children: [
                  if (title != null)
                    Expanded(
                      child: Text(title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _Text.cardTitle),
                    )
                  else
                    const Spacer(),
                  const SizedBox(width: AppSpacing.sm),
                  Text(MemoryDetailScreen.formatDate(content.displayDate),
                      style: AlbumFormText.note),
                ]),
                if (note != null) ...[
                  const SizedBox(height: 6),
                  if (photo == null)
                    // Note-only: the note on a ruled page.
                    Expanded(
                      child: CustomPaint(
                        painter: _Rules(
                            line: MediaQuery.textScalerOf(context)
                                    .scale(_Text.excerpt.fontSize!) *
                                _Text.excerpt.height!),
                        child: Text(note,
                            overflow: TextOverflow.fade, style: _Text.excerpt),
                      ),
                    )
                  else
                    Text(note,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: _Text.excerpt),
                ] else if (photo == null)
                  const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A card behind: only its bottom strip shows (thumbnail, title, date).
class _BehindCard extends StatelessWidget {
  const _BehindCard({required this.memory});

  final Memory memory;

  @override
  Widget build(BuildContext context) {
    final content = memory.content;
    final photo = content.photoPath;
    return ExcludeSemantics(
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        alignment: Alignment.bottomLeft,
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
        child: SizedBox(
          height: _StackView.peek - 14,
          child: Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox.square(
                dimension: 36,
                child: photo != null
                    ? Image.file(File(photo),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            const ColoredBox(color: AppColors.background))
                    : const ColoredBox(
                        color: AppColors.primaryLight,
                        child: Icon(Icons.notes_rounded,
                            size: 18, color: AppColors.textPrimary)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(content.title ?? 'Kỷ niệm',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AlbumFormText.bodyStrong),
            ),
            Text(MemoryDetailScreen.formatDate(content.displayDate),
                style: AlbumFormText.note),
          ]),
        ),
      ),
    );
  }
}

/// "Xem tất cả": static cards by month, newest first, 20 at a time.
class _Timeline extends StatelessWidget {
  const _Timeline({
    required this.memories,
    required this.shown,
    required this.controller,
    required this.onMore,
    required this.onOpen,
  });

  final List<Memory> memories;
  final int shown;
  final ScrollController controller;
  final VoidCallback onMore;
  final Future<void> Function(Memory) onOpen;

  @override
  Widget build(BuildContext context) {
    final visible = memories.take(shown).toList();
    final more = memories.length > visible.length;
    // Month headers between items.
    final rows = <Object>[];
    String? month;
    for (final memory in visible) {
      final label = AlbumBrowseScreen.month(memory.content.displayDate);
      if (label != month) rows.add(month = label);
      rows.add(memory);
    }
    return ListView.builder(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.md),
      itemCount: rows.length + (more ? 1 : 0),
      itemBuilder: (context, i) {
        if (i == rows.length) {
          return Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: TextButton(
              onPressed: onMore,
              style: TextButton.styleFrom(
                  foregroundColor: AppColors.primaryAction,
                  minimumSize: const Size.fromHeight(48)),
              child: const Text('Xem thêm kỷ niệm'),
            ),
          );
        }
        final row = rows[i];
        if (row is String) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
            child: Semantics(
                header: true, child: Text(row, style: AlbumFormText.section)),
          );
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: _Row(memory: row as Memory, onOpen: () => onOpen(row)),
        );
      },
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.memory, required this.onOpen});

  final Memory memory;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final content = memory.content;
    final photo = content.photoPath;
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox.square(
                dimension: 64,
                child: photo != null
                    ? Image.file(File(photo),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            const ColoredBox(color: AppColors.background))
                    : const ColoredBox(
                        color: AppColors.primaryLight,
                        child: Icon(Icons.notes_rounded,
                            color: AppColors.textPrimary)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(MemoryDetailScreen.formatDate(content.displayDate),
                      style: AlbumFormText.note),
                  if (content.title case final title?)
                    Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AlbumFormText.section),
                  if (content.note case final note?)
                    Text(note,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AlbumFormText.body),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Faint ruled lines under a note, one per line of text.
class _Rules extends CustomPainter {
  const _Rules({required this.line});

  final double line;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.border.withValues(alpha: .7)
      ..strokeWidth = 1;
    for (var y = line - 2; y < size.height; y += line) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_Rules old) => old.line != line;
}

/// Icon and label that shrinks (ellipsis) instead of overflowing.
class _IconLabel extends StatelessWidget {
  const _IconLabel({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 18),
        const SizedBox(width: 6),
        Flexible(
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis)),
      ]);
}

class _Dock extends StatelessWidget {
  const _Dock({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.md + MediaQuery.paddingOf(context).bottom),
        decoration: const BoxDecoration(
          color: AppColors.background,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: AlbumPrimaryButton(
          label: AlbumBrowseScreen.addLabel,
          onPressed: onAdd,
        ),
      );
}

abstract final class _Text {
  static const cardTitle = TextStyle(
    fontFamily: 'Nunito',
    fontSize: 20,
    fontWeight: FontWeight.w700,
    height: 1.3,
    color: AppColors.textPrimary,
  );
  static const excerpt = TextStyle(
    fontFamily: 'BeVietnamPro',
    fontSize: 15,
    height: 1.5,
    color: AppColors.textPrimary,
  );
}
