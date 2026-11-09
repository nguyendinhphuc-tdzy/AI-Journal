import '../../journal/data/analysis_archive.dart';
import '../../journal/data/cloud_ai_api.dart';
import '../../journal/data/journal_entry.dart';
import 'emotion_scale.dart';

/// One day of [EmotionWeek].
class EmotionDay {
  const EmotionDay({
    required this.date,
    required this.entries,
    required this.analyses,
    this.serverScore,
    this.scoredOnServer = false,
  });

  /// The server's score for the day ([scoredOnServer]), from the account's
  /// current analyses; null there means none, never a local guess.
  final double? serverScore;
  final bool scoredOnServer;

  /// Midnight, local time.
  final DateTime date;

  /// Entries written that day.
  final int entries;

  /// The kept analyses of that day's entries, latest first.
  final List<SavedAnalysis> analyses;

  /// The day on the chart: the server's when it gave one, else the mean of
  /// its analyses that fit a group (the backend's score of each when it
  /// has one, else the app's sorting of the words).
  double? get score {
    if (scoredOnServer) return serverScore;
    final scores = [
      for (final saved in analyses)
        if (saved.analysis.moodScore?.toDouble() ??
                scoreOf(saved.analysis.emotion)
            case final score?)
          score,
    ];
    if (scores.isEmpty) return null;
    return scores.reduce((a, b) => a + b) / scores.length;
  }

  /// The feelings the AI named that day, as it wrote them, no repeats.
  List<String> get emotions => [
        ...{for (final saved in analyses) saved.analysis.emotion.trim()},
      ];
}

/// A week (Monday to Sunday) of entries and the analyses kept for them.
class EmotionWeek {
  EmotionWeek._(this.monday, this.days, [this._serverStandout]);

  /// The groups the server counted, when it did.
  final List<({EmotionGroup group, int count})>? _serverStandout;

  /// The same week with the server's scores and standout (an account):
  /// entries, analyses and words stay as here.
  EmotionWeek withServer(CloudWeek server) {
    final byDate = {
      for (final day in server.days)
        DateTime(day.date.year, day.date.month, day.date.day): day,
    };
    final groups = {for (final group in emotionGroups) group.id: group};
    return EmotionWeek._(
      monday,
      [
        for (final day in days)
          EmotionDay(
            date: day.date,
            entries: day.entries,
            analyses: day.analyses,
            serverScore: byDate[day.date]?.score,
            scoredOnServer: byDate.containsKey(day.date),
          ),
      ],
      [
        for (final top in server.topEmotions)
          if (groups[top.group] case final group?)
            (group: group, count: top.count),
      ],
    );
  }

  /// The week holding [day], from [entries] and the [analyses] kept for
  /// them (by entry id). An analysis whose entry is gone is not counted.
  factory EmotionWeek.of(
    DateTime day,
    List<JournalEntry> entries,
    Map<String, SavedAnalysis> analyses,
  ) {
    final date = DateTime(day.year, day.month, day.day);
    final monday = date.subtract(Duration(days: date.weekday - 1));
    final days = [
      for (var i = 0; i < 7; i++)
        () {
          final at = DateTime(monday.year, monday.month, monday.day + i);
          final written = [
            for (final entry in entries)
              if (_sameDay(entry.createdAt.toLocal(), at)) entry,
          ];
          return EmotionDay(
            date: at,
            entries: written.length,
            analyses: [
              for (final entry in written)
                if (analyses[entry.id] case final saved?) saved,
            ]..sort((a, b) => b.savedAt.compareTo(a.savedAt)),
          );
        }(),
    ];
    return EmotionWeek._(monday, days);
  }

  final DateTime monday;
  final List<EmotionDay> days;

  DateTime get sunday => days.last.date;
  int get entries => days.fold(0, (sum, day) => sum + day.entries);
  int get analysed => days.fold(0, (sum, day) => sum + day.analyses.length);

  /// How often each group came up this week, most first; a mixed feeling
  /// counts for each group it names.
  List<({EmotionGroup group, int count})> get standout {
    if (_serverStandout case final server?) return server;
    final counts = <EmotionGroup, int>{};
    for (final day in days) {
      for (final saved in day.analyses) {
        for (final group in groupsOf(saved.analysis.emotion)) {
          counts[group] = (counts[group] ?? 0) + 1;
        }
      }
    }
    return [
      for (final MapEntry(key: group, value: count) in counts.entries)
        (group: group, count: count),
    ]..sort((a, b) => b.count != a.count
        ? b.count.compareTo(a.count)
        : b.group.score.compareTo(a.group.score));
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
