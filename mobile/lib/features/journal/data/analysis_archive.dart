import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'api_ai_service.dart';

/// The analysis shown after an entry was saved, kept to read again later
/// and for the week's emotions.
class SavedAnalysis {
  const SavedAnalysis({
    required this.entryId,
    required this.bodyVersion,
    required this.savedAt,
    required this.analysis,
    this.quote,
  });

  final String entryId;

  /// The entry's version it was made for; an edit since makes it older.
  final int bodyVersion;
  final DateTime savedAt;
  final AiAnalysis analysis;

  /// The quote shown after it, if any.
  final ({String text, String author})? quote;

  Map<String, Object?> toJson() => {
        'entryId': entryId,
        'bodyVersion': bodyVersion,
        'savedAt': savedAt.toUtc().toIso8601String(),
        'analysis': analysis.toJson(),
        if (quote case final quote?)
          'quote': {'text': quote.text, 'author': quote.author},
      };

  static SavedAnalysis? fromJson(Object? raw) {
    try {
      final json = raw as Map<String, dynamic>;
      final quote = json['quote'] as Map<String, dynamic>?;
      return SavedAnalysis(
        entryId: json['entryId'] as String,
        bodyVersion: json['bodyVersion'] as int,
        savedAt: DateTime.parse(json['savedAt'] as String).toLocal(),
        analysis:
            AiAnalysis.fromJson(json['analysis'] as Map<String, dynamic>),
        quote: quote == null
            ? null
            : (text: quote['text'] as String, author: quote['author'] as String),
      );
    } catch (_) {
      // Unreadable (an older shape): as if there were none.
      return null;
    }
  }
}

/// Analyses kept on this device, per account, one per entry (the latest).
///
/// On the device only until the backend keeps analyses with the entries
/// (proposed to the backend): another phone, or a reinstall, starts empty.
class AnalysisArchive {
  AnalysisArchive._(this._prefs, this.userId);

  static Future<AnalysisArchive> open({String? userId}) async =>
      AnalysisArchive._(await SharedPreferences.getInstance(), userId);

  final SharedPreferences _prefs;
  final String? userId;

  String get _prefix => userId == null
      ? 'journal.analysis.'
      : 'account.$userId.journal.analysis.';

  SavedAnalysis? of(String entryId) {
    final raw = _prefs.getString('$_prefix$entryId');
    return raw == null ? null : SavedAnalysis.fromJson(jsonDecode(raw));
  }

  /// Every kept analysis of this account, newest first.
  List<SavedAnalysis> all() => [
        for (final key in _prefs.getKeys())
          if (key.startsWith(_prefix))
            if (of(key.substring(_prefix.length)) case final saved?) saved,
      ]..sort((a, b) => b.savedAt.compareTo(a.savedAt));

  Future<void> save(SavedAnalysis analysis) => _prefs.setString(
      '$_prefix${analysis.entryId}', jsonEncode(analysis.toJson()));

  /// With its entry: an analysis never outlives what it read.
  Future<void> remove(String entryId) => _prefs.remove('$_prefix$entryId');
}
