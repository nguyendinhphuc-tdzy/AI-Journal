import '../../../core/network/api_client.dart';
import 'api_ai_service.dart';

/// The number of a server-owned journal ("cloud-12" → 12); null for an
/// entry kept on the device only.
int? cloudJournalNumber(String entryId) {
  final match = RegExp(r'^cloud-([1-9][0-9]*)$').firstMatch(entryId);
  return match == null ? null : int.parse(match.group(1)!);
}

/// An analysis the backend keeps with a journal (`AnalysisRead`).
class CloudAnalysis {
  const CloudAnalysis({
    required this.journalNumber,
    required this.bodyVersion,
    required this.savedAt,
    required this.stale,
    required this.analysis,
    this.feedback,
  });

  final int journalNumber;

  /// The journal version it read; [stale] once the journal was edited.
  final int bodyVersion;
  final DateTime savedAt;
  final bool stale;
  final AiAnalysis analysis;

  /// "up", "down" or null.
  final String? feedback;

  String get entryId => 'cloud-$journalNumber';

  factory CloudAnalysis.fromJson(Map<String, dynamic> json) {
    final journal = json['journal_id'];
    final version = json['body_version'];
    final savedAt = json['saved_at'];
    final analysis = json['analysis'];
    final feedback = json['feedback'];
    if (journal is! int ||
        version is! int ||
        savedAt is! String ||
        analysis is! Map ||
        (feedback != null && feedback != 'up' && feedback != 'down')) {
      throw const FormatException('Malformed analysis response');
    }
    return CloudAnalysis(
      journalNumber: journal,
      bodyVersion: version,
      savedAt: DateTime.parse(savedAt).toLocal(),
      stale: json['stale'] == true,
      analysis: AiAnalysis.fromJson(Map<String, dynamic>.from(analysis)),
      feedback: feedback as String?,
    );
  }
}

/// A quote the account saved on the server.
typedef CloudQuote = ({
  String id,
  String text,
  String author,
  DateTime savedAt
});

/// One day of [CloudWeek].
typedef CloudDay = ({
  DateTime date,
  int journalCount,
  int analyzedCount,
  double? score,
});

/// `GET /insights/week`: counted on the server from the account's journals
/// and their current analyses.
class CloudWeek {
  const CloudWeek({
    required this.days,
    required this.topEmotions,
    required this.summary,
    required this.summaryStatus,
  });

  final List<CloudDay> days;

  /// Mood group ids, most first, with how often.
  final List<({String group, int count})> topEmotions;

  /// The AI's words on the week, only when [summaryStatus] is "ready".
  final String? summary;

  /// "ready", "not_requested", "no_data" or "unavailable".
  final String summaryStatus;

  factory CloudWeek.fromJson(Map<String, dynamic> json) {
    final days = json['days'];
    final top = json['top_emotions'];
    final status = json['summary_status'];
    if (days is! List ||
        days.length != 7 ||
        top is! List ||
        status is! String) {
      throw const FormatException('Malformed week response');
    }
    final summary = json['summary'];
    return CloudWeek(
      days: [
        for (final raw in days)
          if (raw is Map)
            (
              date: DateTime.parse(raw['date'] as String),
              journalCount: raw['journal_count'] as int,
              analyzedCount: raw['analyzed_count'] as int,
              score: (raw['score'] as num?)?.toDouble(),
            ),
      ],
      topEmotions: [
        for (final raw in top)
          if (raw is Map)
            (group: raw['mood_group'] as String, count: raw['count'] as int),
      ],
      summary:
          status == 'ready' && summary is String && summary.trim().isNotEmpty
              ? summary.trim()
              : null,
      summaryStatus: status,
    );
  }
}

/// The account's AI data kept on the server (analyses with their journals,
/// feedback, saved quotes, the week). Only for a signed-in account; the
/// caller decides, by the user's AI setting, whether anything may run the
/// AI ([analyze], [week] with a summary).
class CloudAiApi {
  const CloudAiApi(this.client);

