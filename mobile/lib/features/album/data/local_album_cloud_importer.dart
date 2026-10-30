import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import 'album.dart';
import 'album_repository.dart';
import 'memory.dart';
import 'remote_album_repository.dart';

/// A deliberate, per-account copy from legacy device albums to private cloud.
/// Local originals and their photo files are NEVER deleted or changed.
class LocalAlbumCloudImporter {
  LocalAlbumCloudImporter({
    required this.local,
    required this.remote,
    SharedPreferences? preferences,
  }) : _preferences = preferences;

  final LocalAlbumRepository local;
  final RemoteAlbumRepository remote;
  final SharedPreferences? _preferences;

  static const int maxBytes = 5 * 1024 * 1024;

  Future<SharedPreferences> get _prefs async =>
      _preferences ?? SharedPreferences.getInstance();

  String _key(Album album) {
    final user = remote.userId;
    if (user == null || !RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(user)) {
      throw StateError('Cần đăng nhập tài khoản thật để import album.');
    }
    if (!album.id.startsWith('local-')) {
      throw ArgumentError('Chỉ có thể nhập album lưu trên máy.');
    }
    return 'album_cloud_import_v1_${user}_${album.id}';
  }

  /// Preview validates everything *before* a cloud album is created.
  /// The current cloud API requires a nonblank note and at most one photo
  /// per memory; never invent text just to import photo-only memories.
  Future<int> validate(Album album) async {
    _key(album);
    if (album.locked) {
      throw StateError('Chưa hỗ trợ nhập album đã khóa; không tự bỏ khóa PIN.');
    }
    final existing = await local.album(album.id);
    if (existing == null) {
      throw StateError('Album local không còn trên thiết bị.');
    }
    final memories = await local.memories(album.id);
    for (final memory in memories) {
      if (!memory.content.hasNote) {
        throw StateError('Album có kỷ niệm chỉ chứa ảnh. Cloud hiện yêu cầu '
            'ghi chú; hãy tự thêm ghi chú trước khi import.');
      }
      if (memory.content.photoPath case final path?) {
        final file = File(path);
        if (!await file.exists() || await file.length() < 1 ||
            await file.length() > maxBytes) {
          throw StateError('Một ảnh local đã mất hoặc vượt giới hạn 5 MiB.');
        }
        // Fail before any writes, not after creating a partial cloud album.
        await RemoteAlbumRepository.validatePhotoFile(path);
      }
    }
    return memories.length;
  }

  /// Safe for a completed import to be invoked again: the saved cloud album
  /// is returned. If a request result is ambiguous, refuse automatic retry
  /// rather than risk creating a duplicate private memory.
  Future<Album> importAlbum(Album album) async {
    await validate(album);
    final preferences = await _prefs;
    final key = _key(album);
    final raw = preferences.getString(key);
    final data = raw == null
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(jsonDecode(raw) as Map);

    Album? created;
    final existingId = data['cloudAlbumId'] as String?;
    if (existingId != null) {
      created = await remote.album(existingId);
      if (created == null) {
        throw StateError('Album cloud đã bị xóa. Không tự tạo lại để tránh '
            'nhập trùng; hãy xử lý bản ghi import trước.');
      }
    } else {
      created = await remote.create(
          name: album.name, themeId: album.themeId, locked: false);
      data['cloudAlbumId'] = created.id;
      data['completed'] = <String>[];
      await preferences.setString(key, jsonEncode(data));
    }

    final inflight = data['inFlight'];
    if (inflight != null) {
      throw StateError('Lần nhập trước bị gián đoạn tại một kỷ niệm. '
          'Hãy kiểm tra album cloud trước, không tự gửi lại để tránh trùng.');
    }

    final completed =
        Set<String>.from((data['completed'] as List? ?? const []).cast<String>());
    for (final memory in await local.memories(album.id)) {
      if (completed.contains(memory.id)) continue;
      data['inFlight'] = memory.id;
      await preferences.setString(key, jsonEncode(data));
      // If network times out after a server commit, the pending marker avoids
      // blindly re-posting a duplicate. Local files always remain intact.
      await remote.createMemory(created.id, memory.content);
      completed.add(memory.id);
      data['completed'] = completed.toList()..sort();
      data.remove('inFlight');
      await preferences.setString(key, jsonEncode(data));
    }
    return created;
  }
}
