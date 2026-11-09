import 'dart:async';

import 'package:ai_diary/core/theme/app_theme.dart';
import 'package:ai_diary/features/album/album_scope.dart';
import 'package:ai_diary/features/album/data/album.dart';
import 'package:ai_diary/features/album/data/album_repository.dart';
import 'package:ai_diary/features/album/data/album_unlocks.dart';
import 'package:ai_diary/features/album/data/memory.dart';
import 'package:ai_diary/features/album/data/memory_photos.dart';
import 'package:ai_diary/features/album/presentation/album_browse_screen.dart';
import 'package:ai_diary/features/album/presentation/album_routes.dart';
import 'package:ai_diary/features/album/presentation/album_start_screen.dart';
import 'package:ai_diary/features/album/presentation/memory_detail_screen.dart';
import 'package:ai_diary/features/album/presentation/memory_editor_screen.dart';
import 'package:ai_diary/features/album/presentation/photo_picker_flow.dart';
import 'package:ai_diary/features/onboarding/presentation/frame_sequence.dart';
import 'package:ai_diary/features/explore/presentation/place_picker_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

typedef _A06 = MemoryEditorScreen;

class _Photos implements MemoryPhotos {
  String? next = '/picked/photo.jpg';
  Completer<String>? gate;
  var failKeep = false;
  var picks = 0;
  var camera = false;
  final sources = <PhotoSource>[];
  PhotoSource? deny;

  @override
  bool get hasCamera => camera;

  @override
  Future<String?> pick([PhotoSource source = PhotoSource.library]) async {
    picks++;
    sources.add(source);
    if (deny == source) throw PhotoAccessDenied(source);
    return next;
  }

  @override
  Future<String> keep(String sourcePath) async {
    if (gate != null) return gate!.future;
    if (failKeep) throw StateError('disk full');
    return '/kept/${sourcePath.split('/').last}';
  }
}

class _Repository extends InMemoryAlbumRepository {
  Completer<void>? saveGate;
  var failSave = false;
  var failDraft = false;
  var creates = 0;

  /// An album this store answers for without holding it (an account one).
  Album? extra;

  @override
  Future<Album?> album(String id) async {
    if (extra case final album? when album.id == id) return album;
    return super.album(id);
  }

  @override
  Future<Memory> createMemory(String albumId, MemoryContent content) async {
    creates++;
    await saveGate?.future;
    if (failSave) throw StateError('offline');
    return super.createMemory(albumId, content);
  }

  @override
  Future<void> saveMemoryDraft(String key, MemoryDraft draft) async {
    if (failDraft) throw StateError('disk full');
    return super.saveMemoryDraft(key, draft);
  }
}

class _Setup {
  _Setup(this.albums, this.album, this.photos);
  final _Repository albums;
  final Album album;
  final _Photos photos;
}

