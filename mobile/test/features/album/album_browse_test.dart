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
import 'package:ai_diary/features/sound/app_sound.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  bool reduced = false,
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
        data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
            disableAnimations: reduced),
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

Finder get _pile => find.byKey(const ValueKey('album-pile'));

/// The sounds asked for, by file.
class _Sounds implements SoundBackend {
  final played = <String>[];

  @override
  Future<void> effect(String asset, double volume) async => played.add(asset);
  @override
  Future<void> music(String? asset, double volume) async {}
  @override
  Future<void> pauseMusic() async {}
  @override
  Future<void> preload(Iterable<String> assets) async {}
}

/// Records the page-turn sound and the phone's taps for one test.
Future<(_Sounds, List<Object?>)> _listen(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final sounds = _Sounds();
  AppSound.backend = sounds;
  addTearDown(() => AppSound.backend = null);
  await AppSound.instance.refresh();
  final taps = <Object?>[];
  tester.binding.defaultBinaryMessenger
      .setMockMethodCallHandler(SystemChannels.platform, (call) async {
    if (call.method == 'HapticFeedback.vibrate') taps.add(call.arguments);
    return null;
  });
  addTearDown(() => tester.binding.defaultBinaryMessenger
      .setMockMethodCallHandler(SystemChannels.platform, null));
  return (sounds, taps);
}

/// Throws the top photo away (up), or pulls the previous one back (down).
Future<void> _swipe(WidgetTester tester, {bool back = false}) async {
  await tester.drag(_pile, Offset(0, back ? 320 : -260));
  await tester.pumpAndSettle();
}

