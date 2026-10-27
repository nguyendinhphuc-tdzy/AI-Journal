import 'package:ai_diary/core/theme/app_theme.dart';
import 'package:ai_diary/features/album/album_scope.dart';
import 'package:ai_diary/features/album/data/album.dart';
import 'package:ai_diary/features/album/data/album_repository.dart';
import 'package:ai_diary/features/album/data/album_unlocks.dart';
import 'package:ai_diary/features/album/presentation/album_browse_screen.dart';
import 'package:ai_diary/features/album/presentation/album_screen.dart';
import 'package:ai_diary/features/album/presentation/album_start_screen.dart';
import 'package:ai_diary/features/album/presentation/create_album_sheet.dart';
import 'package:ai_diary/features/onboarding/presentation/frame_sequence.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

typedef _A01 = AlbumScreen;

/// Fails to load until [failing] is turned off.
class _FlakyRepository extends InMemoryAlbumRepository {
  var failing = true;

  @override
  Future<List<Album>> albums() async {
    if (failing) throw StateError('offline');
    return super.albums();
  }
}

Future<AlbumRepository> _pump(
  WidgetTester tester, {
  AlbumRepository? repository,
  Size size = const Size(390, 844),
  double textScale = 1,
}) async {
  final albums = repository ?? InMemoryAlbumRepository();
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  addTearDown(AlbumUnlocks.instance.lockAll);
  addTearDown(CreateAlbumDraft.session.clear);
  addTearDown(AlbumStartScreen.resetPlayed);
  await tester.pumpWidget(AlbumScope(
    repository: albums,
    child: MaterialApp(
      theme: AppTheme.light,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: const AlbumScreen(),
    ),
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  return albums;
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

Future<Album> _seed(AlbumRepository albums, String name,
        {bool locked = false, int memories = 0, bool hideName = false}) async =>
    albums.update((await albums.create(name: name, locked: locked))
        .copyWith(memoryCount: memories, hideNameWhenLocked: hideName));

Finder _tile(String name) =>
    find.ancestor(of: find.text(name), matching: find.byType(InkWell)).first;

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    AlbumUnlocks.instance.didChangeAppLifecycleState(AppLifecycleState.resumed);
  });
  group('Repository', () {
    test('trims names, refuses blank ones, newest first', () async {
      final albums = InMemoryAlbumRepository();
      final first = await albums.create(name: '  Đà Lạt  ');
      await Future<void>.delayed(const Duration(milliseconds: 2));
      final second = await albums.create(name: 'Mùa thu');
      expect(first.name, 'Đà Lạt');
      expect(() => albums.create(name: '   '), throwsArgumentError);
      expect(
          [for (final a in await albums.albums()) a.id], [second.id, first.id]);
    });

    test('update keeps the id and creation time', () async {
      final albums = InMemoryAlbumRepository();
      final album = await albums.create(name: 'A');
      final updated = await albums.update(album.copyWith(name: 'B'));
      expect(updated.id, album.id);
      expect(updated.createdAt, album.createdAt);
      expect((await albums.album(album.id))!.name, 'B');
    });
  });

  testWidgets('Title, subtitle, create CTA', (tester) async {
    await _pump(tester);
    expect(find.text(_A01.title), findsOneWidget);
    expect(find.text(_A01.subtitle), findsOneWidget);
    expect(find.text(_A01.createLabel), findsOneWidget);
  });

  testWidgets('No album: Nudaeng, explanation, create; no "add photo" copy',
      (tester) async {
    await _pump(tester);
    expect(find.text(_A01.emptyTitle), findsOneWidget);
    expect(find.text(_A01.emptyBody), findsOneWidget);
    expect(find.textContaining('ảnh đầu tiên'), findsNothing);
    expect(
        find.byWidgetPredicate((w) =>
            w is Image && (w.image as AssetImage).assetName == _A01.emptyAsset),
        findsOneWidget);
  });

  testWidgets('Grid: two columns, names, memory counts, newest first',
      (tester) async {
    final albums = InMemoryAlbumRepository();
    await _seed(albums, 'Đà Lạt', memories: 3);
    await _seed(albums, 'Mùa thu');
    await _pump(tester, repository: albums);

    expect(find.text(_A01.emptyTitle), findsNothing);
    expect(find.text(_A01.countLabel(3)), findsOneWidget);
    final newest = tester.getRect(_tile('Mùa thu'));
    final older = tester.getRect(_tile('Đà Lạt'));
    expect(newest.top, older.top, reason: 'same row');
    expect(newest.left, lessThan(older.left), reason: 'newest first');
    expect(newest.left, 20);
    expect(older.right, 370);
    expect(older.left - newest.right, 16, reason: 'gap 16');
  });

  testWidgets('Locked: generic cover, no count, lock label', (tester) async {
    final albums = InMemoryAlbumRepository();
    await _seed(albums, 'Riêng tư', locked: true, memories: 4);
    await _seed(albums, 'Bí mật', locked: true, memories: 2, hideName: true);
    await _pump(tester, repository: albums);

    expect(find.text('Riêng tư'), findsOneWidget);
    expect(find.text('Bí mật'), findsNothing);
    expect(find.text(_A01.lockedName), findsOneWidget);
    expect(find.text(_A01.lockedLabel), findsNWidgets(2));
    expect(find.textContaining('kỷ niệm'), findsNothing);
    expect(find.byIcon(Icons.lock_outline_rounded), findsWidgets);
  });

  group('Opening an album', () {
    testWidgets('empty → A05', (tester) async {
      final albums = InMemoryAlbumRepository();
      await _seed(albums, 'Mới');
      await _pump(tester, repository: albums);
      await tester.tap(_tile('Mới'));
      await _settle(tester);
      expect(find.text(AlbumStartScreen.title), findsOneWidget);
    });

    testWidgets('with memories → A09', (tester) async {
      final albums = InMemoryAlbumRepository();
      await _seed(albums, 'Đầy', memories: 2);
      await _pump(tester, repository: albums);
      await tester.tap(_tile('Đầy'));
      await _settle(tester);
      expect(find.byType(AlbumBrowseScreen), findsOneWidget);
    });

    testWidgets('locked → A04 first', (tester) async {
      final albums = InMemoryAlbumRepository();
      await _seed(albums, 'Khóa', locked: true, memories: 2);
      await _pump(tester, repository: albums);
      await tester.tap(_tile('Khóa'));
      await _settle(tester);
      expect(find.text('Mở khóa để xem album này'), findsOneWidget);
      expect(find.byType(AlbumBrowseScreen), findsNothing);
    });

    testWidgets('locked but unlocked this session → its content',
        (tester) async {
      final albums = InMemoryAlbumRepository();
      final album = await _seed(albums, 'Khóa', locked: true, memories: 2);
      AlbumUnlocks.instance.unlock(album.id);
      await _pump(tester, repository: albums);
      await tester.tap(_tile('Khóa'));
      await _settle(tester);
      expect(find.byType(AlbumBrowseScreen), findsOneWidget);
    });

    testWidgets('still shown locked in the library while opened',
        (tester) async {
      final albums = InMemoryAlbumRepository();
      final album = await _seed(albums, 'Khóa', locked: true, memories: 2);
      AlbumUnlocks.instance.unlock(album.id);
      await _pump(tester, repository: albums);
      expect(find.text(_A01.lockedLabel), findsOneWidget);
      expect(find.text(_A01.countLabel(2)), findsNothing);
    });

    testWidgets('leaving it locks it again: the next visit asks',
        (tester) async {
      final albums = InMemoryAlbumRepository();
      final album = await _seed(albums, 'Khóa', locked: true, memories: 2);
      AlbumUnlocks.instance.unlock(album.id);
      await _pump(tester, repository: albums);
      await tester.tap(_tile('Khóa'));
      await _settle(tester);
      expect(find.byType(AlbumBrowseScreen), findsOneWidget);
      await tester.pageBack();
      await _settle(tester);
      expect(AlbumUnlocks.instance.isUnlocked(album.id), isFalse);
      expect(find.text(_A01.lockedLabel), findsOneWidget);

      await tester.tap(_tile('Khóa'));
      await _settle(tester);
      expect(find.byType(AlbumBrowseScreen), findsNothing);
      expect(find.text('Mở khóa'), findsOneWidget);
    });

    testWidgets('going to the background locks it again', (tester) async {
      final albums = InMemoryAlbumRepository();
      final album = await _seed(albums, 'Khóa', locked: true);
      AlbumUnlocks.instance.unlock(album.id);
      AlbumUnlocks.instance
          .didChangeAppLifecycleState(AppLifecycleState.paused);
      expect(AlbumUnlocks.instance.isUnlocked(album.id), isFalse);
    });
  });

  group('Menu, apart from opening', () {
    testWidgets('menu button → A03, does not open the album', (tester) async {
      final albums = InMemoryAlbumRepository();
      await _seed(albums, 'Mới');
      await _pump(tester, repository: albums);
      final menu = find.byTooltip('Tùy chọn album Mới');
      expect(tester.getSize(menu), const Size(48, 48));
      await tester.tap(menu);
      await _settle(tester);
      expect(find.text('Cài đặt album'), findsOneWidget);
      expect(find.text(AlbumStartScreen.title), findsNothing);
    });

    testWidgets('long press → A03', (tester) async {
      final albums = InMemoryAlbumRepository();
      await _seed(albums, 'Mới');
      await _pump(tester, repository: albums);
      await tester.longPress(_tile('Mới'));
      await _settle(tester);
      expect(find.text('Cài đặt album'), findsOneWidget);
    });

    testWidgets('locked: A04 before settings', (tester) async {
      final albums = InMemoryAlbumRepository();
      await _seed(albums, 'Khóa', locked: true);
      await _pump(tester, repository: albums);
      await tester.tap(find.byTooltip('Tùy chọn album Khóa'));
      await _settle(tester);
      expect(find.text('Mở khóa để xem album này'), findsOneWidget);
      expect(find.text('Cài đặt album'), findsNothing);
    });
  });

  group('Creating', () {
    testWidgets('new album appears with a glow, no mascot, shortcut to add',
        (tester) async {
      final albums = await _pump(tester);
      await tester.tap(find.text(_A01.createLabel));
      await _settle(tester);
      await tester.enterText(find.byType(TextField), '  Đà Lạt ');
      await tester.pump();
      final create = find.descendant(
          of: find.byType(BottomSheet), matching: find.byType(FilledButton));
      await tester.tap(create);
      await tester.tap(create, warnIfMissed: false);
      await _settle(tester);

      expect(await albums.albums(), hasLength(1), reason: 'one album');
      expect(find.text('Đà Lạt'), findsOneWidget);
      expect(find.text(_A01.created), findsOneWidget);
      // No Nudaeng over the grid; the new tile is outlined, then not.
      expect(find.byType(FrameSequence), findsNothing);
      final glow = find.byKey(const ValueKey('album-new-glow'));
      expect(glow, findsOneWidget);
      Color outline() {
        final box = tester.widget<DecoratedBox>(find
            .descendant(of: glow, matching: find.byType(DecoratedBox))
            .first);
        return ((box.decoration as BoxDecoration).border as Border).top.color;
      }

      await tester.pump(const Duration(milliseconds: 300));
      expect(outline().a, greaterThan(.9), reason: 'glowing');
      await tester.pump(_A01.newGlow);
      expect(outline().a, 0, reason: 'faded away');

      await tester.tap(find.text(_A01.addMemoryLabel));
      await _settle(tester);
      expect(find.text(AlbumStartScreen.title), findsOneWidget);
      await tester.pageBack();
      await _settle(tester);
      expect(find.byKey(const ValueKey('album-new-glow')), findsNothing,
          reason: 'once, for the new album');
    });
  });

  group('Loading', () {
    testWidgets('failure is not an empty library; retry loads', (tester) async {
      final albums = _FlakyRepository();
      await albums.create(name: 'Đà Lạt');
      await _pump(tester, repository: albums);
      expect(find.text(_A01.loadFailed), findsOneWidget);
      expect(find.text(_A01.emptyTitle), findsNothing);

      albums.failing = false;
      await tester.tap(find.text(_A01.retryLabel));
      await _settle(tester);
      expect(find.text('Đà Lạt'), findsOneWidget);
      expect(find.text(_A01.loadFailed), findsNothing);
    });

    testWidgets('a failed refresh keeps what was shown', (tester) async {
      final albums = _FlakyRepository()..failing = false;
      await albums.create(name: 'Đà Lạt');
      await _pump(tester, repository: albums);
      albums.failing = true;
      await albums.create(name: 'Mới');
      await _settle(tester);
      expect(find.text('Đà Lạt'), findsOneWidget);
      expect(find.text(_A01.refreshFailed), findsOneWidget);
    });
  });

  for (final (size, scale) in [
    (const Size(360, 640), 1.0),
    (const Size(390, 844), 1.0),
    (const Size(430, 932), 1.0),
    (const Size(390, 844), 1.6),
  ]) {
    testWidgets('Lays out at $size × $scale; the dock never covers a tile',
        (tester) async {
      final albums = InMemoryAlbumRepository();
      for (var i = 0; i < 7; i++) {
        await _seed(
            albums, 'Một album có cái tên khá dài số $i để thử xuống dòng',
            memories: i, locked: i == 3);
      }
      await _pump(tester, repository: albums, size: size, textScale: scale);
      expect(tester.takeException(), isNull);

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -4000));
      await _settle(tester);
      expect(tester.takeException(), isNull);
      final dock =
          tester.getRect(find.widgetWithText(FilledButton, _A01.createLabel));
      // Oldest album: the last tile.
      final last = tester.getRect(
          _tile('Một album có cái tên khá dài số 0 để thử xuống dòng'));
      expect(last.bottom, lessThanOrEqualTo(dock.top));
    });
  }
}
