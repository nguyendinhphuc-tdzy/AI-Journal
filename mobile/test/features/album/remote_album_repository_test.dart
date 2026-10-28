import 'dart:convert';

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

  test('photo-only or attached photo refuses network before data loss', () async {
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
      throwsUnsupportedError,
    );
    expect(count, 0);
    repo.dispose();
    api.close();
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
}
