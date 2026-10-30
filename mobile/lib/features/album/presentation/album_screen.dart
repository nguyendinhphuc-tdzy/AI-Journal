import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_ui.dart';
import '../album_scope.dart';
import '../data/album.dart';
import '../data/album_repository.dart';
import '../data/remote_album_repository.dart';
import '../data/local_album_cloud_importer.dart';
import '../data/album_unlocks.dart';
import '../data/memory_share.dart';
import 'album_backdrop.dart';
import 'album_cover.dart';
import 'album_routes.dart';

/// A01: the album library. Title, a two-column grid of folder covers, and
/// "Tạo album" docked above the bottom navigation.
///
/// - Empty album → A05; album with memories → A09; locked and not unlocked
///   in this session → A04, then on to where the tap was going.
/// - The menu button (its own 48 × 48 target, apart from the area that opens
///   the album) and a long press open A03; a locked album asks A04 first.
/// - A locked album shows a generic cover and no memory count; with
///   [Album.hideNameWhenLocked], "Album đã khóa" instead of its name.
/// - A new album fades in at the top with a soft teal glow (1.8 s) that
///   fades away; no mascot over the grid.
/// - No album yet: one group, close together and centred a little above the
///   middle (it scrolls when space is short): the first page of a scrapbook
///   (two small framed drawings, a sky and a flower, never anything like a
///   user's photo; two strips of tape; Nudaeng hugging a photo in the
///   corner), an invitation, and "Tạo album đầu tiên" right under it. The
///   docked "Tạo album" is not shown then.
class AlbumScreen extends StatefulWidget {
  const AlbumScreen({super.key, this.onShare, this.onUnshare});

  /// A post just made in A10 (the album routes have closed): the app shell
  /// shows it on the map (E01). The library itself shares nothing.
  final ValueChanged<SharedMemoryPost>? onShare;

  /// Posts taken off the map in A11 or A12: the shell drops them from E01.
  final ValueChanged<ShareRemoval>? onUnshare;

  /// The tab's name in the bottom navigation.
  static const title = 'Kỷ niệm';
  static const subtitle = 'Giữ lại những điều bạn muốn nhớ.';
  static const createLabel = 'Tạo album';
  static const emptyTitle = 'Những điều nhỏ, đáng nhớ';
  static const emptyBody =
      'Gom ảnh và vài dòng kể lại thành một cuốn album của bạn.';
  static const firstCreateLabel = 'Tạo album đầu tiên';
  static const loadFailed = 'Chưa tải được album.';
  static const refreshFailed = 'Chưa cập nhật được danh sách album.';
  static const retryLabel = 'Thử lại';
  static const lockedName = 'Album đã khóa';
  static const lockedLabel = 'Đã khóa';
  static const addMemoryLabel = 'Thêm kỷ niệm';

  static String countLabel(int count) => '$count kỷ niệm';
  static const created = 'Đã tạo album';

  /// How long a new album's glow lasts, fade-in included.
  static const newGlow = Duration(milliseconds: 1800);
  static const backdropAsset = AlbumBackdrop.figureAsset;
  static const emptyAsset = 'assets/images/scrapbook/nudaeng-hugging-photo.png';

  @override
  State<AlbumScreen> createState() => _AlbumScreenState();
}

class _AlbumScreenState extends State<AlbumScreen> {
  final _scroll = ScrollController();
  AlbumRepository? _repository;
  List<Album>? _albums;
  var _loading = true;
  var _failed = false;
  var _creating = false;
  var _importing = false;

  /// The album just created: it fades in with a glow.
  String? _newId;

