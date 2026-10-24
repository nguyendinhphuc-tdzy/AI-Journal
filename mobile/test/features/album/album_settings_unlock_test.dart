import 'dart:async';

import 'package:ai_diary/core/theme/app_theme.dart';
import 'package:ai_diary/features/album/album_scope.dart';
import 'package:ai_diary/features/album/data/memory.dart';
import 'package:ai_diary/features/album/data/album.dart';
import 'package:ai_diary/features/album/data/album_auth.dart';
import 'package:ai_diary/features/album/data/album_repository.dart';
import 'package:ai_diary/features/album/data/album_settings.dart';
import 'package:ai_diary/features/album/data/album_sharing.dart';
import 'package:ai_diary/features/album/data/album_unlocks.dart';
import 'package:ai_diary/features/album/presentation/album_browse_screen.dart';
import 'package:ai_diary/features/album/presentation/album_cover.dart';
import 'package:ai_diary/features/album/presentation/album_routes.dart';
import 'package:ai_diary/features/album/presentation/album_settings_screen.dart';
import 'package:ai_diary/features/album/presentation/album_start_screen.dart';
import 'package:ai_diary/features/album/presentation/memory_detail_screen.dart';
import 'package:ai_diary/features/album/presentation/album_unlock_screen.dart';
import 'package:ai_diary/features/album/presentation/nudaeng_album_key.dart';
import 'package:ai_diary/features/album/presentation/confirm_delete_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Auth implements AlbumAuth {
  AlbumAuthResult result = AlbumAuthResult.success;
  Completer<AlbumAuthResult>? pending;
  int calls = 0;
  bool supported = true;
  @override
  Future<bool> isSupported() async => supported;
  @override
  Future<AlbumAuthResult> authenticate(String reason) async {
    calls++;
    return pending == null ? result : await pending!.future;
  }
}

class _Shares implements AlbumSharing {
  bool active = true;
  bool fail = false;
  int revocations = 0;
  @override
  Future<bool> hasActiveShares(String id) async => active;
  @override
  Future<void> revokeAll(String id) async {
    revocations++;
    if (fail) throw StateError('offline');
    active = false;
  }

  @override
  Future<T> withPublicationBlocked<T>(String id, Future<T> Function() action) =>
      action();
}

final _session = AlbumUnlocks.instance;

Future<Album> _open(
  WidgetTester tester, {
  required InMemoryAlbumRepository repository,
  required _Auth auth,
  bool locked = true,
  AlbumDestination destination = AlbumDestination.browse,
  AlbumSharing sharing = const NoAlbumPublishing(),
  Size size = const Size(390, 844),
  double scale = 1,
}) async {
  var album = await repository.create(
      name: 'Bí mật', themeId: 'reading', locked: locked);
  if (destination == AlbumDestination.browse) {
    // A09 is for an album with memories; an empty one opens A05.
    await repository.createMemory(album.id,
        MemoryContent(note: 'Một kỷ niệm', displayDate: DateTime(2026, 10, 1)));
    album = (await repository.album(album.id))!;
  }
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(AlbumScope(
    repository: repository,
    auth: auth,
    sharing: sharing,
    child: MaterialApp(
      theme: AppTheme.light,
      builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!),
      home: Builder(
          builder: (context) => Scaffold(
                  body: Column(children: [
                const Text('Nguồn an toàn'),
                FilledButton(
                    onPressed: () => AlbumRoutes.unlock(
                        context, album, destination,
                        memoryId: destination == AlbumDestination.memory
                            ? 'memory-7'
                            : null),
                    child: const Text('Mở album')),
              ]))),
    ),
  ));
  await tester.tap(find.text('Mở album'));
  await tester.pumpAndSettle();
  return album;
}

