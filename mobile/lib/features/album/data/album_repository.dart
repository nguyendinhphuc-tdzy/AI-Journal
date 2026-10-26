import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'album.dart';
import 'memory.dart';

/// Albums on this device until the backend has an album API (none in
/// `docs/API_CONTRACT.md` yet). An API version implements this same
/// interface.
abstract interface class AlbumRepository implements Listenable {
  /// Newest first.
  Future<List<Album>> albums();

  Future<Album?> album(String id);

  /// [name] is stored trimmed; blank names are refused.
  Future<Album> create({
    required String name,
    String themeId = Album.defaultTheme,
    bool locked = false,
  });

  Future<Album> update(Album album);

  /// Patches settings only; preserves all memory data, dates, IDs and ordering.
  Future<Album> updateSettings(String id,
      {required String name, required String themeId, required bool locked});

  /// The album's memories, newest day first (then newest created).
  Future<List<Memory>> memories(String albumId);

  Future<Memory?> memory(String albumId, String memoryId);

  /// One new memory; the album's count changes in the same write. Refuses
  /// content without a photo or a non-blank note.
  Future<Memory> createMemory(String albumId, MemoryContent content);

  /// Same id and creation time; only the content and [Memory.updatedAt].
  Future<Memory> updateMemory(
      String albumId, String memoryId, MemoryContent content);

  /// Removes one memory (with its place); the album's count changes in the
  /// same write. Nothing happens when it is already gone.
  Future<void> deleteMemory(String albumId, String memoryId);

  /// Removes the album and every memory in it. Nothing happens when it is
  /// already gone.
  Future<void> deleteAlbum(String albumId);

  /// Editor drafts (A06), by a key per album or memory being edited.
  Future<MemoryDraft?> memoryDraft(String key);
  Future<void> saveMemoryDraft(String key, MemoryDraft draft);
  Future<void> deleteMemoryDraft(String key);
}

