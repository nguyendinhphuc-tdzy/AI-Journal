import 'package:ai_diary/core/theme/app_theme.dart';
import 'package:ai_diary/features/album/album_scope.dart';
import 'package:ai_diary/features/album/data/album.dart';
import 'package:ai_diary/features/album/data/album_repository.dart';
import 'package:ai_diary/features/album/data/album_unlocks.dart';
import 'package:ai_diary/features/album/data/memory.dart';
import 'package:ai_diary/features/album/data/memory_photos.dart';
import 'package:ai_diary/features/album/presentation/album_routes.dart';
import 'package:ai_diary/features/album/presentation/album_start_screen.dart';
import 'package:ai_diary/features/album/presentation/memory_detail_screen.dart';
import 'package:ai_diary/features/album/presentation/memory_editor_screen.dart';
import 'package:ai_diary/features/album/presentation/share_memory_sheet.dart';
import 'package:ai_diary/features/onboarding/presentation/frame_sequence.dart';
import 'package:ai_diary/features/album/presentation/confirm_delete_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

typedef _A08 = MemoryDetailScreen;

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

/// Opens A08 for a memory with [content] in an album (locked if asked and
/// already unlocked for the session).
Future<(AlbumRepository, Album, Memory)> _pump(
  WidgetTester tester, {
  MemoryContent? content,
  bool locked = false,
  Size size = const Size(390, 844),
  bool open = true,
}) async {
  final albums = InMemoryAlbumRepository();
  final album = await albums.create(name: 'Đà Lạt', locked: locked);
  final memory = await albums.createMemory(
      album.id,
      content ??
          MemoryContent(
            title: 'Chiều ở Đà Lạt',
            note: 'Trời se lạnh, ly ca cao nóng.',
            photoPath: '/kept/photo.jpg',
            displayDate: DateTime(2026, 10, 12),
            place: _place,
          ));
  final current = (await albums.album(album.id))!;
  if (locked) AlbumUnlocks.instance.unlock(album.id);
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  addTearDown(AlbumUnlocks.instance.lockAll);
  addTearDown(AlbumStartScreen.resetPlayed);
  await tester.pumpWidget(AlbumScope(
    repository: albums,
    photos: _Photos(),
    child: MaterialApp(
      theme: AppTheme.light,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: FilledButton(
              onPressed: () => AlbumRoutes.memory(context, current, memory.id),
              child: const Text('Mở'),
            ),
          ),
        ),
      ),
    ),
  ));
  if (open) {
    await tester.tap(find.text('Mở'));
    await tester.pumpAndSettle();
  }
  return (albums, current, memory);
}

Finder get _photo => find.byWidgetPredicate(
    (w) => w is Semantics && w.properties.label == 'Ảnh của kỷ niệm');