/// A host page with "Mở" opening A06 for a new memory (or [memoryId]).
Future<_Setup> _pump(
  WidgetTester tester, {
  _Repository? repository,
  _Photos? photos,
  String? memoryId,
  Album? album,
  MemoryStartIntent intent = MemoryStartIntent.photo,
  Size size = const Size(390, 844),
  double textScale = 1,
}) async {
  final albums = repository ?? _Repository();
  final target = album ?? await albums.create(name: 'Đà Lạt');
  final picker = photos ?? _Photos();
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  addTearDown(AlbumUnlocks.instance.lockAll);
  addTearDown(AlbumStartScreen.resetPlayed);
  await tester.pumpWidget(AlbumScope(
    repository: albums,
    photos: picker,
    child: MaterialApp(
      theme: AppTheme.light,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: FilledButton(
              onPressed: () => memoryId == null
                  ? AlbumRoutes.newMemory(context, target, intent)
                  : AlbumRoutes.editMemory(context, target, memoryId),
              child: const Text('Mở'),
            ),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('Mở'));
  await tester.pumpAndSettle();
  return _Setup(albums, target, picker);
}

Finder get _note =>
    find.byWidgetPredicate((w) => w is TextField && w.minLines == 5);
Finder get _title => find.byWidgetPredicate(
    (w) => w is TextField && w.decoration?.labelText == _A06.titleLabel);
Finder get _save => find.widgetWithText(FilledButton, _A06.saveLabel);

Future<void> _tapSave(WidgetTester tester) async {
  await tester.tap(_save);
  await tester.pumpAndSettle();
}

/// Taps the photo slot; with [use], "Dùng ảnh" on the preview (A07).
Future<void> _addPhoto(WidgetTester tester, {bool use = true}) async {
  await tester.tap(find.bySemanticsLabel(_A06.addPhotoLabel));
  await tester.pumpAndSettle();
  if (!use) return;
  if (find.text(PhotoPickerFlow.useLabel).evaluate().isEmpty) return;
  await tester.tap(find.text(PhotoPickerFlow.useLabel));
  await tester.pump();
  await tester.pump();
  // Past the preview's exit, without settling the editor's own animations.
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets('Fields: title, 4:3 photo slot, note, date, place, save',
      (tester) async {
    await _pump(tester);
    expect(find.text(_A06.newTitle), findsOneWidget);
    expect(_title, findsOneWidget);
    expect(find.text(_A06.addPhotoLabel), findsOneWidget);
    final slot = tester.getSize(find.bySemanticsLabel(_A06.addPhotoLabel));
    expect(slot.width / slot.height, closeTo(4 / 3, .01));
    expect(find.text(_A06.noteLabel), findsOneWidget);
    final now = DateTime.now();
    expect(
        find.text('${now.day.toString().padLeft(2, '0')}/'
            '${now.month.toString().padLeft(2, '0')}/${now.year}'),
        findsOneWidget);
    expect(find.text(_A06.addPlaceLabel), findsOneWidget);
    expect(_save, findsOneWidget);
    // One add-photo action only; the primary is Save.
    expect(find.text(_A06.addPhotoLabel), findsOneWidget);
  });

  testWidgets('Empty or title only: not a memory, says why', (tester) async {
    final setup = await _pump(tester);
    await _tapSave(tester);
    expect(find.text(_A06.needContent), findsOneWidget);
    await tester.enterText(_title, 'Chỉ có tiêu đề');
    await _tapSave(tester);
    expect(find.text(_A06.needContent), findsOneWidget);
    expect(await setup.albums.memories(setup.album.id), isEmpty);
  });

  testWidgets('Note only: one memory, count 1, then A08 with its id',
      (tester) async {
    final setup = await _pump(tester, intent: MemoryStartIntent.note);
    await tester.enterText(_note, 'Một buổi chiều mát.');
    await _tapSave(tester);
    final memories = await setup.albums.memories(setup.album.id);
    expect(memories, hasLength(1));
    expect(memories.single.content.note, 'Một buổi chiều mát.');
    expect((await setup.albums.album(setup.album.id))!.memoryCount, 1);
    expect(find.byType(MemoryEditorScreen), findsNothing);
    expect(find.byType(MemoryDetailScreen), findsOneWidget);
    final route =
        ModalRoute.of(tester.element(find.byType(MemoryDetailScreen)))!;
    expect((route.settings.arguments as Map)['memoryId'], memories.single.id);
    expect(
        await setup.albums
            .memoryDraft(MemoryEditorScreen.draftKey(setup.album.id, null)),
        isNull,
        reason: 'the draft goes once saved');
  });

  testWidgets('Photo only: picked on tap, kept, saved', (tester) async {
    final setup = await _pump(tester);
    expect(setup.photos.picks, 0, reason: 'nothing asked on open');
    await _addPhoto(tester);
    expect(setup.photos.picks, 1);
    expect(find.byTooltip('Tùy chọn ảnh'), findsOneWidget);
    await _tapSave(tester);
    final memory = (await setup.albums.memories(setup.album.id)).single;
    expect(memory.content.photoPath, '/kept/photo.jpg');
    expect(memory.content.note, isNull);
  });

  testWidgets('Account album: a photo alone asks for a note, saves none',
      (tester) async {
    final now = DateTime(2026, 10, 28);
    final cloud =
        Album(id: 'cloud-5f1c', name: 'Đà Lạt', createdAt: now, updatedAt: now);
    final setup = await _pump(tester,
        repository: _Repository()..extra = cloud, album: cloud);
    await _addPhoto(tester);
    await _tapSave(tester);
    expect(find.text(_A06.needNote), findsOneWidget);
    expect(find.text(_A06.saveFailed), findsNothing);
    expect(setup.albums.creates, 0, reason: 'no save that cannot work');
  });

  testWidgets('Closing the picker keeps the photo slot as it was',
      (tester) async {
    final setup = await _pump(tester);
    setup.photos.next = null;
    await _addPhoto(tester);
    expect(find.text(_A06.addPhotoLabel), findsOneWidget);
  });

  testWidgets('Photo loading: its own state, saving waits', (tester) async {
    final photos = _Photos()..gate = Completer<String>();
    final setup = await _pump(tester, photos: photos);
    await tester.enterText(_note, 'Ghi chú');
    await _addPhoto(tester);
    expect(find.text(_A06.photoLoading), findsOneWidget);
    await tester.tap(_save);
    await tester.pump();
    expect(find.text(_A06.waitPhoto), findsOneWidget);
    expect(await setup.albums.memories(setup.album.id), isEmpty);
    photos.gate!.complete('/kept/late.jpg');
    await tester.pumpAndSettle();
    expect(find.text(_A06.photoLoading), findsNothing);
  });

  testWidgets('Photo failed: Retry or Remove; the note stays', (tester) async {
    final photos = _Photos()..failKeep = true;
    final setup = await _pump(tester, photos: photos);
    await tester.enterText(_note, 'Vẫn còn đây');
    await _addPhoto(tester);
    expect(find.text(_A06.photoFailed), findsOneWidget);
    await tester.tap(_save);
    await tester.pump();
    expect(find.text(_A06.fixPhoto), findsOneWidget);

    photos.failKeep = false;
    await tester.tap(find.text(_A06.retryLabel));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Tùy chọn ảnh'), findsOneWidget);
    expect(setup.photos.picks, 1, reason: 'retry keeps the same pick');
    expect(tester.widget<TextField>(_note).controller!.text, 'Vẫn còn đây');
  });

  testWidgets('Replace and remove from the photo menu', (tester) async {
    await _pump(tester);
    await _addPhoto(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Tùy chọn ảnh'));
    await tester.pumpAndSettle();
    expect(find.text(_A06.replacePhotoLabel), findsOneWidget);
    await tester.tap(find.text(_A06.removePhotoLabel));
    await tester.pumpAndSettle();
    expect(find.text(_A06.addPhotoLabel), findsOneWidget);
  });

  testWidgets('Repeated taps: one save, one memory', (tester) async {
    final albums = _Repository()..saveGate = Completer<void>();
    final setup = await _pump(tester, repository: albums);
    await tester.enterText(_note, 'Một lần thôi');
    await tester.tap(_save);
    await tester.pump();
    // The label gives way to a spinner while saving.
    await tester.tap(find.byType(FilledButton), warnIfMissed: false);
    await tester.pump();
    albums.saveGate!.complete();
    await tester.pumpAndSettle();
    expect(albums.creates, 1);
    expect(await albums.memories(setup.album.id), hasLength(1));
  });

  testWidgets('Save fails: stays with text and photo; retry saves',
      (tester) async {
    final albums = _Repository()..failSave = true;
    final setup = await _pump(tester, repository: albums);
    await tester.enterText(_note, 'Giữ lại');
    await _addPhoto(tester);
    await tester.pumpAndSettle();
    await _tapSave(tester);
    expect(find.text(_A06.saveFailed), findsOneWidget);
    expect(tester.widget<TextField>(_note).controller!.text, 'Giữ lại');
    expect(find.byTooltip('Tùy chọn ảnh'), findsOneWidget);
    albums.failSave = false;
    await _tapSave(tester);
    expect(await albums.memories(setup.album.id), hasLength(1));
  });

  testWidgets('Draft after 800 ms; Back keeps it; reopening restores it',
      (tester) async {
    final setup = await _pump(tester);
    await tester.enterText(_note, 'Nháp dở');
    await tester.pump(const Duration(milliseconds: 900));
    expect(find.text(_A06.draftSaved), findsOneWidget);
    final key = MemoryEditorScreen.draftKey(setup.album.id, null);
    expect((await setup.albums.memoryDraft(key))!.content.note, 'Nháp dở');
    expect(await setup.albums.memories(setup.album.id), isEmpty,
        reason: 'a draft is not a memory');

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(MemoryEditorScreen), findsNothing);
    await tester.tap(find.text('Mở'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(_note).controller!.text, 'Nháp dở');
  });

  testWidgets('Back when the draft cannot be kept: the user decides',
      (tester) async {
    final albums = _Repository()..failDraft = true;
    await _pump(tester, repository: albums);
    await tester.enterText(_note, 'Đừng mất');
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Chưa lưu được bản nháp'), findsOneWidget);
    await tester.tap(find.text('Tiếp tục viết'));
    await tester.pumpAndSettle();
    expect(find.byType(MemoryEditorScreen), findsOneWidget);
    expect(tester.widget<TextField>(_note).controller!.text, 'Đừng mất');

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bỏ thay đổi'));
    await tester.pumpAndSettle();
    expect(find.byType(MemoryEditorScreen), findsNothing);
  });

  testWidgets('Edit: same id and creation time, count unchanged',
      (tester) async {
    final albums = _Repository();
    final album = await albums.create(name: 'Đà Lạt');
    final first = await albums.createMemory(album.id,
        MemoryContent(note: 'Bản đầu', displayDate: DateTime(2026, 10, 1)));
    await _pump(tester,
        repository: albums,
        album: (await albums.album(album.id))!,
        memoryId: first.id);
    expect(find.text(_A06.editTitle), findsOneWidget);
    expect(tester.widget<TextField>(_note).controller!.text, 'Bản đầu');
    await tester.enterText(_note, 'Bản sửa');
    await _tapSave(tester);
    final memories = await albums.memories(album.id);
    expect(memories, hasLength(1));
    expect(memories.single.id, first.id);
    expect(memories.single.createdAt, first.createdAt);
    expect(memories.single.content.note, 'Bản sửa');
    expect(memories.single.content.displayDate, DateTime(2026, 10, 1));
    expect((await albums.album(album.id))!.memoryCount, 1);
  });

  testWidgets('ND09: first note focus writes once, then goes', (tester) async {
    await _pump(tester);
    await tester.tap(_note);
    await tester.pump();
    expect(find.byType(FrameSequence), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1100));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(FrameSequence), findsNothing);
    // Not again on the next focus.
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    await tester.tap(_note);
    await tester.pump();
    expect(find.byType(FrameSequence), findsNothing);
  });

  testWidgets('A new photo comes without Nudaeng; its options are a sheet',
      (tester) async {
    await _pump(tester);
    await _addPhoto(tester);
    expect(find.byType(FrameSequence), findsNothing);
    await tester.tap(find.byTooltip('Tùy chọn ảnh'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.text(_A06.replacePhotoLabel), findsOneWidget);
    expect(find.text(_A06.removePhotoLabel), findsOneWidget);
  });

  testWidgets('First memory from A05: back shows A09, not A05 again',
      (tester) async {
    final albums = _Repository();
    final album = await albums.create(name: 'Đà Lạt');
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
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
                  onPressed: () => AlbumRoutes.open(context, album),
                  child: const Text('Mở')),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('Mở'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AlbumStartScreen.noteFirstLabel));
    await tester.pumpAndSettle();
    await tester.enterText(_note, 'Kỷ niệm đầu tiên');
    await _tapSave(tester);
    expect(find.byType(MemoryDetailScreen), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(AlbumStartScreen), findsNothing);
    expect(find.byType(AlbumBrowseScreen), findsOneWidget);
  });

  group('A07', () {
    testWidgets('no camera: straight to the system picker, then preview',
        (tester) async {
      final setup = await _pump(tester);
      await _addPhoto(tester, use: false);
      expect(find.text(PhotoPickerFlow.libraryLabel), findsNothing);
      expect(setup.photos.sources, [PhotoSource.library]);
      expect(find.text(PhotoPickerFlow.useLabel), findsOneWidget);
      expect(find.text(PhotoPickerFlow.cancelLabel), findsWidgets);
    });

    testWidgets('camera: a sheet with both; camera asked only on tap',
        (tester) async {
      final photos = _Photos()..camera = true;
      await _pump(tester, photos: photos);
      await _addPhoto(tester, use: false);
      expect(find.text(PhotoPickerFlow.libraryLabel), findsOneWidget);
      expect(find.text(PhotoPickerFlow.cameraLabel), findsOneWidget);
      expect(photos.picks, 0, reason: 'nothing opened before a choice');
      await tester.tap(find.text(PhotoPickerFlow.cameraLabel));
      await tester.pumpAndSettle();
      expect(photos.sources, [PhotoSource.camera]);
      await tester.tap(find.text(PhotoPickerFlow.useLabel));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Tùy chọn ảnh'), findsOneWidget);
    });

    testWidgets('closing the source sheet changes nothing', (tester) async {
      final photos = _Photos()..camera = true;
      await _pump(tester, photos: photos);
      await _addPhoto(tester, use: false);
      await tester.tap(find.text(PhotoPickerFlow.cancelLabel));
      await tester.pumpAndSettle();
      expect(photos.picks, 0);
      expect(find.text(_A06.addPhotoLabel), findsOneWidget);
    });

    testWidgets(
        'replace, then cancel the preview: the old photo stays, '
        'no Nudaeng', (tester) async {
      final setup = await _pump(tester);
      await _addPhoto(tester);
      await tester.pump(const Duration(seconds: 2));
      setup.photos.next = '/picked/other.jpg';
      await tester.tap(find.byTooltip('Tùy chọn ảnh'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(_A06.replacePhotoLabel));
      await tester.pumpAndSettle();
      expect(find.text(PhotoPickerFlow.useLabel), findsOneWidget);
      await tester.tap(find.byTooltip(PhotoPickerFlow.cancelLabel));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(FrameSequence), findsNothing, reason: 'no ND08');
      await tester.enterText(_note, 'Có ảnh');
      await _tapSave(tester);
      final memory = (await setup.albums.memories(setup.album.id)).single;
      expect(memory.content.photoPath, '/kept/photo.jpg');
    });

    testWidgets('camera refused: said once, note still works, no loop',
        (tester) async {
      final photos = _Photos()
        ..camera = true
        ..deny = PhotoSource.camera;
      final setup = await _pump(tester, photos: photos);
      await _addPhoto(tester, use: false);
      await tester.tap(find.text(PhotoPickerFlow.cameraLabel));
      await tester.pumpAndSettle();
      expect(find.text(_A06.cameraDenied), findsOneWidget);
      expect(photos.picks, 1);
      expect(find.byType(AlertDialog), findsNothing);
      await tester.enterText(_note, 'Chỉ ghi chú');
      await _tapSave(tester);
      expect((await setup.albums.memories(setup.album.id)).single.content.note,
          'Chỉ ghi chú');
    });
  });

  for (final (size, scale, keyboard) in [
    (const Size(360, 640), 1.0, 280.0),
    (const Size(390, 844), 1.6, 0.0),
    (const Size(430, 932), 1.0, 320.0),
  ]) {
    testWidgets('Save above the keyboard at $size × $scale, kb $keyboard',
        (tester) async {
      await _pump(tester, size: size, textScale: scale);
      tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(tester.getRect(_save).bottom,
          lessThanOrEqualTo(size.height - keyboard));
    });
  }

  testWidgets('Place: E05 search → confirm fills A06; Back keeps it',
      (tester) async {
    final setup = await _pump(tester, intent: MemoryStartIntent.note);
    await tester.enterText(_note, 'Học bài cả chiều');
    await tester.ensureVisible(find.text(_A06.addPlaceLabel));
    await tester.tap(find.text(_A06.addPlaceLabel));
    await tester.pumpAndSettle();
    expect(find.byType(PlacePickerScreen), findsOneWidget);
    await tester.enterText(
        find.widgetWithText(TextField, PlacePickerScreen.searchHint), 'Quiet');
    await tester.pump(PlacePickerScreen.debounce);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Quiet corner'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(PlacePickerScreen.confirmLabel));
    await tester.pumpAndSettle();
    expect(find.byType(PlacePickerScreen), findsNothing);
    expect(find.text('Quiet corner'), findsOneWidget);
    expect(_note, findsOneWidget);
    expect(
        tester.widget<TextField>(_note).controller!.text, 'Học bài cả chiều');

    // Reopened: starts from that place; Back keeps it.
    await tester.tap(find.text('Quiet corner'));
    await tester.pumpAndSettle();
    expect(
        find.descendant(
            of: find.byType(PlacePickerScreen),
            matching: find.text('Quiet corner')),
        findsOneWidget);
    await tester.tap(find.byTooltip(PlacePickerScreen.backTooltip));
    await tester.pumpAndSettle();
    expect(find.text('Quiet corner'), findsOneWidget);

    await _tapSave(tester);
    final memory = (await setup.albums.memories(setup.album.id)).single;
    expect(memory.content.place?.label, 'Quiet corner');
    expect(memory.content.place?.placeId, 'cafe');
    expect(memory.content.place?.named, isTrue);
  });
}
