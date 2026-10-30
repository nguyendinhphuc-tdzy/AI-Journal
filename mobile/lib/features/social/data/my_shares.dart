import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One 24-hour post the user shared, kept on this device after it ends:
/// the archive under "Đã chia sẻ" and the user's own pins on the map. The
/// photo is the album memory's own file (the server deletes its copy when
/// the post ends).
@immutable
class MyShare {
  const MyShare({
    required this.id,
    required this.memoryId,
    required this.albumId,
    required this.text,
    required this.placeLabel,
    required this.latitude,
    required this.longitude,
    required this.sharedAt,
    required this.expiresAt,
    this.title,
    this.category,
    this.photoPath,
    this.recipientIds = const [],
    this.recipientNames = const [],
    this.revokedAt,
  });

  final String id;
  final String memoryId;
  final String albumId;
  final String? title;
  final String text;
  final String placeLabel;
  final double latitude;
  final double longitude;

  /// The category's label, as shown.
  final String? category;
  final String? photoPath;
  final List<String> recipientIds;
  final List<String> recipientNames;
  final DateTime sharedAt;
  final DateTime expiresAt;
  final DateTime? revokedAt;

  bool isActive(DateTime now) => revokedAt == null && now.isBefore(expiresAt);

  MyShare revoked(DateTime at) => MyShare(
        id: id,
        memoryId: memoryId,
        albumId: albumId,
        title: title,
        text: text,
        placeLabel: placeLabel,
        latitude: latitude,
        longitude: longitude,
        category: category,
        photoPath: photoPath,
        recipientIds: recipientIds,
        recipientNames: recipientNames,
        sharedAt: sharedAt,
        expiresAt: expiresAt,
        revokedAt: revokedAt ?? at,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'memoryId': memoryId,
        'albumId': albumId,
        'title': title,
        'text': text,
        'placeLabel': placeLabel,
        'latitude': latitude,
        'longitude': longitude,
        'category': category,
        'photoPath': photoPath,
        'recipientIds': recipientIds,
        'recipientNames': recipientNames,
        'sharedAt': sharedAt.toUtc().toIso8601String(),
        'expiresAt': expiresAt.toUtc().toIso8601String(),
        'revokedAt': revokedAt?.toUtc().toIso8601String(),
      };

  static MyShare? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'], memory = json['memoryId'], album = json['albumId'];
    final text = json['text'], label = json['placeLabel'];
    final lat = json['latitude'], lon = json['longitude'];
    final shared = DateTime.tryParse('${json['sharedAt']}');
    final expires = DateTime.tryParse('${json['expiresAt']}');
    if (id is! String ||
        memory is! String ||
        album is! String ||
        text is! String ||
        label is! String ||
        lat is! num ||
        lon is! num ||
        shared == null ||
        expires == null) {
      return null;
    }
    List<String> strings(Object? v) =>
        v is List ? [for (final x in v) if (x is String) x] : const [];
    return MyShare(
      id: id,
      memoryId: memory,
      albumId: album,
      title: json['title'] as String?,
      text: text,
      placeLabel: label,
      latitude: lat.toDouble(),
      longitude: lon.toDouble(),
      category: json['category'] as String?,
      photoPath: json['photoPath'] as String?,
      recipientIds: strings(json['recipientIds']),
      recipientNames: strings(json['recipientNames']),
      sharedAt: shared,
      expiresAt: expires,
      revokedAt: DateTime.tryParse('${json['revokedAt']}'),
    );
  }
}

/// The user's shared posts on this device, newest first, per account.
class MySharesArchive {
  MySharesArchive({required this.userId, this.keep = true});

  final String userId;

  /// False in tests: nothing is written to the device.
  final bool keep;

  /// At most this many are kept; the oldest go first.
  static const limit = 300;

  final _shares = ValueNotifier<List<MyShare>>(const []);
  ValueListenable<List<MyShare>> get shares => _shares;

  String get _key => 'shares.mine.$userId';

  Future<void> load() async {
    if (!keep) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return;
      final list = (jsonDecode(raw) as List).map(MyShare.fromJson).nonNulls;
      _shares.value = List.unmodifiable(
          list.toList()..sort((a, b) => b.sharedAt.compareTo(a.sharedAt)));
    } catch (_) {
      // Unreadable: an empty archive.
    }
  }

  MyShare? byId(String id) {
    for (final s in _shares.value) {
      if (s.id == id) return s;
    }
    return null;
  }

  /// The memory's post still on, if any.
  MyShare? activeFor(String memoryId, DateTime now) {
    for (final s in _shares.value) {
      if (s.memoryId == memoryId && s.isActive(now)) return s;
    }
    return null;
  }

  Future<void> add(MyShare share) => _set([
        share,
        for (final s in _shares.value)
          if (s.id != share.id) s
      ]);

  Future<void> revoke(String id, DateTime at) => _set([
        for (final s in _shares.value) s.id == id ? s.revoked(at) : s
      ]);

  Future<void> _set(List<MyShare> list) async {
    final kept = list.length > limit ? list.sublist(0, limit) : list;
    _shares.value = List.unmodifiable(kept);
    if (!keep) return;
    try {
      await (await SharedPreferences.getInstance()).setString(
          _key, jsonEncode([for (final s in kept) s.toJson()]));
    } catch (_) {
      // Kept for this run only.
    }
  }
}