/// Albums as one JSON list in a key–value store.
abstract class _JsonAlbumRepository extends ChangeNotifier
    implements AlbumRepository {
  static const _albumsKey = 'album.albums';

  final _random = math.Random();
  Future<void> _writes = Future<void>.value();

  Future<T> _mutate<T>(Future<T> Function() action) {
    final next = _writes.then((_) => action());
    _writes = next.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return next;
  }

  String? read(String key);
  Future<void> write(String key, String? value);

  static String _draftKey(String key) => 'album.memoryDraft.$key';

  /// Albums as stored, with fields [Album] does not model (its memories).
  List<Map<String, Object?>> _raw() {
    final raw = read(_albumsKey);
    if (raw == null) return [];
    return [
      for (final item in jsonDecode(raw) as List)
        Map<String, Object?>.from(item as Map),
    ];
  }

  Future<void> _storeRaw(List<Map<String, Object?>> albums) async {
    await write(_albumsKey, jsonEncode(albums));
    notifyListeners();
  }

  List<Album> _all() => [for (final item in _raw()) Album.fromJson(item)];

  String _newId() {
    final now = DateTime.now();
    return 'local-${now.microsecondsSinceEpoch}-${_random.nextInt(1 << 32)}';
  }

  static List<Map<String, Object?>> _memoriesOf(Map<String, Object?> album) => [
        for (final item in album['memories'] as List? ?? const [])
          Map<String, Object?>.from(item as Map),
      ];

  @override
  Future<List<Album>> albums() async {
    final all = _all();
    // Newest first; the id breaks ties so the order never flickers.
    all.sort((a, b) {
      final byDate = b.createdAt.compareTo(a.createdAt);
      return byDate != 0 ? byDate : b.id.compareTo(a.id);
    });
    return all;
  }

  @override
  Future<Album?> album(String id) async {
    for (final album in _all()) {
      if (album.id == id) return album;
    }
    return null;
  }

  @override
  Future<Album> create({
    required String name,
    String themeId = Album.defaultTheme,
    bool locked = false,
  }) =>
      _mutate(() async {
        final trimmed = name.trim();
        if (trimmed.isEmpty) throw ArgumentError.value(name, 'name', 'blank');
        final now = DateTime.now();
        final album = Album(
          id: 'local-${now.microsecondsSinceEpoch}-${_random.nextInt(1 << 32)}',
          name: trimmed,
          themeId: themeId,
          locked: locked,
          createdAt: now,
          updatedAt: now,
        );
        await _storeRaw([..._raw(), album.toJson()]);
        return album;
      });

  @override
  Future<Album> update(Album album) => _mutate(() async {
        final all = _raw();
        final index = all.indexWhere((item) => item['id'] == album.id);
        if (index < 0) throw StateError('No album ${album.id}');
        final updated = album.copyWith(updatedAt: DateTime.now());
        // Merged, so its memories survive.
        all[index] = {...all[index], ...updated.toJson()};
        await _storeRaw(all);
        return updated;
      });

  @override
  Future<List<Memory>> memories(String albumId) async {
    final album = _raw().where((item) => item['id'] == albumId).firstOrNull;
    if (album == null) return [];
    final list = [for (final item in _memoriesOf(album)) Memory.fromJson(item)];
    list.sort((a, b) {
      final byDay = b.content.displayDate.compareTo(a.content.displayDate);
      if (byDay != 0) return byDay;
      final byCreated = b.createdAt.compareTo(a.createdAt);
      return byCreated != 0 ? byCreated : b.id.compareTo(a.id);
    });
    return list;
  }

  @override
  Future<Memory?> memory(String albumId, String memoryId) async {
    for (final memory in await memories(albumId)) {
      if (memory.id == memoryId) return memory;
    }
    return null;
  }

  @override
  Future<Memory> createMemory(String albumId, MemoryContent content) =>
      _mutate(() async {
        if (!content.isValid) {
          throw ArgumentError.value(content, 'content', 'no photo or note');
        }
        final all = _raw();
        final index = all.indexWhere((item) => item['id'] == albumId);
        if (index < 0) throw StateError('No album $albumId');
        final now = DateTime.now();
        final memory = Memory(
            id: _newId(),
            albumId: albumId,
            content: content,
            createdAt: now,
            updatedAt: now);
        final memories = [..._memoriesOf(all[index]), memory.toJson()];
        all[index] = {
          ...all[index],
          'memories': memories,
          'memoryCount': memories.length,
        };
        await _storeRaw(all);
        return memory;
      });

  @override
  Future<Memory> updateMemory(
          String albumId, String memoryId, MemoryContent content) =>
      _mutate(() async {
        if (!content.isValid) {
          throw ArgumentError.value(content, 'content', 'no photo or note');
        }
        final all = _raw();
        final index = all.indexWhere((item) => item['id'] == albumId);
        if (index < 0) throw StateError('No album $albumId');
        final memories = _memoriesOf(all[index]);
        final at = memories.indexWhere((item) => item['id'] == memoryId);
        if (at < 0) throw StateError('No memory $memoryId');
        final old = Memory.fromJson(memories[at]);
        final memory = Memory(
            id: old.id,
            albumId: albumId,
            content: content,
            createdAt: old.createdAt,
            updatedAt: DateTime.now());
        memories[at] = memory.toJson();
        all[index] = {...all[index], 'memories': memories};
        await _storeRaw(all);
        return memory;
      });

  @override
  Future<void> deleteMemory(String albumId, String memoryId) =>
      _mutate(() async {
        final all = _raw();
        final index = all.indexWhere((item) => item['id'] == albumId);
        if (index < 0) return;
        final memories = _memoriesOf(all[index]);
        final left = memories.where((item) => item['id'] != memoryId).toList();
        if (left.length == memories.length) return;
        all[index] = {
          ...all[index],
          'memories': left,
          'memoryCount': left.length,
        };
        await _storeRaw(all);
      });

  @override
  Future<void> deleteAlbum(String albumId) => _mutate(() async {
        final all = _raw();
        final left = all.where((item) => item['id'] != albumId).toList();
        if (left.length == all.length) return;
        await _storeRaw(left);
      });

  @override
  Future<MemoryDraft?> memoryDraft(String key) async {
    final raw = read(_draftKey(key));
    return raw == null
        ? null
        : MemoryDraft.fromJson(
            Map<String, Object?>.from(jsonDecode(raw) as Map));
  }

  @override
  Future<void> saveMemoryDraft(String key, MemoryDraft draft) =>
      write(_draftKey(key), jsonEncode(draft.toJson()));

  @override
  Future<void> deleteMemoryDraft(String key) => write(_draftKey(key), null);

  @override
  Future<Album> updateSettings(String id,
          {required String name,
          required String themeId,
          required bool locked}) =>
      _mutate(() async {
        final trimmed = name.trim();
        if (trimmed.isEmpty) throw ArgumentError.value(name, 'name', 'blank');
        final raw = read(_albumsKey);
        final all = raw == null ? <dynamic>[] : jsonDecode(raw) as List;
        final index = all.indexWhere((item) => item['id'] == id);
        if (index < 0) throw StateError('No album $id');
        // Patch raw JSON so even fields not modeled by Album (future memory
        // IDs, timestamps, order) survive unchanged. No date is rewritten.
        final item = Map<String, Object?>.from(all[index] as Map)
          ..addAll({'name': trimmed, 'themeId': themeId, 'locked': locked});
        all[index] = item;
        await write(_albumsKey, jsonEncode(all));
        notifyListeners();
        return Album.fromJson(item);
      });
}

/// On this device, via shared_preferences.
class LocalAlbumRepository extends _JsonAlbumRepository {
  LocalAlbumRepository(this._prefs, {this.userId});

  static Future<LocalAlbumRepository> open({String? userId}) async =>
      LocalAlbumRepository(await SharedPreferences.getInstance(), userId: userId);

  final SharedPreferences _prefs;
  final String? userId;

  // Preserve legacy unscoped demo keys; auth + guest never read them.
  String _key(String key) => userId == null ? key : 'users.$userId.$key';

  /// Acknowledged values by key; a key not written yet reads what was there
  /// when the app started.
  final _committed = <String, String?>{};

  @override
  String? read(String key) =>
      _committed.putIfAbsent(_key(key), () => _prefs.getString(_key(key)));

  @override
  Future<void> write(String key, String? value) async {
    final scoped = _key(key);
    final ok = value == null
        ? await _prefs.remove(scoped)
        : await _prefs.setString(scoped, value);
    if (!ok) throw StateError('Could not write $scoped');
    // SharedPreferences mutates its cache before the platform write finishes.
    // Expose only acknowledged data to the UI, including after a write failure.
    _committed[scoped] = value;
  }
}

/// In memory only: tests, and screens shown without an [AlbumScope].
class InMemoryAlbumRepository extends _JsonAlbumRepository {
  final _values = <String, String>{};

  @override
  String? read(String key) => _values[key];

  @override
  Future<void> write(String key, String? value) async {
    value == null ? _values.remove(key) : _values[key] = value;
  }
}
