import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/network/api_client.dart';
import 'album.dart';
import 'album_repository.dart';
import 'memory.dart';

/// Owner-scoped FastAPI Album/Memory persistence.
///
/// Private photos are transferred through owner-scoped FastAPI endpoints.
/// Existing local albums/drafts never automatically upload to the cloud.
class RemoteAlbumRepository extends ChangeNotifier implements AlbumRepository {
  RemoteAlbumRepository({
    required this.client,
    required this.localDrafts,
    this.userId,
    Future<Directory> Function()? photoCacheRoot,
  }) : _photoCacheRoot = photoCacheRoot ?? getApplicationDocumentsDirectory;

  final ApiClient client;
  final LocalAlbumRepository localDrafts;
  /// Authenticated user ID for strict separation of private photo caches.
  final String? userId;

  /// Where the private photo cache lives; the app's documents by default.
  final Future<Directory> Function() _photoCacheRoot;

  /// Photo downloads in flight, per cache file. A change reloads several
  /// screens at once (Home, the album list, the open album), and a new photo
  /// is not cached yet: they share one download instead of racing on it.
  final _downloads = <String, Future<void>>{};
  /// A newly uploaded image is still at its original device path until
  /// the next cloud fetch caches it. Edits during this session must not
  /// re-upload the exact same image.
  final _uploadedPaths = <String, String>{};

  static const _prefix = 'cloud-';

  String _id(String raw, {required String entity}) {
    if (!raw.startsWith(_prefix) || raw.length <= _prefix.length) {
      throw ArgumentError.value(raw, entity, 'Not a cloud identifier');
    }
    final uuid = raw.substring(_prefix.length);
    if (!RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(uuid)) {
      throw ArgumentError.value(raw, entity, 'Invalid UUID');
    }
    return uuid;
  }

