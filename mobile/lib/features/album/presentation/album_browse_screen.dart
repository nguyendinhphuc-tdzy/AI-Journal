import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_ui.dart';
import '../../sound/app_sound.dart';
import '../album_scope.dart';
import '../data/album.dart';
import '../data/album_repository.dart';
import '../data/memory.dart';
import 'album_backdrop.dart';
import 'album_form_parts.dart';
import 'memory_detail_screen.dart';

/// A09: an album's memories as a pile of photos on a table, or all of them
/// as a grid.
///
/// - Back, the album name and its menu (A03). "+ Thêm kỷ niệm" (A06) docked
///   at the bottom; the pile ends above it, never under it.
/// - Each memory on ivory paper (date small on top, the photo at its own
///   proportions with a height cap so the title and note always show, then
///   title and a few lines of note, left aligned). Note-only memories are a
///   compact text card. No border, one strip of tape at the top and one
///   small sticker in a corner, never over the content.
/// - The pile: the memory shown on top, the next two under it, each a little
///   off and turned (the same way for a memory each time), so there is no
///   gap between them and it is clear there are more.
/// - Pick up the top photo and drag it anywhere: it follows the finger,
///   turning with where it was gripped, and lifts (a larger, softer shadow).
///   Let go far enough (30 % of its width) or throw it: it flies off,
///   turning over to show the back of the paper, and the ones under it move
///   up. Otherwise it settles back. Pull down instead to bring the previous
///   photo back: it comes down face down and turns over as it lands. The
///   last photo (nothing under it) and a pull down on the first only give a
///   little. Each turn rustles (the interface's page-turn sound, off with the
///   sound settings) with a light tap of the phone, once, on letting go.
///   Reduced motion: no flying or turning over. Screen readers get "Kỷ niệm
///   tiếp theo" / "Kỷ niệm trước" actions. Only a small "02 / 03" under it.
/// - "Xem tất cả": a grid by month, 20 at a time; tap → A08.
/// - Order: the memory's date, newest first, then creation time, then id
///   (from the repository, never the loading order).
/// - Back from A08 keeps the memory on top, the mode and the grid's scroll.
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
  static const pileLabel = 'Xấp ảnh';
  static const settingsTooltip = 'Cài đặt album';
  static const loadFailed = 'Chưa tải được kỷ niệm.';
  static const retryLabel = 'Thử lại';
  static const moreLabel = 'Xem thêm kỷ niệm';
  static const pageSize = 20;

  static const nextAction = 'Kỷ niệm tiếp theo';
  static const previousAction = 'Kỷ niệm trước';

  static String countLabel(int n) => '$n kỷ niệm';
  static String position(int index, int total) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(index + 1)} / ${two(total)}';
  }

  static String positionSpoken(int index, int total) =>
      'Kỷ niệm ${index + 1} trên $total';
  static String month(DateTime d) => 'Tháng ${d.month}, ${d.year}';
  static String longDate(DateTime d) => '${d.day} tháng ${d.month}, ${d.year}';

  /// One strip of tape per page, the same for a memory each time.
  static const tapes = [
    'assets/images/scrapbook/tape-cream-stripe.png',
    'assets/images/scrapbook/tape-mint.png',
    'assets/images/scrapbook/tape-cream.png',
  ];
  static const sticker = 'assets/images/scrapbook/nudaeng-hugging-photo.png';

  @override
  State<AlbumBrowseScreen> createState() => _AlbumBrowseScreenState();
}

class _AlbumBrowseScreenState extends State<AlbumBrowseScreen> {
  AlbumRepository? _repository;
  late Album _album = widget.album;
  List<Memory>? _memories;
  var _failed = false;

  /// The memory on the page shown; kept by id across reloads.
  var _index = 0;
  String? _selectedId;
  var _list = false;
  var _shown = AlbumBrowseScreen.pageSize;
  final _listScroll = ScrollController();

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
        // The same memory stays shown when it is still there.
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

