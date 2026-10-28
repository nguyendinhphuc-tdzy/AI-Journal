import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import 'journal_entry.dart';
import 'journal_mood.dart';
import 'journal_repository.dart';

/// Owner-scoped cloud entries via FastAPI, with per-user drafts kept locally.
///
/// This adapter does not upload older local entries or guest content. It is
/// injected only when an actual SupabaseAuthService session is active AND
/// JOURNAL_CLOUD_ENABLED=true. Existing local entries are exposed explicitly
/// alongside cloud via CombinedJournalRepository, never silently hidden.
/// Backend must first deploy Alembic 20261026_08.
class RemoteJournalRepository extends ChangeNotifier implements JournalRepository {
  RemoteJournalRepository({required this.client, required this.localDrafts});

  final ApiClient client;
  final LocalJournalRepository localDrafts;

  static const String _prefix = 'cloud-';
  static final _cloudIdPattern = RegExp(r'^cloud-([1-9][0-9]*)$');

  String _pathFor(String id) {
    final match = _cloudIdPattern.firstMatch(id);
    if (match == null) {
      throw ArgumentError.value(id, 'id', 'Not a server-owned journal ID');
    }
    return '/journals/${match.group(1)!}';
  }

  JournalEntry _read(Map<String, dynamic> record) {
    final rawId = record['id'];
    final body = record['content'];
    final version = record['body_version'];
    final date = record['created_at'];
    final updated = record['updated_at'];
    final mood = record['mood'];
    final rawGuided = record['guided'];
    final rawSource = record['source'];

    if (rawId is! int || rawId <= 0 ||
        body is! String || version is! int || version < 1 ||
        date is! String || updated is! String ||
        (mood != null && mood is! String)) {
      throw const FormatException('Malformed private journal response');
    }
    final resolvedMood = mood == null ? null : JournalMood.values.asNameMap()[mood];
    if (mood != null && resolvedMood == null) {
      throw const FormatException('Unsupported journal mood');
    }
    GuidedValues? guided;
    if (rawGuided != null) {
      if (rawGuided is! Map) {
        throw const FormatException('Malformed guided journal response');
      }
      try {
        guided = GuidedValues.fromJson(
          Map<String, Object?>.from(rawGuided),
        );
      } on Object {
        throw const FormatException('Malformed guided journal response');
      }
    }

    JournalSource? source;
    if (rawSource != null) {
      if (rawSource is! Map) {
        throw const FormatException('Malformed Study source');
      }
      try {
        source = JournalSource.fromJson(Map<String, Object?>.from(rawSource));
      } on Object {
        throw const FormatException('Malformed Study source');
      }
    }

    return JournalEntry(
      id: '$_prefix$rawId',
      createdAt: DateTime.parse(date),
      updatedAt: DateTime.parse(updated),
      bodyVersion: version,
      content: JournalContent(
        body: body,
        mood: resolvedMood,
        guided: guided,
        source: source,
      ),
    );
  }

  Map<String, dynamic> _payload(JournalContent content) {
    if (content.body.trim().isEmpty) {
      throw ArgumentError.value(null, 'content', 'Journal cannot be blank');
    }
    return {
      'content': content.body,
      'mood': content.mood?.name,
      'guided': content.guided?.toJson(),
      'source': content.source?.toJson(),
    };
  }

