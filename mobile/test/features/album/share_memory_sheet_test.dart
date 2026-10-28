import 'dart:async';
import 'dart:math' as math;

import 'package:ai_diary/core/theme/app_theme.dart';
import 'package:ai_diary/features/album/album_scope.dart';
import 'package:ai_diary/features/album/data/album.dart';
import 'package:ai_diary/features/album/data/album_repository.dart';
import 'package:ai_diary/features/album/data/album_sharing.dart';
import 'package:ai_diary/features/album/data/album_unlocks.dart';
import 'package:ai_diary/features/album/data/memory.dart';
import 'package:ai_diary/features/album/data/memory_photos.dart';
import 'package:ai_diary/features/album/data/memory_share.dart';
import 'package:ai_diary/features/album/presentation/album_form_parts.dart';
import 'package:ai_diary/features/album/presentation/album_routes.dart';
import 'package:ai_diary/features/album/presentation/album_start_screen.dart';
import 'package:ai_diary/features/album/presentation/memory_detail_screen.dart';
import 'package:ai_diary/features/album/presentation/share_memory_sheet.dart';
import 'package:ai_diary/features/explore/presentation/place_picker_screen.dart';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:flutter_test/flutter_test.dart';

typedef _A10 = ShareMemorySheet;

class _Photos implements MemoryPhotos {
  @override
  bool get hasCamera => false;
  @override
  Future<String?> pick([PhotoSource source = PhotoSource.library]) async =>
      null;
  @override
  Future<String> keep(String sourcePath) async => sourcePath;
}

const _friends =
    ShareAudience(id: 'friends', label: 'Bạn bè', detail: '12 người');
const _family = ShareAudience(id: 'family', label: 'Gia đình');
const _place =
    MemoryPlace(label: 'Hồ Xuân Hương', latitude: 11.94, longitude: 108.44);
const _note = 'Trời se lạnh, ly ca cao nóng. Chuyện riêng không kể ai.';

class _Sharing implements MemorySharing {
  List<ShareAudience> list = const [_friends, _family];
  SharedMemoryPost? active;
  bool audiencesFail = false;
  Object? failWith;
  Completer<void>? gate;
  final published = <(SharePayload, String?)>[];

  @override
  Future<List<ShareAudience>> audiences() async {
    if (audiencesFail) throw StateError('offline');
    return list;
  }

  @override
  Future<SharedMemoryPost?> activePost(String memoryId) async => active;

  @override
  Future<SharedMemoryPost?> post(String postId) async => null;

  @override
  Future<SharedMemoryPost> revoke(String postId) =>
      Future.error(const ShareUnavailable());

  @override
  Future<SharedMemoryPost> publish(SharePayload payload,
      {String? replacing}) async {
    published.add((payload, replacing));
    await gate?.future;
    if (failWith case final error?) throw error;
    return SharedMemoryPost(
      id: 'post-${published.length}',
      payload: payload,
      publishedAt: DateTime(2026, 10, 20, 14, 5),
      expiresAt: DateTime(2026, 10, 21, 14, 5),
    );
  }
}

