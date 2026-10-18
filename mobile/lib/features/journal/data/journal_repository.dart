import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'journal_entry.dart';

/// The one journal store, shared by Home, the editor and onboarding (no
/// separate onboarding store).
///
/// [LocalJournalRepository] keeps entries on this device so the UI works
/// before the backend is wired. The API version should implement this same
/// interface on `/api/v1/journals`; the contract needs the structured
/// fields, template version and body version added first (see
/// `features/onboarding/README.md`).
abstract interface class JournalRepository implements Listenable {
  /// Newest first.
  Future<List<JournalEntry>> entries();

  Future<JournalEntry?> entry(String id);

  Future<JournalEntry> create(JournalContent content);

  /// Same id; [JournalEntry.bodyVersion] goes up when the content changed.
  Future<JournalEntry> update(String id, JournalContent content);

  Future<JournalDraft?> draft(String key);

  Future<void> saveDraft(String key, JournalDraft draft);

  Future<void> deleteDraft(String key);
}

/// Entries and drafts as JSON strings in a key–value store.
abstract class _JsonJournalRepository extends ChangeNotifier
    implements JournalRepository {
  static const _entriesKey = 'journal.entries';
  static String _draftKey(String key) => 'journal.draft.$key';

  final _random = math.Random();

  String? read(String key);
  Future<void> write(String key, String? value);

  List<JournalEntry> _all() {
    final raw = read(_entriesKey);
    if (raw == null) return [];
    return [
      for (final item in jsonDecode(raw) as List)
        JournalEntry.fromJson(Map<String, Object?>.from(item as Map)),
    ];
  }

  Future<void> _store(List<JournalEntry> entries) async {
    await write(
        _entriesKey, jsonEncode([for (final entry in entries) entry.toJson()]));
    notifyListeners();
  }

  @override
  Future<List<JournalEntry>> entries() async =>
      _all()..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  @override
  Future<JournalEntry?> entry(String id) async {
    for (final entry in _all()) {
      if (entry.id == id) return entry;
    }
    return null;
  }

  @override
  Future<JournalEntry> create(JournalContent content) async {
    final now = DateTime.now();
    final entry = JournalEntry(
      id: 'local-${now.microsecondsSinceEpoch}-${_random.nextInt(1 << 32)}',
      createdAt: now,
      updatedAt: now,
      bodyVersion: 1,
      content: content,
    );
    await _store([..._all(), entry]);
    return entry;
  }

  @override
  Future<JournalEntry> update(String id, JournalContent content) async {
    final all = _all();
    final index = all.indexWhere((entry) => entry.id == id);
    if (index < 0) throw StateError('No journal entry $id');
    final old = all[index];
    if (old.content == content) return old;
    final entry = JournalEntry(
      id: id,
      createdAt: old.createdAt,
      updatedAt: DateTime.now(),
      bodyVersion: old.bodyVersion + 1,
      content: content,
    );
    all[index] = entry;
    await _store(all);
    return entry;
  }

  @override
  Future<JournalDraft?> draft(String key) async {
    final raw = read(_draftKey(key));
    return raw == null
        ? null
        : JournalDraft.fromJson(
            Map<String, Object?>.from(jsonDecode(raw) as Map));
  }

  @override
  Future<void> saveDraft(String key, JournalDraft draft) =>
      write(_draftKey(key), jsonEncode(draft.toJson()));

  @override
  Future<void> deleteDraft(String key) => write(_draftKey(key), null);
}

/// On this device, via shared_preferences.
class LocalJournalRepository extends _JsonJournalRepository {
  LocalJournalRepository(this._prefs);

  static Future<LocalJournalRepository> open() async =>
      LocalJournalRepository(await SharedPreferences.getInstance());

  final SharedPreferences _prefs;

  @override
  String? read(String key) => _prefs.getString(key);

  @override
  Future<void> write(String key, String? value) async {
    final ok = value == null
        ? await _prefs.remove(key)
        : await _prefs.setString(key, value);
    if (!ok) throw StateError('Could not write $key');
  }
}

/// In memory only: tests, and screens shown without a [JournalScope].
class InMemoryJournalRepository extends _JsonJournalRepository {
  final _values = <String, String>{};

  @override
  String? read(String key) => _values[key];

  @override
  Future<void> write(String key, String? value) async {
    value == null ? _values.remove(key) : _values[key] = value;
  }
}