  Map<String, dynamic> _json(Object? value) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Invalid album API object');
    }
    return value;
  }

  String _text(Map<String, dynamic> value, String name) {
    final raw = value[name];
    if (raw is! String) throw const FormatException('Invalid album API text');
    return raw;
  }

  int _count(Map<String, dynamic> value) {
    final count = value['memory_count'];
    if (count is! int || count < 0) {
      throw const FormatException('Invalid memory count');
    }
    return count;
  }

  Album _album(Object? raw) {
    final data = _json(raw);
    return Album(
      id: '$_prefix${_text(data, 'id')}',
      name: _text(data, 'name'),
      themeId: _text(data, 'theme_id'),
      locked: data['locked'] == true,
      hideNameWhenLocked: data['hide_name_when_locked'] == true,
      memoryCount: _count(data),
      createdAt: DateTime.parse(_text(data, 'created_at')),
      updatedAt: DateTime.parse(_text(data, 'updated_at')),
    );
  }

  MemoryPlace? _place(Object? raw) {
    if (raw == null) return null;
    final data = _json(raw);
    final lat = data['latitude'];
    final lon = data['longitude'];
    if (lat is! num || lon is! num || !lat.isFinite || !lon.isFinite ||
        lat < -90 || lat > 90 || lon < -180 || lon > 180) {
      throw const FormatException('Invalid memory place coordinates');
    }
    return MemoryPlace(
      label: _text(data, 'label'),
      latitude: lat.toDouble(),
      longitude: lon.toDouble(),
      named: data['named'] != false,
      address: data['address'] as String?,
      placeId: data['place_id'] as String?,
    );
  }

  Memory _memory(Object? raw) {
    final data = _json(raw);
    return Memory(
      id: '$_prefix${_text(data, 'id')}',
      albumId: '$_prefix${_text(data, 'album_id')}',
      content: MemoryContent(
        title: data['title'] as String?,
        note: _text(data, 'note'),
        displayDate: DateTime.parse(_text(data, 'display_date')),
        place: _place(data['place']),
        // Photo bytes are downloaded after parsing, into the user's cache.
        photoPath: null,
      ),
      createdAt: DateTime.parse(_text(data, 'created_at')),
      updatedAt: DateTime.parse(_text(data, 'updated_at')),
    );
  }

  Map<String, dynamic> _content(MemoryContent content) {
    final note = content.note?.trim() ?? '';
    if (note.isEmpty) {
      throw ArgumentError.value(content, 'content', 'Cloud Memory requires a note');
    }
    final day = content.displayDate;
    return {
      'title': content.title,
      'note': note,
      'display_date': '${day.year.toString().padLeft(4, '0')}-'
          '${day.month.toString().padLeft(2, '0')}-'
          '${day.day.toString().padLeft(2, '0')}',
      'place': content.place == null ? null : {
        'label': content.place!.label,
        'latitude': content.place!.latitude,
        'longitude': content.place!.longitude,
        'named': content.place!.named,
        'address': content.place!.address,
        'place_id': content.place!.placeId,
      },
    };
  }

  String _photoUrl(String albumId, String memoryId) =>
      '/albums/${_id(albumId, entity: 'album')}/memories/'
      '${_id(memoryId, entity: 'memory')}/photo';

  Future<void> _uploadPhoto(
      String albumId, String memoryId, String path) async {
    final file = File(path);
    final size = await file.length();
    if (size < 1 || size > 5 * 1024 * 1024) {
      throw ArgumentError('Ảnh cloud cần có kích thước tối đa 5 MB');
    }
    final head = await file.openRead(0, 12).fold<List<int>>(
        <int>[], (bytes, chunk) => bytes..addAll(chunk));
    String type;
    if (head.length >= 3 &&
        head[0] == 0xff && head[1] == 0xd8 && head[2] == 0xff) {
      type = 'image/jpeg';
    } else if (head.length >= 8 &&
        head.take(8).toList().join(',') == '137,80,78,71,13,10,26,10') {
      type = 'image/png';
    } else if (head.length >= 12 &&
        String.fromCharCodes(head.take(4)) == 'RIFF' &&
        String.fromCharCodes(head.skip(8).take(4)) == 'WEBP') {
      type = 'image/webp';
    } else {
      throw ArgumentError('Ảnh không phải JPEG, PNG hoặc WebP');
    }
    await client.putBytes(_photoUrl(albumId, memoryId), await file.readAsBytes(),
        contentType: type);
  }

  Future<void> _download(Memory memory, String path) async {
    final bytes = await client.getBytes(_photoUrl(memory.albumId, memory.id));
    // Its own temporary file, so no other writer can take it away.
    final pending =
        File('$path.${DateTime.now().microsecondsSinceEpoch}.tmp');
    try {
      await pending.writeAsBytes(bytes, flush: true);
      await pending.rename(path);
    } finally {
      if (await pending.exists()) await pending.delete();
    }
  }

  Future<Memory> _hydratePhoto(Memory memory, Object? raw) async {
    // The backend exposes only availability, never an internal Storage key.
    if (_json(raw)['photo_available'] != true) return memory;
    final uid = userId;
    if (uid == null || !RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(uid)) {
      throw StateError('Authenticated photo cache requires a user ID');
    }
    final base = await _photoCacheRoot();
    final folder = Directory('${base.path}/cloud_memory_photos/$uid');
    await folder.create(recursive: true);
    final stem = _id(memory.id, entity: 'memory');
    final revision = memory.updatedAt.microsecondsSinceEpoch;
    final path = '${folder.path}/$stem-$revision.private';
    if (!await File(path).exists()) {
      try {
        await (_downloads[path] ??=
            _download(memory, path).whenComplete(() {
          _downloads.remove(path);
        }));
      } catch (_) {
        // A failed image must not hide this memory or the entire album.
        // Preserve the private cache path so an edit does not delete it.
        // Opening the album again retries this download.
      }
    }
    return Memory(
      id: memory.id,
      albumId: memory.albumId,
      createdAt: memory.createdAt,
      updatedAt: memory.updatedAt,
      content: MemoryContent(
        title: memory.content.title,
        note: memory.content.note,
        photoPath: path,
        displayDate: memory.content.displayDate,
        place: memory.content.place,
      ),
    );
  }

  /// Keep the legacy JSON-list contract, but retrieve every page instead of
  /// silently truncating private memories or albums at 100 rows.
  Future<List<dynamic>> _allPages(String path) async {
    final all = <dynamic>[];
    const pageSize = 100;
    for (var page = 0; page < 1000; page++) {
      final items = await client.getList(
        '$path?limit=$pageSize&offset=${page * pageSize}',
        requireAuth: true,
      );
      if (items.length > pageSize) {
        throw const FormatException('Album API page exceeds requested limit');
      }
      all.addAll(items);
      if (items.length < pageSize) return all;
    }
    throw const FormatException('Album API exceeded safe pagination limit');
  }

  @override
  Future<List<Album>> albums() async =>
      (await _allPages('/albums')).map(_album).toList();

  @override
  Future<Album?> album(String id) async {
    try {
      return _album(await client.getJson(
        '/albums/${_id(id, entity: 'album')}',
        requireAuth: true,
      ));
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  @override
  Future<Album> create({
    required String name,
    String themeId = Album.defaultTheme,
    bool locked = false,
  }) async {
    final saved = _album(await client.postJson('/albums', {
      'name': name.trim(), 'theme_id': themeId, 'locked': locked,
    }, requireAuth: true));
    notifyListeners();
    return saved;
  }

  @override
  Future<Album> update(Album album) async {
    final saved = _album(await client.patchJson(
      '/albums/${_id(album.id, entity: 'album')}',
      {
        'name': album.name,
        'theme_id': album.themeId,
        'locked': album.locked,
        'hide_name_when_locked': album.hideNameWhenLocked,
      }, requireAuth: true,
    ));
    notifyListeners();
    return saved;
  }

  @override
  Future<Album> updateSettings(String id, {
    required String name,
    required String themeId,
    required bool locked,
  }) async {
    final saved = _album(await client.patchJson(
      '/albums/${_id(id, entity: 'album')}',
      {'name': name.trim(), 'theme_id': themeId, 'locked': locked},
      requireAuth: true,
    ));
    notifyListeners();
    return saved;
  }

  @override
  Future<List<Memory>> memories(String albumId) async {
    final items = await _allPages(
        '/albums/${_id(albumId, entity: 'album')}/memories');
    return Future.wait(items.map((raw) => _hydratePhoto(_memory(raw), raw)));
  }

  @override
  Future<Memory?> memory(String albumId, String memoryId) async {
    try {
      final raw = await client.getJson(
        '/albums/${_id(albumId, entity: 'album')}/memories/'
        '${_id(memoryId, entity: 'memory')}',
        requireAuth: true,
      );
      return await _hydratePhoto(_memory(raw), raw);
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  @override
  Future<Memory> createMemory(String albumId, MemoryContent content) async {
    final body = _content(content);
    // Validate the local photo before creating any remote data.
    if (content.photoPath case final path?) {
      final file = File(path);
      if (!await file.exists() ||
          await file.length() > 5 * 1024 * 1024) {
        throw ArgumentError('Ảnh không tồn tại hoặc quá 5 MB');
      }
    }
    final saved = _memory(await client.postJson(
      '/albums/${_id(albumId, entity: 'album')}/memories',
      body, requireAuth: true,
    ));
    if (content.photoPath case final path?) {
      try {
        await _uploadPhoto(albumId, saved.id, path);
        _uploadedPaths[_id(saved.id, entity: 'memory')] = path;
      } catch (_) {
        // Avoid duplicate note-only memories after a failed photo upload.
        await deleteMemory(albumId, saved.id);
        rethrow;
      }
    }
    notifyListeners();
    return Memory(
      id: saved.id, albumId: saved.albumId, createdAt: saved.createdAt,
      updatedAt: saved.updatedAt,
      content: MemoryContent(
        title: saved.content.title, note: saved.content.note,
        photoPath: content.photoPath, displayDate: saved.content.displayDate,
        place: saved.content.place,
      ),
    );
  }

  /// Detect this account's cloud cache file; it is not a newly selected image.
  bool _isCachedPhoto(String memoryId, String path) {
    final uid = userId;
    if (uid == null || !RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(uid)) {
      return false;
    }
    final stem = _id(memoryId, entity: 'memory');
    final normalized = path.replaceAll('\\', '/');
    return RegExp(
      '/cloud_memory_photos/${RegExp.escape(uid)}/'
      '${RegExp.escape(stem)}-[0-9]+[.]private\$',
    ).hasMatch(normalized);
  }

  @override
  Future<Memory> updateMemory(
    String albumId, String memoryId, MemoryContent content,
  ) async {
    final body = _content(content);
    final raw = await client.patchJson(
      '/albums/${_id(albumId, entity: 'album')}/memories/'
      '${_id(memoryId, entity: 'memory')}',
      body, requireAuth: true,
    );
    final saved = _memory(raw);
    if (content.photoPath case final path?) {
      final id = _id(memoryId, entity: 'memory');
      if (!_isCachedPhoto(memoryId, path) &&
          _uploadedPaths[id] != path) {
        await _uploadPhoto(albumId, memoryId, path);
        _uploadedPaths[id] = path;
      }
    } else if (raw['photo_available'] == true) {
      await client.deleteNoContent(_photoUrl(albumId, memoryId));
    }
    notifyListeners();
    return Memory(
      id: saved.id, albumId: saved.albumId, createdAt: saved.createdAt,
      updatedAt: saved.updatedAt,
      content: MemoryContent(
        title: saved.content.title, note: saved.content.note,
        photoPath: content.photoPath, displayDate: saved.content.displayDate,
        place: saved.content.place,
      ),
    );
  }

  @override
  Future<void> deleteMemory(String albumId, String memoryId) async {
    await client.deleteNoContent(
      '/albums/${_id(albumId, entity: 'album')}/memories/'
      '${_id(memoryId, entity: 'memory')}',
      requireAuth: true,
    );
    _uploadedPaths.remove(_id(memoryId, entity: 'memory'));
    notifyListeners();
  }

  @override
  Future<void> deleteAlbum(String albumId) async {
    await client.deleteNoContent(
      '/albums/${_id(albumId, entity: 'album')}',
      requireAuth: true,
    );
    notifyListeners();
  }

  // Editor drafts remain scoped local-only; no accidental media upload.
  @override
  Future<MemoryDraft?> memoryDraft(String key) => localDrafts.memoryDraft(key);
  @override
  Future<void> saveMemoryDraft(String key, MemoryDraft draft) =>
      localDrafts.saveMemoryDraft(key, draft);
  @override
  Future<void> deleteMemoryDraft(String key) => localDrafts.deleteMemoryDraft(key);
}


/// Explicit dual-source view: existing local Albums (including device photos)
/// remain usable while new cloud Albums are persisted remotely. No implicit
/// migration or background upload occurs. Existing IDs stay disjoint.
class CombinedAlbumRepository extends ChangeNotifier implements AlbumRepository {
  CombinedAlbumRepository({
    required this.local,
    required this.remote,
  }) {
    local.addListener(notifyListeners);
    remote.addListener(notifyListeners);
  }

  final LocalAlbumRepository local;
  final RemoteAlbumRepository remote;

  bool _cloud(String id) => id.startsWith('cloud-');

  AlbumRepository _owner(String id) {
    if (_cloud(id)) return remote;
    return local;
  }

  @override
  Future<List<Album>> albums() async {
    // Fail visibly if remote state is unavailable; no partial cloud
    // response masquerades as the complete private album library.
    final values = await Future.wait([local.albums(), remote.albums()]);
    final all = [...values[0], ...values[1]];
    all.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return all;
  }

  @override
  Future<Album?> album(String id) => _owner(id).album(id);

  /// New Albums are cloud-only after explicit opt-in.
  @override
  Future<Album> create({
    required String name,
    String themeId = Album.defaultTheme,
    bool locked = false,
  }) => remote.create(name: name, themeId: themeId, locked: locked);

  @override
  Future<Album> update(Album album) => _owner(album.id).update(album);

  @override
  Future<Album> updateSettings(String id, {
    required String name,
    required String themeId,
    required bool locked,
  }) => _owner(id).updateSettings(
        id, name: name, themeId: themeId, locked: locked,
      );

  @override
  Future<List<Memory>> memories(String albumId) =>
      _owner(albumId).memories(albumId);

  @override
  Future<Memory?> memory(String albumId, String memoryId) =>
      _owner(albumId).memory(albumId, memoryId);

  @override
  Future<Memory> createMemory(String albumId, MemoryContent content) =>
      _owner(albumId).createMemory(albumId, content);

  @override
  Future<Memory> updateMemory(
    String albumId, String memoryId, MemoryContent content,
  ) => _owner(albumId).updateMemory(albumId, memoryId, content);

  @override
  Future<void> deleteMemory(String albumId, String memoryId) =>
      _owner(albumId).deleteMemory(albumId, memoryId);

  @override
  Future<void> deleteAlbum(String albumId) =>
      _owner(albumId).deleteAlbum(albumId);

  // Drafts always stay local, per account, regardless of album ID.
  @override
  Future<MemoryDraft?> memoryDraft(String key) => local.memoryDraft(key);
  @override
  Future<void> saveMemoryDraft(String key, MemoryDraft draft) =>
      local.saveMemoryDraft(key, draft);
  @override
  Future<void> deleteMemoryDraft(String key) => local.deleteMemoryDraft(key);

  @override
  void dispose() {
    local.removeListener(notifyListeners);
    remote.removeListener(notifyListeners);
    remote.dispose();
    super.dispose();
  }
}