  AlbumUnlocks get _unlocks => AlbumUnlocks.instance;

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
    _unlocks.addListener(_rebuild);
    AlbumRoutes.published.addListener(_published);
    AlbumRoutes.unshared.addListener(_unshared);
  }

  @override
  void dispose() {
    _repository?.removeListener(_load);
    _unlocks.removeListener(_rebuild);
    AlbumRoutes.published.removeListener(_published);
    AlbumRoutes.unshared.removeListener(_unshared);
    _scroll.dispose();
    super.dispose();
  }

  void _rebuild() => setState(() {});

  void _published() {
    final post = AlbumRoutes.published.value;
    if (post == null) return;
    AlbumRoutes.published.value = null;
    widget.onShare?.call(post);
  }

  void _unshared() {
    final removal = AlbumRoutes.unshared.value;
    if (removal == null) return;
    AlbumRoutes.unshared.value = null;
    widget.onUnshare?.call(removal);
  }

  Future<void> _load() async {
    final repository = _repository!;
    setState(() => _loading = true);
    try {
      final albums = await repository.albums();
      if (!mounted || repository != _repository) return;
      setState(() {
        _albums = albums;
        _loading = false;
        _failed = false;
      });
    } catch (_) {
      if (!mounted) return;
      // Whatever was shown stays: a failed refresh is not an empty library.
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  bool _isLocked(Album album) => album.locked && !_unlocks.isUnlocked(album.id);

  /// Leaving the library ends the glow: it is for the new album, once.
  Future<void> _leave(Future<void> Function() route) async {
    if (_newId != null) setState(() => _newId = null);
    await route();
  }

  Future<void> _open(Album album) => _leave(() => _isLocked(album)
      ? AlbumRoutes.unlock(context, album, AlbumDestination.open(album))
      : AlbumRoutes.open(context, album));

  Future<void> _settings(Album album) => _leave(() => _isLocked(album)
      ? AlbumRoutes.unlock(context, album, AlbumDestination.settings)
      : AlbumRoutes.settings(context, album));

  Future<void> _create() async {
    if (_creating) return;
    _creating = true;
    final album = await AlbumRoutes.create(context);
    _creating = false;
    if (album == null || !mounted) return;
    setState(() => _newId = album.id);
    // Newest first: the new album is the first tile.
    if (_scroll.hasClients) {
      _scroll.animateTo(0,
          duration: const Duration(milliseconds: 280), curve: Curves.easeOut);
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        // Floats above the dock so "Tạo album" stays reachable.
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg,
            _Dock.heightOf(context) - AppSpacing.sm),
        content: const Text(AlbumScreen.created),
        // Leaves on its own, as every snack bar, though it has an action.
        persist: false,
        action: SnackBarAction(
          label: AlbumScreen.addMemoryLabel,
          onPressed: () {
            if (mounted) _open(album);
          },
        ),
      ));
  }

  /// Explicit per-account copy only, never automatic background sync.
  Future<void> _importLocal() async {
    final source = _repository;
    if (source is! CombinedAlbumRepository || _importing) return;
    final candidates = await source.local.albums();
    if (!mounted || candidates.isEmpty) return;
    final selected = await showDialog<Album>(
      context: context,
      builder: (dialog) => SimpleDialog(
        title: const Text('Chọn album trên máy để nhập'),
        children: [
          for (final album in candidates)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialog, album),
              child: Text(album.name, maxLines: 2),
            ),
        ],
      ),
    );
    if (!mounted || selected == null) return;
    final importer = LocalAlbumCloudImporter(
        local: source.local, remote: source.remote);
    int count;
    try {
      count = await importer.validate(selected);
    } on StateError catch (error) {
      if (mounted) {
        _showImportMessage(error.message.toString());
      }
      return;
    } catch (_) {
      if (mounted) {
        _showImportMessage('Album có ảnh không hợp lệ hoặc đã mất. '
            'Không có dữ liệu nào được tải lên.');
      }
      return;
    }
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Nhập album lên Cloud?'),
        content: Text('Sao chép "${selected.name}" và $count kỷ niệm lên '
            'tài khoản đang đăng nhập. Ảnh được gửi lên kho riêng tư. '
            'Album và ảnh gốc trên máy vẫn được giữ nguyên. '
            'Không chia sẻ cho bạn bè.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false),
              child: const Text('Hủy')),
          FilledButton(onPressed: () => Navigator.pop(dialog, true),
              child: const Text('Đồng ý nhập')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _importing = true);
    try {
      final imported = await importer.importAlbum(selected);
      if (!mounted) return;
      _showImportMessage('Đã nhập "${imported.name}" lên Cloud. '
          'Bản trên máy vẫn được giữ nguyên.');
      await _load();
    } on StateError catch (error) {
      if (mounted) _showImportMessage(error.message.toString());
    } catch (_) {
      if (mounted) {
        _showImportMessage('Chưa nhập xong. Bản local vẫn còn. '
            'Kiểm tra album cloud trước khi thử lại để tránh trùng.');
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  void _showImportMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final albums = _albums;
    final firstLoad = albums == null;
    // The large background Nudaeng only while the grid is short.
    final showFigure =
        albums != null && albums.isNotEmpty && albums.length <= 2;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // The sky runs under the status bar; the library stays below it.
          AlbumBackdrop(showFigure: showFigure),
          SafeArea(
            bottom: false,
            child: LayoutBuilder(
              builder: (context, box) => CustomScrollView(
                controller: _scroll,
                slivers: [
                  const SliverToBoxAdapter(child: _Header()),
                  if (_repository is CombinedAlbumRepository &&
                      albums != null &&
                      albums.any((album) => album.id.startsWith('local-')))
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.lg),
                        child: OutlinedButton.icon(
                          onPressed: _importing ? null : _importLocal,
                          icon: _importing
                              ? const SizedBox(width: 18, height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.cloud_upload_outlined),
                          label: Text(_importing
                              ? 'Đang nhập album…'
                              : 'Nhập album từ máy lên Cloud'),
                        ),
                      ),
                    ),
                  if (_failed && albums != null)
                    SliverToBoxAdapter(
                      child: _Notice(
                          text: AlbumScreen.refreshFailed, onRetry: _load),
                    ),
                  if (firstLoad && _loading)
                    const _SkeletonGrid()
                  else if (firstLoad)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child:
                          _Notice(text: AlbumScreen.loadFailed, onRetry: _load),
                    )
                  else if (albums.isEmpty)
                    // As tall as it needs (scrolls when short), at least most
                    // of the screen so it sits near the middle.
                    SliverToBoxAdapter(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                            minHeight: math.max(0, box.maxHeight - 120)),
                        child: _EmptyLibrary(onCreate: _create),
                      ),
                    )
                  else
                    _Grid(
                      albums: albums,
                      width: box.maxWidth,
                      newId: _newId,
                      onOpen: _open,
                      onSettings: _settings,
                    ),
                  if (albums?.isEmpty != true)
                    SliverToBoxAdapter(
                        child: SizedBox(height: _Dock.heightOf(context))),
                ],
              ),
            ),
          ),
          // Empty: the button is in the invitation, close to its words.
          if (albums?.isEmpty != true)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _Dock(onCreate: _create),
            ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  // Same header as the other tabs (title = tab name, line under it).
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.fromLTRB(
            AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xl),
        child: AppPageHeader(
            title: AlbumScreen.title, subtitle: AlbumScreen.subtitle),
      );
}

