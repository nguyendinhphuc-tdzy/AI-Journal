import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/data/app_data.dart';
import 'cloud_ai_api.dart';

/// A quote the user kept ("Lưu"), newest first in [SavedQuotes.all]. [id]
/// is the server's, for one kept on the account; null for one kept on
/// this device only.
typedef SavedQuote = ({String? id, String text, String author, DateTime savedAt});

/// The quotes an account kept, so they outlive a restart and never show in
/// another account. Mirrored into [savedThisWeekItems], which Home's "Đã
/// lưu" shows.
///
/// With [cloud] (a signed-in account) a new quote is kept on the server
/// (/saved-quotes) and a copy here; one kept here before stays here only,
/// never sent up by itself. Without it (a guest), on this device only.
class SavedQuotes {
  SavedQuotes._(this._prefs, this.userId, this.cloud);

  static Future<SavedQuotes> open({String? userId, CloudAiApi? cloud}) async =>
      SavedQuotes._(await SharedPreferences.getInstance(), userId, cloud);

  final SharedPreferences _prefs;
  final String? userId;
  final CloudAiApi? cloud;

  String get _key =>
      userId == null ? 'journal.savedQuotes' : 'account.$userId.journal.savedQuotes';

  List<SavedQuote> all() {
    final raw = _prefs.getString(_key);
    if (raw == null) return const [];
    try {
      return [
        for (final item in jsonDecode(raw) as List)
          (
            id: item['id'] as String?,
            text: item['text'] as String,
            author: item['author'] as String,
            savedAt: DateTime.parse(item['savedAt'] as String).toLocal(),
          ),
      ];
    } catch (_) {
      return const [];
    }
  }

  bool contains(String text) => all().any((quote) => quote.text == text);

  /// Kept again, it moves to the top with the new time: never twice. On
  /// the account first, when there is one: a failure there keeps nothing.
  Future<void> save(String text, String author) async {
    SavedQuote saved =
        (id: null, text: text, author: author, savedAt: DateTime.now());
    if (cloud case final cloud?) {
      final q = await cloud.saveQuote(text, author);
      saved = (id: q.id, text: q.text, author: q.author, savedAt: q.savedAt);
    }
    await _write([
      saved,
      for (final quote in all())
        if (quote.text != text) quote,
    ]);
  }

  /// Let go here, and on the account when it is kept there.
  Future<void> remove(String text) async {
    final ids = [
      for (final quote in all())
        if (quote.text == text && quote.id != null) quote.id!,
    ];
    if (cloud case final cloud?) {
      for (final id in ids) {
        await cloud.deleteQuote(id);
      }
    }
    await _write([for (final quote in all()) if (quote.text != text) quote]);
  }

  /// The account's quotes from the server (kept on another phone, or let
  /// go there), with the ones kept on this device only. Reads only.
  Future<void> refresh() async {
    final api = cloud;
    if (api == null) {
      show();
      return;
    }
    final server = await api.savedQuotes();
    final onServer = {for (final q in server) q.text};
    await _write([
      for (final q in server)
        (id: q.id, text: q.text, author: q.author, savedAt: q.savedAt),
      // Kept here only before: still here, not sent up.
      for (final quote in all())
        if (quote.id == null && !onServer.contains(quote.text)) quote,
    ]..sort((a, b) => b.savedAt.compareTo(a.savedAt)));
  }

  Future<void> _write(List<SavedQuote> quotes) async {
    await _prefs.setString(
        _key,
        jsonEncode([
          for (final quote in quotes)
            {
              if (quote.id != null) 'id': quote.id,
              'text': quote.text,
              'author': quote.author,
              'savedAt': quote.savedAt.toUtc().toIso8601String(),
            },
        ]));
    showIn(quotes);
  }

  /// Home's "Đã lưu" from these quotes; other saved items stay.
  void show() => showIn(all());

  static void showIn(List<SavedQuote> quotes) {
    savedThisWeekItems.value = [
      for (final quote in quotes) item(quote),
      for (final other in savedThisWeekItems.value)
        if (other['type'] != 'quote') other,
    ];
  }

  /// One quote as Home's saved list shows it.
  static Map<String, dynamic> item(SavedQuote quote) {
    final at = quote.savedAt;
    String two(int n) => n.toString().padLeft(2, '0');
    final today = DateTime.now();
    final sameDay = at.year == today.year &&
        at.month == today.month &&
        at.day == today.day;
    return {
      'type': 'quote',
      'content': quote.text,
      'author': quote.author,
      'date': sameDay ? 'Hôm nay' : '${two(at.day)}/${two(at.month)}/${at.year}',
      'timestamp': '${two(at.day)}/${two(at.month)} · ${two(at.hour)}:${two(at.minute)}',
    };
  }
}
