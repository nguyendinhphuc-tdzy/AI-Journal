import 'dart:async';

import 'package:ai_diary/core/theme/app_theme.dart';
import 'package:ai_diary/features/album/album_scope.dart';
import 'package:ai_diary/features/album/data/album.dart';
import 'package:ai_diary/features/album/data/album_auth.dart';
import 'package:ai_diary/features/album/data/album_repository.dart';
import 'package:ai_diary/features/album/data/album_theme.dart';
import 'package:ai_diary/features/album/data/album_unlocks.dart';
import 'package:ai_diary/features/album/presentation/album_cover.dart';
import 'package:ai_diary/features/album/presentation/album_screen.dart';
import 'package:ai_diary/features/album/presentation/create_album_sheet.dart';
import 'package:flutter/material.dart';
import 'dart:ui' show Tristate;
import 'package:flutter_test/flutter_test.dart';

typedef _A02 = CreateAlbumSheet;

class _FakeAuth implements AlbumAuth {
  _FakeAuth({this.supported = true});

  final bool supported;
  var result = AlbumAuthResult.success;
  final reasons = <String>[];

  @override
  Future<bool> isSupported() async => supported;

  @override
  Future<AlbumAuthResult> authenticate(String reason) async {
    reasons.add(reason);
    return result;
  }
}

/// Creates only when [gate] completes; fails while [failing].
class _SlowRepository extends InMemoryAlbumRepository {
  Completer<void>? gate;
  var failing = false;

  @override
  Future<Album> create({
    required String name,
    String themeId = Album.defaultTheme,
    bool locked = false,
  }) async {
    await gate?.future;
    if (failing) throw StateError('offline');
    return super.create(name: name, themeId: themeId, locked: locked);
  }
}

