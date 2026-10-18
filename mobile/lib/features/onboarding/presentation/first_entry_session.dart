import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../journal/data/guided_template.dart';
import '../../journal/data/journal_entry.dart';
import '../../journal/data/journal_mood.dart';
import '../../journal/data/journal_repository.dart';
import '../data/onboarding_store.dart';

enum DraftStatus { none, saving, saved, failed }

enum SaveStatus { idle, saving, failed }

/// OB07 state, owned by the flow so Back to OB06 and return keeps the mood,
/// the fields, the draft and the sheets' unconfirmed text.
///
/// Writes go to the shared [JournalRepository]: an autosaved draft (not an
/// entry) while writing, then one entry. Once saved, saving again updates
/// that same entry id.
class FirstEntrySession extends ChangeNotifier {
  FirstEntrySession({
    required this.journals,
    required this.store,
    this.template = GuidedTemplate.firstEntry,
    this.autosaveDelay = const Duration(milliseconds: 800),
  });

  static const draftKey = 'onboarding.first_entry';

  final JournalRepository journals;
  final OnboardingStore store;
  final GuidedTemplate template;
  final Duration autosaveDelay;

  JournalMood? _mood;
  final _fields = <String, String>{};

  /// Text typed in a sheet but not confirmed yet, per field.
  final sheetDrafts = <String, String>{};

  JournalEntry? _saved;
  var _draft = DraftStatus.none;
  var _save = SaveStatus.idle;
  var _loaded = false;
  Timer? _autosave;
  var _disposed = false;

  JournalMood? get mood => _mood;
  Map<String, String> get fields => Map.unmodifiable(_fields);
  String? field(String id) => _fields[id];

  /// The entry saved from this step, if any.
  JournalEntry? get saved => _saved;
  DraftStatus get draft => _draft;
  SaveStatus get save => _save;
  bool get loaded => _loaded;

  /// At least one text field; a mood alone does not make an entry.
  bool get canSave => template.hasText(_fields);

  bool get hasContent => _mood != null || _fields.isNotEmpty;

  JournalContent get content => JournalContent(
        body: template.render(mood: _mood, fields: _fields),
        mood: _mood,
        guided: GuidedValues.of(template, _fields),
      );

  /// True when there is nothing saved yet, or the text differs from it.
  bool get changed => _saved == null || _saved!.content != content;

  /// The saved entry (if any), then a newer draft over it.
  Future<void> load() async {
    if (_loaded) return;
    final id = store.firstEntryId;
    final saved = id == null ? null : await journals.entry(id);
    if (saved != null) {
      _saved = saved;
      _mood = saved.content.mood;
      _fields.addAll(saved.content.guided?.fields ?? const {});
    }
    final draft = await journals.draft(draftKey);
    if (draft != null) {
      _mood = draft.mood;
      _fields
        ..clear()
        ..addAll(template.clean(draft.fields));
      _draft = DraftStatus.saved;
    }
    _loaded = true;
    _notify();
  }

  void setMood(JournalMood? mood) {
    if (mood == _mood) return;
    _mood = mood;
    _changed();
  }

  /// Confirms a sheet: replaces the field (empty clears it).
  void setField(String id, String value) {
    final text = value.trim();
    text.isEmpty ? _fields.remove(id) : _fields[id] = text;
    sheetDrafts.remove(id);
    _changed();
  }

  void _changed() {
    if (_save == SaveStatus.failed) _save = SaveStatus.idle;
    _notify();
    _autosave?.cancel();
    _autosave = Timer(autosaveDelay, flushDraft);
  }

  /// Keeps the current text as a draft now. False when it could not be kept.
  Future<bool> flushDraft() async {
    _autosave?.cancel();
    try {
      if (!hasContent || !changed) {
        await journals.deleteDraft(draftKey);
        _draft = DraftStatus.none;
        return true;
      }
      _draft = DraftStatus.saving;
      _notify();
      await journals.saveDraft(
        draftKey,
        JournalDraft(
            mood: _mood, fields: Map.of(_fields), updatedAt: DateTime.now()),
      );
      _draft = DraftStatus.saved;
      return true;
    } catch (_) {
      _draft = DraftStatus.failed;
      return false;
    } finally {
      _notify();
    }
  }

  /// Drops the draft: back to the saved entry, or empty.
  Future<void> discardDraft() async {
    _autosave?.cancel();
    final saved = _saved;
    _mood = saved?.content.mood;
    _fields
      ..clear()
      ..addAll(saved?.content.guided?.fields ?? const {});
    sheetDrafts.clear();
    _draft = DraftStatus.none;
    try {
      await journals.deleteDraft(draftKey);
    } catch (_) {
      // Nothing to keep; a stale draft is replaced on the next write.
    }
    _notify();
  }

  /// Saves the entry, or updates the same id. Null when the save failed: the
  /// content stays, and the same call retries. Repeated taps while saving are
  /// ignored.
  Future<JournalEntry?> commit() async {
    if (_save == SaveStatus.saving || !canSave) return null;
    _autosave?.cancel();
    _save = SaveStatus.saving;
    _notify();
    try {
      final saved = _saved;
      final entry = saved == null
          ? await journals.create(content)
          : await journals.update(saved.id, content);
      await store.saveFirstEntryId(entry.id);
      _saved = entry;
      _save = SaveStatus.idle;
    } catch (_) {
      _save = SaveStatus.failed;
      _notify();
      return null;
    }
    try {
      await journals.deleteDraft(draftKey);
    } catch (_) {
      // The entry is saved; a leftover draft only reopens the same text.
    }
    _draft = DraftStatus.none;
    _notify();
    return _saved;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _autosave?.cancel();
    super.dispose();
  }
}
