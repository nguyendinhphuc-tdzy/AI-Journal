import 'package:flutter/foundation.dart';

/// An album: a named place for memories. Private by default; [locked] is an
/// extra access check on top of that, not the same thing as private.
@immutable
class Album {
  const Album({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    this.themeId = defaultTheme,
    this.locked = false,
    this.hideNameWhenLocked = false,
    this.memoryCount = 0,
  });

  /// Cover style when none was chosen. A theme only changes the cover, pose
  /// and paper details, never the app palette, navigation or body font.
  static const defaultTheme = 'classic';

  final String id;
  final String name;
  final String themeId;
  final bool locked;

  /// While locked, show "Album đã khóa" instead of [name].
  final bool hideNameWhenLocked;
  final int memoryCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isEmpty => memoryCount == 0;

  Album copyWith({
    String? name,
    String? themeId,
    bool? locked,
    bool? hideNameWhenLocked,
    int? memoryCount,
    DateTime? updatedAt,
  }) =>
      Album(
        id: id,
        name: name ?? this.name,
        themeId: themeId ?? this.themeId,
        locked: locked ?? this.locked,
        hideNameWhenLocked: hideNameWhenLocked ?? this.hideNameWhenLocked,
        memoryCount: memoryCount ?? this.memoryCount,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'themeId': themeId,
        'locked': locked,
        'hideNameWhenLocked': hideNameWhenLocked,
        'memoryCount': memoryCount,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Album.fromJson(Map<String, Object?> json) => Album(
        id: json['id']! as String,
        name: json['name']! as String,
        themeId: json['themeId'] as String? ?? defaultTheme,
        locked: json['locked'] as bool? ?? false,
        hideNameWhenLocked: json['hideNameWhenLocked'] as bool? ?? false,
        memoryCount: json['memoryCount'] as int? ?? 0,
        createdAt: DateTime.parse(json['createdAt']! as String),
        updatedAt: DateTime.parse(json['updatedAt']! as String),
      );

  @override
  bool operator ==(Object other) =>
      other is Album &&
      other.id == id &&
      other.name == name &&
      other.themeId == themeId &&
      other.locked == locked &&
      other.hideNameWhenLocked == hideNameWhenLocked &&
      other.memoryCount == memoryCount &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(id, name, themeId, locked, hideNameWhenLocked,
      memoryCount, createdAt, updatedAt);
}
