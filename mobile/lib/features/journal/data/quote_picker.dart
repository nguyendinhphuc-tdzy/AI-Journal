import 'api_ai_service.dart';
import 'quotes_vi.dart';

/// Picks the team's quote that fits an entry best, from the AI's analysis
/// of it (and the entry itself). Only [Quote.pickable] quotes, never a
/// written one; none when nothing fits well enough.
///
/// The backend's own pick ([AiAnalysis.quote]), once it has one, comes
/// first; this is used until then.
class QuotePicker {
  const QuotePicker([this.quotes = quotesVi]);

  final List<Quote> quotes;

  /// How much a topic word counts, by where it is found: what the AI read
  /// as the feeling weighs most.
  static const _weights = (emotion: 3, topic: 2, analysis: 1, entry: 1);

  /// Below this, no quote: better none than one beside the point.
  static const minScore = 3;

  /// [seed] (e.g. the entry) varies the pick among equally good quotes,
  /// the same for the same entry.
  Quote? pick(AiAnalysis analysis, {String entry = '', String seed = ''}) {
    final found = <String, int>{};
    void count(String text, int weight) {
      for (final topic in _topicsIn(text)) {
        found[topic] = (found[topic] ?? 0) + weight;
      }
    }

    count(analysis.emotion, _weights.emotion);
    for (final topic in [
      if (analysis.title case final title?) title,
      ...analysis.topics,
    ]) {
      count(topic, _weights.topic);
    }
    for (final text in [
      analysis.observation,
      analysis.reflection,
      if (analysis.analysis case final text?) text,
    ]) {
      count(text, _weights.analysis);
    }
    count(entry, _weights.entry);
    if (found.isEmpty) return null;

    var best = 0;
    final top = <Quote>[];
    for (final quote in quotes.where((quote) => quote.pickable)) {
      final score = quote.tags.fold(0, (sum, tag) => sum + (found[tag] ?? 0));
      if (score < minScore || score < best) continue;
      if (score > best) {
        best = score;
        top.clear();
      }
      top.add(quote);
    }
    if (top.isEmpty) return null;
    return top[_stableHash(seed) % top.length];
  }

  /// The topics [text] speaks of: a topic's word or phrase found whole.
  static Iterable<String> _topicsIn(String text) {
    final words = ' ${text.toLowerCase().split(RegExp(r'[^\p{L}\p{N}]+',
        unicode: true)).where((word) => word.isNotEmpty).join(' ')} ';
    return [
      for (final MapEntry(key: topic, value: phrases) in quoteTopics.entries)
        if (phrases.any((phrase) => words.contains(' $phrase '))) topic,
    ];
  }

  static int _stableHash(String text) =>
      text.codeUnits.fold(7, (hash, unit) => (hash * 31 + unit) & 0x3fffffff);
}
