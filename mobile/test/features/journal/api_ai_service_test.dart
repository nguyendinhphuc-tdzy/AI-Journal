import 'dart:convert';

import 'package:ai_diary/core/network/api_client.dart';
import 'package:ai_diary/features/journal/data/api_ai_service.dart';
import 'package:ai_diary/features/journal/data/journal_entry.dart';
import 'package:ai_diary/features/journal/ai_reflection_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  const example = {
    'emotion': 'lo lắng',
    'observation': 'Bạn đã cố gắng hoàn thành một việc nhỏ.',
    'reflection': 'Có thể bạn muốn ghi nhận nỗ lực của mình.',
    'question': 'Điều gì khiến bạn cảm thấy nhẹ lòng nhất?',
  };

  test('requires bearer token before sending any private journal text', () async {
    var requests = 0;
    final client = ApiClient(
      client: MockClient((request) async {
        requests++;
        return http.Response(jsonEncode(example), 200);
      }),
      accessTokenProvider: () async => null,
    );
    final service = ApiAIService(client);
    await expectLater(
      service.analyze('PRIVATE-JOURNAL-NOT-SENT'),
      throwsA(isA<MissingAccessTokenException>()),
    );
    await expectLater(
      service.goDeeper('PRIVATE-JOURNAL-NOT-SENT'),
      throwsA(isA<MissingAccessTokenException>()),
    );
    expect(requests, 0);
    client.close();
  });

  test('uses fresh token, correct endpoints, and maps result to real reflection',
      () async {
    String token = 'first';
    final seen = <http.Request>[];
    final client = ApiClient(
      client: MockClient((request) async {
        seen.add(request);
        if (request.url.path.endsWith('/go-deeper')) {
          return http.Response(
              jsonEncode({'question': 'Điều gì khiến bạn lo lắng?'}), 200);
        }
        return http.Response(jsonEncode(example), 200);
      }),
      accessTokenProvider: () async => token,
    );
    final service = ApiAIService(client);
    final question = await service.goDeeper('Hôm nay hơi lo.');
    token = 'refreshed';
    final entry = JournalEntry(
      id: 'local-test',
      createdAt: DateTime.utc(2026, 10, 26),
      updatedAt: DateTime.utc(2026, 10, 26),
      bodyVersion: 2,
      content: const JournalContent(body: 'Hôm nay hơi lo.'),
    );
    final reflected = await service.reflect(entry);

    expect(question, 'Điều gì khiến bạn lo lắng?');
    expect(reflected.simulated, isFalse);
    expect(reflected.entryId, entry.id);
    expect(reflected.bodyVersion, 2);
    expect(reflected.text, contains(example['observation']));
    expect(reflected.text, contains(example['question']));
    expect(seen, hasLength(2));
    expect(seen.first.headers['authorization'], 'Bearer first');
    expect(seen.last.headers['authorization'], 'Bearer refreshed');
    expect(seen.first.url.path, '/api/v1/ai/go-deeper');
    expect(seen.last.url.path, '/api/v1/ai/reflection');
    expect(jsonDecode(seen.last.body)['content'], 'Hôm nay hơi lo.');
    client.close();
  });

  test('rejects malformed successful backend response', () async {
    final client = ApiClient(
      client: MockClient((request) async => http.Response(
          jsonEncode({'emotion': 'lo lắng'}), 200)),
      accessTokenProvider: () async => 'test-token',
    );
    await expectLater(ApiAIService(client).analyze('demo'),
        throwsA(isA<FormatException>()));
    client.close();
  });

  testWidgets('real AI card contains server content rather than hardcoded mock',
      (tester) async {
    final client = ApiClient(
      client: MockClient((_) async => http.Response(jsonEncode(example), 200)),
      accessTokenProvider: () async => 'test-token',
    );
    await tester.pumpWidget(MaterialApp(
      home: AIReflectionScreen(
        journalContent: 'Nhật ký kiểm thử',
        remote: ApiAIService(client),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text(example['reflection']!), findsOneWidget);
    expect(find.text(example['observation']!), findsOneWidget);
    expect(find.text(example['question']!), findsOneWidget);
    expect(find.text('Né tránh chuyện học hành'), findsNothing);
    expect(tester.takeException(), isNull);
    client.close();
  });

  testWidgets('failed real AI request does not claim a simulated insight',
      (tester) async {
    var sent = 0;
    final client = ApiClient(
      client: MockClient((request) async {
        sent++;
        return http.Response('offline', 503);
      }),
      accessTokenProvider: () async => 'test-token',
    );
    await tester.pumpWidget(MaterialApp(
      home: AIReflectionScreen(
        journalContent: 'Nội dung giả để kiểm thử',
        remote: ApiAIService(client),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Thử lại AI'), findsOneWidget);
    expect(find.text('Né tránh chuyện học hành'), findsNothing);
    expect(sent, 1);
    expect(tester.takeException(), isNull);
    client.close();
  });
}
