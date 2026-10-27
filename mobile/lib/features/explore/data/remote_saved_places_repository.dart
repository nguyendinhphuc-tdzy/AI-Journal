import 'dart:convert';

import 'package:flutter/widgets.dart';

import '../../../core/network/api_client.dart';
import '../presentation/widgets/place_sheets.dart';

/// Private location pins on FastAPI, never public social/map posts.
/// UI decorations are stored in the authenticated place's private note,
/// because the backend places table has no mood/category columns.
class RemoteSavedPlacesRepository {
  const RemoteSavedPlacesRepository(this.client);
  final ApiClient client;

  static const _prefix = 'saved:';
  static const _meta = 'AIJOURNAL_PLACE_V1:';

  int _id(String id) {
    if (!id.startsWith(_prefix)) throw ArgumentError.value(id, 'id');
    final number = int.tryParse(id.substring(_prefix.length));
    if (number == null || number <= 0) throw ArgumentError.value(id, 'id');
    return number;
  }

  Map<String, dynamic> _map(Object? value) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Invalid place response');
    }
    return value;
  }

  Map<String, dynamic> _metadata(PlaceDraft draft) => {
        'category': draft.category,
        'mood_tag': draft.moodTag,
        'note': draft.note,
        'mood_label': draft.moodLabel,
      };

  String _asset(String moodLabel) => switch (moodLabel) {
        'Reading' => 'assets/images/docsach.gif',
        'On the road' => 'assets/images/laixe.gif',
        'Loved it' => 'assets/images/like.gif',
        _ => 'assets/images/loading.gif',
      };

  Map<String, dynamic> _unpack(String? note) {
    if (note == null || note.isEmpty) return const {};
    if (!note.startsWith(_meta)) return {'note': note};
    try {
      final data = jsonDecode(note.substring(_meta.length));
      if (data is Map<String, dynamic>) return data;
    } on FormatException {
      // Legacy unstructured notes remain readable, no data destroyed.
    }
    return {'note': note};
  }

  Future<String?> _firstNote(int id) async {
    final response = await client.getJson(
      '/places/$id/notes?limit=1', requireAuth: true,
    );
    final raw = response['items'];
    if (raw is! List) throw const FormatException('Invalid place notes');
    if (raw.isEmpty) return null;
    final note = _map(raw.first)['content'];
    if (note is! String) throw const FormatException('Invalid place note');
    return note;
  }

  Future<SavedPlace> _convert(Object? raw) async {
    final obj = _map(raw);
    final id = obj['id'];
    final label = obj['label'];
    final lat = obj['latitude'];
    final lon = obj['longitude'];
    if (id is! int || id <= 0 ||
        label is! String || label.trim().isEmpty ||
        lat is! num || !lat.isFinite || lat < -90 || lat > 90 ||
        lon is! num || !lon.isFinite || lon < -180 || lon > 180) {
      throw const FormatException('Invalid saved place');
    }
    final stored = _unpack(await _firstNote(id));
    final mood = stored['mood_label'] is String
        ? stored['mood_label'] as String
        : 'Taking a breath';
    return SavedPlace(
      id: '$_prefix$id',
      name: label,
      latitude: lat.toDouble(),
      longitude: lon.toDouble(),
      category: stored['category'] is String
          ? stored['category'] as String : 'Chill',
      moodTag: stored['mood_tag'] is String
          ? stored['mood_tag'] as String : 'Yên tĩnh',
      note: stored['note'] is String ? stored['note'] as String : '',
      moodLabel: mood,
      moodAsset: _asset(mood),
    );
  }

  Future<List<SavedPlace>> all() async {
    final results = <SavedPlace>[];
    String? cursor;
    final seen = <String>{};
    do {
      final suffix = cursor == null
          ? '?limit=100'
          : '?limit=100&cursor=${Uri.encodeQueryComponent(cursor)}';
      final response = await client.getJson(
        '/places$suffix', requireAuth: true,
      );
      final items = response['items'];
      if (items is! List) throw const FormatException('Invalid places page');
      for (final item in items) {
        // The provider's response is scoped to the user by JWT.
        results.add(await _convert(item));
      }
      final next = response['next_cursor'];
      if (next != null && (next is! String || next.isEmpty || !seen.add(next))) {
        throw const FormatException('Invalid saved places cursor');
      }
      cursor = next as String?;
      if (results.length > 1000) {
        throw StateError('Too many saved places for this MVP');
      }
    } while (cursor != null);
    return results;
  }

  /// A private pin is first created, then its private note is attached.
  /// Partial failure is explicit (with saved server id); never retry POST
  /// blindly, which would create duplicate manual pins.
  Future<SavedPlace> create(PlaceDraft draft, {
    required double latitude,
    required double longitude,
  }) async {
    if (draft.isAnonymousShare) {
      throw UnsupportedError('Community posts are not private Saved Places');
    }
    if (!latitude.isFinite || !longitude.isFinite ||
        latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) {
      throw ArgumentError('Invalid pin coordinates');
    }
    final saved = await client.postJson('/places', {
      'label': draft.name.trim(),
      'latitude': latitude,
      'longitude': longitude,
      'provider': 'manual',
    }, requireAuth: true);
    final id = saved['id'];
    if (id is! int || id <= 0) throw const FormatException('Invalid saved pin');
    try {
      await client.postJson('/places/$id/notes', {
        'content': '$_meta${jsonEncode(_metadata(draft))}',
      }, requireAuth: true);
    } catch (_) {
      throw PartiallySavedPlace(id);
    }
    return _convert(saved);
  }

  Future<void> delete(String id) async => client.deleteNoContent(
        '/places/${_id(id)}', requireAuth: true,
      );

  Future<SavedPlace> rename(String id, String label) async {
    final updated = await client.patchJson('/places/${_id(id)}', {
      'label': label.trim(),
    }, requireAuth: true);
    return _convert(updated);
  }
}

/// The pin exists in Supabase, but its decoration/note did not save.
class PartiallySavedPlace implements Exception {
  const PartiallySavedPlace(this.remoteId);
  final int remoteId;
}

/// Only present when a real Supabase session enables cloud Saved Places.
class SavedPlacesScope extends InheritedWidget {
  const SavedPlacesScope({
    super.key, required this.repository, required super.child,
  });

  final RemoteSavedPlacesRepository repository;

  static RemoteSavedPlacesRepository? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SavedPlacesScope>()?.repository;

  @override
  bool updateShouldNotify(SavedPlacesScope old) =>
      old.repository != repository;
}