Future<void> _unlock(WidgetTester tester) async {
  await tester.tap(find.text('Mở khóa'));
  await tester.pump();
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    _session.didChangeAppLifecycleState(AppLifecycleState.resumed);
    _session.lockAll();
    AlbumSettingsDraft.session.clear();
  });
  tearDown(() {
    _session.didChangeAppLifecycleState(AppLifecycleState.resumed);
    _session.lockAll();
    AlbumSettingsDraft.session.clear();
  });

  testWidgets('A04 is generic, holds key at 96, waits for auth and animation',
      (tester) async {
    final auth = _Auth()..pending = Completer<AlbumAuthResult>();
    final album =
        await _open(tester, repository: InMemoryAlbumRepository(), auth: auth);
    expect(find.text('Bí mật'), findsNothing);
    expect(tester.widget<AlbumCover>(find.byType(AlbumCover)).locked, isTrue);
    expect(tester.getSize(find.byType(NudaengAlbumKey)), const Size(96, 96));
    await tester.tap(find.text('Mở khóa'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 5));
    expect(
        tester
            .widget<NudaengAlbumKey>(find.byType(NudaengAlbumKey))
            .authSucceeded,
        isFalse);
    expect(_session.isUnlocked(album.id), isFalse);
    auth.pending!.complete(AlbumAuthResult.success);
    await tester.pump();
    await tester.pump();
    expect(find.text('Xác thực thành công. Đang mở album…'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(AlbumBrowseScreen), findsNothing);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(find.byType(AlbumBrowseScreen), findsOneWidget);
    expect(_session.isUnlocked(album.id), isTrue);
  });

  for (final result in [
    AlbumAuthResult.failed,
    AlbumAuthResult.canceled,
    AlbumAuthResult.notSetUp,
    AlbumAuthResult.notSupported
  ]) {
    testWidgets(
        '$result keeps private preview hidden and Cancel returns safely',
        (tester) async {
      final auth = _Auth()..result = result;
      final album = await _open(tester,
          repository: InMemoryAlbumRepository(), auth: auth);
      await tester.tap(find.text('Mở khóa'));
      await tester.pumpAndSettle();
      expect(find.text('Bí mật'), findsNothing);
      expect(_session.isUnlocked(album.id), isFalse);
      expect(
          tester
              .widget<NudaengAlbumKey>(find.byType(NudaengAlbumKey))
              .authSucceeded,
          isFalse);
      await tester.tap(find.text('Hủy'));
      await tester.pumpAndSettle();
      expect(find.text('Nguồn an toàn'), findsOneWidget);
    });
  }

  for (final (destination, label) in [
    (AlbumDestination.start, AlbumStartScreen.title),
    (AlbumDestination.memory, MemoryDetailScreen.gone),
    (AlbumDestination.settings, AlbumSettingsScreen.title),
  ]) {
    testWidgets('Auth resumes pending $destination', (tester) async {
      await _open(tester,
          repository: InMemoryAlbumRepository(),
          auth: _Auth(),
          destination: destination);
      await _unlock(tester);
      expect(find.text(label), findsOneWidget);
      if (destination == AlbumDestination.memory) {
        final route = ModalRoute.of(tester.element(find.text(label)))!;
        expect((route.settings.arguments as Map)['memoryId'], 'memory-7');
      }
    });
  }

  testWidgets('Native overlay does not abandon auth or pending route',
      (tester) async {
    final auth = _Auth()..pending = Completer<AlbumAuthResult>();
    await _open(tester, repository: InMemoryAlbumRepository(), auth: auth);
    await tester.tap(find.text('Mở khóa'));
    await tester.pump();
    _session.didChangeAppLifecycleState(AppLifecycleState.inactive);
    await tester.pump();
    _session.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await tester.pump();
    expect(auth.calls, 1);
    auth.pending!.complete(AlbumAuthResult.success);
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.byType(AlbumBrowseScreen), findsOneWidget);
  });

  testWidgets(
      'Overlay at animation completion resumes without replay or reauth',
      (tester) async {
    final auth = _Auth();
    final album =
        await _open(tester, repository: InMemoryAlbumRepository(), auth: auth);
    await tester.tap(find.text('Mở khóa'));
    await tester.pump();
    await tester.pump();
    _session.didChangeAppLifecycleState(AppLifecycleState.inactive);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(_session.isUnlocked(album.id), isFalse);
    expect(find.byType(AlbumBrowseScreen), findsNothing);
    _session.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.byType(AlbumBrowseScreen), findsOneWidget);
    expect(auth.calls, 1);
  });

  testWidgets('Background during success animation invalidates pending unlock',
      (tester) async {
    final album = await _open(tester,
        repository: InMemoryAlbumRepository(), auth: _Auth());
    await tester.tap(find.text('Mở khóa'));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    _session.didChangeAppLifecycleState(AppLifecycleState.paused);
    _session.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(_session.isUnlocked(album.id), isFalse);
    expect(find.text('Bí mật'), findsNothing);
    expect(find.byType(AlbumUnlockScreen), findsOneWidget);
  });

  testWidgets('Background hides content, reauth restores A03 draft',
      (tester) async {
    final auth = _Auth();
    await _open(tester,
        repository: InMemoryAlbumRepository(),
        auth: auth,
        destination: AlbumDestination.settings);
    await _unlock(tester);
    await tester.enterText(find.byType(TextField), 'Bản nháp riêng');
    _session.didChangeAppLifecycleState(AppLifecycleState.paused);
    await tester.pump();
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Bản nháp riêng'), findsNothing);
    _session.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.byType(AlbumUnlockScreen), findsOneWidget);
    await _unlock(tester);
    expect(find.text('Bản nháp riêng'), findsOneWidget);
    expect(auth.calls, 2);
  });

  testWidgets('A03 disabled when unchanged, previews theme, Back retains draft',
      (tester) async {
    final repository = InMemoryAlbumRepository();
    final album = await _open(tester,
        repository: repository,
        auth: _Auth(),
        locked: false,
        destination: AlbumDestination.settings);
    final save =
        find.widgetWithText(FilledButton, AlbumSettingsScreen.saveLabel);
    expect(tester.widget<FilledButton>(save).onPressed, isNull);
    await tester.enterText(find.byType(TextField), 'Nội dung mới');
    await tester.tap(find.text('Quàng khăn'));
    await tester.pump();
    // Past the 180 ms preview crossfade.
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.widget<AlbumCover>(find.byType(AlbumCover)).themeId, 'scarf');
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mở album'));
    await tester.pumpAndSettle();
    expect(find.text('Nội dung mới'), findsOneWidget);
    await tester.tap(find.text(AlbumSettingsScreen.saveLabel));
    await tester.pumpAndSettle();
    final updated = (await repository.album(album.id))!;
    expect(updated.name, 'Nội dung mới');
    expect(updated.themeId, 'scarf');
    expect(updated.createdAt, album.createdAt);
    expect(updated.updatedAt, album.updatedAt);
    // Saved: back where A03 was opened from, saying so.
    expect(find.byType(AlbumSettingsScreen), findsNothing);
    expect(find.text('Nguồn an toàn'), findsOneWidget);
    expect(find.text(AlbumSettingsScreen.saved), findsOneWidget);
  });

  testWidgets(
      'A03 lock needs auth, share consent; failed revoke stays unlocked with Retry',
      (tester) async {
    final repository = InMemoryAlbumRepository();
    final shares = _Shares()..fail = true;
    final auth = _Auth();
    final album = await _open(tester,
        repository: repository,
        auth: auth,
        sharing: shares,
        locked: false,
        destination: AlbumDestination.settings);
    await tester.ensureVisible(find.byType(SwitchListTile));
    await tester.tap(find.byType(SwitchListTile));
    await tester.pump();
    await tester.tap(find.text(AlbumSettingsScreen.saveLabel));
    await tester.pumpAndSettle();
    expect(auth.calls, 1);
    expect(find.text(AlbumSettingsScreen.revokeLabel), findsOneWidget);
    expect((await repository.album(album.id))!.locked, isFalse);
    await tester.tap(find.text(AlbumSettingsScreen.revokeLabel));
    await tester.pumpAndSettle();
    expect((await repository.album(album.id))!.locked, isFalse);
    expect(find.text('Thử lại'), findsOneWidget);
    shares.fail = false;
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AlbumSettingsScreen.revokeLabel));
    await tester.pumpAndSettle();
    expect(shares.active, isFalse);
    expect((await repository.album(album.id))!.locked, isTrue);
    expect(find.byType(AlbumSettingsScreen), findsNothing);
    expect(find.text('Nguồn an toàn'), findsOneWidget);
    expect(find.text(AlbumSettingsScreen.savedLocked), findsOneWidget);
    // Locked at once: not left open for the rest of the session.
    expect(AlbumUnlocks.instance.isUnlocked(album.id), isFalse);
  });

  testWidgets(
      'A03 turning lock off requires fresh auth; failure keeps saved lock',
      (tester) async {
    final repository = InMemoryAlbumRepository();
    final auth = _Auth();
    final album = await _open(tester,
        repository: repository,
        auth: auth,
        destination: AlbumDestination.settings);
    await _unlock(tester);
    await tester.ensureVisible(find.byType(SwitchListTile));
    await tester.tap(find.byType(SwitchListTile));
    await tester.pump();
    auth.result = AlbumAuthResult.failed;
    await tester.tap(find.text(AlbumSettingsScreen.saveLabel));
    await tester.pumpAndSettle();
    expect(auth.calls, 2);
    expect((await repository.album(album.id))!.locked, isTrue);
    auth.result = AlbumAuthResult.success;
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect((await repository.album(album.id))!.locked, isFalse);
  });

  testWidgets('A11 over A03, canceled, asks no PIN again',
      (tester) async {
    final repository = InMemoryAlbumRepository();
    final album = await _open(tester,
        repository: repository,
        auth: _Auth(),
        destination: AlbumDestination.settings);
    await _unlock(tester);
    expect(find.byType(AlbumSettingsScreen), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Xóa album'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Xóa album'));
    await tester.pumpAndSettle();
    expect(find.byType(ConfirmDeleteDialog), findsOneWidget);
    await tester.tap(find.text(ConfirmDeleteDialog.cancelLabel));
    await tester.pumpAndSettle();
    expect(find.byType(AlbumSettingsScreen), findsOneWidget);
    expect(find.byType(AlbumUnlockScreen), findsNothing);
    expect(AlbumUnlocks.instance.isUnlocked(album.id), isTrue);

    // Out of the album altogether: locked again.
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Nguồn an toàn'), findsOneWidget);
    expect(AlbumUnlocks.instance.isUnlocked(album.id), isFalse);
  });

  testWidgets('Delete is separate: A11 first, canceled deletes nothing',
      (tester) async {
    final repository = InMemoryAlbumRepository();
    final album = await _open(tester,
        repository: repository,
        auth: _Auth(),
        locked: false,
        destination: AlbumDestination.settings);
    await tester.scrollUntilVisible(find.text('Xóa album'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Xóa album'));
    await tester.pumpAndSettle();
    expect(find.byType(ConfirmDeleteDialog), findsOneWidget);
    expect(await repository.album(album.id), isNotNull);
    await tester.tap(find.text(ConfirmDeleteDialog.cancelLabel));
    await tester.pumpAndSettle();
    expect(find.byType(AlbumSettingsScreen), findsOneWidget);
    expect(await repository.album(album.id), isNotNull);
  });

  for (final locked in [true, false]) {
    testWidgets('A03/A04 fit small screen and large text (locked=$locked)',
        (tester) async {
      await _open(tester,
          repository: InMemoryAlbumRepository(),
          auth: _Auth(),
          locked: locked,
          destination: AlbumDestination.settings,
          size: const Size(320, 568),
          scale: 2);
      expect(tester.takeException(), isNull);
    });
  }
}
