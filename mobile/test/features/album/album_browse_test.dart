import 'package:ai_diary/core/theme/app_theme.dart';
import 'package:ai_diary/features/album/album_scope.dart';
import 'package:ai_diary/features/album/data/album.dart';
import 'package:ai_diary/features/album/data/album_repository.dart';
import 'package:ai_diary/features/album/data/album_unlocks.dart';
import 'package:ai_diary/features/album/data/memory.dart';
import 'package:ai_diary/features/album/data/memory_photos.dart';
import 'package:ai_diary/features/album/presentation/album_browse_screen.dart';
import 'package:ai_diary/features/album/presentation/album_routes.dart';
import 'package:ai_diary/features/album/presentation/album_settings_screen.dart';
import 'package:ai_diary/features/album/presentation/memory_detail_screen.dart';
import 'package:ai_diary/features/album/presentation/memory_editor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

typedef _A09 = AlbumBrowseScreen;

class _Photos implements MemoryPhotos {
  @override
  bool get hasCamera => false;
  @override
  Future<String?> pick([PhotoSource source = PhotoSource.library]) async =>
      null;
  @override
  Future<String> keep(String sourcePath) async => sourcePath;
}

/// An album with notes "Kỷ niệm 1…[count]", day i in October (1 = oldest).
Future<(AlbumRepository, Album)> _pump(
  WidgetTester tester, {
  int count = 3,
  Size size = const Size(390, 844),
  double textScale = 1,
}) async {
  final albums = InMemoryAlbumRepository();
  final created = await albums.create(name: 'Đà Lạt');
  for (var i = 1; i <= count; i++) {
    await albums.createMemory(
        created.id,
        MemoryContent(
            title: 'Kỷ niệm $i',
            note: 'Ghi chú số $i',
            displayDate: DateTime(2026, 10, (i - 1) % 28 + 1)));
  }
  final album = (await albums.album(created.id))!;
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  addTearDown(AlbumUnlocks.instance.lockAll);
  await tester.pumpWidget(AlbumScope(
    repository: albums,
    photos: _Photos(),
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
              onPressed: () => AlbumRoutes.open(context, album),
              child: const Text('Mở'),
            ),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('Mở'));
  await tester.pumpAndSettle();
  return (albums, album);
}

Finder _button(String label) =>
    find.ancestor(of: find.text(label), matching: find.byType(OutlinedButton));

bool _enabled(WidgetTester tester, String label) =>
    tester.widget<OutlinedButton>(_button(label)).onPressed != null;

Finder get _stack => find.byKey(const ValueKey('album-stack'));

