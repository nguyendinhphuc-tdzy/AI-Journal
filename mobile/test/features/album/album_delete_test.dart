import 'dart:async';

import 'package:ai_diary/core/theme/app_theme.dart';
import 'package:ai_diary/features/album/album_scope.dart';
import 'package:ai_diary/features/album/data/album.dart';
import 'package:ai_diary/features/album/data/album_deletion.dart';
import 'package:ai_diary/features/album/data/album_repository.dart';
import 'package:ai_diary/features/album/data/album_sharing.dart';
import 'package:ai_diary/features/album/data/album_unlocks.dart';
import 'package:ai_diary/features/album/data/memory.dart';
import 'package:ai_diary/features/album/data/memory_photos.dart';
import 'package:ai_diary/features/album/data/memory_share.dart';
import 'package:ai_diary/features/album/presentation/album_routes.dart';
import 'package:ai_diary/features/album/presentation/album_settings_screen.dart';
import 'package:ai_diary/features/album/presentation/album_start_screen.dart';
import 'package:ai_diary/features/album/presentation/confirm_delete_dialog.dart';
import 'package:ai_diary/features/album/presentation/memory_detail_screen.dart';
import 'package:ai_diary/features/album/presentation/memory_editor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

typedef _A11 = ConfirmDeleteDialog;

class _Photos implements MemoryPhotos, MemoryPhotoCleanup {
  final discarded = <String>[];
  @override
  bool get hasCamera => false;
  @override
  Future<String?> pick([PhotoSource source = PhotoSource.library]) async =>
      null;
  @override
  Future<String> keep(String sourcePath) async => sourcePath;
  @override
  Future<void> discard(String keptPath) async => discarded.add(keptPath);
}

class _Repository extends InMemoryAlbumRepository {
  bool fail = false;
  Completer<void>? gate;
  final events = <String>[];

  @override
  Future<void> deleteMemory(String albumId, String memoryId) async {
    events.add('delete memory');
    await gate?.future;
    if (fail) throw StateError('disk');
    await super.deleteMemory(albumId, memoryId);
  }

  @override
  Future<void> deleteAlbum(String albumId) async {
    events.add('delete album');
    if (fail) throw StateError('disk');
    await super.deleteAlbum(albumId);
  }
}

/// One fake share service for both the album and the memory side.
class _Sharing implements AlbumSharing, MemorySharing {
  _Sharing(this.events);
  final List<String> events;
  final active = <String, SharedMemoryPost>{};
  bool revokeFails = false;
  bool blocked = false;

  @override
  Future<bool> hasActiveShares(String albumId) async =>
      active.values.any((p) => p.payload.albumId == albumId);
  @override
  Future<void> revokeAll(String albumId) async {
    expect(blocked, isTrue);
    events.add('revoke album');
    if (revokeFails) throw StateError('offline');
    active.removeWhere((_, p) => p.payload.albumId == albumId);
  }

  @override
  Future<T> withPublicationBlocked<T>(
      String albumId, Future<T> Function() action) async {
    blocked = true;
    try {
      return await action();
    } finally {
      blocked = false;
    }
  }

  @override
  Future<List<ShareAudience>> audiences() async => const [];
  @override
  Future<SharedMemoryPost?> activePost(String memoryId) async =>
      active[memoryId];
  @override
  Future<SharedMemoryPost> publish(SharePayload payload, {String? replacing}) =>
      Future.error(const ShareUnavailable());
  @override
  Future<SharedMemoryPost?> post(String postId) async => null;
  @override
  Future<SharedMemoryPost> revoke(String postId) async {
    events.add('revoke $postId');
    if (revokeFails) throw StateError('offline');
    final post = active.values.firstWhere((p) => p.id == postId);
    active.remove(post.memoryId);
    return post;
  }
}

