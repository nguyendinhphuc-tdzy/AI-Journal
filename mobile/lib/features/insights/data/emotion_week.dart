import '../../journal/data/analysis_archive.dart';
import '../../journal/data/journal_entry.dart';
import 'emotion_scale.dart';

/// One day of [EmotionWeek].
class EmotionDay {
  const EmotionDay({
    required this.date,
    required this.entries,
    required this.analyses,
  });

  /// Midnight, local time.
  final DateTime date;

  /// Entries written that day.
  final int entries;

  /// The kept analyses of that day's entries, latest first.
  final List<SavedAnalysis> analyses;

  /// The day on the chart: the mean of its analyses that fit a group.
  double? get score {
    final scores = [
      for (final saved in analyses)
        if (scoreOf(saved.analysis.emotion) case final score?) score,
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
  EmotionWeek._(this.monday, this.days);

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
