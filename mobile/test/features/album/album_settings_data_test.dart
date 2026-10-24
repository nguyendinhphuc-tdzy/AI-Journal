import 'dart:async';
import 'dart:convert';

import 'package:ai_diary/features/album/data/album_repository.dart';
import 'package:ai_diary/features/album/data/album_settings.dart';
import 'package:ai_diary/features/album/data/album_sharing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Mirrors the plugin's optimistic in-memory cache, even when disk writes fail.
class _Preferences implements SharedPreferences {
  String? cached;
  bool fail = false;
  @override
  String? getString(String key) => cached;
  @override
  Future<bool> setString(String key, String value) async {
    cached = value;
    return !fail;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Store extends InMemoryAlbumRepository {
  bool fail = false;
  Completer<void>? gate;
  @override
  Future<void> write(String key, String? value) async {
    await gate?.future;
    if (fail) throw StateError('disk failed');
    await super.write(key, value);
  }
}

class _Shares implements AlbumSharing {
  bool active = true;
  bool lookupFails = false;
  bool revokeFails = false;
  bool stillPublic = false;
  bool blocked = false;
  final events = <String>[];
  @override
  Future<bool> hasActiveShares(String id) async {
    events.add('check');
    if (lookupFails) throw StateError('offline');
    return active;
  }

  @override
  Future<void> revokeAll(String id) async {
    expect(blocked, isTrue);
    events.add('revoke');
    if (revokeFails) throw StateError('offline');
    if (!stillPublic) active = false;
  }

  @override
  Future<T> withPublicationBlocked<T>(
      String id, Future<T> Function() action) async {
    blocked = true;
    try {
      return await action();
    } finally {
      blocked = false;
    }
  }
}

void main() {
  test('Failed platform write does not expose optimistic locked cache',
      () async {
    final prefs = _Preferences();
    final store = LocalAlbumRepository(prefs);
    final album = await store.create(name: 'A');
    prefs.fail = true;
    await expectLater(
        store.updateSettings(album.id,
            name: 'A', themeId: 'classic', locked: true),
        throwsStateError);
    expect((jsonDecode(prefs.cached!) as List).single['locked'], isTrue);
    expect((await store.album(album.id))!.locked, isFalse);
    prefs.fail = false;
    await store.updateSettings(album.id,
        name: 'A', themeId: 'classic', locked: true);
    expect((await store.album(album.id))!.locked, isTrue);
  });

  test('Settings patch preserves raw memory IDs/dates/order and album dates',
      () async {
    final store = _Store();
    final album = await store.create(name: 'Old');
    final second = await store.create(name: 'Second');
    final records = jsonDecode(store.read('album.albums')!) as List;
    records[0]['memoryIds'] = ['m2', 'm1'];
    records[0]['memories'] = [
      {'id': 'm2', 'date': '2020-03-05', 'order': 0},
      {'id': 'm1', 'date': '2019-01-01', 'order': 1},
    ];
    await store.write('album.albums', jsonEncode(records));
    final before = jsonDecode(store.read('album.albums')!) as List;
    final result = await store.updateSettings(album.id,
        name: '  New  ', themeId: 'scarf', locked: true);
    final after = jsonDecode(store.read('album.albums')!) as List;
    final expected = Map<String, dynamic>.from(before[0] as Map)
      ..addAll({'name': 'New', 'themeId': 'scarf', 'locked': true});
    expect(after, [expected, before[1]]);
    expect(result.createdAt, album.createdAt);
    expect(result.updatedAt, album.updatedAt);
    expect((await store.albums()).map((a) => a.id), [second.id, album.id]);
  });

  test('Concurrent create and settings save do not overwrite each other',
      () async {
    final store = _Store();
    final album = await store.create(name: 'Old');
    await Future.wait([
      store.updateSettings(album.id,
          name: 'New', themeId: 'classic', locked: false),
      store.create(name: 'Second'),
    ]);
    expect((await store.albums()).map((a) => a.name), ['Second', 'New']);
  });

  for (final failure in ['check', 'revoke', 'verification', 'write']) {
    test(
        '$failure failure never publishes locked; retry uses actual share state',
        () async {
      final store = _Store();
      final album = await store.create(name: 'A');
      final draft = AlbumSettingsDraft(album)..locked = true;
      final shares = _Shares()
        ..lookupFails = failure == 'check'
        ..revokeFails = failure == 'revoke'
        ..stillPublic = failure == 'verification';
      store.fail = failure == 'write';
      final writer = AlbumSettingsWriter(store, shares);
      await expectLater(
          writer.save(album.id, draft,
              revokeShares: true, mayCommit: () => true),
          throwsA(isA<AlbumSettingsFailure>()));
      expect((await store.album(album.id))!.locked, isFalse);
      expect(shares.blocked, isFalse);
      if (failure == 'write') expect(shares.active, isFalse);
      shares.lookupFails =
          shares.revokeFails = shares.stillPublic = store.fail = false;
      await writer.save(album.id, draft,
          revokeShares: true, mayCommit: () => true);
      expect((await store.album(album.id))!.locked, isTrue);
      expect(shares.active, isFalse);
    });
  }

  test('Active share requires explicit consent before revocation or write',
      () async {
    final store = _Store();
    final album = await store.create(name: 'A');
    final shares = _Shares();
    await expectLater(
        AlbumSettingsWriter(store, shares).save(
            album.id, AlbumSettingsDraft(album)..locked = true,
            revokeShares: false, mayCommit: () => true),
        throwsA(isA<ShareRevocationRequired>()));
    expect(shares.events, ['check']);
    expect(shares.active, isTrue);
    expect((await store.album(album.id))!.locked, isFalse);
  });

  test('Lock stays false while commit is pending; barrier spans the write',
      () async {
    final store = _Store();
    final album = await store.create(name: 'A');
    final shares = _Shares();
    store.gate = Completer<void>();
    final save = AlbumSettingsWriter(store, shares).save(
        album.id, AlbumSettingsDraft(album)..locked = true,
        revokeShares: true, mayCommit: () => true);
    await Future<void>.delayed(Duration.zero);
    expect(shares.events, ['check', 'revoke', 'check']);
    expect(shares.blocked, isTrue);
    expect(shares.active, isFalse);
    expect((await store.album(album.id))!.locked, isFalse);
    store.gate!.complete();
    await save;
    expect((await store.album(album.id))!.locked, isTrue);
    expect(shares.blocked, isFalse);
  });

  test('Expired auth prevents external revocation and commit', () async {
    final store = _Store();
    final album = await store.create(name: 'A');
    final shares = _Shares();
    await expectLater(
        AlbumSettingsWriter(store, shares).save(
            album.id, AlbumSettingsDraft(album)..locked = true,
            revokeShares: true, mayCommit: () => false),
        throwsA(isA<AlbumSettingsFailure>()));
    expect(shares.events, isEmpty);
    expect((await store.album(album.id))!.locked, isFalse);
  });
}