/// Where the card showing [text] is now.
Offset _at(WidgetTester tester, String text) =>
    tester.getCenter(find.text(text));

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

  testWidgets('A pile: two photos under the top one, no gap, no buttons',
      (tester) async {
    await _pump(tester, count: 5);
    // Top 5; under it 4 and 3; 2 and 1 not drawn.
    expect(find.text('Kỷ niệm 4'), findsOneWidget);
    expect(find.text('Kỷ niệm 3'), findsOneWidget);
    expect(find.text('Kỷ niệm 2'), findsNothing);
    // Under, not after: they overlap the top one.
    final top = tester.getRect(find
        .ancestor(of: find.text('Kỷ niệm 5'), matching: find.byType(Material))
        .first);
    final under = tester.getRect(find
        .ancestor(of: find.text('Kỷ niệm 4'), matching: find.byType(Material))
        .first);
    expect(top.overlaps(under), isTrue);
    expect(find.text('Trước'), findsNothing);
    expect(find.text('Sau'), findsNothing);
    expect(find.text('5 tháng 10, 2026'), findsOneWidget, reason: 'date');
  });

  testWidgets('Throw the top photo: the next comes up; heard and felt once',
      (tester) async {
    final (sounds, taps) = await _listen(tester);
    await _pump(tester);
    // Held: it follows the finger, nothing heard yet.
    final before = _at(tester, 'Kỷ niệm 3');
    final hand = await tester.startGesture(tester.getCenter(_pile));
    await hand.moveBy(const Offset(20, -20));
    await hand.moveBy(const Offset(60, -180));
    await tester.pump();
    expect(_at(tester, 'Kỷ niệm 3').dy, lessThan(before.dy - 150));
    expect(sounds.played, isEmpty);
    await hand.up();
    await tester.pump();
    expect(sounds.played, hasLength(1), reason: 'on letting go');
    expect(SoundCue.pageTurn.assets, contains(sounds.played.single));
    expect(taps, ['HapticFeedbackType.lightImpact']);
    // In flight it turns over: the back of the paper.
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.byKey(const ValueKey('paper-back')), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text(_A09.position(1, 3)), findsOneWidget);
    expect(_A09.position(1, 3), '02 / 03');
    expect(find.byKey(const ValueKey('paper-back')), findsNothing);
    expect(sounds.played, hasLength(1));
  });

  testWidgets('A short drag settles back, quietly; a flick throws',
      (tester) async {
    final (sounds, taps) = await _listen(tester);
    await _pump(tester);
    final before = _at(tester, 'Kỷ niệm 3');
    await tester.drag(_pile, const Offset(30, -40));
    await tester.pumpAndSettle();
    expect(find.text(_A09.position(0, 3)), findsOneWidget);
    expect(_at(tester, 'Kỷ niệm 3'), before);
    expect(sounds.played, isEmpty);
    expect(taps, isEmpty);
    // 40 px in 30 ms: short, but fast.
    final flick = await tester.startGesture(tester.getCenter(_pile));
    for (var i = 1; i <= 5; i++) {
      await flick.moveBy(const Offset(0, -8),
          timeStamp: Duration(milliseconds: 6 * i));
    }
    await flick.up(timeStamp: const Duration(milliseconds: 31));
    await tester.pumpAndSettle();
    expect(find.text(_A09.position(1, 3)), findsOneWidget);
    expect(sounds.played, hasLength(1));
  });

  testWidgets('Pull down: the previous photo comes back, face down first',
      (tester) async {
    final (sounds, _) = await _listen(tester);
    await _pump(tester);
    await _swipe(tester);
    expect(find.text(_A09.position(1, 3)), findsOneWidget);
    final hand = await tester.startGesture(tester.getCenter(_pile));
    await hand.moveBy(const Offset(0, 20));
    await hand.moveBy(const Offset(0, 60));
    await tester.pump();
    expect(find.byKey(const ValueKey('paper-back')), findsOneWidget,
        reason: 'still face down, high up');
    await hand.moveBy(const Offset(0, 250));
    await hand.up();
    await tester.pumpAndSettle();
    expect(find.text(_A09.position(0, 3)), findsOneWidget);
    expect(find.byKey(const ValueKey('paper-back')), findsNothing);
    expect(sounds.played, hasLength(2));
  });

  testWidgets('The ends: the last and a pull on the first only give',
      (tester) async {
    final (sounds, _) = await _listen(tester);
    await _pump(tester);
    await _swipe(tester, back: true);
    expect(find.text(_A09.position(0, 3)), findsOneWidget);
    await _swipe(tester);
    await _swipe(tester);
    expect(find.text(_A09.position(2, 3)), findsOneWidget);
    await _swipe(tester);
    expect(find.text(_A09.position(2, 3)), findsOneWidget);
    await tester.drag(_pile, const Offset(300, 0));
    await tester.pumpAndSettle();
    expect(find.text(_A09.position(2, 3)), findsOneWidget);
    expect(sounds.played, hasLength(2));
  });

  testWidgets('Screen readers: next and previous as actions', (tester) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester);
    SemanticsNode node() => tester.getSemantics(_pile);
    List<String> actions() => [
          for (final id in node().getSemanticsData().customSemanticsActionIds!)
            CustomSemanticsAction.getAction(id)!.label!,
        ];
    expect(actions(), [_A09.nextAction]);
    node().owner!.performAction(node().id, SemanticsAction.customAction,
        node().getSemanticsData().customSemanticsActionIds!.single);
    await tester.pumpAndSettle();
    expect(find.text(_A09.position(1, 3)), findsOneWidget);
    expect(actions(), unorderedEquals([_A09.nextAction, _A09.previousAction]));
    semantics.dispose();
  });

  testWidgets('Reduced motion: no flying, no turning over', (tester) async {
    await _pump(tester, reduced: true);
    await tester.drag(_pile, const Offset(0, -260));
    await tester.pump();
    expect(find.byKey(const ValueKey('paper-back')), findsNothing);
    await tester.pumpAndSettle();
    expect(find.text(_A09.position(1, 3)), findsOneWidget);
  });

  testWidgets('A memory added before it keeps the same one on top, quietly',
      (tester) async {
    final (sounds, _) = await _listen(tester);
    final (albums, album) = await _pump(tester);
    await _swipe(tester);
    expect(sounds.played, hasLength(1));
    await albums.createMemory(
        album.id,
        MemoryContent(
            title: 'Mới',
            note: 'Vừa thêm',
            displayDate: DateTime(2026, 10, 30)));
    await tester.pumpAndSettle();
    expect(find.text(_A09.position(2, 4)), findsOneWidget);
    expect(sounds.played, hasLength(1));
  });

  testWidgets('Card → A08; Back keeps the selected card', (tester) async {
    await _pump(tester);
    await _swipe(tester);
    await tester.tap(find.text('Ghi chú số 2').hitTestable());
    await tester.pumpAndSettle();
    expect(find.byType(MemoryDetailScreen), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text(_A09.position(1, 3)), findsOneWidget);
  });

  testWidgets('Xem tất cả: grid by month, 20 at a time; Back keeps mode',
      (tester) async {
    await _pump(tester, count: 25);
    await tester.tap(find.text(_A09.seeAllLabel));
    await tester.pumpAndSettle();
    expect(find.text(_A09.pileLabel), findsOneWidget);
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

    await tester.ensureVisible(find.text('Kỷ niệm 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kỷ niệm 1').hitTestable());
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text(_A09.pileLabel), findsOneWidget, reason: 'still list');
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