  final ApiClient client;

  /// Runs the AI on the journal as saved on the server, and keeps the
  /// result there. The same version again returns the kept one.
  Future<CloudAnalysis> analyze(int journal, {bool force = false}) async =>
      CloudAnalysis.fromJson(await client.postJson(
        '/journals/$journal/analysis',
        {'force': force},
        requireAuth: true,
      ));

  /// The kept analysis, never a new one; null when there is none.
  Future<CloudAnalysis?> analysisOf(int journal) async {
    try {
      return CloudAnalysis.fromJson(await client
          .getJson('/journals/$journal/analysis', requireAuth: true));
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  /// Every kept analysis of the account's journals, page by page.
  Future<List<CloudAnalysis>> analyses() async {
    final all = <CloudAnalysis>[];
    String? cursor;
    final seen = <String>{};
    do {
      final page = await client.getJson(
        '/journals?limit=100&include=analysis'
        '${cursor == null ? '' : '&cursor=${Uri.encodeQueryComponent(cursor)}'}',
        requireAuth: true,
      );
      final items = page['items'];
      final next = page['next_cursor'];
      if (items is! List) throw const FormatException('Malformed page');
      for (final item in items) {
        if (item is Map && item['analysis'] is Map) {
          all.add(CloudAnalysis.fromJson(
              Map<String, dynamic>.from(item['analysis'] as Map)));
        }
      }
      cursor =
          next is String && next.isNotEmpty && seen.add(next) ? next : null;
    } while (cursor != null);
    return all;
  }

  /// "up", "down" or null (none); no journal text is sent.
  Future<CloudAnalysis> rate(int journal, String? rating) async =>
      CloudAnalysis.fromJson(await client.putJson(
        '/journals/$journal/analysis/feedback',
        {'rating': rating},
        requireAuth: true,
      ));

  Future<List<CloudQuote>> savedQuotes() async {
    final all = <CloudQuote>[];
    int? offset = 0;
    while (offset != null) {
      final page = await client
          .getJson('/saved-quotes?limit=100&offset=$offset', requireAuth: true);
      final items = page['items'];
      if (items is! List) throw const FormatException('Malformed page');
      all.addAll([
        for (final item in items)
          if (item is Map) _quote(item)
      ]);
      final next = page['next_offset'];
      offset = next is int && next > offset ? next : null;
    }
    return all;
  }

  Future<CloudQuote> saveQuote(String text, String author) async =>
      _quote(await client.postJson(
        '/saved-quotes',
        {'text': text, 'author': author, 'source': null},
        requireAuth: true,
      ));

  Future<void> deleteQuote(String id) async {
    try {
      await client.deleteNoContent('/saved-quotes/$id', requireAuth: true);
    } on ApiException catch (e) {
      // Already gone is what was asked.
      if (e.statusCode != 404) rethrow;
    }
  }

  /// The week from [monday]; with [summary], the AI writes its note on the
  /// week (from counts and scores only, never the entries).
  Future<CloudWeek> week(DateTime monday, {bool summary = false}) async {
    String two(int n) => n.toString().padLeft(2, '0');
    final start = '${monday.year}-${two(monday.month)}-${two(monday.day)}';
    return CloudWeek.fromJson(await client.getJson(
      '/insights/week?start=$start&generate_summary=$summary',
      requireAuth: true,
    ));
  }

  static CloudQuote _quote(Map raw) {
    final id = raw['id'];
    final text = raw['text'];
    final author = raw['author'];
    final savedAt = raw['saved_at'];
    if (id is! String ||
        text is! String ||
        author is! String ||
        savedAt is! String) {
      throw const FormatException('Malformed saved quote');
    }
    return (
      id: id,
      text: text,
      author: author,
      savedAt: DateTime.parse(savedAt).toLocal(),
    );
  }
}
