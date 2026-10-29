import 'dart:convert';

import 'package:ai_diary/core/network/api_client.dart';
import 'package:ai_diary/features/journal/data/api_ai_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// The backend's AI, answered in memory: what an account gets in the app.
class FakeAi {
  FakeAi({
    this.questions = const ['điều gì khiến bạn thấy như vậy?'],
    this.analysis = reflection,
  });

  /// What /ai/reflection answers.
  final Map<String, Object?> analysis;

  /// Go Deeper answers, in order; the last one repeats.
  final List<String> questions;

  /// The `content` sent to /ai/go-deeper, per request.
  final deeperSent = <String>[];

  /// The `content` sent to /ai/reflection, per request.
  final reflectionSent = <String>[];

  /// Fail the next Go Deeper request (503), once.
  bool failNextDeeper = false;

  static const reflection = {
    'emotion': 'nhẹ nhõm',
    'observation': 'bạn đã cho mình một buổi chiều chậm lại.',
    'reflection': 'có lẽ bạn cần những khoảng lặng như vậy.',
    'question': 'điều gì giúp bạn thấy nhẹ lòng nhất hôm nay?',
  };

  late final ApiAIService service = ApiAIService(ApiClient(
    accessTokenProvider: () async => 'token',
    client: MockClient((request) async {
      final content = (jsonDecode(request.body) as Map)['content'] as String;
      if (request.url.path.endsWith('/go-deeper')) {
        deeperSent.add(content);
        if (failNextDeeper) {
          failNextDeeper = false;
          return http.Response('{"detail":"unavailable"}', 503);
        }
        final i = deeperSent.length - 1;
        return _json({
          'question': questions[i < questions.length ? i : questions.length - 1]
        });
      }
      reflectionSent.add(content);
      return _json(analysis);
    }),
  ));

  static http.Response _json(Object body) => http.Response(
      jsonEncode(body), 200,
      headers: {'content-type': 'application/json; charset=utf-8'});
}