  void _turned(int index) {
    final memories = _memories;
    if (memories == null || index < 0 || index >= memories.length) return;
    setState(() {
      _index = index;
      _selectedId = memories[index].id;
    });
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
        // Static: it never moves with the pile.
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
                              ? _Grid(
                                  memories: memories,
                                  shown: _shown,
                                  controller: _listScroll,
                                  onMore: () => setState(() =>
                                      _shown += AlbumBrowseScreen.pageSize),
                                  onOpen: widget.onOpen,
                                )
                              : _Pile(
                                  memories: memories,
                                  index: _index,
                                  onTurned: _turned,
                                  onOpen: widget.onOpen,
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
              icon:
                  list ? Icons.auto_stories_outlined : Icons.grid_view_rounded,
              label: list
                  ? AlbumBrowseScreen.pileLabel
                  : AlbumBrowseScreen.seeAllLabel,
            ),
          ),
        ),
      ]),
    );
  }
}

/// The memories as a pile of photos on a table; "02 / 03" under it.
class _Pile extends StatefulWidget {
  const _Pile({
    required this.memories,
    required this.index,
    required this.onTurned,
    required this.onOpen,
  });

  final List<Memory> memories;
  final int index;
  final ValueChanged<int> onTurned;
  final Future<void> Function(Memory) onOpen;

  /// Moved this far (of its width), or thrown this fast (px/s), the top
  /// photo goes.
  static const throwShare = .3;
  static const throwSpeed = 900.0;

  /// Pulled down this far (of the room), or this fast, the previous photo
  /// lands.
  static const landShare = .3;
  static const landSpeed = 700.0;

  @override
  State<_Pile> createState() => _PileState();
}

/// What a drag on the pile holds: the top photo, the previous one coming
/// back, or the top photo where there is nowhere to go (it only gives).
enum _Grip { none, top, previous, nudge }

/// Where the pile is at a moment.
typedef _Pose = ({Offset top, double lift, double gone, double back});

class _PileState extends State<_Pile> with SingleTickerProviderStateMixin {
  late final _motion = AnimationController(vsync: this)..addListener(_step);

  var _grip = _Grip.none;
  var _grippedAbove = true;

  /// How far the top photo has been moved; how far it is lifted (0 on the
  /// pile, 1 held up); how far it has been thrown (0 to 1, gone); how far
  /// the previous photo has come back (0 to 1, landed).
  var _top = Offset.zero;
  var _lift = 0.0;
  var _gone = 0.0;
  var _back = 0.0;

  /// A throw or a landing under way: the pile takes no new drag.
  var _busy = false;
  var _room = Size.zero;

  _Pose? _from;
  _Pose? _to;
  Curve _curve = Curves.easeOutCubic;

  bool get _last => widget.index >= widget.memories.length - 1;

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  void _step() {
    final from = _from;
    final to = _to;
    if (from == null || to == null) return;
    final t = _curve.transform(_motion.value);
    setState(() {
      _top = Offset.lerp(from.top, to.top, t)!;
      _lift = lerpDouble(from.lift, to.lift, t)!;
      _gone = lerpDouble(from.gone, to.gone, t)!;
      _back = lerpDouble(from.back, to.back, t)!;
    });
  }

  /// Moves the pile to the given pose; at once under reduced motion.
  Future<void> _animate(Duration duration,
      {Offset top = Offset.zero,
      double lift = 0,
      double gone = 0,
      double back = 0,
      Curve curve = Curves.easeOutCubic}) async {
    _from = (top: _top, lift: _lift, gone: _gone, back: _back);
    _to = (top: top, lift: lift, gone: gone, back: back);
    _curve = curve;
    _motion.duration =
        MediaQuery.disableAnimationsOf(context) ? Duration.zero : duration;
    try {
      await _motion.forward(from: 0).orCancel;
    } on TickerCanceled {
      // A new drag took over from where it was.
    }
  }

  void _start(DragStartDetails details) {
    if (_busy) return;
    _motion.stop();
    _grip = _Grip.none;
    _grippedAbove = details.localPosition.dy < _room.height / 2;
  }

  void _update(DragUpdateDetails details) {
    if (_busy) return;
    final delta = details.delta;
    if (_grip == _Grip.none) {
      final down = delta.dy > delta.dx.abs();
      _grip = down
          ? (widget.index > 0 ? _Grip.previous : _Grip.nudge)
          : (_last ? _Grip.nudge : _Grip.top);
    }
    setState(() {
      switch (_grip) {
        case _Grip.previous:
          _back = (_back + delta.dy / _room.height).clamp(0.0, 1.0);
        case _Grip.top:
          _top += delta;
          _lift = (_top.distance / 40).clamp(0.0, 1.0);
        case _Grip.nudge:
          // Nowhere to go: it gives a little and no more.
          _top += delta * .3;
          _lift = (_top.distance / 40).clamp(0.0, 1.0);
        case _Grip.none:
      }
    });
  }

