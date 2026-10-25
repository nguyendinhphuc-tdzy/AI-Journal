import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../explore/data/place_lookup.dart';
import '../../explore/presentation/place_picker_screen.dart';
import '../data/album.dart';
import '../data/memory.dart';
import '../album_scope.dart';
import '../data/album_repository.dart';
import '../data/album_unlocks.dart';
import '../data/memory_share.dart';
import 'album_access_guard.dart';
import '../data/album_deletion.dart';
import '../data/album_settings.dart';
import 'album_browse_screen.dart';
import 'confirm_delete_dialog.dart';
import 'manage_post_screen.dart';
import 'album_settings_screen.dart';
import 'album_start_screen.dart';
import 'memory_detail_screen.dart';
import 'memory_editor_screen.dart';
import 'create_album_sheet.dart';
import 'share_memory_sheet.dart';

/// Where opening an album leads once it is unlocked.
enum AlbumDestination {
  /// A05: the album has no memory yet.
  start,

  /// A09: scrapbook browse.
  browse,

  /// A03: album settings.
  settings,

  /// A08: one memory, retaining its ID through authentication.
  memory,

  /// A06: a new memory, opened photo-first or note-first.
  newMemory,

  /// A12: one 24-hour post of a memory.
  post;

  static AlbumDestination open(Album album) => album.isEmpty ? start : browse;
}

/// Album navigation. Child screens go on the root navigator, so they cover
/// the bottom navigation and come with Back (as in Study).
///
/// A02–A12 and E05 are implemented; E04 is a stand-in.
abstract final class AlbumRoutes {
  /// A02. The new album, or null when closed without creating one. What was
  /// typed stays for the session until an album is created.
  static Future<Album?> create(BuildContext context) =>
      CreateAlbumSheet.show(context, CreateAlbumDraft.session);

  /// A05 or A09 for an album that is not locked (or already unlocked).
  static Future<void> open(BuildContext context, Album album) =>
      _destination(context, album, AlbumDestination.open(album));

  /// A03.
  static Future<void> settings(BuildContext context, Album album) =>
      _destination(context, album, AlbumDestination.settings);

  static Future<void> memory(
          BuildContext context, Album album, String memoryId) =>
      _destination(context, album, AlbumDestination.memory, memoryId: memoryId);

  /// A06 for a new memory in [album].
  static Future<void> newMemory(
          BuildContext context, Album album, MemoryStartIntent intent) =>
      _destination(context, album, AlbumDestination.newMemory, intent: intent);

  /// A06 editing an existing memory (same id after saving).
  static Future<void> editMemory(
          BuildContext context, Album album, String memoryId) =>
      _destination(context, album, AlbumDestination.newMemory,
          memoryId: memoryId);

  /// E05 for a place in [album] (A06's memory place, A10's share place),
  /// starting from [current]. The confirmed place, or null to keep
  /// [current]. Nothing is saved or posted here. Guarded like the album's
  /// screens: hidden in the background, A04 again once a locked album locks.
  static Future<MemoryPlace?> pickPlace(BuildContext context, Album album,
      {MemoryPlace? current}) async {
    final repository = AlbumScope.of(context);
    final auth = AlbumScope.authOf(context);
    final picked = await Navigator.of(context, rootNavigator: true)
        .push<PlaceCandidate>(MaterialPageRoute(
            settings: RouteSettings(
                name: 'album/E05', arguments: {'albumId': album.id}),
            builder: (_) => AlbumScope(
                repository: repository,
                auth: auth,
                child: AlbumAccessGuard(
                    albumId: album.id,
                    builder: (_) => PlacePickerScreen(
                        initial:
                            current == null ? null : _candidate(current))))));
    return picked == null ? null : _place(picked);
  }

  static PlaceCandidate _candidate(MemoryPlace place) => PlaceCandidate(
        id: place.placeId,
        name: place.named ? place.label : null,
        address: place.address,
        latitude: place.latitude,
        longitude: place.longitude,
        source: place.placeId == null ? PlaceSource.pin : PlaceSource.search,
      );

  static MemoryPlace _place(PlaceCandidate picked) => MemoryPlace(
        label: picked.named
            ? picked.name!.trim()
            : MemoryPlace.unnamedLabel(picked.latitude, picked.longitude),
        latitude: picked.latitude,
        longitude: picked.longitude,
        named: picked.named,
        address: picked.address,
        placeId: picked.id,
      );

  /// A10 over A08. Once posted, the album routes close and [published]
  /// carries the post to the library, which hands it to the map (E01).
  static Future<void> share(
      BuildContext context, Album album, Memory memory) async {
    final post = await ShareMemorySheet.show(
      context,
      album: album,
      memory: memory,
      repository: AlbumScope.of(context),
      sharing: AlbumScope.memorySharingOf(context),
      onPickPlace: (current) => pickPlace(context, album, current: current),
    );
    if (post == null || !context.mounted) return;
    Navigator.of(context, rootNavigator: true).popUntil((r) => r.isFirst);
    published.value = post;
  }