  /// FastAPI returns a cursor-paginated page, maximum 100 rows per request.
  /// Never silently show the first page as a complete personal archive.
  @override
  Future<List<JournalEntry>> entries() async {
    final all = <JournalEntry>[];
    String? cursor;
    final seen = <String>{};
    do {
      final query = cursor == null
          ? '/journals?limit=100'
          : '/journals?limit=100&cursor=${Uri.encodeQueryComponent(cursor)}';
      final result = await client.getJson(query, requireAuth: true);
      final rawItems = result['items'];
      final next = result['next_cursor'];
      if (rawItems is! List || (next != null && (next is! String || next.isEmpty))) {
        throw const FormatException('Malformed journal archive page');
      }
      for (final raw in rawItems) {
        if (raw is! Map) throw const FormatException('Malformed journal entry');
        all.add(_read(Map<String, dynamic>.from(raw)));
      }
      if (next != null && !seen.add(next)) {
        throw const FormatException('Repeating journal archive cursor');
      }
      cursor = next as String?;
      if (seen.length > 1000) {
        throw const FormatException('Journal archive exceeded page limit');
      }
    } while (cursor != null);
    all.sort((a, b) {
      final dateOrder = b.createdAt.compareTo(a.createdAt);
      return dateOrder != 0 ? dateOrder : b.id.compareTo(a.id);
    });
    return all;
  }

  @override
  Future<JournalEntry?> entry(String id) async {
    try {
      return _read(await client.getJson(_pathFor(id), requireAuth: true));
    } on ApiException catch (error) {
      if (error.statusCode == 404) return null;
      rethrow;
    }
  }

  @override
  Future<JournalEntry> create(JournalContent content) async {
    final response = await client.postJson(
      '/journals', _payload(content), requireAuth: true,
    );
    final journal = _read(response);
    notifyListeners();
    return journal;
  }

  @override
  Future<JournalEntry> update(String id, JournalContent content) async {
    final response = await client.putJson(
      _pathFor(id), _payload(content), requireAuth: true,
    );
    final journal = _read(response);
    if (journal.id != id) {
      throw const FormatException('Journal update returned a different ID');
    }
    notifyListeners();
    return journal;
  }

  @override
  Future<void> delete(String id) async {
    await client.deleteNoContent(_pathFor(id), requireAuth: true);
    notifyListeners();
  }

  // Autosaved drafts never leave the device, even for logged-in users.
  @override
  Future<JournalDraft?> draft(String key) => localDrafts.draft(key);

  @override
  Future<void> saveDraft(String key, JournalDraft draft) =>
      localDrafts.saveDraft(key, draft);

  @override
  Future<void> deleteDraft(String key) => localDrafts.deleteDraft(key);
}

/// Explicit two-source archive for accounts with legacy on-device journals.
/// New entries go to cloud; existing device IDs remain local, never silently
/// uploaded, discarded, or hidden behind a feature flag.
class CombinedJournalRepository extends ChangeNotifier implements JournalRepository {
  CombinedJournalRepository({required this.local, required this.remote}) {
    local.addListener(notifyListeners);
    remote.addListener(notifyListeners);
  }

  final LocalJournalRepository local;
  final RemoteJournalRepository remote;

  JournalRepository _owner(String id) =>
      id.startsWith('cloud-') ? remote : local;

  @override
  Future<List<JournalEntry>> entries() async {
    final parts = await Future.wait([local.entries(), remote.entries()]);
    final entries = [...parts[0], ...parts[1]];
    entries.sort((a, b) {
      final date = b.createdAt.compareTo(a.createdAt);
      return date != 0 ? date : b.id.compareTo(a.id);
    });
    return entries;
  }

  @override
  Future<JournalEntry?> entry(String id) => _owner(id).entry(id);

  @override
  Future<JournalEntry> create(JournalContent content) => remote.create(content);

  @override
  Future<JournalEntry> update(String id, JournalContent content) =>
      _owner(id).update(id, content);

  @override
  Future<void> delete(String id) => _owner(id).delete(id);

  @override
  Future<JournalDraft?> draft(String key) => local.draft(key);

  @override
  Future<void> saveDraft(String key, JournalDraft draft) =>
      local.saveDraft(key, draft);

  @override
  Future<void> deleteDraft(String key) => local.deleteDraft(key);

  @override
  void dispose() {
    local.removeListener(notifyListeners);
    remote.removeListener(notifyListeners);
    super.dispose();
  }
}