/// A08 for a memory, then A10 over it.
Future<(InMemoryAlbumRepository, Album, Memory)> _open(
  WidgetTester tester, {
  MemorySharing? sharing,
  MemoryContent? content,
  Size size = const Size(390, 844),
  double textScale = 1,
}) async {
  final albums = InMemoryAlbumRepository();
  final album = await albums.create(name: 'Đà Lạt');
  final memory = await albums.createMemory(
      album.id,
      content ??
          MemoryContent(
            title: 'Chiều ở Đà Lạt',
            note: _note,
            photoPath: '/kept/photo.jpg',
            displayDate: DateTime(2026, 10, 12),
            place: _place,
          ));
  final current = (await albums.album(album.id))!;
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  addTearDown(AlbumUnlocks.instance.lockAll);
  addTearDown(AlbumStartScreen.resetPlayed);
  addTearDown(MemoryShareDraft.reset);
  addTearDown(() => AlbumRoutes.published.value = null);
  await tester.pumpWidget(AlbumScope(
    repository: albums,
    photos: _Photos(),
    memorySharing: sharing ?? const NoAlbumPublishing(),
    child: MaterialApp(
      theme: AppTheme.light,
      builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!),
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
  await tester.tap(find.text('Mở'));
  await tester.pumpAndSettle();
  await _share(tester);
  return (albums, current, memory);
}

Future<void> _share(WidgetTester tester) async {
  final share = find.text(MemoryDetailScreen.shareLabel);
  await tester.ensureVisible(share);
  await tester.tap(share);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Finder _inSheet(Finder finder) =>
    find.descendant(of: find.byType(ShareMemorySheet), matching: finder);

Finder get _cta =>
    _inSheet(find.widgetWithText(FilledButton, _A10.publishLabel));

bool _enabled(WidgetTester tester, Finder button) =>
    tester.widget<FilledButton>(button).onPressed != null;

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _choose(WidgetTester tester,
    {bool audience = true, bool place = true}) async {
  if (audience) await _tapVisible(tester, _inSheet(find.text('Bạn bè')));
  if (place) {
    await _tapVisible(
        tester, _inSheet(find.text(_A10.useMemoryPlace(_place.label))));
  }
}

void main() {
  testWidgets('Order: title, preview, audience, place, category, text, expiry',
      (tester) async {
    await _open(tester, sharing: _Sharing());
    final labels = [
      _A10.title,
      _A10.previewLabel,
      _A10.audienceLabel,
      _A10.placeLabel,
      _A10.categoryLabel,
      _A10.textLabel,
      _A10.expiry,
    ];
    double top(String text) =>
        tester.getTopLeft(_inSheet(find.text(text)).first).dy;
    for (var i = 1; i < labels.length; i++) {
      expect(top(labels[i]), greaterThan(top(labels[i - 1])),
          reason: labels[i]);
    }
    expect(find.byTooltip(_A10.closeTooltip), findsOneWidget);
    // The CTA is docked, visible without scrolling.
    expect(_cta.hitTestable(), findsOneWidget);
    // Audiences named as the service names them.
    expect(_inSheet(find.text('Bạn bè')), findsOneWidget);
    expect(_inSheet(find.text('12 người')), findsOneWidget);
    expect(_inSheet(find.text('Gia đình')), findsOneWidget);
  });

  testWidgets('The private note is not copied; nothing is preselected',
      (tester) async {
    await _open(tester, sharing: _Sharing());
    final field = tester.widget<TextField>(_inSheet(find.byType(TextField)));
    expect(field.controller!.text, isEmpty);
    expect(_inSheet(find.text(_note)), findsNothing);
    // Preview: the photo and title of the memory, no place yet, no category.
    expect(
        _inSheet(find.byWidgetPredicate((w) =>
            w is Semantics && w.properties.label == 'Ảnh sẽ được chia sẻ')),
        findsOneWidget);
    expect(_inSheet(find.text('Chiều ở Đà Lạt')), findsOneWidget);
    expect(_inSheet(find.text(_A10.placeNone)), findsNWidgets(2));
    expect(_inSheet(find.text(ShareCategory.uncategorized)), findsOneWidget);
    expect(_enabled(tester, _cta), isFalse);
    expect(_inSheet(find.text(_A10.needs([_A10.needAudience, _A10.needPlace]))),
        findsOneWidget);
  });

  testWidgets('Enabled with audience and a confirmed place; photo-only text',
      (tester) async {
    await _open(tester, sharing: _Sharing());
    await _choose(tester, place: false);
    expect(_enabled(tester, _cta), isFalse);
    expect(_inSheet(find.text(_A10.needs([_A10.needPlace]))), findsOneWidget);
    await _choose(tester, audience: false);
    expect(_enabled(tester, _cta), isTrue);
    // The place shows in the preview and in its section.
    expect(_inSheet(find.text(_place.label)), findsNWidgets(2));
    expect(
        _inSheet(find.text(_A10.useMemoryPlace(_place.label))), findsNothing);
  });

  testWidgets('Category: none is "Chưa phân loại", never Food by default',
      (tester) async {
    await _open(tester, sharing: _Sharing());
    final food = _inSheet(find.widgetWithText(ChoiceChip, 'Ăn uống'));
    expect(tester.widget<ChoiceChip>(food).selected, isFalse);
    await _tapVisible(tester, food);
    expect(tester.widget<ChoiceChip>(food).selected, isTrue);
    expect(_inSheet(find.text(ShareCategory.uncategorized)), findsNothing);
    await _tapVisible(tester, food);
    expect(tester.widget<ChoiceChip>(food).selected, isFalse);
    expect(_inSheet(find.text(ShareCategory.uncategorized)), findsOneWidget);
  });

  testWidgets('Note-only needs chosen text; a passage of the note can be added',
      (tester) async {
    final sharing = _Sharing();
    await _open(tester,
        sharing: sharing,
        content: MemoryContent(
            note: _note, displayDate: DateTime(2026, 10, 12), place: _place));
    await _choose(tester);
    expect(_enabled(tester, _cta), isFalse);
    expect(_inSheet(find.text(_A10.previewEmpty)), findsOneWidget);
    expect(_inSheet(find.text(_A10.needs([_A10.needText]))), findsOneWidget);

    await _tapVisible(tester, _inSheet(find.text(_A10.notePick)));
    expect(_inSheet(find.text(_A10.notePrivate)), findsOneWidget);
    final add = _inSheet(find.widgetWithText(FilledButton, _A10.noteAdd));
    expect(tester.widget<FilledButton>(add).onPressed, isNull);
    // Select "ly ca cao nóng." only.
    const passage = 'ly ca cao nóng.';
    final start = _note.indexOf(passage);
    tester
            .widget<SelectableText>(_inSheet(find.byType(SelectableText)))
            .onSelectionChanged!(
        TextSelection(baseOffset: start, extentOffset: start + passage.length),
        SelectionChangedCause.drag);
    await tester.pump();
    await _tapVisible(tester, add);
    expect(
        tester
            .widget<TextField>(_inSheet(find.byType(TextField)))
            .controller!
            .text,
        passage);
    // The preview shows exactly that (and the field holds it); the rest of
    // the note stays private.
    expect(_inSheet(find.text(passage)), findsNWidgets(2));
    await _tapVisible(tester, _inSheet(find.text(_A10.noteHide)));
    expect(_inSheet(find.textContaining('Chuyện riêng')), findsNothing);
    expect(_enabled(tester, _cta), isTrue);

    await _tapVisible(tester, _cta);
    final (payload, _) = sharing.published.single;
    expect(payload.text, passage);
    expect(payload.photoPath, isNull);
  });

  testWidgets('Close keeps the choices for the session and posts nothing',
      (tester) async {
    final sharing = _Sharing();
    await _open(tester, sharing: sharing);
    await _choose(tester);
    await tester.enterText(_inSheet(find.byType(TextField)), 'Ghé đây nhé');
    await tester.tap(find.byTooltip(_A10.closeTooltip));
    await tester.pumpAndSettle();
    expect(find.byType(ShareMemorySheet), findsNothing);
    expect(sharing.published, isEmpty);

    await _share(tester);
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<TextField>(_inSheet(find.byType(TextField)))
            .controller!
            .text,
        'Ghé đây nhé');
    expect(_inSheet(find.text(_place.label)), findsNWidgets(2));
    expect(_enabled(tester, _cta), isTrue);
    expect(sharing.published, isEmpty);
  });

  testWidgets('E05 from A10: Back keeps the sheet; confirm posts nothing',
      (tester) async {
    final sharing = _Sharing();
    await _open(tester, sharing: sharing);
    await _choose(tester, place: false);
    await _tapVisible(tester, _inSheet(find.text(_A10.pickPlace)));
    expect(find.byType(PlacePickerScreen), findsOneWidget);
    await tester.tap(find.byTooltip(PlacePickerScreen.backTooltip));
    await tester.pumpAndSettle();
    expect(find.byType(ShareMemorySheet), findsOneWidget);
    // Back from E05: no place (as before); the audience kept.
    expect(_inSheet(find.text(_A10.placeNone)), findsNWidgets(2));
    final tile = tester
        .widget<ListTile>(_inSheet(find.widgetWithText(ListTile, 'Bạn bè')));
    expect(tile.selected, isTrue);

    // A pin with no name (no lookup service), named by the user.
    await _tapVisible(tester, _inSheet(find.text(_A10.pickPlace)));
    tester.widget<MapLibreMap>(find.byType(MapLibreMap)).onMapClick!(
        const math.Point(10, 10), const LatLng(10.77, 106.7));
    await tester.pumpAndSettle();
    expect(find.text(PlacePickerScreen.lookupFailed), findsOneWidget);
    await tester.enterText(
        find.widgetWithText(TextField, PlacePickerScreen.nameLabel),
        'Góc quán quen');
    await tester.tap(find.text(PlacePickerScreen.confirmLabel));
    await tester.pumpAndSettle();
    expect(find.byType(PlacePickerScreen), findsNothing);
    expect(_inSheet(find.text('Góc quán quen')), findsNWidgets(2));
    // Confirming a place is not publishing: back to the preview.
    expect(sharing.published, isEmpty);
    expect(_enabled(tester, _cta), isTrue);
  });

  testWidgets('An unnamed place says so in the section and the preview',
      (tester) async {
    await _open(tester, sharing: _Sharing());
    await _tapVisible(tester, _inSheet(find.text(_A10.pickPlace)));
    tester.widget<MapLibreMap>(find.byType(MapLibreMap)).onMapClick!(
        const math.Point(10, 10), const LatLng(10.77, 106.7));
    await tester.pumpAndSettle();
    await tester.tap(find.text(PlacePickerScreen.confirmLabel));
    await tester.pumpAndSettle();
    final label = MemoryPlace.unnamedLabel(10.77, 106.7);
    expect(_inSheet(find.text(label)), findsNWidgets(2));
    expect(_inSheet(find.text(_A10.placeUnnamed)), findsOneWidget);
  });

  testWidgets('Publishing: one post for repeated taps, then check, then map',
      (tester) async {
    final sharing = _Sharing()..gate = Completer();
    final (_, album, memory) = await _open(tester, sharing: sharing);
    await _choose(tester);
    await _tapVisible(
        tester, _inSheet(find.widgetWithText(ChoiceChip, 'Giải trí')));
    await tester.enterText(_inSheet(find.byType(TextField)), '  Ghé đây nhé  ');
    await tester.ensureVisible(_cta);
    await tester.tap(_cta);
    await tester.pump();
    // Repeated tap on the busy button.
    await tester.tap(_inSheet(find.byType(AlbumPrimaryButton)));
    await tester.pump();
    expect(sharing.published, hasLength(1));
    // Busy: a spinner in the button, the form kept, Close off.
    expect(_inSheet(find.byType(CircularProgressIndicator)), findsOneWidget);
    expect(_inSheet(find.text('  Ghé đây nhé  ')), findsOneWidget);
    expect(
        tester
            .widget<IconButton>(_inSheet(find.byType(IconButton)).first)
            .onPressed,
        isNull);

    final (payload, replacing) = sharing.published.single;
    expect(payload.albumId, album.id);
    expect(payload.memoryId, memory.id);
    expect(payload.audience, _friends);
    expect(payload.place, _place);
    expect(payload.category, ShareCategory.entertainment);
    expect(payload.title, 'Chiều ở Đà Lạt');
    expect(payload.photoPath, '/kept/photo.jpg');
    expect(payload.text, 'Ghé đây nhé');
    expect(replacing, isNull);

    sharing.gate!.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(_inSheet(find.text(_A10.published)), findsOneWidget);
    expect(
        _inSheet(find.text(_A10.expiresLabel(DateTime(2026, 10, 21, 14, 5)))),
        findsOneWidget);
    expect(AlbumRoutes.published.value, isNull);
    await tester.pump(_A10.successHold);
    await tester.pumpAndSettle();
    // Album routes closed; the post goes to the library (and the map).
    expect(find.byType(ShareMemorySheet), findsNothing);
    expect(find.byType(MemoryDetailScreen), findsNothing);
    expect(AlbumRoutes.published.value?.id, 'post-1');
    expect(
        AlbumRoutes.published.value?.expiresAt, DateTime(2026, 10, 21, 14, 5));
    // Shared: the draft is gone.
    expect(MemoryShareDraft.of(memory.id).audienceId, isNull);
  });

  testWidgets('A failure keeps the form and offers Retry', (tester) async {
    final sharing = _Sharing()..failWith = StateError('500');
    await _open(tester, sharing: sharing);
    await _choose(tester);
    await _tapVisible(tester, _cta);
    expect(_inSheet(find.text(_A10.failed)), findsOneWidget);
    expect(find.byType(ShareMemorySheet), findsOneWidget);
    final retry = _inSheet(find.widgetWithText(FilledButton, _A10.retryLabel));
    expect(retry, findsOneWidget);
    expect(_inSheet(find.text(_place.label)), findsNWidgets(2));
    expect(AlbumRoutes.published.value, isNull);

    sharing.failWith = null;
    await _tapVisible(tester, retry);
    expect(sharing.published, hasLength(2));
    await tester.pump(_A10.successHold);
    await tester.pumpAndSettle();
    expect(AlbumRoutes.published.value?.id, 'post-2');
  });

  testWidgets('No share service: no audience, never said to be shared',
      (tester) async {
    await _open(tester);
    expect(_inSheet(find.text(_A10.audienceNone)), findsOneWidget);
    expect(_inSheet(find.text(_A10.noService)), findsOneWidget);
    // Who will see it, shown ahead but not selectable.
    final friends = find.widgetWithText(ListTile, _A10.friendsLabel);
    expect(_inSheet(friends), findsOneWidget);
    expect(tester.widget<ListTile>(friends).enabled, isFalse);
    expect(_inSheet(find.text(_A10.soonLabel)), findsOneWidget);
    expect(_enabled(tester, _cta), isFalse);
  });

  testWidgets('Service unavailable at publish says nothing was shared',
      (tester) async {
    final sharing = _Sharing()..failWith = const ShareUnavailable();
    await _open(tester, sharing: sharing);
    await _choose(tester);
    await _tapVisible(tester, _cta);
    expect(_inSheet(find.text(_A10.unavailable)), findsOneWidget);
    expect(_inSheet(find.text(_A10.published)), findsNothing);
    expect(AlbumRoutes.published.value, isNull);
  });

  testWidgets('Audiences that fail to load offer Retry', (tester) async {
    final sharing = _Sharing()..audiencesFail = true;
    await _open(tester, sharing: sharing);
    expect(_inSheet(find.text(_A10.audienceFailed)), findsOneWidget);
    expect(_enabled(tester, _cta), isFalse);
    sharing.audiencesFail = false;
    await _tapVisible(
        tester, _inSheet(find.widgetWithText(TextButton, _A10.retryLabel)));
    expect(_inSheet(find.text('Bạn bè')), findsOneWidget);
  });

  testWidgets('An active post: says it is replaced, with a new expiry',
      (tester) async {
    final sharing = _Sharing();
    final old = SharedMemoryPost(
      id: 'old',
      payload: const SharePayload(
          albumId: 'a', memoryId: 'm', audience: _friends, place: _place),
      publishedAt: DateTime.now().subtract(const Duration(hours: 2)),
      expiresAt: DateTime.now().add(const Duration(hours: 22)),
    );
    sharing.active = old;
    await _open(tester, sharing: sharing);
    expect(_inSheet(find.text(_A10.replaces(old.expiresAt))), findsOneWidget);
    // Opening the sheet changed nothing.
    expect(sharing.published, isEmpty);
    await _choose(tester);
    await _tapVisible(tester, _cta);
    expect(sharing.published.single.$2, 'old');
    expect(_inSheet(find.text(_A10.replaced)), findsOneWidget);
    expect(
        _inSheet(find.text(_A10.expiresLabel(DateTime(2026, 10, 21, 14, 5)))),
        findsOneWidget);
  });

  testWidgets('Locked since opening: nothing is posted', (tester) async {
    final sharing = _Sharing();
    final (albums, album, _) = await _open(tester, sharing: sharing);
    await _choose(tester);
    await albums.updateSettings(album.id,
        name: album.name, themeId: album.themeId, locked: true);
    await _tapVisible(tester, _cta);
    expect(sharing.published, isEmpty);
  });

  testWidgets('Small screen, large text: scrolls, CTA docked, no overflow',
      (tester) async {
    await _open(tester,
        sharing: _Sharing(), size: const Size(320, 568), textScale: 2);
    expect(tester.takeException(), isNull);
    expect(_cta.hitTestable(), findsOneWidget);
    // The form (the first scroll view) scrolls to its end.
    final hint =
        _inSheet(find.text(_A10.needs([_A10.needAudience, _A10.needPlace])));
    await tester.scrollUntilVisible(hint, 200,
        scrollable: find
            .descendant(
                of: _inSheet(find.byType(SingleChildScrollView)).first,
                matching: find.byType(Scrollable))
            .first);
    await tester.pumpAndSettle();
    // The hint sits at the end of the form, right above the CTA.
    expect(hint.hitTestable(), findsOneWidget);
    expect(_cta.hitTestable(), findsOneWidget);
    // The form keeps at least a third of the sheet.
    expect(
        tester
            .getSize(_inSheet(find.byType(SingleChildScrollView)).first)
            .height,
        greaterThan(tester.getSize(find.byType(ShareMemorySheet)).height / 3));
    expect(tester.takeException(), isNull);
  });
}
