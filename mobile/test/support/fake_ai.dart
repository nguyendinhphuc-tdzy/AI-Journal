import 'dart:convert';

import 'package:ai_diary/core/network/api_client.dart';
import 'package:ai_diary/features/journal/data/api_ai_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// The backend's AI and the account's AI data (PR #72 contract), answered
/// in memory: what an account gets in the app.
class FakeAi {
  FakeAi({
    this.questions = const ['điều gì khiến bạn thấy như vậy?'],
    this.analysis = reflection,
  });

  /// What /ai/reflection (and a journal's analysis) answers.
  final Map<String, Object?> analysis;

  /// Go Deeper answers, in order; the last one repeats.
  final List<String> questions;

  /// The `content` sent to /ai/go-deeper, per request.
  final deeperSent = <String>[];

  /// The `content` sent to /ai/reflection, per request.
  final reflectionSent = <String>[];

  /// Journals analysed on the server (POST /journals/{n}/analysis).
  final analyzed = <int>[];

  /// Fail the next Go Deeper request (503), once.
  bool failNextDeeper = false;

  /// Status for the next request to [failPath] (once), e.g. 429.
  String? failPath;
  int failStatus = 503;

  /// Server state: analyses by journal, saved quotes, the week.
  final serverAnalyses = <int, Map<String, Object?>>{};
  final serverQuotes = <Map<String, Object?>>[];
  Map<String, Object?>? week;
  String weekSummary = 'Một tuần có nhiều khoảnh khắc bình yên.';

  /// Every request: method and path with query.
  final requests = <String>[];

  /// Body version of each server journal, for its analysis.
  final journalVersions = <int, int>{};

  static const reflection = {
    'emotion': 'nhẹ nhõm',
    'observation': 'bạn đã cho mình một buổi chiều chậm lại.',
    'reflection': 'có lẽ bạn cần những khoảng lặng như vậy.',
    'question': 'điều gì giúp bạn thấy nhẹ lòng nhất hôm nay?',
  };

  /// A kept analysis as `AnalysisRead`.
  Map<String, Object?> analysisRead(int journal,
          {int bodyVersion = 1, String? feedback, Map<String, Object?>? of}) =>
      {
        'id': '00000000-0000-0000-0000-${journal.toString().padLeft(12, '0')}',
        'journal_id': journal,
        'body_version': bodyVersion,
        'saved_at': '2026-10-29T07:00:00Z',
        'stale': false,
        'analysis': {
          ...(of ?? analysis),
          'mood_group': 'calm',
          'mood_score': 80
        },
        'feedback': feedback,
      };

  late final ApiClient client = ApiClient(
    accessTokenProvider: () async => 'token',
    client: MockClient(_answer),
  );

  late final ApiAIService service = ApiAIService(client);

  Future<http.Response> _answer(http.Request request) async {
    final path = request.url.path.replaceFirst(RegExp(r'^.*/api/v1'), '');
    requests.add('${request.method} $path'
        '${request.url.query.isEmpty ? '' : '?${request.url.query}'}');
    if (failPath != null && path == failPath) {
      failPath = null;
      return http.Response('{"detail":"fail"}', failStatus);
    }
    final body = request.body.isEmpty ? null : jsonDecode(request.body);
    final journal =
        RegExp(r'^/journals/(\d+)/analysis(/feedback)?$').firstMatch(path);

    if (path == '/ai/go-deeper') {
      deeperSent.add((body as Map)['content'] as String);
      if (failNextDeeper) {
        failNextDeeper = false;
        return http.Response('{"detail":"unavailable"}', 503);
      }
      final i = deeperSent.length - 1;
      return _json({
        'question': questions[i < questions.length ? i : questions.length - 1]
      });
    }
    if (path == '/ai/reflection') {
      reflectionSent.add((body as Map)['content'] as String);
      return _json(analysis);
    }
    if (journal != null) {
      final n = int.parse(journal.group(1)!);
      if (journal.group(2) != null) {
        final kept = serverAnalyses[n];
        if (kept == null) return http.Response('{}', 404);
        kept['feedback'] = (body as Map)['rating'];
        return _json(kept);
      }
      if (request.method == 'POST') {
        analyzed.add(n);
        return _json(serverAnalyses[n] =
            analysisRead(n, bodyVersion: journalVersions[n] ?? 1));
      }
      final kept = serverAnalyses[n];
      return kept == null ? http.Response('{}', 404) : _json(kept);
    }
    if (path == '/journals' &&
        request.url.queryParameters['include'] == 'analysis') {
      return _json({
        'items': [
          for (final MapEntry(:key, :value) in serverAnalyses.entries)
            {'id': key, 'analysis': value},
        ],
        'next_cursor': null,
      });
    }
    if (path == '/saved-quotes' && request.method == 'POST') {
      final map = body as Map;
      serverQuotes.removeWhere((q) => q['text'] == map['text']);
      final quote = {
        'id':
            '11111111-0000-0000-0000-${serverQuotes.length.toString().padLeft(12, '0')}',
        'text': map['text'],
        'author': map['author'],
        'source': null,
        'saved_at': '2026-10-29T08:00:00Z',
      };
      serverQuotes.insert(0, quote);
      return _json(quote);
    }
    if (path == '/saved-quotes') {
      return _json({'items': serverQuotes, 'next_offset': null});
    }
    if (path.startsWith('/saved-quotes/') && request.method == 'DELETE') {
      final id = path.substring('/saved-quotes/'.length);
      final before = serverQuotes.length;
      serverQuotes.removeWhere((q) => q['id'] == id);
      return http.Response('', before == serverQuotes.length ? 404 : 204);
    }
    if (path == '/insights/week') {
      final start = DateTime.parse(request.url.queryParameters['start']!);
      final summary = request.url.queryParameters['generate_summary'] == 'true';
      String day(int i) {
        final d = start.add(Duration(days: i));
        return '${d.year}-${d.month.toString().padLeft(2, '0')}-'
            '${d.day.toString().padLeft(2, '0')}';
      }

      final base = week ??
          {
            'days': [
              for (var i = 0; i < 7; i++)
                {
                  'date': day(i),
                  'journal_count': 0,
                  'analyzed_count': 0,
                  'score': null
                },
            ],
            'top_emotions': <Object>[],
          };
      return _json({
        'start': day(0),
        'end': day(6),
        ...base,
        'summary': summary ? weekSummary : null,
        'summary_status': summary ? 'ready' : 'not_requested',
      });
    }
    return http.Response('{"detail":"not found"}', 404);
  }

  static http.Response _json(Object? body) =>
      http.Response(jsonEncode(body), 200,
          headers: {'content-type': 'application/json; charset=utf-8'});
}