  /// The post just made in A10, until the library passes it on (and clears
  /// it).
  static final published = ValueNotifier<SharedMemoryPost?>(null);

  /// Posts just taken off the map (A11, A12), until the library passes it on.
  static final unshared = ValueNotifier<ShareRemoval?>(null);

  /// A12 for [post] (over A08). True once it was taken off the map (the
  /// map then drops it too).
  static Future<bool> managePost(
      BuildContext context, Album album, SharedMemoryPost post) async {
    final revoked = await _destination(context, album, AlbumDestination.post,
            memoryId: post.memoryId, post: post) ==
        true;
    if (revoked) unshared.value = ShareRemoval(postId: post.id);
    return revoked;
  }

  static AlbumDeletion _deletion(BuildContext context) => AlbumDeletion(
        repository: AlbumScope.of(context),
        albumSharing: AlbumScope.sharingOf(context),
        memorySharing: AlbumScope.memorySharingOf(context),
        photos: AlbumScope.photosOf(context),
      );

  /// A11 for [memory]. True once it is deleted (its post gone first); the
  /// caller then takes it off screen.
  static Future<bool> deleteMemory(
      BuildContext context, Album album, Memory memory) async {
    final repository = AlbumScope.of(context);
    final deletion = _deletion(context);
    final deleted = await ConfirmDeleteDialog.show(
      context,
      title: ConfirmDeleteDialog.memoryTitle,
      body: ConfirmDeleteDialog.memoryBody(
          title: memory.content.title, album: album),
      confirmLabel: ConfirmDeleteDialog.memoryTitle,
      failed: AlbumDeletion.memoryFailed,
      onConfirm: () => deletion.deleteMemory(album.id, memory.id),
    );
    if (!deleted) return false;
    MemoryShareDraft.discard(memory.id);
    _forgetDraft(repository, MemoryEditorScreen.draftKey(album.id, memory.id));
    unshared.value = ShareRemoval(memoryId: memory.id);
    return true;
  }

  /// A11 for [album] and all its memories. True once it is deleted; the
  /// caller then leaves the album.
  static Future<bool> deleteAlbum(BuildContext context, Album album) async {
    final repository = AlbumScope.of(context);
    final deletion = _deletion(context);
    List<Memory> memories;
    try {
      memories = await repository.memories(album.id);
    } catch (_) {
      memories = const [];
    }
    if (!context.mounted) return false;
    final deleted = await ConfirmDeleteDialog.show(
      context,
      title: ConfirmDeleteDialog.albumTitle,
      body: ConfirmDeleteDialog.albumBody(
          album, memories.isEmpty ? album.memoryCount : memories.length),
      confirmLabel: ConfirmDeleteDialog.albumTitle,
      failed: AlbumDeletion.albumFailed,
      onConfirm: () async {
        // Its screens stay as they are while they leave, instead of
        // flashing "no longer exists".
        AlbumAccessGuard.departing.add(album.id);
        try {
          await deletion.deleteAlbum(album.id);
        } catch (_) {
          AlbumAccessGuard.departing.remove(album.id);
          rethrow;
        }
      },
    );
    if (!deleted) return false;
    AlbumSettingsDraft.session.remove(album.id);
    _forgetDraft(repository, MemoryEditorScreen.draftKey(album.id, null));
    for (final memory in memories) {
      MemoryShareDraft.discard(memory.id);
      _forgetDraft(
          repository, MemoryEditorScreen.draftKey(album.id, memory.id));
    }
    unshared.value = ShareRemoval(albumId: album.id);
    return true;
  }

  /// A draft of something deleted; failing to remove it changes nothing.
  static void _forgetDraft(AlbumRepository repository, String key) =>
      repository.deleteMemoryDraft(key).catchError((Object _) {});

