import 'package:ai_diary/core/theme/app_theme.dart';
import 'package:ai_diary/features/album/album_scope.dart';
import 'package:ai_diary/features/album/data/album_repository.dart';
import 'package:ai_diary/features/album/data/album_unlocks.dart';
import 'package:ai_diary/features/album/presentation/album_screen.dart';
import 'package:ai_diary/features/album/data/memory_photos.dart';
import 'package:ai_diary/features/album/presentation/album_start_screen.dart';
import 'package:ai_diary/features/album/presentation/memory_editor_screen.dart';
import 'package:ai_diary/features/onboarding/presentation/frame_sequence.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

typedef _A05 = AlbumStartScreen;

class _Photos implements MemoryPhotos {
  var picks = 0;

  @override
  bool get hasCamera => false;

  @override
  Future<String?> pick([PhotoSource source = PhotoSource.library]) async {
    picks++;
    return null;
  }

  @override
  Future<String> keep(String sourcePath) async => sourcePath;
}

final _photos = _Photos();

/// The library with one empty album, opened to A05.
Future<void> _pumpA05(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  double textScale = 1,
  bool reducedMotion = false,
  bool settle = true,
}) async {
  final albums = InMemoryAlbumRepository();
  await albums.create(name: 'Đà Lạt mùa sương');
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  addTearDown(AlbumStartScreen.resetPlayed);
  addTearDown(AlbumUnlocks.instance.lockAll);
  _photos.picks = 0;
  await tester.pumpWidget(AlbumScope(
    repository: albums,
    photos: _photos,
    child: MaterialApp(
      theme: AppTheme.light,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
            disableAnimations: reducedMotion),
        child: child!,
      ),
      home: const AlbumScreen(),
    ),
  ));
  await tester.pumpAndSettle();
  if (settle) {
    await _openAlbum(tester);
  } else {
    // Into A05 but well inside the hero's 1.8 s.
    await tester.tap(find.text('Đà Lạt mùa sương'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
  }
}

Future<void> _openAlbum(WidgetTester tester) async {
  await tester.tap(find.text('Đà Lạt mùa sương'));
  await tester.pumpAndSettle();
}

Finder get _primary => find.widgetWithText(FilledButton, _A05.addFirstLabel);
Finder get _secondary => find.text(_A05.noteFirstLabel);

void main() {
  testWidgets('Back and album name, hero, copy, two ways in, caption',
      (tester) async {
    await _pumpA05(tester);
    expect(find.byType(AlbumStartScreen), findsOneWidget);
    expect(
        find.descendant(
            of: find.byType(AppBar), matching: find.text('Đà Lạt mùa sương')),
        findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);
    expect(find.text(_A05.title), findsOneWidget);
    expect(find.text(_A05.body), findsOneWidget);
    expect(_primary, findsOneWidget);
    expect(_secondary, findsOneWidget);
    expect(find.text(_A05.caption), findsOneWidget);
    expect(find.bySemanticsLabel('Nudaeng mắt long lanh chờ kỷ niệm đầu tiên'),
        findsOneWidget);

    final body = tester.getRect(find.text(_A05.body));
    final primary = tester.getRect(_primary);
    final secondary = tester.getRect(
        find.ancestor(of: _secondary, matching: find.byType(OutlinedButton)));
    expect(primary.top - body.bottom, 16, reason: 'text to CTA');
    expect(secondary.top - primary.bottom, 12, reason: 'between the CTAs');
    expect(primary.height, 56);
  });

  testWidgets('Hero: 128–176 square, at most a third of the screen',
      (tester) async {
    await _pumpA05(tester);
    final hero = tester.getSize(
        find.bySemanticsLabel('Nudaeng mắt long lanh chờ kỷ niệm đầu tiên'));
    expect(hero.width, hero.height);
    expect(hero.width, inInclusiveRange(128, 176));
    expect(hero.height, lessThanOrEqualTo(844 / 3));
  });

  testWidgets('Large text: hero 128, page scrolls to the CTAs', (tester) async {
    await _pumpA05(tester, size: const Size(360, 640), textScale: 1.6);
    expect(tester.takeException(), isNull);
    final hero = tester.getSize(
        find.bySemanticsLabel('Nudaeng mắt long lanh chờ kỷ niệm đầu tiên'));
    expect(hero.width, 128);
    await tester.ensureVisible(_secondary);
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(tester.getRect(_secondary).bottom, lessThanOrEqualTo(640));
  });

  testWidgets('CTAs work at once, without waiting for the animation',
      (tester) async {
    await _pumpA05(tester, settle: false);
    expect(find.byType(FrameSequence), findsOneWidget, reason: 'playing');
    await tester.tap(_primary);
    await tester.pumpAndSettle();
    expect(find.byType(MemoryEditorScreen), findsOneWidget);
  });

  testWidgets('Photo first → A06 photo area; nothing asked here',
      (tester) async {
    await _pumpA05(tester);
    await tester.tap(_primary);
    await tester.pumpAndSettle();
    expect(find.byType(MemoryEditorScreen), findsOneWidget);
    expect(find.text(MemoryEditorScreen.addPhotoLabel), findsOneWidget);
    expect(_photos.picks, 0, reason: 'the picker opens only on tap');
  });

  testWidgets('Note first → A06 note focused', (tester) async {
    await _pumpA05(tester);
    await tester.tap(_secondary);
    await tester.pumpAndSettle();
    expect(find.byType(MemoryEditorScreen), findsOneWidget);
    final note = tester.widget<TextField>(
        find.byWidgetPredicate((w) => w is TextField && w.minLines == 5));
    expect(note.focusNode!.hasFocus, isTrue);
    expect(_photos.picks, 0);
  });

  testWidgets('Back → A01', (tester) async {
    await _pumpA05(tester);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(AlbumStartScreen), findsNothing);
    expect(find.text(AlbumScreen.title), findsOneWidget);
  });

  testWidgets('Plays once per album in the session, then still',
      (tester) async {
    await _pumpA05(tester);
    expect(find.byType(FrameSequence), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));

    // Back from A06 (e.g. the picker): still.
    await tester.tap(_secondary);
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(AlbumStartScreen), findsOneWidget);

    // Leaving and opening again: still, no replay.
    await tester.pageBack();
    await tester.pumpAndSettle();
    await _openAlbum(tester);
    expect(find.byType(AlbumStartScreen), findsOneWidget);
    expect(find.byType(FrameSequence), findsNothing);
  });

  testWidgets('Reduced motion: a still pose', (tester) async {
    await _pumpA05(tester, reducedMotion: true);
    expect(find.byType(FrameSequence), findsNothing);
    expect(find.byType(AlbumStartScreen), findsOneWidget);
  });

  test('The hero ends by 1.8 s, on the first pose', () {
    final total =
        AlbumStartScreen.heroDurations.fold(Duration.zero, (sum, d) => sum + d);
    expect(total, lessThanOrEqualTo(const Duration(milliseconds: 1800)));
  });
}
