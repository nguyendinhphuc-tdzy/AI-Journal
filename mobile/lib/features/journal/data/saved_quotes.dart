import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/data/app_data.dart';

/// A quote the user kept ("Lưu"), newest first in [SavedQuotes.all].
typedef SavedQuote = ({String text, String author, DateTime savedAt});

/// The quotes an account kept, on this device, so they outlive a restart
/// and never show in another account. Mirrored into [savedThisWeekItems],
/// which Home's "Đã lưu" shows. On the device until the backend keeps them
/// (proposed: /saved-quotes).
class SavedQuotes {
  SavedQuotes._(this._prefs, this.userId);

  static Future<SavedQuotes> open({String? userId}) async =>
      SavedQuotes._(await SharedPreferences.getInstance(), userId);

  final SharedPreferences _prefs;
  final String? userId;

  String get _key =>
      userId == null ? 'journal.savedQuotes' : 'account.$userId.journal.savedQuotes';

  List<SavedQuote> all() {
    final raw = _prefs.getString(_key);
    if (raw == null) return const [];
    try {
      return [
        for (final item in jsonDecode(raw) as List)
          (
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

  /// Kept again, it moves to the top with the new time: never twice.
  Future<void> save(String text, String author) => _write([
        (text: text, author: author, savedAt: DateTime.now()),
        for (final quote in all())
          if (quote.text != text) quote,
      ]);

  Future<void> remove(String text) =>
      _write([for (final quote in all()) if (quote.text != text) quote]);

  Future<void> _write(List<SavedQuote> quotes) async {
    await _prefs.setString(
        _key,
        jsonEncode([
          for (final quote in quotes)
            {
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