  /// A screen of another spec not built yet (E04).
  static Future<void> _standIn(
          BuildContext context, String code, String title) =>
      Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(
          settings: RouteSettings(name: 'album/$code'),
          builder: (_) => _PendingScreen(code: code, title: title)));

  /// A04, then [destination] after the device authentication succeeds.
  static Future<void> unlock(
          BuildContext context, Album album, AlbumDestination destination,
          {String? memoryId}) =>
      _destination(context, album, destination, memoryId: memoryId);

  static Future<Object?> _destination(
      BuildContext context, Album album, AlbumDestination destination,
      {String? memoryId,
      MemoryStartIntent? intent,
      SharedMemoryPost? post,
      bool replace = false,
      bool justSaved = false}) {
    assert(destination != AlbumDestination.memory || memoryId != null);
    assert(destination != AlbumDestination.post || post != null);
    final code = switch (destination) {
      AlbumDestination.start => 'A05',
      AlbumDestination.browse => 'A09',
      AlbumDestination.settings => 'A03',
      AlbumDestination.memory => 'A08',
      AlbumDestination.newMemory => 'A06',
      AlbumDestination.post => 'A12',
    };
    final repository = AlbumScope.of(context);
    final auth = AlbumScope.authOf(context);
    final sharing = AlbumScope.sharingOf(context);
    final photos = AlbumScope.photosOf(context);
    final memorySharing = AlbumScope.memorySharingOf(context);
    final route = MaterialPageRoute<Object?>(
      settings: RouteSettings(
          name: 'album/$code',
          arguments: {'albumId': album.id, 'memoryId': memoryId}),
      builder: (_) => AlbumScope(
          repository: repository,
          auth: auth,
          sharing: sharing,
          photos: photos,
          memorySharing: memorySharing,
          child: Builder(
              builder: (routeContext) => AlbumAccessGuard(
                    albumId: album.id,
                    builder: (current) => switch (destination) {
                      AlbumDestination.settings => AlbumSettingsScreen(
                          album: current,
                          onDelete: () => deleteAlbum(routeContext, current)),
                      AlbumDestination.start ||
                      AlbumDestination.browse =>
                        _StartOrBrowse(
                            album: current,
                            start: AlbumStartScreen(
                                album: current,
                                onStart: (intent) =>
                                    newMemory(routeContext, current, intent)),
                            browse: AlbumBrowseScreen(
                                album: current,
                                onOpen: (memory) => AlbumRoutes.memory(
                                    routeContext, current, memory.id),
                                onAdd: () => newMemory(routeContext, current,
                                    MemoryStartIntent.photo),
                                onSettings: () =>
                                    settings(routeContext, current))),
                      AlbumDestination.newMemory => MemoryEditorScreen(
                          album: current,
                          memoryId: memoryId,
                          intent: intent ?? MemoryStartIntent.photo,
                          onPickPlace: (place) =>
                              pickPlace(routeContext, current, current: place),
                          // New: A08 takes the editor's place. Edited: back
                          // to the A08 it was opened from, which updates.
                          onSaved: (memory) => memoryId == null
                              ? _destination(routeContext, current,
                                  AlbumDestination.memory,
                                  memoryId: memory.id,
                                  replace: true,
                                  justSaved: true)
                              : Navigator.of(routeContext).pop()),
                      AlbumDestination.memory => MemoryDetailScreen(
                          album: current,
                          memoryId: memoryId!,
                          justSaved: justSaved,
                          onEdit: () =>
                              editMemory(routeContext, current, memoryId),
                          onDelete: (memory) =>
                              deleteMemory(routeContext, current, memory),
                          onManagePost: (post) =>
                              managePost(routeContext, current, post),
                          onShare: (memory) =>
                              share(routeContext, current, memory),
                          onPlace: (place) =>
                              _standIn(routeContext, 'E04', place.label)),
                      AlbumDestination.post => ManagePostScreen(
                          album: current,
                          post: post!,
                          // Opened from that memory's A08: back to it.
                          onOpenMemory: () =>
                              Navigator.of(routeContext).pop(false),
                          onShareAgain: (memory) =>
                              share(routeContext, current, memory)),
                    },
                  ))),
    );
    _openRoutes.update(album.id, (n) => n + 1, ifAbsent: () => 1);
    // Leaving the album (its last route gone, after the exit animation so the
    // unlock screen never flashes) locks it again: every visit asks.
    route.completed.then((_) {
      final left = (_openRoutes[album.id] ?? 1) - 1;
      if (left > 0) {
        _openRoutes[album.id] = left;
        return;
      }
      _openRoutes.remove(album.id);
      AlbumAccessGuard.departing.remove(album.id);
      AlbumUnlocks.instance.lock(album.id);
    });
    final navigator = Navigator.of(context, rootNavigator: true);
    return replace
        ? navigator.pushReplacement<Object?, Object?>(route)
        : navigator.push<Object?>(route);
  }

  /// Album routes on the stack, per album; nested ones (A08 → A12) keep the
  /// album open until the outermost one is gone.
  static final _openRoutes = <String, int>{};
}

/// A05 while the album is empty; A09 once it has a memory (even note-only),
/// e.g. on coming back from the first save; back to A05 if all are gone.
class _StartOrBrowse extends StatefulWidget {
  const _StartOrBrowse(
      {required this.album, required this.start, required this.browse});

  final Album album;
  final Widget start;
  final Widget browse;

  @override
  State<_StartOrBrowse> createState() => _StartOrBrowseState();
}

class _StartOrBrowseState extends State<_StartOrBrowse> {
  late bool _empty = widget.album.isEmpty;
  AlbumRepository? _repository;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final repository = AlbumScope.of(context);
    if (repository == _repository) return;
    _repository?.removeListener(_check);
    _repository = repository..addListener(_check);
  }

  Future<void> _check() async {
    final album = await _repository!.album(widget.album.id);
    if (mounted && album != null && album.isEmpty != _empty) {
      setState(() => _empty = album.isEmpty);
    }
  }

  @override
  void dispose() {
    _repository?.removeListener(_check);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _empty ? widget.start : widget.browse;
}

class _PendingScreen extends StatelessWidget {
  const _PendingScreen({required this.code, required this.title});

  final String code;
  final String title;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text('$code đang được dựng.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textPrimary)),
          ),
        ),
      );
}
