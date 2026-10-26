import 'package:flutter/widgets.dart';

import '../../../core/network/api_client.dart';
import 'journal_entry.dart';
import 'reflection_service.dart';

/// Backend-validated AI analysis. This is real AI output, not a local
/// simulation. It is never persisted by this service.
class AiAnalysis {
  const AiAnalysis({
    required this.emotion,
    required this.observation,
    required this.reflection,
    required this.question,
  });

  final String emotion;
  final String observation;
  final String reflection;
  final String question;

  factory AiAnalysis.fromJson(Map<String, dynamic> json) {
    String requiredText(String key) {
      final value = json[key];
      if (value is! String || value.trim().isEmpty) {
        throw const FormatException('Malformed AI response');
      }
      return value.trim();
    }

    return AiAnalysis(
      emotion: requiredText('emotion'),
      observation: requiredText('observation'),
      reflection: requiredText('reflection'),
      question: requiredText('question'),
    );
  }
}

/// One private HTTP boundary for AI reflection and Go Deeper.
///
/// The ApiClient must be constructed with a Supabase session-token provider:
/// ApiClient(accessTokenProvider: () async => session?.accessToken).
/// Missing tokens are rejected before journal text is sent; a guest cannot
/// reach these endpoints. Caller explicitly injects this service only for an
/// authenticated account, after the Auth PR has been reconciled.
class ApiAIService implements ReflectionService {
  const ApiAIService(this.client);

  final ApiClient client;

  Future<String> goDeeper(String content) async {
    final text = content.trim();
    if (text.isEmpty) throw ArgumentError('Journal text is required');
    final response = await client.postJson(
      '/ai/go-deeper',
      {'content': text},
      requireAuth: true,
    );
    final question = response['question'];
    if (question is! String || question.trim().isEmpty) {
      throw const FormatException('Malformed AI response');
    }
    return question.trim();
  }

  Future<AiAnalysis> analyze(String content, {String? mood}) async {
    final text = content.trim();
    if (text.isEmpty) throw ArgumentError('Journal text is required');
    final response = await client.postJson(
      '/ai/reflection',
      {'content': text, if (mood != null && mood.isNotEmpty) 'mood': mood},
      requireAuth: true,
    );
    return AiAnalysis.fromJson(response);
  }

  @override
  Future<Reflection> reflect(JournalEntry entry) async {
    final result = await analyze(
      entry.body,
      mood: entry.content.mood?.name,
    );
    return Reflection(
      entryId: entry.id,
      bodyVersion: entry.bodyVersion,
      text: [result.observation, result.reflection, result.question].join('\n\n'),
      simulated: false,
    );
  }
}

/// No AI network request is made without deliberate explicit injection.
/// This remains absent for guest mode and the original device-only demo.
class AiRemoteScope extends InheritedWidget {
  const AiRemoteScope({
    super.key,
    required this.service,
    required super.child,
  });

  final ApiAIService service;

  static ApiAIService? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AiRemoteScope>()?.service;

  @override
  bool updateShouldNotify(AiRemoteScope old) => old.service != service;
}