class _Grid extends StatelessWidget {
  const _Grid({
    required this.albums,
    required this.width,
    required this.newId,
    required this.onOpen,
    required this.onSettings,
  });

  final List<Album> albums;
  final double width;
  final String? newId;
  final ValueChanged<Album> onOpen;
  final ValueChanged<Album> onSettings;

  static const gap = 16.0;

  @override
  Widget build(BuildContext context) {
    final tileWidth = (width - AppSpacing.lg * 2 - gap) / 2;
    // Rows sized by their content, so long names grow the tile.
    final rows = <Widget>[
      for (var i = 0; i < albums.length; i += 2)
        Padding(
          padding: EdgeInsets.only(top: i == 0 ? 0 : gap),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final j in [i, i + 1]) ...[
                  if (j == i + 1) const SizedBox(width: gap),
                  SizedBox(
                    width: tileWidth,
                    child: j < albums.length
                        ? _AlbumTile(
                            key: ValueKey(albums[j].id),
                            album: albums[j],
                            width: tileWidth,
                            // Always shown as locked here, opened or not.
                            locked: albums[j].locked,
                            isNew: albums[j].id == newId,
                            onOpen: () => onOpen(albums[j]),
                            onSettings: () => onSettings(albums[j]),
                          )
                        : null,
                  ),
                ],
              ],
            ),
          ),
        ),
    ];
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.md),
      sliver: SliverList.list(children: rows),
    );
  }
}

class _AlbumTile extends StatelessWidget {
  const _AlbumTile({
    super.key,
    required this.album,
    required this.width,
    required this.locked,
    required this.isNew,
    required this.onOpen,
    required this.onSettings,
  });

  final Album album;
  final double width;
  final bool locked;
  final bool isNew;
  final VoidCallback onOpen;
  final VoidCallback onSettings;

  static const padding = 12.0;
  static const radius = 20.0;

