import 'dart:convert';
import 'dart:io';

import 'package:ai_diary/core/network/api_client.dart';
import 'package:ai_diary/features/album/data/album_repository.dart';
import 'package:ai_diary/features/album/data/local_album_cloud_importer.dart';
import 'package:ai_diary/features/album/data/memory.dart';
import 'package:ai_diary/features/album/data/remote_album_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

const user = '12345678-1234-1234-1234-1234567890ab';
const cloudAlbum = 'abcdef12-1234-1234-1234-1234567890ab';
const cloudMemory = 'abcdef12-aaaa-bbbb-cccc-1234567890ab';

http.Response reply(Object body, [int status = 200]) =>
    http.Response.bytes(utf8.encode(jsonEncode(body)), status,
        headers: const {'content-type': 'application/json; charset=utf-8'});
Map<String, Object?> albumResponse() => {
  'id': cloudAlbum, 'name': 'Ảnh của mình', 'theme_id': 'classic',
  'locked': false, 'hide_name_when_locked': false, 'memory_count': 1,
  'created_at': '2026-10-30T00:00:00Z', 'updated_at': '2026-10-30T00:00:00Z',
};
Map<String, Object?> memoryResponse() => {
  'id': cloudMemory, 'album_id': cloudAlbum, 'title': null,
  'note': 'Một ngày đáng nhớ', 'display_date': '2026-10-30', 'place': null,
  'photo_available': false, 'created_at': '2026-10-30T00:00:00Z',
  'updated_at': '2026-10-30T00:00:00Z',
};

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('explicit import copies private photo, keeps local and deduplicates', () async {
    final dir = await Directory.systemTemp.createTemp('album-import');
    addTearDown(() => dir.delete(recursive: true));
    final photo = File([dir.path, 'photo.jpg'].join('/'));
    await photo.writeAsBytes([0xff, 0xd8, 0xff, 0xe0, 1, 2, 3]);
    final local = await LocalAlbumRepository.open(userId: user);
    final album = await local.create(name: 'Ảnh của mình');
    await local.createMemory(album.id, MemoryContent(note: 'Một ngày đáng nhớ',
      photoPath: photo.path, displayDate: DateTime(2026, 10, 30)));
    final requests = <http.Request>[];
    final api = ApiClient(accessTokenProvider: () async => 'user-jwt',
      client: MockClient((request) async {
        requests.add(request);
        if (request.method == 'POST' && request.url.path.endsWith('/albums')) {
          return reply(albumResponse(), 201);
        }
        if (request.method == 'POST' && request.url.path.endsWith('/memories')) {
          return reply(memoryResponse(), 201);
        }
        if (request.method == 'PUT' && request.url.path.endsWith('/photo')) {
          return reply({'photo_available': true});
        }
        if (request.method == 'GET' && request.url.path.endsWith('/$cloudAlbum')) {
          return reply(albumResponse());
        }
        throw StateError('Unexpected mock request');
      }));
    final importer = LocalAlbumCloudImporter(local: local,
      remote: RemoteAlbumRepository(client: api, localDrafts: local, userId: user));
    expect(requests, isEmpty);
    expect(await importer.validate(album), 1);
    expect(requests, isEmpty, reason: 'preview performs no writes');
    final created = await importer.importAlbum(album);
    expect(created.id, 'cloud-$cloudAlbum');
    expect(requests.where((r) => r.method == 'POST').length, 2);
    expect(requests.where((r) => r.method == 'PUT').length, 1);
    expect(requests.every((r) => r.headers['authorization'] == 'Bearer user-jwt'), isTrue);
    expect(await photo.exists(), isTrue);
    expect((await local.albums()).single.id, album.id);
    expect((await importer.importAlbum(album)).id, created.id);
    expect(requests.where((r) => r.method == 'POST').length, 2);
  });

  test('photo-only and invalid image fail before cloud writes', () async {
    final dir = await Directory.systemTemp.createTemp('album-invalid');
    addTearDown(() => dir.delete(recursive: true));
    final local = await LocalAlbumRepository.open(userId: user);
    final album = await local.create(name: 'Only photos');
    final bad = File([dir.path, 'wrong.jpg'].join('/'));
    await bad.writeAsBytes([1, 2, 3]);
    final memory = await local.createMemory(album.id,
      MemoryContent(photoPath: bad.path, displayDate: DateTime(2026)));
    var count = 0;
    final importer = LocalAlbumCloudImporter(local: local,
      remote: RemoteAlbumRepository(userId: user, localDrafts: local,
        client: ApiClient(accessTokenProvider: () async => 'jwt',
          client: MockClient((_) async { count++; return reply(albumResponse()); }))));
    await expectLater(importer.importAlbum(album), throwsStateError);
    await local.updateMemory(album.id, memory.id, MemoryContent(
      note: 'Note', photoPath: bad.path, displayDate: DateTime(2026)));
    await expectLater(importer.validate(album), throwsArgumentError);
    expect(count, 0);
  });

  test('uncertain memory write refuses automatic duplicate retry', () async {
    final local = await LocalAlbumRepository.open(userId: user);
    final album = await local.create(name: 'Ảnh của mình');
    await local.createMemory(album.id,
      MemoryContent(note: 'Một ngày đáng nhớ', displayDate: DateTime(2026)));
    var posted = 0;
    final api = ApiClient(accessTokenProvider: () async => 'jwt',
      client: MockClient((request) async {
        if (request.method == 'POST' && request.url.path.endsWith('/albums')) {
          return reply(albumResponse(), 201);
        }
        if (request.method == 'POST' && request.url.path.endsWith('/memories')) {
          posted++;
          return reply({}, 503);
        }
        if (request.method == 'GET' && request.url.path.endsWith('/$cloudAlbum')) {
          return reply(albumResponse());
        }
        throw StateError('Unexpected request');
      }));
    final importer = LocalAlbumCloudImporter(local: local,
      remote: RemoteAlbumRepository(client: api, localDrafts: local, userId: user));
    await expectLater(importer.importAlbum(album), throwsA(isA<ApiException>()));
    await expectLater(importer.importAlbum(album), throwsStateError);
    expect(posted, 1);
    expect((await local.memories(album.id)).length, 1);
  });
}
