import 'dart:convert';

import 'package:flutter/widgets.dart';

import 'package:shared_preferences/shared_preferences.dart';

/// Where the user is in Study, kept on this device so leaving the app loses
/// nothing: the challenge (joined, paused or left), tasks done and their
/// journal entries, lessons read, and unsaved task drafts.
class StudyProgress {
  StudyProgress({
    this.joined = false,
    this.paused = false,
    this.left = false,
    this.caseRead = false,
    Set<int>? doneTasks,
    Set<int>? doneLessons,
    Map<int, String>? drafts,
    Map<int, String>? taskEntries,
  })  : doneTasks = doneTasks ?? {},
        doneLessons = doneLessons ?? {},
        drafts = drafts ?? {},
        taskEntries = taskEntries ?? {};

  bool joined;
  bool paused;
  bool left;
  bool caseRead;
  final Set<int> doneTasks;
  final Set<int> doneLessons;

  /// Task → unsaved text.
  final Map<int, String> drafts;

  /// Task → the journal entry it was saved as.
  final Map<int, String> taskEntries;

  /// Takes [other]'s values, keeping these collections (others hold them).
  void replaceWith(StudyProgress other) {
    joined = other.joined;
    paused = other.paused;
    left = other.left;
    caseRead = other.caseRead;
    doneTasks
      ..clear()
      ..addAll(other.doneTasks);
    doneLessons
      ..clear()
      ..addAll(other.doneLessons);
    drafts
      ..clear()
      ..addAll(other.drafts);
    taskEntries
      ..clear()
      ..addAll(other.taskEntries);
  }

  Map<String, Object?> toJson() => {
        'joined': joined,
        'paused': paused,
        'left': left,
        'caseRead': caseRead,
        'doneTasks': doneTasks.toList()..sort(),
        'doneLessons': doneLessons.toList()..sort(),
        'drafts': {for (final e in drafts.entries) '${e.key}': e.value},
        'taskEntries': {
          for (final e in taskEntries.entries) '${e.key}': e.value
        },
      };

  static StudyProgress fromJson(Map<String, Object?> json) {
    Map<int, String> byTask(Object? map) => {
          for (final e in (map as Map? ?? const {}).entries)
            if (int.tryParse('${e.key}') case final task?) task: '${e.value}',
        };
    Set<int> ints(Object? list) =>
        {for (final item in list as List? ?? const []) item as int};
    return StudyProgress(
      joined: json['joined'] == true,
      paused: json['paused'] == true,
      left: json['left'] == true,
      caseRead: json['caseRead'] == true,
      doneTasks: ints(json['doneTasks']),
      doneLessons: ints(json['doneLessons']),
      drafts: byTask(json['drafts']),
      taskEntries: byTask(json['taskEntries']),
    );
  }
}

/// Keeps [StudyProgress]. [LocalStudyProgressStore] in the app;
/// [InMemoryStudyProgressStore] in tests.
abstract interface class StudyProgressStore {
  /// Null when nothing was kept yet.
  Future<StudyProgress?> load();

  Future<void> save(StudyProgress progress);
}

/// On this device, via shared_preferences.
class LocalStudyProgressStore implements StudyProgressStore {
  const LocalStudyProgressStore({this.userId});

  /// Null retains the original local-only demo key. Real auth and guest
  /// sessions always pass their own user IDs, never importing other users'
  /// unscoped Study drafts without an explicit reviewed migration.
  final String? userId;

  String get _key => userId == null ? 'study.progress' : 'study.progress.$userId';

  @override
  Future<StudyProgress?> load() async {
    final raw = (await SharedPreferences.getInstance()).getString(_key);
    return raw == null
        ? null
        : StudyProgress.fromJson(
            Map<String, Object?>.from(jsonDecode(raw) as Map));
  }

  @override
  Future<void> save(StudyProgress progress) async {
    final ok = await (await SharedPreferences.getInstance())
        .setString(_key, jsonEncode(progress.toJson()));
    if (!ok) throw StateError('Could not keep Study progress');
  }
}

/// In memory only, for tests.
class InMemoryStudyProgressStore implements StudyProgressStore {
  InMemoryStudyProgressStore([this.kept]);

  StudyProgress? kept;

  @override
  Future<StudyProgress?> load() async =>
      kept == null ? null : StudyProgress.fromJson(kept!.toJson());

  @override
  Future<void> save(StudyProgress progress) async =>
      kept = StudyProgress.fromJson(progress.toJson());
}


/// A different identity gets a different on-device Study progress store.
/// This is never a Supabase table; account sync is a later contract.
class StudyProgressScope extends InheritedWidget {
  const StudyProgressScope({
    super.key,
    required this.repository,
    required super.child,
  });

  final StudyProgressStore repository;

  static StudyProgressScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<StudyProgressScope>();

  @override
  bool updateShouldNotify(StudyProgressScope old) =>
      repository != old.repository;
}