void main() {
  testWidgets('Title, date chip, whole photo, note, place, share',
      (tester) async {
    await _pump(tester);
    expect(find.byTooltip(_A08.moreTooltip), findsOneWidget);
    expect(find.text('Chiều ở Đà Lạt'), findsOneWidget);
    expect(find.text('12/10/2026'), findsOneWidget);
    expect(_photo, findsOneWidget);
    final image = tester.widget<Image>(
        find.descendant(of: _photo, matching: find.byType(Image)));
    expect(image.fit, BoxFit.contain, reason: 'never cropped');
    expect(find.text('Trời se lạnh, ly ca cao nóng.'), findsOneWidget);
    expect(find.text('Hồ Xuân Hương'), findsOneWidget);
    expect(find.text(_A08.shareLabel), findsOneWidget);
  });

  testWidgets('Nudaeng is outside the photo, never on it', (tester) async {
    await _pump(tester);
    final photo = tester.getRect(_photo);
    final mascot = tester.getRect(find.byWidgetPredicate((w) =>
        w is Image &&
        w.image is AssetImage &&
        (w.image as AssetImage).assetName == _A08.savedFrames.last));
    expect(mascot.overlaps(photo), isFalse);
  });

  testWidgets('Note only: no photo placeholder, the note on paper',
      (tester) async {
    await _pump(tester,
        content: MemoryContent(
            note: 'Chỉ vài dòng thôi.', displayDate: DateTime(2026, 10, 1)));
    expect(_photo, findsNothing);
    expect(find.text('Chỉ vài dòng thôi.'), findsOneWidget);
    expect(find.text('01/10/2026'), findsOneWidget);
  });

  testWidgets('Locked album: no share, says why', (tester) async {
    await _pump(tester, locked: true);
    expect(find.text(_A08.shareLabel), findsNothing);
    expect(find.text(_A08.lockedShare), findsOneWidget);
  });

  testWidgets('Long note scrolls; nothing overflows', (tester) async {
    await _pump(tester,
        size: const Size(360, 640),
        content: MemoryContent(
            note: List.filled(80, 'Một dòng dài về buổi chiều hôm ấy.')
                .join('\n'),
            displayDate: DateTime(2026, 10, 1)));
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(find.text(_A08.shareLabel), 300,
        scrollable: find.byType(Scrollable).first);
    expect(find.text(_A08.shareLabel), findsOneWidget);
  });

  testWidgets('Reopened: Nudaeng still, no animation', (tester) async {
    await _pump(tester);
    expect(find.byType(FrameSequence), findsNothing);
  });

  testWidgets('Right after creating: ND11 plays once (about 1.6 s)',
      (tester) async {
    final albums = InMemoryAlbumRepository();
    final album = await albums.create(name: 'Đà Lạt');
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(AlbumScope(
      repository: albums,
      photos: _Photos(),
      child: MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () =>
                  AlbumRoutes.newMemory(context, album, MemoryStartIntent.note),
              child: const Text('Mở'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('Mở'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byWidgetPredicate((w) => w is TextField && w.minLines == 5),
        'Mới lưu');
    await tester.tap(find.text(MemoryEditorScreen.saveLabel));
    await tester.pumpAndSettle();
    expect(find.byType(MemoryDetailScreen), findsOneWidget);
    // The sequence (played, then holding its last frame), not the still pose.
    expect(find.byType(FrameSequence), findsOneWidget);
    expect(_A08.savedDurations.fold(Duration.zero, (a, b) => a + b),
        const Duration(milliseconds: 1620));
  });

  testWidgets('Edit: back to this A08, updated, ND11 again; one A08',
      (tester) async {
    final (albums, album, memory) = await _pump(tester);
    await tester.tap(find.byTooltip(_A08.moreTooltip));
    await tester.pumpAndSettle();
    await tester.tap(find.text(_A08.editLabel));
    await tester.pumpAndSettle();
    expect(find.text(MemoryEditorScreen.editTitle), findsOneWidget);
    await tester.enterText(
        find.byWidgetPredicate((w) => w is TextField && w.minLines == 5),
        'Đã sửa');
    await tester.tap(find.text(MemoryEditorScreen.saveLabel));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(MemoryEditorScreen), findsNothing);
    expect(
        find.byType(MemoryDetailScreen, skipOffstage: false), findsOneWidget);
    expect(find.text('Đã sửa'), findsOneWidget);
    expect(find.byType(FrameSequence), findsOneWidget);
    final saved = (await albums.memories(album.id)).single;
    expect(saved.id, memory.id);
  });

  testWidgets('More → Delete opens A11; place chip → E04; share → A10',
      (tester) async {
    await _pump(tester);
    await tester.tap(find.byTooltip(_A08.moreTooltip));
    await tester.pumpAndSettle();
    await tester.tap(find.text(_A08.deleteLabel));
    await tester.pumpAndSettle();
    expect(find.byType(ConfirmDeleteDialog), findsOneWidget);
    await tester.tap(find.text(ConfirmDeleteDialog.cancelLabel));
    await tester.pumpAndSettle();
    expect(find.text('Chiều ở Đà Lạt'), findsOneWidget);

    await tester.tap(find.text('Hồ Xuân Hương'));
    await tester.pumpAndSettle();
    expect(find.text('E04 đang được dựng.'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text(_A08.shareLabel));
    await tester.tap(find.text(_A08.shareLabel));
    await tester.pumpAndSettle();
    expect(find.text(ShareMemorySheet.title), findsOneWidget);
  });

  testWidgets('A memory that is gone says so', (tester) async {
    final (albums, album, memory) = await _pump(tester, open: false);
    await tester.tap(find.text('Mở'));
    await tester.pumpAndSettle();
    expect(find.byType(MemoryDetailScreen), findsOneWidget);
    // Not deletable yet (A11); check the empty state with an unknown id.
    final missing = AlbumRoutes.memory(
        tester.element(find.byType(MemoryDetailScreen)), album, 'nope');
    await tester.pumpAndSettle();
    expect(find.text(_A08.gone), findsOneWidget);
    expect(memory.id, isNot('nope'));
    expect(albums, isNotNull);
    expect(missing, isNotNull);
  });
}