  String get _name =>
      locked && album.hideNameWhenLocked ? AlbumScreen.lockedName : album.name;

  String? get _meta => locked
      ? AlbumScreen.lockedLabel
      : album.memoryCount > 0
          ? AlbumScreen.countLabel(album.memoryCount)
          : null;

  @override
  Widget build(BuildContext context) {
    final meta = _meta;
    final bigText = MediaQuery.textScalerOf(context).scale(16) > 20;
    final shape =
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius));
    final tile = Material(
      color: AppColors.surface,
      shape: shape.copyWith(side: const BorderSide(color: AppColors.border)),
      child: InkWell(
        customBorder: shape,
        onTap: onOpen,
        onLongPress: onSettings,
        child: Padding(
          padding: const EdgeInsets.all(padding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AlbumCover(themeId: album.themeId, locked: locked),
              const SizedBox(height: AppSpacing.sm),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _name,
                            maxLines: bigText ? 3 : 2,
                            overflow: TextOverflow.ellipsis,
                            style: _Text.name,
                          ),
                          if (meta != null) ...[
                            const SizedBox(height: 2),
                            Row(children: [
                              if (locked) ...[
                                const Icon(Icons.lock_outline_rounded,
                                    size: 14, color: AppColors.textPrimary),
                                const SizedBox(width: 4),
                              ],
                              Flexible(child: Text(meta, style: _Text.meta)),
                            ]),
                          ],
                        ],
                      ),
                    ),
                    // Its own target, apart from the area that opens.
                    SizedBox(
                      width: 40,
                      child: OverflowBox(
                        maxWidth: 48,
                        maxHeight: 48,
                        alignment: Alignment.topRight,
                        child: IconButton(
                          tooltip: 'Tùy chọn album $_name',
                          onPressed: onSettings,
                          icon: const Icon(Icons.more_horiz_rounded,
                              color: AppColors.textPrimary),
                          constraints: const BoxConstraints.tightFor(
                              width: 48, height: 48),
                          padding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    final semantic = Semantics(
      button: true,
      label: [
        'Album $_name',
        if (meta != null) meta,
      ].join(', '),
      child: tile,
    );
    if (!isNew) return semantic;
    // The new album fades into its place (200 ms) with a teal glow that
    // holds, then fades away. Reduced motion: there at once, no glow.
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : AlbumScreen.newGlow,
      builder: (context, t, child) {
        final opacity = (t * 9).clamp(0.0, 1.0);
        final glow =
            1 - Curves.easeIn.transform(((t - .35) / .65).clamp(0.0, 1.0));
        final shape = BorderRadius.circular(radius);
        return Opacity(
          opacity: opacity,
          // The glow under the tile, its outline over it.
          child: DecoratedBox(
            key: const ValueKey('album-new-glow'),
            decoration: BoxDecoration(borderRadius: shape, boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: .35 * glow),
                blurRadius: 18,
              ),
            ]),
            child: DecoratedBox(
              position: DecorationPosition.foreground,
              decoration: BoxDecoration(
                borderRadius: shape,
                border: Border.all(
                    color: AppColors.primaryAction.withValues(alpha: glow),
                    width: 2),
              ),
              child: child,
            ),
          ),
        );
      },
      child: semantic,
    );
  }
}

/// No album yet: the first page of a scrapbook, an invitation and the
/// button to start, as one group.
class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) => Align(
        // A little above the middle: close to the title, never far apart.
        alignment: const Alignment(0, -.35),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const ExcludeSemantics(child: _FirstPage()),
                const SizedBox(height: AppSpacing.xl),
                const Text(AlbumScreen.emptyTitle,
                    textAlign: TextAlign.center, style: _Text.invite),
                const SizedBox(height: AppSpacing.sm),
                const Text(AlbumScreen.emptyBody,
                    textAlign: TextAlign.center, style: _Text.body),
                const SizedBox(height: AppSpacing.lg),
                _PressScale(
                  child: AppPrimaryButton(
                    label: AlbumScreen.firstCreateLabel,
                    icon: Icons.add_rounded,
                    onPressed: onCreate,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

/// A sheet of ivory paper with two small framed drawings set off from each
/// other, a strip of tape on each, and Nudaeng hugging a photo in the
/// corner. Drawings only: nothing that could pass for the user's photos.
class _FirstPage extends StatelessWidget {
  const _FirstPage();

  static const paper = Color(0xFFFBF8F1);
  static const height = 196.0;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 300,
        height: height,
        child: Stack(clipBehavior: Clip.none, children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: paper,
                borderRadius: BorderRadius.circular(6),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.textPrimary.withValues(alpha: .12),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
            ),
          ),
          const Positioned(
            left: 28,
            top: 22,
            child: _Frame(
                angle: -.07,
                tape: 'assets/images/scrapbook/tape-mint.png',
                painter: _SkyDrawing()),
          ),
          const Positioned(
            left: 142,
            top: 56,
            child: _Frame(
                angle: .06,
                tape: 'assets/images/scrapbook/tape-cream-stripe.png',
                painter: _FlowerDrawing()),
          ),
          Positioned(
            right: -14,
            bottom: -18,
            child: Image.asset(AlbumScreen.emptyAsset,
                width: 92,
                cacheWidth: 300,
                errorBuilder: (_, __, ___) => const SizedBox.shrink()),
          ),
        ]),
      );
}