  void _end(DragEndDetails details) {
    if (_busy) return;
    final v = details.velocity.pixelsPerSecond;
    final grip = _grip;
    _grip = _Grip.none;
    switch (grip) {
      case _Grip.previous:
        if (_back > _Pile.landShare || v.dy > _Pile.landSpeed) {
          _land();
        } else {
          _animate(const Duration(milliseconds: 240));
        }
      case _Grip.top:
        final far = _top.distance > _room.width * _Pile.throwShare;
        // Thrown the way it was moving, not back toward the pile.
        final thrown = v.distance > _Pile.throwSpeed &&
            v.dx * _top.dx + v.dy * _top.dy > 0;
        if (far || thrown) {
          _throw(v);
        } else {
          _animate(const Duration(milliseconds: 360),
              curve: Curves.easeOutBack);
        }
      case _Grip.nudge:
        _animate(const Duration(milliseconds: 360), curve: Curves.easeOutBack);
      case _Grip.none:
    }
  }

  /// The turn is decided: heard and felt once, on letting go.
  void _turnFelt() {
    AppSound.instance.play(SoundCue.pageTurn);
    HapticFeedback.lightImpact();
  }

  /// The top photo flies off along [velocity] (or the way it was moved, or
  /// up), turning over; the next one is then on top.
  Future<void> _throw([Offset velocity = Offset.zero]) async {
    if (_busy || _last) return;
    _busy = true;
    _turnFelt();
    final way = velocity.distance > 300
        ? velocity / velocity.distance
        : _top.distance > 1
            ? _top / _top.distance
            : const Offset(0, -1);
    await _animate(const Duration(milliseconds: 380),
        top: _top + way * (_room.longestSide * 1.3), lift: 1, gone: 1);
    if (!mounted) return;
    widget.onTurned(widget.index + 1);
    setState(() {
      _top = Offset.zero;
      _lift = 0;
      _gone = 0;
      _busy = false;
    });
  }

  /// The previous photo comes down onto the pile and is on top.
  Future<void> _land() async {
    if (_busy || widget.index == 0) return;
    _busy = true;
    _turnFelt();
    await _animate(const Duration(milliseconds: 320), back: 1);
    if (!mounted) return;
    widget.onTurned(widget.index - 1);
    setState(() {
      _back = 0;
      _busy = false;
    });
  }

  /// -1 to 1 for [memory], the same each time: how its photo lies.
  static double _jitter(Memory memory, int salt) =>
      (Object.hash(memory.id, salt).abs() % 2001) / 1000 - 1;

