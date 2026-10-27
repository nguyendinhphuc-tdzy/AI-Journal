import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_ui.dart';
import '../album_scope.dart';
import '../data/album.dart';
import '../data/album_repository.dart';
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
  static const emptyTitle = 'Chưa có album nào';
  static const emptyBody =
      'Tạo một album để giữ ảnh và những dòng ghi chú bạn muốn nhớ.';
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
  static const emptyAsset = 'assets/Deimage/album-empty-nudaeng.png';

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
                    const SliverFillRemaining(
                        hasScrollBody: false, child: _EmptyLibrary())
                  else
                    _Grid(
                      albums: albums,
                      width: box.maxWidth,
                      newId: _newId,
                      onOpen: _open,
                      onSettings: _settings,
                    ),
                  SliverToBoxAdapter(
                      child: SizedBox(height: _Dock.heightOf(context))),
                ],
              ),
            ),
          ),
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

/// No album yet: Nudaeng holding an empty notebook over a sheet of paper.
class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.md),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ExcludeSemantics(
              child: SizedBox(
                height: 150,
                child: Image.asset(AlbumScreen.emptyAsset,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink()),
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              child: const Column(children: [
                Text(AlbumScreen.emptyTitle,
                    textAlign: TextAlign.center, style: _Text.section),
                SizedBox(height: AppSpacing.sm),
                Text(AlbumScreen.emptyBody,
                    textAlign: TextAlign.center, style: _Text.body),
              ]),
            ),
          ],
        ),
      );
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
  static const section = TextStyle(
    fontFamily: 'Nunito',
    fontSize: 20,
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
