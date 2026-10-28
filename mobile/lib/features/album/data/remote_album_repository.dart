import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import 'album.dart';
import 'album_repository.dart';
import 'memory.dart';

/// Owner-scoped FastAPI Album/Memory persistence.
///
/// Backend currently has NO private photo object storage. Note-only memories
/// work; rejecting photo content BEFORE HTTP prevents silently losing photos.
/// Existing local albums/drafts never automatically upload to the cloud.
class RemoteAlbumRepository extends ChangeNotifier implements AlbumRepository {
  RemoteAlbumRepository({required this.client, required this.localDrafts});

  final ApiClient client;
  final LocalAlbumRepository localDrafts;

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
        // Photos are never represented as local paths on another device.
        photoPath: null,
      ),
      createdAt: DateTime.parse(_text(data, 'created_at')),
      updatedAt: DateTime.parse(_text(data, 'updated_at')),
    );
  }

  Map<String, dynamic> _content(MemoryContent content) {
    if (content.photoPath != null) {
      throw UnsupportedError(
        'Cloud Memory chưa hỗ trợ lưu ảnh. Hãy giữ ảnh trên thiết bị.'
      );
    }
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

  @override
  Future<List<Album>> albums() async => (await client.getList(
        '/albums?limit=100', requireAuth: true,
      )).map(_album).toList();

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
  Future<List<Memory>> memories(String albumId) async =>
      (await client.getList(
        '/albums/${_id(albumId, entity: 'album')}/memories?limit=100',
        requireAuth: true,
      )).map(_memory).toList();

  @override
  Future<Memory?> memory(String albumId, String memoryId) async {
    try {
      return _memory(await client.getJson(
        '/albums/${_id(albumId, entity: 'album')}/memories/'
        '${_id(memoryId, entity: 'memory')}',
        requireAuth: true,
      ));
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  @override
  Future<Memory> createMemory(String albumId, MemoryContent content) async {
    final body = _content(content); // fail before any network request
    final saved = _memory(await client.postJson(
      '/albums/${_id(albumId, entity: 'album')}/memories',
      body, requireAuth: true,
    ));
    notifyListeners();
    return saved;
  }

  @override
  Future<Memory> updateMemory(
    String albumId, String memoryId, MemoryContent content,
  ) async {
    final body = _content(content);
    final saved = _memory(await client.patchJson(
      '/albums/${_id(albumId, entity: 'album')}/memories/'
      '${_id(memoryId, entity: 'memory')}',
      body, requireAuth: true,
    ));
    notifyListeners();
    return saved;
  }

  @override
  Future<void> deleteMemory(String albumId, String memoryId) async {
    await client.deleteNoContent(
      '/albums/${_id(albumId, entity: 'album')}/memories/'
      '${_id(memoryId, entity: 'memory')}',
      requireAuth: true,
    );
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
