import 'package:ai_diary/core/theme/app_theme.dart';
import 'package:ai_diary/features/album/album_scope.dart';
import 'package:ai_diary/features/album/data/album.dart';
import 'package:ai_diary/features/album/data/album_repository.dart';
import 'package:ai_diary/features/album/data/album_unlocks.dart';
import 'package:ai_diary/features/album/data/memory.dart';
import 'package:ai_diary/features/album/data/memory_photos.dart';
import 'package:ai_diary/features/album/data/memory_share.dart';
import 'package:ai_diary/features/album/presentation/album_backdrop.dart';
import 'package:ai_diary/features/album/presentation/album_routes.dart';
import 'package:ai_diary/features/album/presentation/album_start_screen.dart';
import 'package:ai_diary/features/album/presentation/confirm_delete_dialog.dart';
import 'package:ai_diary/features/album/presentation/manage_post_screen.dart';
import 'package:ai_diary/features/album/presentation/memory_detail_screen.dart';
import 'package:ai_diary/features/album/presentation/share_memory_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

typedef _A12 = ManagePostScreen;

class _Photos implements MemoryPhotos {
  @override
  bool get hasCamera => false;
  @override
  Future<String?> pick([PhotoSource source = PhotoSource.library]) async =>
      null;
  @override
  Future<String> keep(String sourcePath) async => sourcePath;
}

const _place =
    MemoryPlace(label: 'Hồ Xuân Hương', latitude: 11.94, longitude: 108.44);
const _friends = ShareAudience(id: 'f', label: 'Bạn bè', detail: '12 người');

/// The server: what [post] answers is [latest] (the active post unless a
/// test changes it).
class _Sharing implements MemorySharing {
  SharedMemoryPost? active;
  SharedMemoryPost? latest;
  var latestSet = false;
  bool revokeFails = false;
  bool refreshFails = false;
  var fetched = 0;
  final revoked = <String>[];
  final published = <SharePayload>[];

  void answer(SharedMemoryPost? post) {
    latest = post;
    latestSet = true;
  }

  @override
  Future<List<ShareAudience>> audiences() async => const [_friends];
  @override
  Future<SharedMemoryPost?> activePost(String memoryId) async => active;
  @override
  Future<SharedMemoryPost> publish(SharePayload payload,
      {String? replacing}) async {
    published.add(payload);
    throw const ShareUnavailable();
  }

  @override
  Future<SharedMemoryPost?> post(String postId) async {
    fetched++;
    if (refreshFails) throw StateError('offline');
    return latestSet ? latest : active;
  }

  @override
  Future<SharedMemoryPost> revoke(String postId) async {
    revoked.add(postId);
    if (revokeFails) throw StateError('offline');
    final post = active!;
    active = null;
    return SharedMemoryPost(
        id: post.id,
        payload: post.payload,
        publishedAt: post.publishedAt,
        expiresAt: post.expiresAt,
        revokedAt: DateTime.now());
  }
}

SharedMemoryPost _post(Album album, Memory memory,
        {Duration left = const Duration(hours: 20), DateTime? revokedAt}) =>
    SharedMemoryPost(
      id: 'post-1',
      payload: SharePayload(
        albumId: album.id,
        memoryId: memory.id,
        audience: _friends,
        place: _place,
        category: ShareCategory.food,
        title: 'Chiều ở Đà Lạt',
        text: 'Ly ca cao nóng.',
      ),
      publishedAt: DateTime.now().subtract(const Duration(hours: 4)),
      expiresAt: DateTime.now().add(left),
      revokedAt: revokedAt,
    );