void main() {
  testWidgets('Album name, menu, count, add; newest in front', (tester) async {
    await _pump(tester);
    expect(find.byType(AlbumBrowseScreen), findsOneWidget);
    expect(find.text('Đà Lạt'), findsOneWidget);
    expect(find.byTooltip(_A09.settingsTooltip), findsOneWidget);
    expect(find.text(_A09.countLabel(3)), findsOneWidget);
    expect(find.text(_A09.addLabel), findsOneWidget);
    expect(find.text('Kỷ niệm 3'), findsOneWidget, reason: 'front');
    expect(find.text('Ghi chú số 3'), findsOneWidget);
    expect(find.text(_A09.position(0, 3)), findsOneWidget);
  });

  testWidgets('Behind: at most two, a strip each, no notes', (tester) async {
    await _pump(tester, count: 5);
    // Front 5; behind 4 and 3 (titles only); 2 and 1 not drawn.
    expect(find.text('Kỷ niệm 4'), findsOneWidget);
    expect(find.text('Kỷ niệm 3'), findsOneWidget);
    expect(find.text('Kỷ niệm 2'), findsNothing);
    expect(find.text('Ghi chú số 4'), findsNothing);
    expect(find.text('Ghi chú số 3'), findsNothing);
  });

  testWidgets('Order: memory date newest first, then newest created',
      (tester) async {
    final albums = InMemoryAlbumRepository();
    final album = await albums.create(name: 'A');
    final day = DateTime(2026, 10, 5);
    final first = await albums.createMemory(
        album.id, MemoryContent(note: 'trước', displayDate: day));
    final second = await albums.createMemory(
        album.id, MemoryContent(note: 'sau', displayDate: day));
    await albums.createMemory(
        album.id, MemoryContent(note: 'cũ', displayDate: DateTime(2026, 9, 1)));
    final order = [for (final m in await albums.memories(album.id)) m.id];
    expect(order.take(2), [second.id, first.id]);
    expect(order, hasLength(3));
    expect(tester, isNotNull);
  });

  testWidgets('Trước / Sau; disabled and said at both ends', (tester) async {
    await _pump(tester);
    expect(_enabled(tester, _A09.previousLabel), isFalse);
    expect(find.textContaining(_A09.firstNote), findsOneWidget);
    await tester.tap(_button(_A09.nextLabel));
    await tester.pumpAndSettle();
    expect(find.text(_A09.position(1, 3)), findsOneWidget);
    expect(find.text('Ghi chú số 2'), findsOneWidget);
    await tester.tap(_button(_A09.nextLabel));
    await tester.pumpAndSettle();
    expect(_enabled(tester, _A09.nextLabel), isFalse);
    expect(find.textContaining(_A09.lastNote), findsOneWidget);
    await tester.tap(_button(_A09.previousLabel));
    await tester.pumpAndSettle();
    expect(find.text(_A09.position(1, 3)), findsOneWidget);
  });

  testWidgets('Drag past 48 moves; a short drag snaps back', (tester) async {
    await _pump(tester);
    await tester.drag(_stack, const Offset(0, -30));
    await tester.pumpAndSettle();
    expect(find.text(_A09.position(0, 3)), findsOneWidget);
    await tester.drag(_stack, const Offset(0, -70));
    await tester.pumpAndSettle();
    expect(find.text(_A09.position(1, 3)), findsOneWidget);
    await tester.drag(_stack, const Offset(0, 70));
    await tester.pumpAndSettle();
    expect(find.text(_A09.position(0, 3)), findsOneWidget);
  });

  testWidgets('Card → A08; Back keeps the selected card', (tester) async {
    await _pump(tester);
    await tester.tap(_button(_A09.nextLabel));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ghi chú số 2'));
    await tester.pumpAndSettle();
    expect(find.byType(MemoryDetailScreen), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text(_A09.position(1, 3)), findsOneWidget);
  });

  testWidgets('Xem tất cả: timeline by month, 20 at a time; Back keeps mode',
      (tester) async {
    await _pump(tester, count: 25);
    await tester.tap(find.text(_A09.seeAllLabel));
    await tester.pumpAndSettle();
    expect(find.text(_A09.stackLabel), findsOneWidget);
    expect(find.text('Tháng 10, 2026'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Xem thêm kỷ niệm'), 400,
        scrollable: find.byType(Scrollable).last);
    expect(find.text('Kỷ niệm 6'), findsOneWidget, reason: '20th newest');
    expect(find.text('Kỷ niệm 5'), findsNothing);
    await tester.tap(find.text('Xem thêm kỷ niệm'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Kỷ niệm 1'), 400,
        scrollable: find.byType(Scrollable).last);
    expect(find.text('Xem thêm kỷ niệm'), findsNothing);

    await tester.tap(find.text('Kỷ niệm 1'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text(_A09.stackLabel), findsOneWidget, reason: 'still list');
    expect(find.text('Kỷ niệm 1'), findsOneWidget, reason: 'same scroll');
  });

  testWidgets('Menu → A03; add → A06', (tester) async {
    await _pump(tester);
    await tester.tap(find.byTooltip(_A09.settingsTooltip));
    await tester.pumpAndSettle();
    expect(find.byType(AlbumSettingsScreen), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text(_A09.addLabel));
    await tester.pumpAndSettle();
    expect(find.byType(MemoryEditorScreen), findsOneWidget);
  });

  testWidgets('A new memory shows up in front after saving', (tester) async {
    await _pump(tester);
    await tester.tap(find.text(_A09.addLabel));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byWidgetPredicate((w) => w is TextField && w.minLines == 5),
        'Hôm nay');
    await tester.tap(find.text(MemoryEditorScreen.saveLabel));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text(_A09.countLabel(4)), findsOneWidget);
  });

  for (final (size, scale) in [
    (const Size(360, 640), 1.0),
    (const Size(390, 844), 1.6),
    (const Size(430, 932), 1.0),
  ]) {
    testWidgets('Lays out at $size × $scale', (tester) async {
      await _pump(tester, size: size, textScale: scale);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text(_A09.seeAllLabel));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
