import 'package:flutter/foundation.dart';

/// Where a memory happened, when the user added a place (E05).
@immutable
class MemoryPlace {
  const MemoryPlace({
    required this.label,
    required this.latitude,
    required this.longitude,
    this.named = true,
    this.address,
    this.placeId,
  });

  /// What is shown for the place. For a pin without a name it says so
  /// ([unnamedLabel]); never empty.
  final String label;
  final double latitude;
  final double longitude;

  /// False for coordinates nobody named (the lookup failed or found nothing).
  final bool named;
  final String? address;

  /// The search provider's id, when picked from search.
  final String? placeId;

  static const unnamed = 'Vị trí chưa có tên';

  static String coordinates(double latitude, double longitude) =>
      '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}';

  static String unnamedLabel(double latitude, double longitude) =>
      '$unnamed (${coordinates(latitude, longitude)})';

  Map<String, Object?> toJson() => {
        'label': label,
        'latitude': latitude,
        'longitude': longitude,
        if (!named) 'named': false,
        if (address case final address?) 'address': address,
        if (placeId case final id?) 'placeId': id,
      };

  /// Places saved before E05 have only label and coordinates: named.
  factory MemoryPlace.fromJson(Map<String, Object?> json) => MemoryPlace(
        label: json['label']! as String,
        latitude: (json['latitude']! as num).toDouble(),
        longitude: (json['longitude']! as num).toDouble(),
        named: json['named'] as bool? ?? true,
        address: json['address'] as String?,
        placeId: json['placeId'] as String?,
      );

  @override
  bool operator ==(Object other) =>
      other is MemoryPlace &&
      other.label == label &&
      other.latitude == latitude &&
      other.longitude == longitude &&
      other.named == named &&
      other.address == address &&
      other.placeId == placeId;

  @override
  int get hashCode =>
      Object.hash(label, latitude, longitude, named, address, placeId);
}

/// What the user writes or picks for a memory. A memory needs a photo or a
/// note that is not blank; a title, date or place alone is not one.
@immutable
class MemoryContent {
  const MemoryContent({
    this.title,
    this.note,
    this.photoPath,
    required this.displayDate,
    this.place,
  });

  final String? title;
  final String? note;

  /// A photo kept by the app (`MemoryPhotos.keep`), never the picker's
  /// temporary file.
  final String? photoPath;

  /// The day the memory is about, chosen by the user; separate from when it
  /// was created or edited.
  final DateTime displayDate;
  final MemoryPlace? place;

  bool get hasNote => (note ?? '').trim().isNotEmpty;
  bool get isValid => photoPath != null || hasNote;

  Map<String, Object?> toJson() => {
        if (title case final title?) 'title': title,
        if (note case final note?) 'note': note,
        if (photoPath case final path?) 'photoPath': path,
        'displayDate': _day(displayDate),
        if (place case final place?) 'place': place.toJson(),
      };

  factory MemoryContent.fromJson(Map<String, Object?> json) => MemoryContent(
        title: json['title'] as String?,
        note: json['note'] as String?,
        photoPath: json['photoPath'] as String?,
        displayDate: DateTime.parse(json['displayDate']! as String),
        place: json['place'] == null
            ? null
            : MemoryPlace.fromJson(
                Map<String, Object?>.from(json['place']! as Map)),
      );

  static String _day(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  @override
  bool operator ==(Object other) =>
      other is MemoryContent &&
      other.title == title &&
      other.note == note &&
      other.photoPath == photoPath &&
      _day(other.displayDate) == _day(displayDate) &&
      other.place == place;

  @override
  int get hashCode =>
      Object.hash(title, note, photoPath, _day(displayDate), place);
}

/// A saved memory in an album.
@immutable
class Memory {
  const Memory({
    required this.id,
    required this.albumId,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String albumId;
  final MemoryContent content;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, Object?> toJson() => {
        'id': id,
        'albumId': albumId,
        ...content.toJson(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Memory.fromJson(Map<String, Object?> json) => Memory(
        id: json['id']! as String,
        albumId: json['albumId']! as String,
        content: MemoryContent.fromJson(json),
        createdAt: DateTime.parse(json['createdAt']! as String),
        updatedAt: DateTime.parse(json['updatedAt']! as String),
      );
}

/// The editor's unsaved state (A06), kept while writing; not a memory.
@immutable
class MemoryDraft {
  const MemoryDraft({required this.content, required this.updatedAt});

  final MemoryContent content;
  final DateTime updatedAt;

  Map<String, Object?> toJson() =>
      {...content.toJson(), 'updatedAt': updatedAt.toIso8601String()};

  factory MemoryDraft.fromJson(Map<String, Object?> json) => MemoryDraft(
        content: MemoryContent.fromJson(json),
        updatedAt: DateTime.parse(json['updatedAt']! as String),
      );
}