/// A08 of a memory with an active post.
Future<(InMemoryAlbumRepository, Album, Memory, _Sharing)> _open(
    WidgetTester tester) async {
  final albums = InMemoryAlbumRepository();
  final created = await albums.create(name: 'Đà Lạt');
  final memory = await albums.createMemory(
      created.id,
      MemoryContent(
          title: 'Chiều ở Đà Lạt',
          note: 'Riêng tư',
          displayDate: DateTime(2026, 10, 12),
          place: _place));
  final album = (await albums.album(created.id))!;
  final sharing = _Sharing()..active = _post(album, memory);
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.reset);
  addTearDown(AlbumUnlocks.instance.lockAll);
  addTearDown(AlbumStartScreen.resetPlayed);
  addTearDown(() => AlbumRoutes.unshared.value = null);
  addTearDown(MemoryShareDraft.reset);
  await tester.pumpWidget(AlbumScope(
    repository: albums,
    photos: _Photos(),
    memorySharing: sharing,
    child: MaterialApp(
      theme: AppTheme.light,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: FilledButton(
              onPressed: () => AlbumRoutes.memory(context, album, memory.id),
              child: const Text('Mở'),
            ),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('Mở'));
  await tester.pumpAndSettle();
  return (albums, album, memory, sharing);
}

Future<void> _manage(WidgetTester tester) async {
  final manage = find.text(MemoryDetailScreen.manageLabel);
  await tester.ensureVisible(manage);
  await tester.tap(manage);
  await tester.pumpAndSettle();
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('A08 says until when it is shared and leads to A12',
      (tester) async {
    final (_, _, _, sharing) = await _open(tester);
    expect(find.text(MemoryDetailScreen.sharedUntil(sharing.active!.expiresAt)),
        findsOneWidget);
    await _manage(tester);
    expect(find.byType(ManagePostScreen), findsOneWidget);
  });

  testWidgets('A12: snapshot, audience, place, state as text, expiry',
      (tester) async {
    final (_, _, _, sharing) = await _open(tester);
    await _manage(tester);
    final post = sharing.active!;
    expect(find.text(_A12.activeLabel), findsOneWidget);
    expect(find.byIcon(Icons.public_rounded), findsOneWidget);
    expect(find.text(_A12.activeUntil(post.expiresAt)), findsOneWidget);
    // The snapshot as posted, not the private note.
    expect(find.text('Chiều ở Đà Lạt'), findsOneWidget);
    expect(find.text('Ly ca cao nóng.'), findsOneWidget);
    expect(find.text('Riêng tư'), findsNothing);
    expect(find.text('Ăn uống'), findsOneWidget);
    expect(find.text('Bạn bè · 12 người'), findsOneWidget);
    expect(find.text(_place.label), findsNWidgets(2));
    expect(find.text(_A12.revokeLabel), findsOneWidget);
    expect(find.text(_A12.shareAgainLabel), findsNothing);
    // No mascot, no countdown ticking.
    // (The backdrop's figure is hidden here, opacity 0.)
    final images = find.descendant(
        of: find.byType(ManagePostScreen), matching: find.byType(Image));
    final backdrop = find.descendant(
        of: find.descendant(
            of: find.byType(ManagePostScreen),
            matching: find.byType(AlbumBackdrop)),
        matching: find.byType(Image));
    expect(images.evaluate().length, backdrop.evaluate().length);
    expect(
        tester
            .widget<AnimatedOpacity>(find.descendant(
                of: find.descendant(
                    of: find.byType(ManagePostScreen),
                    matching: find.byType(AlbumBackdrop)),
                matching: find.byType(AnimatedOpacity)))
            .opacity,
        0);
    expect(sharing.fetched, 1);
    await tester.pump(const Duration(seconds: 5));
    expect(sharing.fetched, 1);
  });

  testWidgets('Revoke: confirmed, off the map, the memory stays',
      (tester) async {
    final (albums, album, memory, sharing) = await _open(tester);
    await _manage(tester);
    await _tapVisible(tester, find.text(_A12.revokeLabel));
    expect(find.text(_A12.revokeTitle), findsOneWidget);
    expect(find.text(_A12.revokeBody), findsOneWidget);
    // Canceled: still on.
    await tester.tap(find.text(ConfirmDeleteDialog.cancelLabel));
    await tester.pumpAndSettle();
    expect(sharing.revoked, isEmpty);

    await _tapVisible(tester, find.text(_A12.revokeLabel));
    await tester.tap(find.descendant(
        of: find.byType(ConfirmDeleteDialog),
        matching: find.widgetWithText(FilledButton, _A12.revokeLabel)));
    await tester.pumpAndSettle();
    expect(sharing.revoked, ['post-1']);
    // Back on A08: no longer shared, said so; memory and place intact.
    expect(find.byType(ManagePostScreen), findsNothing);
    expect(find.byType(MemoryDetailScreen), findsOneWidget);
    expect(find.text(MemoryDetailScreen.revoked), findsOneWidget);
    expect(find.text(MemoryDetailScreen.manageLabel), findsNothing);
    final kept = await albums.memory(album.id, memory.id);
    expect(kept!.content.place, _place);
    expect(AlbumRoutes.unshared.value?.postId, 'post-1');
  });

  testWidgets('A failed revoke keeps the post and offers Retry',
      (tester) async {
    final (_, _, _, sharing) = await _open(tester);
    sharing.revokeFails = true;
    await _manage(tester);
    await _tapVisible(tester, find.text(_A12.revokeLabel));
    await tester.tap(find.descendant(
        of: find.byType(ConfirmDeleteDialog),
        matching: find.widgetWithText(FilledButton, _A12.revokeLabel)));
    await tester.pumpAndSettle();
    expect(find.text(_A12.revokeFailed), findsOneWidget);
    expect(
        find.descendant(
            of: find.byType(ConfirmDeleteDialog),
            matching: find.text(ConfirmDeleteDialog.retryLabel)),
        findsOneWidget);
    expect(AlbumRoutes.unshared.value, isNull);
  });

  testWidgets('The server says expired: no revoke; Share again opens A10',
      (tester) async {
    final (_, album, memory, sharing) = await _open(tester);
    final expired = _post(album, memory, left: const Duration(minutes: -5));
    sharing.answer(expired);
    await _manage(tester);
    expect(find.text(_A12.expiredLabel), findsOneWidget);
    expect(find.text(_A12.expiredAt(expired.expiresAt)), findsOneWidget);
    expect(find.text(_A12.endedHelp), findsOneWidget);
    expect(find.text(_A12.revokeLabel), findsNothing);
    await _tapVisible(tester, find.text(_A12.shareAgainLabel));
    expect(find.byType(ShareMemorySheet), findsOneWidget);
    // Opening A10 posts nothing.
    expect(sharing.published, isEmpty);
  });

  testWidgets('Revoked elsewhere, and gone from the server', (tester) async {
    final (_, album, memory, sharing) = await _open(tester);
    sharing.answer(_post(album, memory, revokedAt: DateTime(2026, 10, 20, 9)));
    await _manage(tester);
    expect(find.text(_A12.revokedLabel), findsOneWidget);
    expect(
        find.text(_A12.revokedAt(DateTime(2026, 10, 20, 9))), findsOneWidget);

    sharing.answer(null);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text(_A12.goneLabel), findsOneWidget);
  });

  testWidgets('Refreshed on resume and once at expiry, not by the clock alone',
      (tester) async {
    final (_, album, memory, sharing) = await _open(tester);
    sharing.active = _post(album, memory, left: const Duration(minutes: 1));
    sharing.answer(sharing.active);
    await _manage(tester);
    expect(sharing.fetched, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(sharing.fetched, 2);
    // At the expiry time, the server is asked (once).
    sharing.answer(_post(album, memory, left: const Duration(seconds: -1)));
    await tester.pump(const Duration(minutes: 1, seconds: 2));
    await tester.pumpAndSettle();
    expect(sharing.fetched, 3);
    expect(find.text(_A12.expiredLabel), findsOneWidget);
  });

  testWidgets('A failed refresh keeps the last state and says so',
      (tester) async {
    final (_, _, _, sharing) = await _open(tester);
    sharing.refreshFails = true;
    await _manage(tester);
    expect(find.text(_A12.refreshFailed), findsOneWidget);
    expect(find.text(_A12.activeLabel), findsOneWidget);
  });

  testWidgets('"Về kỷ niệm gốc" goes back to the memory', (tester) async {
    await _open(tester);
    await _manage(tester);
    await _tapVisible(tester, find.text(_A12.memoryLabel));
    expect(find.byType(ManagePostScreen), findsNothing);
    expect(find.byType(MemoryDetailScreen), findsOneWidget);
  });
}