  @override
  Widget build(BuildContext context) {
    final memories = widget.memories;
    final index = widget.index;
    final reduced = MediaQuery.disableAnimationsOf(context);
    return Column(children: [
      Expanded(
        child: Padding(
          // Room above for the tape, at the sides for the photos' turn.
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, 28, AppSpacing.lg, AppSpacing.lg),
          child: LayoutBuilder(builder: (context, box) {
            _room = box.biggest;
            final room = BoxConstraints(
                maxWidth: box.maxWidth, maxHeight: box.maxHeight - 20);
            final cards = <Widget>[
              // Under the top one, back to front.
              for (var j = math.min(index + 3, memories.length - 1);
                  j > index;
                  j--)
                if ((j - index) - _gone + _back < 3)
                  _under(memories[j], (j - index) - _gone + _back, room),
              _topCard(memories[index], room, reduced),
              if (_back > 0 && index > 0)
                _coming(memories[index - 1], room, reduced),
            ];
            return Semantics(
              customSemanticsActions: {
                if (!_last)
                  const CustomSemanticsAction(
                      label: AlbumBrowseScreen.nextAction): () => _throw(),
                if (index > 0)
                  const CustomSemanticsAction(
                      label: AlbumBrowseScreen.previousAction): _land,
              },
              child: GestureDetector(
                key: const ValueKey('album-pile'),
                behavior: HitTestBehavior.opaque,
                onPanStart: _start,
                onPanUpdate: _update,
                onPanEnd: _end,
                child: Stack(clipBehavior: Clip.none, children: cards),
              ),
            );
          }),
        ),
      ),
      Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: Semantics(
          label: AlbumBrowseScreen.positionSpoken(index, memories.length),
          excludeSemantics: true,
          liveRegion: true,
          child: Text(AlbumBrowseScreen.position(index, memories.length),
              style:
                  AlbumFormText.chip.copyWith(color: AppColors.textSecondary)),
        ),
      ),
    ]);
  }

  /// [memory] [depth] photos down the pile (0 on top, 2 the lowest shown;
  /// in between while they move up): a little lower, off to one side,
  /// turned and smaller the further down.
  Widget _under(Memory memory, double depth, BoxConstraints room) {
    final d = depth.clamp(0.0, 1.0);
    final tilt = _jitter(memory, 1) * .05;
    return _placed(
      memory,
      room,
      offset: Offset(_jitter(memory, 2) * 10 * d, 9 * depth),
      angle: lerpDouble(tilt * .25, tilt, d)!,
      scale: 1 - .025 * depth,
      opacity: (3 - depth).clamp(0.0, 1.0),
    );
  }

  /// The photo on top: where the finger has it, turned with where it was
  /// gripped and lifted; thrown, it turns over and fades at the end. Under
  /// the previous one coming back, it moves down the pile.
  Widget _topCard(Memory memory, BoxConstraints room, bool reduced) {
    if (_back > 0) return _under(memory, _back, room);
    final tilt = _jitter(memory, 1) * .05 * .25;
    final turn = _top.dx / room.maxWidth * .35 * (_grippedAbove ? 1 : -1);
    return _placed(
      memory,
      room,
      offset: _top,
      angle: tilt + turn,
      scale: 1 + .03 * _lift,
      flip: reduced ? 0 : _gone,
      lift: _lift,
      opacity: (1 - (_gone - .75) / .25).clamp(0.0, 1.0),
      live: _gone == 0,
    );
  }

  /// The previous photo coming back: from above the pile, face down, turning
  /// over as it lands.
  Widget _coming(Memory memory, BoxConstraints room, bool reduced) {
    final away = 1 - _back;
    final tilt = _jitter(memory, 1) * .05 * .25;
    return _placed(
      memory,
      room,
      offset: Offset(0, -(_room.height + 40) * away),
      angle: tilt - .3 * away,
      flip: reduced ? 0 : away,
      lift: away,
    );
  }

  Widget _placed(
    Memory memory,
    BoxConstraints room, {
    required Offset offset,
    required double angle,
    double scale = 1,
    double flip = 0,
    double lift = 0,
    double opacity = 1,
    bool live = false,
  }) {
    Widget card = ConstrainedBox(
      constraints: room,
      child: _Page(
        memory: memory,
        lift: lift,
        back: flip > .5,
        onOpen: live ? () => widget.onOpen(memory) : null,
      ),
    );
    if (flip > 0) {
      card = Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..setEntry(3, 2, .0012)
          ..rotateY(flip * math.pi),
        child: card,
      );
    }
    card = Transform.translate(
      offset: offset,
      child: Transform.rotate(
        angle: angle,
        child: Transform.scale(scale: scale, child: card),
      ),
    );
    if (opacity < 1) card = Opacity(opacity: opacity, child: card);
    return Positioned.fill(
      key: ValueKey(memory.id),
      child: IgnorePointer(ignoring: !live, child: Center(child: card)),
    );
  }
}

/// Ivory paper: date, the photo (or nothing), title and note; one strip of
/// tape over the top edge and a small sticker hanging off a corner. Lifted
/// off the pile, its shadow grows larger and softer; turned over, the back
/// of the paper shows instead.
class _Page extends StatelessWidget {
  const _Page({
    required this.memory,
    required this.onOpen,
    this.lift = 0,
    this.back = false,
  });

  final Memory memory;

  /// Null on a photo that cannot be opened now (under the top one, moving).
  final VoidCallback? onOpen;

  /// 0 lying on the pile, 1 held up.
  final double lift;

