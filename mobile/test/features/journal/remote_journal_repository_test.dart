import 'dart:convert';

import 'package:ai_diary/core/network/api_client.dart';
import 'package:ai_diary/features/journal/data/journal_entry.dart';
import 'package:ai_diary/features/journal/data/journal_mood.dart';
import 'package:ai_diary/features/journal/data/journal_repository.dart';
import 'package:ai_diary/features/journal/data/remote_journal_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _guided = {
  'id': 'onboarding_first_entry',
  'version': 1,
  'fields': {'cause': 'trời mát', 'hope': 'nghỉ ngơi'},
};

Map<String, Object?> _serverEntry({
  int id = 42,
  int version = 1,
  String content = 'Một ngày yên bình',
  String? mood = 'calm',
}) => {
      'id': id,
      'title': 'Untitled',
      'content': content,
      'prompt': null,
      'mood': mood,
      'guided': _guided,
      'body_version': version,
      'created_at': '2026-10-26T10:00:00Z',
      'updated_at': '2026-10-26T10:01:00Z',
    };

// Package:http Response defaults to latin1 for String bodies. Use UTF-8
// explicitly: real FastAPI JSON may contain Vietnamese journal text.
http.Response _json(Object? value, int status) =>
    http.Response.bytes(
      utf8.encode(jsonEncode(value)), status,
      headers: const {'content-type': 'application/json; charset=utf-8'},
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('remote roundtrip retains guided values, version, mood and local drafts',
      () async {
    final requests = <http.Request>[];
    var token = 'initial-token';
    final api = ApiClient(
      accessTokenProvider: () async => token,
      client: MockClient((request) async {
        requests.add(request);
        if (request.method == 'POST') {
          return _json(_serverEntry(), 201);
        }
        if (request.method == 'DELETE') {
          return http.Response('', 204);
        }
        if (request.method == 'GET' && request.url.path.endsWith('/journals/42')) {
          return _json(_serverEntry(), 200);
        }
        if (request.method == 'PUT') {
          return _json(_serverEntry(version: 2,
              content: 'Nội dung mới'), 200);
        }
        return _json({
          'items': [_serverEntry()], 'next_cursor': null,
        }, 200);
      }),
    );
    final local = await LocalJournalRepository.open(userId: 'alice');
    final repo = RemoteJournalRepository(client: api, localDrafts: local);
    final guided = GuidedValues.fromJson(Map<String, Object?>.from(_guided));
    const draftKey = 'onboarding.first_entry';
    await repo.saveDraft(draftKey, JournalDraft(
      fields: const {'cause': 'chưa gửi'},
      mood: JournalMood.tired,
      updatedAt: DateTime(2026, 10, 26),
    ));

    var updates = 0;
    repo.addListener(() => updates++);
    final created = await repo.create(JournalContent(
      body: 'Một ngày yên bình',
      mood: JournalMood.calm,
      guided: guided,
    ));
    expect(created.id, 'cloud-42');
    expect(created.bodyVersion, 1);
    expect(created.content.mood, JournalMood.calm);
    expect(created.content.guided!.fields['hope'], 'nghỉ ngơi');
    expect((await repo.entry(created.id))!.id, created.id);
    expect((await repo.entries()).single.content.guided!.templateId,
        'onboarding_first_entry');
    expect(await repo.draft(draftKey), isNotNull);
    expect((await local.entries()), isEmpty,
        reason: 'cloud writes must not create local Journal entries');

    token = 'refreshed-token';
    final edited = await repo.update(created.id,
        JournalContent(body: 'Nội dung mới', mood: JournalMood.calm,
            guided: guided));
    expect(edited.bodyVersion, 2);
    expect(updates, 2);
    expect(requests.last.headers['authorization'], 'Bearer refreshed-token');
    final posted = jsonDecode(requests.first.body) as Map<String, dynamic>;
    expect(posted['guided'], _guided);
    expect(posted['mood'], 'calm');
    expect(requests.every((req) =>
        req.headers.containsKey('authorization')), isTrue);
    await repo.delete(created.id);
    expect(updates, 3);
    expect(requests.last.method, 'DELETE');
    await repo.deleteDraft(draftKey);
    expect(await local.draft(draftKey), isNull);

    repo.dispose();
    api.close();
  });

  test('missing Supabase JWT fails closed before transmitting private content',
      () async {
    var networkCalls = 0;
    final api = ApiClient(
      accessTokenProvider: () async => null,
      client: MockClient((_) async {
        networkCalls++;
        return http.Response('{}', 200);
      }),
    );
    final local = await LocalJournalRepository.open(userId: 'alice');
    final repo = RemoteJournalRepository(client: api, localDrafts: local);
    await expectLater(
      repo.create(const JournalContent(body: 'Private thoughts')),
      throwsA(isA<MissingAccessTokenException>()),
    );
    await expectLater(repo.entries(),
        throwsA(isA<MissingAccessTokenException>()));
    await expectLater(repo.delete('cloud-42'),
        throwsA(isA<MissingAccessTokenException>()));
    expect(networkCalls, 0);
    expect((await local.entries()), isEmpty);
    repo.dispose();
    api.close();
  });

  test('paginated cloud archive and denied cross-account entry', () async {
    final api = ApiClient(
      accessTokenProvider: () async => 'user-a-token',
      client: MockClient((request) async {
        if (request.url.path.endsWith('/journals/999')) {
          return http.Response('{"detail":"Not found"}', 404);
        }
        if (request.url.queryParameters['cursor'] == 'after-1') {
          return _json({
            'items': [_serverEntry(id: 1)], 'next_cursor': null,
          }, 200);
        }
        return _json({
          'items': [_serverEntry(id: 2)], 'next_cursor': 'after-1',
        }, 200);
      }),
    );
    final local = await LocalJournalRepository.open(userId: 'user-a');
    final repo = RemoteJournalRepository(client: api, localDrafts: local);
    expect((await repo.entries()).map((entry) => entry.id),
        ['cloud-2', 'cloud-1']);
    expect(await repo.entry('cloud-999'), isNull);
    await expectLater(
      repo.entry('local-42'), throwsA(isA<ArgumentError>()),
    );
    repo.dispose();
    api.close();
  });

  test('server errors do not clear a locally autosaved draft', () async {
    final api = ApiClient(
      accessTokenProvider: () async => 'user-token',
      client: MockClient((_) async => http.Response('unavailable', 503)),
    );
    final local = await LocalJournalRepository.open(userId: 'owner');
    final repo = RemoteJournalRepository(client: api, localDrafts: local);
    await repo.saveDraft('in-progress', JournalDraft(
      fields: const {'thought': 'important'},
      updatedAt: DateTime(2026, 10, 26),
    ));
    await expectLater(
      repo.create(const JournalContent(body: 'Save attempt')),
      throwsA(isA<ApiException>()),
    );
    expect((await repo.draft('in-progress'))!.fields['thought'], 'important');
    repo.dispose();
    api.close();
  });
}