SharedMemoryPost _post(Album album, Memory memory) => SharedMemoryPost(
      id: 'post-${memory.id}',
      payload: SharePayload(
          albumId: album.id,
          memoryId: memory.id,
          audience: const ShareAudience(id: 'f', label: 'Bạn bè'),
          place: const MemoryPlace(
              label: 'Chợ Đà Lạt', latitude: 11.9, longitude: 108.4)),
      publishedAt: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(hours: 20)),
    );

class _Setup {
  _Setup(this.repository, this.sharing, this.photos, this.album, this.memories);
  final _Repository repository;
  final _Sharing sharing;
  final _Photos photos;
  final Album album;
  final List<Memory> memories;
}

/// An album with [count] memories; "Mở" opens [destination] for it.
Future<_Setup> _pump(WidgetTester tester,
    {int count = 2,
    AlbumDestination destination = AlbumDestination.memory}) async {
  final repository = _Repository();
  final sharing = _Sharing(repository.events);
  final photos = _Photos();
  final created = await repository.create(name: 'Đà Lạt');
  final memories = [
    for (var i = 0; i < count; i++)
      await repository.createMemory(
          created.id,
          MemoryContent(
              title: 'Kỷ niệm $i',
              note: 'Ghi chú $i',
              photoPath: '/kept/$i.jpg',
              displayDate: DateTime(2026, 10, 10 + i))),
  ];
  final album = (await repository.album(created.id))!;
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.reset);
  addTearDown(AlbumUnlocks.instance.lockAll);
  addTearDown(AlbumStartScreen.resetPlayed);
  addTearDown(() => AlbumRoutes.unshared.value = null);
  await tester.pumpWidget(AlbumScope(
    repository: repository,
    sharing: sharing,
    memorySharing: sharing,
    photos: photos,
    child: MaterialApp(
      theme: AppTheme.light,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: FilledButton(
              onPressed: () => switch (destination) {
                AlbumDestination.memory =>
                  AlbumRoutes.memory(context, album, memories.first.id),
                AlbumDestination.settings =>
                  AlbumRoutes.settings(context, album),
                _ => AlbumRoutes.open(context, album),
              },
              child: const Text('Mở'),
            ),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('Mở'));
  await tester.pumpAndSettle();
  return _Setup(repository, sharing, photos, album, memories);
}

Future<void> _askDeleteMemory(WidgetTester tester) async {
  await tester.tap(find.byTooltip(MemoryDetailScreen.moreTooltip));
  await tester.pumpAndSettle();
  await tester.tap(find.text(MemoryDetailScreen.deleteLabel));
  await tester.pumpAndSettle();
}

Finder _confirm(String label) => find.descendant(
    of: find.byType(ConfirmDeleteDialog),
    matching: find.widgetWithText(FilledButton, label));

void main() {
  testWidgets('A11 for a memory names it and its album; destructive colour',
      (tester) async {
    final setup = await _pump(tester);
    await _askDeleteMemory(tester);
    expect(
        find.descendant(
            of: find.byType(ConfirmDeleteDialog),
            matching: find.text(_A11.memoryTitle)),
        findsNWidgets(2)); // Title and button.
    expect(find.text(_A11.memoryBody(title: 'Kỷ niệm 0', album: setup.album)),
        findsOneWidget);
    expect(find.textContaining('"Kỷ niệm 0"'), findsOneWidget);
    expect(find.textContaining(_A11.noUndo), findsOneWidget);
    final button = tester.widget<FilledButton>(_confirm(_A11.memoryTitle));
    final colour = button.style!.backgroundColor!.resolve({});
    final scheme =
        Theme.of(tester.element(_confirm(_A11.memoryTitle))).colorScheme;
    expect(colour, scheme.error);
    expect(find.text('Hoàn tác'), findsNothing);

    await tester.tap(find.text(_A11.cancelLabel));
    await tester.pumpAndSettle();
    expect(await setup.repository.memories(setup.album.id), hasLength(2));
    expect(setup.repository.events, isEmpty);
  });

  testWidgets('Delete a memory: its post goes first, then it, then the page',
      (tester) async {
    final setup = await _pump(tester);
    final memory = setup.memories.first;
    setup.sharing.active[memory.id] = _post(setup.album, memory);
    setup.repository.gate = Completer();
    await _askDeleteMemory(tester);
    await tester.tap(_confirm(_A11.memoryTitle));
    await tester.pump();
    // Busy: spinner, Cancel off; a second tap does nothing.
    expect(
        find.descendant(
            of: find.byType(ConfirmDeleteDialog),
            matching: find.byType(CircularProgressIndicator)),
        findsOneWidget);
    expect(
        tester
            .widget<TextButton>(
                find.widgetWithText(TextButton, _A11.cancelLabel))
            .onPressed,
        isNull);
    await tester.tap(find.descendant(
        of: find.byType(ConfirmDeleteDialog),
        matching: find.byType(FilledButton)));
    await tester.pump();
    // Still on screen until the delete is committed.
    expect(find.text('Kỷ niệm 0'), findsWidgets);
    setup.repository.gate!.complete();
    await tester.pump();
    await tester.pump();
    expect(
        setup.repository.events, ['revoke post-${memory.id}', 'delete memory']);
    // Committed: the page fades (180 ms), then closes.
    await tester.pump(const Duration(milliseconds: 90));
    // The page's own fade: 180 ms to nothing.
    expect(
        find.descendant(
            of: find.byType(MemoryDetailScreen),
            matching: find.byWidgetPredicate((w) =>
                w is AnimatedOpacity &&
                w.opacity == 0 &&
                w.duration == const Duration(milliseconds: 180))),
        findsOneWidget);
    expect(find.text(MemoryDetailScreen.gone), findsNothing);
    await tester.pumpAndSettle();
    expect(find.byType(MemoryDetailScreen), findsNothing);
    expect(find.text('Mở'), findsOneWidget);

    final left = await setup.repository.memories(setup.album.id);
    expect(left.map((m) => m.id), [setup.memories[1].id]);
    expect((await setup.repository.album(setup.album.id))!.memoryCount, 1);
    expect(setup.sharing.active, isEmpty);
    expect(setup.photos.discarded, ['/kept/0.jpg']);
    expect(AlbumRoutes.unshared.value?.memoryId, memory.id);
  });

  testWidgets('A failed delete keeps the memory and offers Retry',
      (tester) async {
    final setup = await _pump(tester);
    final memory = setup.memories.first;
    setup.sharing.active[memory.id] = _post(setup.album, memory);
    setup.repository.fail = true;
    await _askDeleteMemory(tester);
    await tester.tap(_confirm(_A11.memoryTitle));
    await tester.pumpAndSettle();
    expect(find.text(AlbumDeletion.memoryRevokedNotDeleted), findsOneWidget);
    expect(find.byType(ConfirmDeleteDialog), findsOneWidget);
    expect(await setup.repository.memories(setup.album.id), hasLength(2));
    expect(setup.photos.discarded, isEmpty);
    expect(AlbumRoutes.unshared.value, isNull);

    setup.repository.fail = false;
    await tester.tap(_confirm(_A11.retryLabel));
    await tester.pumpAndSettle();
    expect(find.byType(MemoryDetailScreen), findsNothing);
    expect(await setup.repository.memories(setup.album.id), hasLength(1));
  });

  testWidgets('Its post cannot be revoked: nothing is deleted', (tester) async {
    final setup = await _pump(tester);
    final memory = setup.memories.first;
    setup.sharing
      ..active[memory.id] = _post(setup.album, memory)
      ..revokeFails = true;
    await _askDeleteMemory(tester);
    await tester.tap(_confirm(_A11.memoryTitle));
    await tester.pumpAndSettle();
    expect(find.text(AlbumDeletion.memoryRevokeFailed), findsOneWidget);
    expect(setup.repository.events, isNot(contains('delete memory')));
    expect(await setup.repository.memories(setup.album.id), hasLength(2));
  });

  testWidgets('From A09: back to the browse with the memory gone',
      (tester) async {
    final setup = await _pump(tester, destination: AlbumDestination.browse);
    await tester.tap(find.text('Kỷ niệm 1').first);
    await tester.pumpAndSettle();
    expect(find.byType(MemoryDetailScreen), findsOneWidget);
    await _askDeleteMemory(tester);
    await tester.tap(_confirm(_A11.memoryTitle));
    await tester.pumpAndSettle();
    expect(find.byType(MemoryDetailScreen), findsNothing);
    expect(find.text('1 kỷ niệm'), findsOneWidget);
    expect(find.text('Kỷ niệm 1'), findsNothing);
    expect(await setup.repository.memories(setup.album.id), hasLength(1));
  });

  testWidgets('A11 for an album says how many memories go with it',
      (tester) async {
    final setup = await _pump(tester, destination: AlbumDestination.settings);
    await tester.scrollUntilVisible(find.text('Xóa album'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Xóa album'));
    await tester.pumpAndSettle();
    expect(find.text(_A11.albumBody(setup.album, 2)), findsOneWidget);
    expect(find.textContaining('2 kỷ niệm'), findsOneWidget);
    await tester.tap(find.text(_A11.cancelLabel));
    await tester.pumpAndSettle();
    expect(await setup.repository.album(setup.album.id), isNotNull);
  });

  testWidgets('Delete an album: posts revoked under the barrier, then all',
      (tester) async {
    final setup = await _pump(tester, destination: AlbumDestination.settings);
    setup.sharing.active[setup.memories.first.id] =
        _post(setup.album, setup.memories.first);
    await setup.repository.saveMemoryDraft(
        MemoryEditorScreen.draftKey(setup.album.id, null),
        MemoryDraft(
            content: MemoryContent(note: 'nháp', displayDate: DateTime(2026)),
            updatedAt: DateTime(2026)));
    await tester.scrollUntilVisible(find.text('Xóa album'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Xóa album'));
    await tester.pumpAndSettle();
    await tester.tap(_confirm(_A11.albumTitle));
    await tester.pump();
    await tester.pump();
    expect(setup.repository.events, ['revoke album', 'delete album']);
    // Leaving: the form fades; never "no longer exists" on the way.
    await tester.pump(const Duration(milliseconds: 90));
    expect(find.text('Album không còn tồn tại.'), findsNothing);
    expect(find.byType(AlbumSettingsScreen), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.byType(AlbumSettingsScreen), findsNothing);
    expect(find.text('Album không còn tồn tại.'), findsNothing);
    expect(find.text('Mở'), findsOneWidget);

    expect(await setup.repository.album(setup.album.id), isNull);
    expect(await setup.repository.albums(), isEmpty);
    expect(setup.sharing.active, isEmpty);
    expect(setup.photos.discarded,
        unorderedEquals(['/kept/0.jpg', '/kept/1.jpg']));
    expect(
        await setup.repository
            .memoryDraft(MemoryEditorScreen.draftKey(setup.album.id, null)),
        isNull);
    expect(AlbumRoutes.unshared.value?.albumId, setup.album.id);
  });

  testWidgets('A failed album delete keeps it all and offers Retry',
      (tester) async {
    final setup = await _pump(tester, destination: AlbumDestination.settings);
    setup.repository.fail = true;
    await tester.scrollUntilVisible(find.text('Xóa album'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Xóa album'));
    await tester.pumpAndSettle();
    await tester.tap(_confirm(_A11.albumTitle));
    await tester.pumpAndSettle();
    expect(find.text(AlbumDeletion.albumFailed), findsOneWidget);
    expect(_confirm(_A11.retryLabel), findsOneWidget);
    expect(await setup.repository.memories(setup.album.id), hasLength(2));
    await tester.tap(find.text(_A11.cancelLabel));
    await tester.pumpAndSettle();
    expect(find.byType(AlbumSettingsScreen), findsOneWidget);
  });
}