  /// Turned over: the back of the paper, nothing on it.
  final bool back;

  static const paper = Color(0xFFFBF8F1);
  static const tapeWidth = 120.0;
  static const stickerWidth = 52.0;

  @override
  Widget build(BuildContext context) {
    final content = memory.content;
    final photo = content.photoPath;
    final note = content.note;
    final title = content.title;
    final tape = AlbumBrowseScreen
        .tapes[memory.id.hashCode.abs() % AlbumBrowseScreen.tapes.length];
    final card = Semantics(
      button: true,
      label: [
        if (title != null) title,
        MemoryDetailScreen.formatDate(content.displayDate),
        if (note != null) note,
      ].join(', '),
      excludeSemantics: true,
      child: Material(
        color: paper,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onOpen,
          child: Padding(
            // The bottom leaves room for the sticker, off the text.
            padding: const EdgeInsets.fromLTRB(18, 22, 18, 30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(AlbumBrowseScreen.longDate(content.displayDate),
                    style: AlbumFormText.note
                        .copyWith(color: AppColors.textSecondary)),
                const SizedBox(height: 12),
                if (photo != null) ...[
                  // Shrinks first, so the words always have room.
                  Flexible(child: _Photo(path: photo)),
                  const SizedBox(height: 14),
                ],
                if (title != null) ...[
                  Text(title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: _Text.title),
                  const SizedBox(height: 4),
                ],
                if (note != null)
                  if (photo != null)
                    Text(note,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: _Text.note)
                  else
                    // A text page is only as tall as its words.
                    Flexible(
                      child: Text(note,
                          maxLines: 12,
                          overflow: TextOverflow.fade,
                          style: _Text.note),
                    ),
              ],
            ),
          ),
        ),
      ),
    );
    final shadow = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withValues(alpha: .12 + .1 * lift),
            blurRadius: 3 + 22 * lift,
            offset: Offset(0, 1.5 + 14 * lift),
          ),
        ],
      ),
      child: card,
    );
    if (back) {
      return Stack(children: [
        // The same size as the front, which is not shown.
        Visibility(
          visible: false,
          maintainSize: true,
          maintainAnimation: true,
          maintainState: true,
          child: shadow,
        ),
        const Positioned.fill(child: _PaperBack()),
      ]);
    }
    return Stack(clipBehavior: Clip.none, children: [
      shadow,
      Positioned(
        top: -tapeWidth * .2,
        left: 22,
        child: IgnorePointer(
          child: Transform.rotate(
            angle: -.05,
            child: Image.asset(tape, width: tapeWidth, cacheWidth: 400),
          ),
        ),
      ),
      Positioned(
        right: -6,
        bottom: -14,
        child: IgnorePointer(
          child: ExcludeSemantics(
            child: Image.asset(AlbumBrowseScreen.sticker,
                width: stickerWidth, cacheWidth: 200),
          ),
        ),
      ),
    ]);
  }
}

/// The back of a memory's paper: plain, with the grain of old paper.
class _PaperBack extends StatelessWidget {
  const _PaperBack();

  @override
  Widget build(BuildContext context) => const DecoratedBox(
        key: ValueKey('paper-back'),
        decoration: BoxDecoration(
          color: Color(0xFFF3EEE3),
          borderRadius: BorderRadius.all(Radius.circular(6)),
          boxShadow: [
            BoxShadow(
                color: Color(0x33201F1C),
                blurRadius: 18,
                offset: Offset(0, 10)),
          ],
          image: DecorationImage(
            image: AssetImage('assets/images/journal-paper-aged.jpg'),
            fit: BoxFit.cover,
            opacity: .35,
          ),
        ),
      );
}

/// The photo at its own proportions, as large as the room allows and never
/// cropped; 4:3 until its size is known.
class _Photo extends StatefulWidget {
  const _Photo({required this.path});

  final String path;

  @override
  State<_Photo> createState() => _PhotoState();
}