Future<AlbumRepository> _pump(
  WidgetTester tester, {
  AlbumRepository? repository,
  bool lockSupported = true,
  _FakeAuth? auth,
  Size size = const Size(390, 844),
  double textScale = 1,
}) async {
  final albums = repository ?? InMemoryAlbumRepository();
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  addTearDown(AlbumUnlocks.instance.lockAll);
  addTearDown(CreateAlbumDraft.session.clear);
  await tester.pumpWidget(AlbumScope(
    repository: albums,
    auth: auth ?? _FakeAuth(supported: lockSupported),
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

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.text(AlbumScreen.createLabel));
  await _settle(tester);
}

Finder get _sheet => find.byType(CreateAlbumSheet);
Finder get _name =>
    find.descendant(of: _sheet, matching: find.byType(TextField));
Finder get _cta =>
    find.descendant(of: _sheet, matching: find.byType(FilledButton));
Finder get _switch =>
    find.descendant(of: _sheet, matching: find.byType(Switch));

Future<void> _create(WidgetTester tester) async {
  await tester.ensureVisible(_cta);
  await tester.tap(_cta);
  await _settle(tester);
}

Future<void> _pickTheme(WidgetTester tester, AlbumTheme theme) async {
  final chip = find.bySemanticsLabel('Bìa ${theme.label}');
  await tester.ensureVisible(chip);
  await tester.tap(chip);
  await _settle(tester);
}

void main() {
  testWidgets('Sheet: title, close, name, preview, themes, lock, CTA',
      (tester) async {
    await _pump(tester);
    await _open(tester);
    expect(find.text(_A02.title), findsWidgets);
    expect(find.byTooltip(_A02.closeTooltip), findsOneWidget);
    expect(find.text(_A02.nameLabel), findsOneWidget);
    expect(find.text(_A02.coverLabel), findsOneWidget);
    for (final theme in AlbumTheme.all.take(3)) {
      expect(find.bySemanticsLabel('Bìa ${theme.label}'), findsOneWidget);
    }
    expect(find.text(_A02.lockLabel), findsOneWidget);
    expect(find.text(_A02.lockHelp), findsOneWidget);
    expect(_cta, findsOneWidget);
    // 70–85 % of the screen to start with.
    final height = tester.getSize(_sheet).height;
    expect(height, inInclusiveRange(844 * .7, 844 * .85));
  });

  testWidgets('Blank name: said below the field; nothing created',
      (tester) async {
    final albums = await _pump(tester);
    await _open(tester);
    await tester.enterText(_name, '   ');
    await _create(tester);
    expect(find.text(_A02.nameRequired), findsOneWidget);
    expect(_sheet, findsOneWidget);
    expect(await albums.albums(), isEmpty);

    await tester.enterText(_name, 'Đà Lạt');
    await tester.pump();
    expect(find.text(_A02.nameRequired), findsNothing);
  });

  testWidgets('At most 60 characters, with a visible counter', (tester) async {
    await _pump(tester);
    await _open(tester);
    await tester.enterText(_name, 'a' * 70);
    await tester.pump();
    expect(tester.widget<TextField>(_name).controller!.text, 'a' * 60);
    expect(find.text('60/60'), findsOneWidget);
  });

  testWidgets('Same name twice: two albums, different ids', (tester) async {
    final albums = await _pump(tester);
    for (var i = 0; i < 2; i++) {
      await _open(tester);
      await tester.enterText(_name, 'Đà Lạt');
      await _create(tester);
    }
    final all = await albums.albums();
    expect(all, hasLength(2));
    expect(all[0].id, isNot(all[1].id));
  });

  testWidgets('Theme: selected, previewed, saved', (tester) async {
    final albums = await _pump(tester);
    await _open(tester);
    await tester.enterText(_name, 'Hẹn hò');
    final shy = AlbumTheme.of('shy');
    await _pickTheme(tester, shy);
    expect(
        tester
            .getSemantics(find.bySemanticsLabel('Bìa ${shy.label}'))
            .flagsCollection
            .isSelected,
        Tristate.isTrue);
    final preview = find.descendant(
        of: _sheet, matching: find.byKey(const ValueKey('shy')));
    expect(preview, findsOneWidget);
    expect(tester.widget<AlbumCover>(preview).themeId, 'shy');

    await _create(tester);
    final album = (await albums.albums()).single;
    expect(album.themeId, 'shy');
    expect(album.name, 'Hẹn hò');
  });

  group('Lock', () {
    testWidgets('supported: can be turned on; album saved locked',
        (tester) async {
      final albums = await _pump(tester);
      await _open(tester);
      await tester.enterText(_name, 'Riêng tư');
      await tester.ensureVisible(_switch);
      await tester.tap(_switch);
      await tester.pump();
      expect(tester.widget<Switch>(_switch).value, isTrue);
      await _create(tester);
      expect((await albums.albums()).single.locked, isTrue);
    });

    testWidgets('on: the device PIN confirms before creating', (tester) async {
      final auth = _FakeAuth();
      final albums = await _pump(tester, auth: auth);
      await _open(tester);
      await tester.enterText(_name, 'Riêng tư');
      await tester.ensureVisible(_switch);
      await tester.tap(_switch);
      await tester.pump();
      await _create(tester);
      expect(auth.reasons, [_A02.lockReason]);
      final album = (await albums.albums()).single;
      expect(album.locked, isTrue);
      // Locked right away, not left open for this session.
      expect(AlbumUnlocks.instance.isUnlocked(album.id), isFalse);
      expect(find.text(AlbumScreen.lockedLabel), findsOneWidget);
    });

    testWidgets('canceled PIN: nothing created, form kept, says why',
        (tester) async {
      final auth = _FakeAuth()..result = AlbumAuthResult.canceled;
      final albums = await _pump(tester, auth: auth);
      await _open(tester);
      await tester.enterText(_name, 'Riêng tư');
      await tester.ensureVisible(_switch);
      await tester.tap(_switch);
      await tester.pump();
      await _create(tester);
      expect(await albums.albums(), isEmpty);
      expect(_sheet, findsOneWidget);
      expect(find.text(_A02.lockCanceled), findsOneWidget);
      expect(tester.widget<Switch>(_switch).value, isTrue);

      auth.result = AlbumAuthResult.success;
      await _create(tester);
      expect((await albums.albums()).single.locked, isTrue);
    });

    testWidgets('off: no PIN asked', (tester) async {
      final auth = _FakeAuth();
      final albums = await _pump(tester, auth: auth);
      await _open(tester);
      await tester.enterText(_name, 'Mở');
      await _create(tester);
      expect(auth.reasons, isEmpty);
      expect((await albums.albums()).single.locked, isFalse);
    });

    testWidgets('not supported: off, disabled, says so', (tester) async {
      final albums = await _pump(tester, lockSupported: false);
      await _open(tester);
      expect(find.text(_A02.lockUnsupported), findsOneWidget);
      expect(find.text(_A02.lockHelp), findsNothing);
      final toggle = tester.widget<Switch>(_switch);
      expect(toggle.value, isFalse);
      expect(toggle.onChanged, isNull);

      await tester.enterText(_name, 'Riêng tư');
      await _create(tester);
      expect((await albums.albums()).single.locked, isFalse);
    });
  });

  testWidgets('Saving: one album for repeated taps, same button size',
      (tester) async {
    final albums = _SlowRepository()..gate = Completer<void>();
    await _pump(tester, repository: albums);
    await _open(tester);
    await tester.enterText(_name, 'Đà Lạt');
    await tester.pump();
    final before = tester.getSize(_cta);
    await tester.tap(_cta);
    await tester.pump();
    await tester.tap(_cta);
    await tester.pump();
    expect(tester.getSize(_cta), before);
    expect(
        find.descendant(
            of: _cta, matching: find.byType(CircularProgressIndicator)),
        findsOneWidget);

    albums.gate!.complete();
    await _settle(tester);
    expect(await albums.albums(), hasLength(1));
    expect(_sheet, findsNothing);
  });

  testWidgets('Save fails: form kept, says so; retry works', (tester) async {
    final albums = _SlowRepository()..failing = true;
    await _pump(tester, repository: albums);
    await _open(tester);
    await tester.enterText(_name, 'Đà Lạt');
    await _pickTheme(tester, AlbumTheme.of('scarf'));
    await _create(tester);
    expect(find.text(_A02.createFailed), findsOneWidget);
    expect(tester.widget<TextField>(_name).controller!.text, 'Đà Lạt');
    expect(find.byKey(const ValueKey('scarf')), findsOneWidget);

    albums.failing = false;
    await _create(tester);
    expect((await albums.albums()).single.themeId, 'scarf');
  });

  testWidgets('Close keeps the draft for the session; nothing created',
      (tester) async {
    final albums = await _pump(tester);
    await _open(tester);
    await tester.enterText(_name, 'Nháp');
    await _pickTheme(tester, AlbumTheme.of('reading'));
    await tester.tap(find.byTooltip(_A02.closeTooltip));
    await _settle(tester);
    expect(await albums.albums(), isEmpty);
    expect(find.text(AlbumScreen.emptyTitle), findsOneWidget);

    await _open(tester);
    expect(tester.widget<TextField>(_name).controller!.text, 'Nháp');
    expect(find.byKey(const ValueKey('reading')), findsOneWidget);
  });

  testWidgets('Success: closes, snack bar with "Thêm kỷ niệm"; draft cleared',
      (tester) async {
    await _pump(tester);
    await _open(tester);
    await tester.enterText(_name, 'Đà Lạt');
    await _create(tester);
    expect(_sheet, findsNothing);
    expect(find.text(AlbumScreen.created), findsOneWidget);
    expect(find.text(AlbumScreen.addMemoryLabel), findsOneWidget);
    expect(find.text('Đà Lạt'), findsOneWidget);

    await _open(tester);
    expect(tester.widget<TextField>(_name).controller!.text, isEmpty);
  });

  for (final (size, scale, keyboard) in [
    (const Size(360, 640), 1.0, 0.0),
    (const Size(360, 640), 1.0, 280.0),
    (const Size(390, 844), 1.6, 0.0),
    (const Size(430, 932), 1.0, 300.0),
  ]) {
    testWidgets('Lays out at $size × $scale, keyboard $keyboard; CTA visible',
        (tester) async {
      await _pump(tester, size: size, textScale: scale);
      await _open(tester);
      tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
      addTearDown(tester.view.resetViewInsets);
      await _settle(tester);
      expect(tester.takeException(), isNull);
      final cta = tester.getRect(_cta);
      expect(cta.bottom, lessThanOrEqualTo(size.height - keyboard));
      expect(cta.height, greaterThanOrEqualTo(56));
    });
  }
}