/// A small white photo frame around a drawing, turned a little, with a strip
/// of tape over its top edge.
class _Frame extends StatelessWidget {
  const _Frame(
      {required this.angle, required this.tape, required this.painter});

  final double angle;
  final String tape;
  final CustomPainter painter;

  @override
  Widget build(BuildContext context) => Transform.rotate(
        angle: angle,
        child: Stack(clipBehavior: Clip.none, children: [
          Container(
            padding: const EdgeInsets.fromLTRB(6, 6, 6, 18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(3),
              boxShadow: [
                BoxShadow(
                  color: AppColors.textPrimary.withValues(alpha: .14),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: CustomPaint(size: const Size(104, 84), painter: painter),
            ),
          ),
          Positioned(
            top: -14,
            left: 24,
            child: Image.asset(tape, width: 70, cacheWidth: 240),
          ),
        ]),
      );
}

/// A drawn sky: sun, a cloud and two soft hills.
class _SkyDrawing extends CustomPainter {
  const _SkyDrawing();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFCFE6EC), AppColors.primaryLight],
        ).createShader(Offset.zero & size),
    );
    canvas.drawCircle(Offset(w * .76, h * .28), h * .13,
        Paint()..color = const Color(0xFFF2C66D));
    final cloud = Paint()..color = Colors.white.withValues(alpha: .95);
    for (final (x, y, r) in [
      (.26, .30, .09),
      (.36, .26, .11),
      (.46, .31, .08)
    ]) {
      canvas.drawCircle(Offset(w * x, h * y), h * r, cloud);
    }
    canvas.drawPath(
      Path()
        ..moveTo(0, h * .78)
        ..quadraticBezierTo(w * .3, h * .52, w * .62, h * .76)
        ..lineTo(w * .62, h)
        ..lineTo(0, h)
        ..close(),
      Paint()..color = AppColors.softAccent,
    );
    canvas.drawPath(
      Path()
        ..moveTo(w * .35, h)
        ..quadraticBezierTo(w * .7, h * .5, w, h * .72)
        ..lineTo(w, h)
        ..close(),
      Paint()..color = AppColors.primary.withValues(alpha: .75),
    );
  }

  @override
  bool shouldRepaint(_SkyDrawing old) => false;
}

/// A drawn flower on a stem with two leaves.
class _FlowerDrawing extends CustomPainter {
  const _FlowerDrawing();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    canvas.drawRect(
        Offset.zero & size, Paint()..color = const Color(0xFFF6EFE2));
    final green = Paint()
      ..color = AppColors.positive
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final centre = Offset(w * .5, h * .36);
    canvas.drawPath(
        Path()
          ..moveTo(w * .5, h)
          ..quadraticBezierTo(w * .44, h * .66, centre.dx, centre.dy),
        green);
    final leaf = Paint()..color = AppColors.softAccent;
    canvas.save();
    canvas.translate(w * .46, h * .72);
    canvas.rotate(-.6);
    canvas.drawOval(
        Rect.fromCenter(center: const Offset(-9, 0), width: 18, height: 8),
        leaf);
    canvas.restore();
    canvas.save();
    canvas.translate(w * .48, h * .6);
    canvas.rotate(.5);
    canvas.drawOval(
        Rect.fromCenter(center: const Offset(9, 0), width: 18, height: 8),
        leaf);
    canvas.restore();
    final petal = Paint()..color = const Color(0xFFE9B7B0);
    for (var i = 0; i < 5; i++) {
      final a = i * 2 * math.pi / 5 - math.pi / 2;
      canvas.drawCircle(
          centre + Offset(math.cos(a), math.sin(a)) * h * .12, h * .085, petal);
    }
    canvas.drawCircle(
        centre, h * .07, Paint()..color = const Color(0xFFF2C66D));
  }

  @override
  bool shouldRepaint(_FlowerDrawing old) => false;
}

