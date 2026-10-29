import 'dart:convert';
import 'dart:io';

import 'package:ai_diary/core/network/api_client.dart';
import 'package:ai_diary/features/album/data/album_repository.dart';
import 'package:ai_diary/features/album/data/memory.dart';
import 'package:ai_diary/features/album/data/remote_album_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _albumId = '12345678-1234-1234-1234-1234567890ab';
const _memoryId = 'fedcba98-1234-1234-1234-1234567890ab';

http.Response _response(Object data, [int code = 200]) => http.Response.bytes(
  utf8.encode(jsonEncode(data)), code,
  headers: const {'content-type': 'application/json; charset=utf-8'},
);

Map<String, Object?> _album() => {
  'id': _albumId, 'name': 'Album của tôi', 'theme_id': 'classic',
  'locked': false, 'hide_name_when_locked': false, 'memory_count': 1,
  'created_at': '2026-10-28T00:00:00Z',
  'updated_at': '2026-10-28T00:00:00Z',
};
Map<String, Object?> _memory() => {
  'id': _memoryId, 'album_id': _albumId,
  'title': 'Buổi sáng', 'note': 'Cà phê ở đây',
  'display_date': '2026-10-27', 'place': null,
  'photo_available': false,
  'created_at': '2026-10-28T00:00:00Z',
  'updated_at': '2026-10-28T00:00:00Z',
};

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('cloud album CRUD and note-only memory CRUD use JWT and PATCH', () async {
    final requests = <http.Request>[];
    String token = 'token-1';
    final api = ApiClient(
      accessTokenProvider: () async => token,
      client: MockClient((request) async {
        requests.add(request);
        final path = request.url.path;
        if (request.method == 'DELETE') return http.Response('', 204);
        if (request.method == 'GET' && path.endsWith('/memories')) {
          return _response([_memory()]);
        }
        if (request.method == 'GET' && path.endsWith('/albums')) {
          return _response([_album()]);
        }
        if (path.endsWith('/memories') || path.endsWith('/memories/$_memoryId')) {
          return _response(_memory(), request.method == 'POST' ? 201 : 200);
        }
        return _response(_album(), request.method == 'POST' ? 201 : 200);
      }),
    );
    final local = await LocalAlbumRepository.open(userId: 'user-a');
    final repo = RemoteAlbumRepository(client: api, localDrafts: local);
    expect((await repo.albums()).single.name, 'Album của tôi');
    final created = await repo.create(name: 'Album của tôi');
    expect(created.id, 'cloud-$_albumId');
    token = 'token-2';
    final changed = await repo.updateSettings(
      created.id, name: 'Album mới', themeId: 'classic', locked: false,
    );
    expect(changed.id, created.id);
    final added = await repo.createMemory(
      created.id,
      MemoryContent(note: 'Cà phê ở đây', displayDate: DateTime(2026, 10, 27)),
    );
    expect(added.id, 'cloud-$_memoryId');
    expect((await repo.memories(created.id)).single.content.note, 'Cà phê ở đây');
    await repo.updateMemory(created.id, added.id, MemoryContent(
      note: 'Một ngày vui', displayDate: DateTime(2026, 10, 27),
    ));
    await repo.deleteMemory(created.id, added.id);
    await repo.deleteAlbum(created.id);
    expect(requests.any((r) => r.method == 'PATCH'), isTrue);
    final posted = requests.firstWhere((r) =>
        r.method == 'POST' && r.url.path.endsWith('/memories'));
    final json = jsonDecode(posted.body) as Map<String, dynamic>;
    expect(json['note'], 'Cà phê ở đây');
    expect(json['display_date'], '2026-10-27');
    expect(json.containsKey('photo_path'), isFalse);
    expect(requests.first.headers['authorization'], 'Bearer token-1');
    expect(requests.last.headers['authorization'], 'Bearer token-2');
    expect(await local.albums(), isEmpty);
    repo.dispose();
    api.close();
  });

  test('combined library preserves existing local albums alongside cloud', () async {
    final api = ApiClient(
      accessTokenProvider: () async => 'jwt',
      client: MockClient((request) async {
        if (request.method == 'GET') return _response([_album()]);
        return _response(_album(), 201);
      }),
    );
    final local = await LocalAlbumRepository.open(userId: 'preserved-user');
    final deviceAlbum = await local.create(name: 'Ảnh cũ trên máy');
    final remote = RemoteAlbumRepository(client: api, localDrafts: local);
    final repo = CombinedAlbumRepository(local: local, remote: remote);
    final albums = await repo.albums();
    expect(albums.map((x) => x.id), containsAll([
      deviceAlbum.id, 'cloud-$_albumId',
    ]));
    expect((await repo.album(deviceAlbum.id))!.name, 'Ảnh cũ trên máy');
    await repo.create(name: 'Album mới');
    expect((await local.albums()).map((x) => x.id), contains(deviceAlbum.id));
    repo.dispose();
    api.close();
  });

  test('photo-only is rejected until cloud note-or-photo contract is added', () async {
    var count = 0;
    final api = ApiClient(
      accessTokenProvider: () async => 'jwt',
      client: MockClient((_) async { count++; return _response({}); }),
    );
    final local = await LocalAlbumRepository.open(userId: 'photo-user');
    final repo = RemoteAlbumRepository(client: api, localDrafts: local);
    await expectLater(
      repo.createMemory('cloud-$_albumId', MemoryContent(
        photoPath: '/private/device/photo.jpg', displayDate: DateTime(2026),
      )),
      throwsArgumentError,
    );
    expect(count, 0);
    repo.dispose();
    api.close();
  });

  test('authenticated Memory photo uploads bytes after note creation', () async {
    final folder = await Directory.systemTemp.createTemp('cloud-photo-test');
    final photo = File('${folder.path}/sample.jpg');
    await photo.writeAsBytes([0xff, 0xd8, 0xff, 0xe0, 1, 2, 3]);
    final requests = <http.Request>[];
    final api = ApiClient(
      accessTokenProvider: () async => 'test-user-token',
      client: MockClient((request) async {
        requests.add(request);
        if (request.method == 'PUT' && request.url.path.endsWith('/photo')) {
          return _response({'photo_available': true});
        }
        return _response(_memory(), 201);
      }),
    );
    final local = await LocalAlbumRepository.open(userId: 'photo-user');
    final repo = RemoteAlbumRepository(
        client: api, localDrafts: local, userId: '12345678-1234-1234-1234-1234567890ab');
    try {
      final created = await repo.createMemory('cloud-$_albumId', MemoryContent(
        note: 'Một ngày vui',
        photoPath: photo.path,
        displayDate: DateTime(2026, 10, 27),
      ));
      expect(created.content.photoPath, photo.path);
      final upload = requests.singleWhere((req) => req.method == 'PUT');
      expect(upload.headers['authorization'], 'Bearer test-user-token');
      expect(upload.headers['content-type'], 'image/jpeg');
      expect(upload.bodyBytes, photo.readAsBytesSync());
    } finally {
      repo.dispose();
      api.close();
      await folder.delete(recursive: true);
    }
  });

  test('photo availability metadata deletes via owner-scoped endpoint', () async {
    final requests = <http.Request>[];
    final api = ApiClient(
      accessTokenProvider: () async => 'jwt',
      client: MockClient((request) async {
        requests.add(request);
        if (request.method == 'DELETE') return http.Response('', 204);
        if (request.method == 'PATCH') {
          return _response({..._memory(), 'photo_available': true});
        }
        return _response(_memory());
      }),
    );
    final local = await LocalAlbumRepository.open(userId: 'photo-user');
    final repo = RemoteAlbumRepository(client: api, localDrafts: local);
    try {
      await repo.updateMemory(
        'cloud-$_albumId', 'cloud-$_memoryId',
        MemoryContent(note: 'No photo', displayDate: DateTime(2026, 10, 27)),
      );
      expect(requests.map((r) => r.method), ['PATCH', 'DELETE']);
      expect(requests.last.url.path, endsWith('/photo'));
      expect(requests.last.headers['authorization'], 'Bearer jwt');
    } finally {
      repo.dispose();
      api.close();
    }
  });

  test('without JWT, private albums fail before network', () async {
    var count = 0;
    final api = ApiClient(
      accessTokenProvider: () async => null,
      client: MockClient((_) async { count++; return _response([]); }),
    );
    final local = await LocalAlbumRepository.open(userId: 'owner');
    final repo = RemoteAlbumRepository(client: api, localDrafts: local);
    await expectLater(repo.albums(), throwsA(isA<MissingAccessTokenException>()));
    expect(count, 0);
    repo.dispose();
    api.close();
  });
  test('album and memory pages above 100 items are fully loaded', () async {
    String id(int index) =>
        '00000000-0000-0000-0000-${index.toString().padLeft(12, '0')}';
    final albums = [
      for (var i = 1; i <= 105; i++) {..._album(), 'id': id(i)}
    ];
    final memories = [
      for (var i = 1; i <= 105; i++) {..._memory(), 'id': id(i)}
    ];
    final requests = <http.Request>[];
    final api = ApiClient(
      accessTokenProvider: () async => 'jwt',
      client: MockClient((request) async {
        requests.add(request);
        final offset = int.parse(request.url.queryParameters['offset'] ?? '0');
        final limit = int.parse(request.url.queryParameters['limit'] ?? '100');
        final items = request.url.path.endsWith('/memories') ? memories : albums;
        return _response(items.skip(offset).take(limit).toList());
      }),
    );
    final local = await LocalAlbumRepository.open(userId: 'owner');
    final repo = RemoteAlbumRepository(client: api, localDrafts: local);
    try {
      expect(await repo.albums(), hasLength(105));
      expect(await repo.memories('cloud-$_albumId'), hasLength(105));
      expect(requests, hasLength(4));
      expect(requests[1].url.queryParameters['offset'], '100');
      expect(requests[3].url.queryParameters['offset'], '100');
      expect(requests.every((r) => r.headers['authorization'] == 'Bearer jwt'),
          isTrue);
    } finally {
      repo.dispose();
      api.close();
    }
  });

  test('two loads at once right after a new photo: both see it', () async {
    // Home, the album list and the open album all reload on a change, so
    // the first download of a new photo can be asked for twice at once.
    final cache = await Directory.systemTemp.createTemp('cloud-photo-cache');
    addTearDown(() => cache.delete(recursive: true));
    var downloads = 0;
    final api = ApiClient(
      accessTokenProvider: () async => 'jwt',
      client: MockClient((request) async {
        if (request.url.path.endsWith('/photo')) {
          downloads++;
          await Future<void>.delayed(const Duration(milliseconds: 20));
          return http.Response.bytes([0xff, 0xd8, 0xff, 0xe0, 9], 200,
              headers: const {'content-type': 'image/jpeg'});
        }
        return _response([
          {..._memory(), 'photo_available': true}
        ]);
      }),
    );
    final repo = RemoteAlbumRepository(
      client: api,
      localDrafts: await LocalAlbumRepository.open(userId: 'cache-user'),
      userId: '11111111-2222-3333-4444-555555555555',
      photoCacheRoot: () async => cache,
    );
    final loads = await Future.wait([
      repo.memories('cloud-$_albumId'),
      repo.memories('cloud-$_albumId'),
    ]);
    for (final memories in loads) {
      final photo = File(memories.single.content.photoPath!);
      expect(await photo.readAsBytes(), [0xff, 0xd8, 0xff, 0xe0, 9]);
    }
    expect(downloads, 1, reason: 'one download, shared');
    expect(
        cache.listSync(recursive: true).whereType<File>().where(
            (file) => file.path.endsWith('.tmp')),
        isEmpty,
        reason: 'no half-written file left behind');
    repo.dispose();
    api.close();
  });
}
