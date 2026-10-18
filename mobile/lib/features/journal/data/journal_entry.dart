import 'guided_template.dart';
import 'journal_mood.dart';

/// Structured values of a guided body.
class GuidedValues {
  const GuidedValues({
    required this.templateId,
    required this.templateVersion,
    required this.fields,
  });

  factory GuidedValues.of(
          GuidedTemplate template, Map<String, String> fields) =>
      GuidedValues(
        templateId: template.id,
        templateVersion: template.version,
        fields: template.clean(fields),
      );

  final String templateId;
  final int templateVersion;
  final Map<String, String> fields;

  Map<String, Object?> toJson() =>
      {'id': templateId, 'version': templateVersion, 'fields': fields};

  static GuidedValues fromJson(Map<String, Object?> json) => GuidedValues(
        templateId: json['id']! as String,
        templateVersion: json['version']! as int,
        fields: Map<String, String>.from(json['fields']! as Map),
      );

  @override
  bool operator ==(Object other) =>
      other is GuidedValues &&
      other.templateId == templateId &&
      other.templateVersion == templateVersion &&
      _sameFields(other.fields, fields);

  @override
  int get hashCode => Object.hash(
      templateId,
      templateVersion,
      Object.hashAllUnordered(
          fields.entries.map((e) => '${e.key}=${e.value}')));

  static bool _sameFields(Map<String, String> a, Map<String, String> b) =>
      a.length == b.length && a.entries.every((e) => b[e.key] == e.value);
}

/// What the user wrote: the readable body, the mood they picked, and the
/// structured values when the body was guided.
class JournalContent {
  const JournalContent({required this.body, this.mood, this.guided});

  final String body;
  final JournalMood? mood;
  final GuidedValues? guided;

  @override
  bool operator ==(Object other) =>
      other is JournalContent &&
      other.body == body &&
      other.mood == mood &&
      other.guided == guided;

  @override
  int get hashCode => Object.hash(body, mood, guided);
}

/// A saved journal entry. [bodyVersion] starts at 1 and goes up on every
/// content change, so an AI reflection can be tied to the text it answered.
class JournalEntry {
  const JournalEntry({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    required this.bodyVersion,
    required this.content,
  });

  final String id;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int bodyVersion;
  final JournalContent content;

  String get body => content.body;

  Map<String, Object?> toJson() => {
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'bodyVersion': bodyVersion,
        'body': content.body,
        'mood': content.mood?.name,
        'guided': content.guided?.toJson(),
      };

  static JournalEntry fromJson(Map<String, Object?> json) => JournalEntry(
        id: json['id']! as String,
        createdAt: DateTime.parse(json['createdAt']! as String),
        updatedAt: DateTime.parse(json['updatedAt']! as String),
        bodyVersion: json['bodyVersion']! as int,
        content: JournalContent(
          body: json['body']! as String,
          mood: JournalMood.values.asNameMap()[json['mood']],
          guided: json['guided'] == null
              ? null
              : GuidedValues.fromJson(
                  Map<String, Object?>.from(json['guided']! as Map)),
        ),
      );
}

/// Unsaved work, autosaved while writing. Not an entry: it has no id and is
/// never listed with entries.
class JournalDraft {
  const JournalDraft(
      {this.mood, required this.fields, required this.updatedAt});

  final JournalMood? mood;
  final Map<String, String> fields;
  final DateTime updatedAt;

  bool get isEmpty =>
      mood == null && fields.values.every((value) => value.trim().isEmpty);

  Map<String, Object?> toJson() => {
        'mood': mood?.name,
        'fields': fields,
        'updatedAt': updatedAt.toIso8601String(),
      };

  static JournalDraft fromJson(Map<String, Object?> json) => JournalDraft(
        mood: JournalMood.values.asNameMap()[json['mood']],
        fields: Map<String, String>.from(json['fields']! as Map),
        updatedAt: DateTime.parse(json['updatedAt']! as String),
      );
}