class _PhotoState extends State<_Photo> {
  double? _ratio;
  ImageStream? _stream;
  late final _listener = ImageStreamListener((info, _) {
    final image = info.image;
    if (mounted) setState(() => _ratio = image.width / image.height);
    info.dispose();
  }, onError: (_, __) {});

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
  }

  @override
  void didUpdateWidget(_Photo old) {
    super.didUpdateWidget(old);
    if (old.path != widget.path) _resolve();
  }

  void _resolve() {
    final stream = FileImage(File(widget.path))
        .resolve(createLocalImageConfiguration(context));
    if (stream.key == _stream?.key) return;
    _stream?.removeListener(_listener);
    _stream = stream..addListener(_listener);
  }

  @override
  void dispose() {
    _stream?.removeListener(_listener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.topCenter,
        // As tall as the photo, never the whole room.
        heightFactor: 1,
        child: AspectRatio(
          // Very tall or wide photos stay within sensible bounds.
          aspectRatio: (_ratio ?? 4 / 3).clamp(.6, 2.0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Image.file(File(widget.path),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const ColoredBox(
                    color: AppColors.background,
                    child: Center(
                        child: Icon(Icons.broken_image_outlined,
                            color: AppColors.textPrimary)))),
          ),
        ),
      );
}

/// "Xem tất cả": a grid by month, newest first, 20 at a time.
class _Grid extends StatelessWidget {
  const _Grid({
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
    final months = <(String, List<Memory>)>[];
    for (final memory in visible) {
      final label = AlbumBrowseScreen.month(memory.content.displayDate);
      if (months.isEmpty || months.last.$1 != label) months.add((label, []));
      months.last.$2.add(memory);
    }
    const side = EdgeInsets.symmetric(horizontal: AppSpacing.lg);
    return CustomScrollView(
      controller: controller,
      slivers: [
        for (final (label, items) in months) ...[
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg + 4, 12, AppSpacing.lg, 8),
            sliver: SliverToBoxAdapter(
              child: Semantics(
                  header: true,
                  child: Text(label, style: AlbumFormText.section)),
            ),
          ),
          SliverPadding(
            padding: side,
            sliver: SliverGrid.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: .78,
              ),
              itemCount: items.length,
              itemBuilder: (context, i) =>
                  _Tile(memory: items[i], onOpen: () => onOpen(items[i])),
            ),
          ),
        ],
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.md),
          sliver: SliverToBoxAdapter(
            child: more
                ? TextButton(
                    onPressed: onMore,
                    style: TextButton.styleFrom(
                        foregroundColor: AppColors.primaryAction,
                        minimumSize: const Size.fromHeight(48)),
                    child: const Text(AlbumBrowseScreen.moreLabel),
                  )
                : const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }
}

/// A memory in the grid: its photo (or its note) and the title under it.
class _Tile extends StatelessWidget {
  const _Tile({required this.memory, required this.onOpen});

  final Memory memory;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final content = memory.content;
    final photo = content.photoPath;
    final note = content.note;
    return Material(
      color: _Page.paper,
      elevation: 1,
      shadowColor: AppColors.textPrimary.withValues(alpha: .15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: photo != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Image.file(File(photo),
                            fit: BoxFit.cover,
                            cacheWidth: 400,
                            errorBuilder: (_, __, ___) =>
                                const ColoredBox(color: AppColors.background)),
                      )
                    : Padding(
                        padding: const EdgeInsets.all(4),
                        child: Text(note ?? '',
                            overflow: TextOverflow.fade,
                            style: AlbumFormText.body),
                      ),
              ),
              const SizedBox(height: 6),
              Text(
                  content.title ??
                      MemoryDetailScreen.formatDate(content.displayDate),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AlbumFormText.bodyStrong),
              if (content.title != null)
                Text(MemoryDetailScreen.formatDate(content.displayDate),
                    maxLines: 1, style: AlbumFormText.note),
            ],
          ),
        ),
      ),
    );
  }
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
        child: AppPrimaryButton(
          label: AlbumBrowseScreen.addLabel,
          icon: Icons.add_rounded,
          onPressed: onAdd,
        ),
      );
}

abstract final class _Text {
  static const title = TextStyle(
    fontFamily: 'Nunito',
    fontSize: 20,
    fontWeight: FontWeight.w700,
    height: 1.3,
    color: AppColors.textPrimary,
  );
  static const note = TextStyle(
    fontFamily: 'BeVietnamPro',
    fontSize: 15,
    height: 1.5,
    color: AppColors.textPrimary,
  );
}
