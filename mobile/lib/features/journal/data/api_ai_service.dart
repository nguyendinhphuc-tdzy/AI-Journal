import 'package:flutter/widgets.dart';

import '../../../core/network/api_client.dart';
import 'journal_entry.dart';
import 'reflection_service.dart';

/// A quote the backend picked for the entry from the team's list of
/// quotes with checked sources; never written by the AI.
class AiQuote {
  const AiQuote({required this.text, required this.author, this.source});

  final String text;
  final String author;

  /// Where it was checked (book, speech…), when the list says.
  final String? source;
}

/// Backend-validated AI analysis. This is real AI output, not a local
/// simulation. It is never persisted by this service.
///
/// [title], [analysis], [topics] and [quote] are optional: proposed for the
/// analysis screen and shown once the backend returns them.
class AiAnalysis {
  const AiAnalysis({
    required this.emotion,
    required this.observation,
    required this.reflection,
    required this.question,
    this.title,
    this.analysis,
    this.topics = const [],
    this.quote,
    this.moodGroup,
    this.moodScore,
  });

  final String emotion;
  final String observation;
  final String reflection;
  final String question;

  /// A few words naming what the entry is about.
  final String? title;

  /// The main reading of the entry, a short paragraph.
  final String? analysis;

  /// What the entry touches on, a word or two each.
  final List<String> topics;

  final AiQuote? quote;

  /// The backend's sorting of [emotion] into one of the 10 groups
  /// ("mixed" for two), and its place on the 0–100 chart; null when the
  /// words fit no group. Absent from older or on-device analyses.
  final String? moodGroup;
  final int? moodScore;

  /// The same fields [AiAnalysis.fromJson] reads, to keep it.
  Map<String, Object?> toJson() => {
        'emotion': emotion,
        'observation': observation,
        'reflection': reflection,
        'question': question,
        if (title != null) 'title': title,
        if (analysis != null) 'analysis': analysis,
        if (topics.isNotEmpty) 'topics': topics,
        if (moodGroup != null) 'mood_group': moodGroup,
        if (moodScore != null) 'mood_score': moodScore,
        if (quote case final quote?)
          'quote': {
            'text': quote.text,
            'author': quote.author,
            if (quote.source != null) 'source': quote.source,
          },
      };

  factory AiAnalysis.fromJson(Map<String, dynamic> json) {
    String requiredText(String key) {
      final value = json[key];
      if (value is! String || value.trim().isEmpty) {
        throw const FormatException('Malformed AI response');
      }
      return value.trim();
    }

    String? optionalText(Object? value) =>
        value is String && value.trim().isNotEmpty ? value.trim() : null;

    final topics = json['topics'];
    final quote = json['quote'];
    final quoteText = quote is Map ? optionalText(quote['text']) : null;
    final quoteAuthor = quote is Map ? optionalText(quote['author']) : null;
    return AiAnalysis(
      emotion: requiredText('emotion'),
      observation: requiredText('observation'),
      reflection: requiredText('reflection'),
      question: requiredText('question'),
      title: optionalText(json['title']),
      analysis: optionalText(json['analysis']),
      topics: [
        if (topics is List)
          for (final topic in topics)
            if (optionalText(topic) case final text?) text,
      ],
      // Only a whole quote: text and who said it.
      quote: quoteText != null && quoteAuthor != null
          ? AiQuote(
              text: quoteText,
              author: quoteAuthor,
              source: optionalText((quote as Map)['source']))
          : null,
      moodGroup: _moodGroups.contains(json['mood_group'])
          ? json['mood_group'] as String
          : null,
      moodScore: switch (json['mood_score']) {
        final int score when score >= 0 && score <= 100 => score,
        _ => null,
      },
    );
  }

  static const _moodGroups = {
    'joy', 'grateful', 'calm', 'hopeful', 'mixed',
    'tired', 'anxious', 'afraid', 'angry', 'sad',
  };
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