/// A message on paper with "Thử lại".
class _Notice extends StatelessWidget {
  const _Notice({required this.text, required this.onRetry});

  final String text;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.md),
        child: Align(
          alignment: Alignment.topCenter,
          child: Semantics(
            liveRegion: true,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(children: [
                const Icon(Icons.info_outline_rounded,
                    size: 20, color: AppColors.textPrimary),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: Text(text, style: _Text.body)),
                TextButton(
                  onPressed: onRetry,
                  style: TextButton.styleFrom(
                      foregroundColor: AppColors.primaryAction,
                      minimumSize: const Size(48, 48)),
                  child: const Text(AlbumScreen.retryLabel),
                ),
              ]),
            ),
          ),
        ),
      );
}

/// Placeholder tiles while the first load runs, the size of real ones.
class _SkeletonGrid extends StatelessWidget {
  const _SkeletonGrid();

  @override
  Widget build(BuildContext context) => SliverPadding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.md),
        sliver: SliverGrid.count(
          crossAxisCount: 2,
          mainAxisSpacing: _Grid.gap,
          crossAxisSpacing: _Grid.gap,
          childAspectRatio: .86,
          children: [
            for (var i = 0; i < 4; i++)
              Semantics(
                label: i == 0 ? 'Đang tải album' : null,
                child: Container(
                  padding: const EdgeInsets.all(_AlbumTile.padding),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(_AlbumTile.radius),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AspectRatio(
                        aspectRatio: AlbumCover.aspectRatio,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      FractionallySizedBox(
                        widthFactor: .7,
                        child: Container(
                          height: 14,
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(7),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
}

/// "Tạo album", always reachable above the bottom navigation; the grid
/// scrolls under a soft fade.
class _Dock extends StatelessWidget {
  const _Dock({required this.onCreate});

  final VoidCallback onCreate;

  static double heightOf(BuildContext context) =>
      math.max(56.0, MediaQuery.textScalerOf(context).scale(16) * 1.5 + 32) +
      AppSpacing.md * 2;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.background.withValues(alpha: 0),
              AppColors.background,
            ],
            stops: const [0, .35],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.md),
          child: _PressScale(
            child: FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add_rounded),
              label: const Text(AlbumScreen.createLabel),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28)),
                textStyle: _Text.button,
              ),
            ),
          ),
        ),
      );
}

/// Scales to 0.98 while pressed; never delays the tap.
class _PressScale extends StatefulWidget {
  const _PressScale({required this.child});

  final Widget child;

  @override
  State<_PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<_PressScale> {
  var _down = false;

  void _set(bool down) {
    if (down != _down) setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) => Listener(
        onPointerDown: (_) => _set(true),
        onPointerUp: (_) => _set(false),
        onPointerCancel: (_) => _set(false),
        child: AnimatedScale(
          scale: _down ? .98 : 1,
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 90),
          child: widget.child,
        ),
      );
}

abstract final class _Text {
  static const invite = TextStyle(
    fontFamily: 'Nunito',
    fontSize: 22,
    fontWeight: FontWeight.w700,
    height: 1.3,
    color: AppColors.textPrimary,
  );
  static const body = TextStyle(
    fontFamily: 'BeVietnamPro',
    fontSize: 16,
    height: 1.5,
    color: AppColors.textPrimary,
  );
  static const name = TextStyle(
    fontFamily: 'BeVietnamPro',
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.4,
    color: AppColors.textPrimary,
  );
  static const meta = TextStyle(
    fontFamily: 'BeVietnamPro',
    fontSize: 14,
    height: 20 / 14,
    color: AppColors.textPrimary,
  );
  static const button = TextStyle(
    fontFamily: 'BeVietnamPro',
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.5,
  );
}
