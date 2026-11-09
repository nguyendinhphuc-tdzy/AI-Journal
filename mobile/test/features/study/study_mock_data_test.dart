import 'package:ai_diary/features/journal/data/journal_entry.dart';
import 'package:ai_diary/features/journal/data/journal_repository.dart';
import 'package:ai_diary/features/study/data/study_mock_data.dart';
import 'package:ai_diary/features/study/data/study_progress.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Study writing goes into the journal, one entry per challenge task',
      () async {
    final journals = InMemoryJournalRepository();
    final session = StudySession(journals: journals);
    const task = StudyWritingContext(
        kind: 'challenge',
        sourceId: 'task-1',
        challenge: challengeId,
        taskIndex: 0);
    final first = await session.save(
        'Nhật ký đầu tiên', challengePrompts[0], task,
        label: 'Challenge · Nhiệm vụ 1');
    final retry = await session.save(
        'Nhật ký đầu tiên', challengePrompts[0], task,
        label: 'Challenge · Nhiệm vụ 1');
    await session.save('Thực hành riêng', studyLessons[0].prompt,
        StudyWritingContext(kind: 'lesson', sourceId: studyLessons[0].id),
        label: 'Bài học · ${studyLessons[0].title}');
    expect(retry.id, first.id);
    expect(session.challengeEntries.map((e) => e.id), [first.id]);
    expect(session.entryForTask(0)?.content, 'Nhật ký đầu tiên');
    expect(session.entryForTask(1), isNull);
    expect(session.taskEntries, {0: first.id});

    // Both are journal entries, named by where they were written.
    final entries = await journals.entries();
    expect(entries, hasLength(2));
    final saved = (await journals.entry(first.id))!;
    expect(saved.body, 'Nhật ký đầu tiên');
    expect(
        saved.content.source,
        const JournalSource(
            kind: 'challenge',
            id: challengeId,
            task: 0,
            label: 'Challenge · Nhiệm vụ 1'));
  });

  test('Task entries come back from the journal; a deleted one is forgotten',
      () async {
    final journals = InMemoryJournalRepository();
    final kept = await journals.create(const JournalContent(body: 'Còn đây'));
    final gone = await journals.create(const JournalContent(body: 'Đã xóa'));
    await journals.delete(gone.id);
    var changed = 0;
    final session =
        StudySession(journals: journals, taskEntries: {0: kept.id, 1: gone.id})
          ..onChanged = () => changed++;
    await session.load();
    expect(session.entryForTask(0)?.content, 'Còn đây');
    expect(session.entryForTask(0)?.prompt, challengePrompts[0]);
    expect(session.entryForTask(1), isNull);
    expect(session.taskEntries, {0: kept.id});
    expect(changed, 1);
  });

  test('Progress survives a round trip through its store', () async {
    final store = InMemoryStudyProgressStore();
    expect(await store.load(), isNull);
    await store.save(StudyProgress(
      joined: true,
      left: true,
      caseRead: true,
      doneTasks: {0, 2},
      doneLessons: {1},
      drafts: {3: 'Bản nháp'},
      taskEntries: {0: 'local-1', 2: 'local-2'},
    ));
    final back = (await store.load())!;
    expect(back.joined, isTrue);
    expect(back.paused, isFalse);
    expect(back.left, isTrue);
    expect(back.caseRead, isTrue);
    expect(back.doneTasks, {0, 2});
    expect(back.doneLessons, {1});
    expect(back.drafts, {3: 'Bản nháp'});
    expect(back.taskEntries, {0: 'local-1', 2: 'local-2'});
  });

  test('Entries saved before sources existed still load', () {
    final entry = JournalEntry.fromJson({
      'id': 'old',
      'createdAt': '2026-10-20T08:00:00.000',
      'updatedAt': '2026-10-20T08:00:00.000',
      'bodyVersion': 1,
      'body': 'Cũ',
      'mood': null,
      'guided': null,
    });
    expect(entry.content.source, isNull);
    const source = JournalSource(
        kind: 'framework', id: 'clear-my-mind', label: 'Mẫu viết · X');
    final round = JournalEntry.fromJson(JournalEntry(
      id: 'new',
      createdAt: DateTime(2026, 10, 27),
      updatedAt: DateTime(2026, 10, 27),
      bodyVersion: 1,
      content: const JournalContent(body: 'Mới', source: source),
    ).toJson());
    expect(round.content.source, source);
  });

  test('Every piece of Study writing has its own deeper questions', () {
    final sources = [
      for (var i = 0; i < challengePrompts.length; i++)
        StudyWritingContext(
            kind: 'challenge',
            sourceId: 'task-${i + 1}',
            challenge: challengeId,
            taskIndex: i),
      for (final lesson in [...studyLessons, studyCase])
        StudyWritingContext(kind: 'lesson', sourceId: lesson.id),
      const StudyWritingContext(kind: 'course', sourceId: 'gratitude-course'),
      const StudyWritingContext(kind: 'framework', sourceId: 'clear-my-mind'),
    ];
    final asked = [for (final source in sources) studyFollowUps(source)];
    for (final questions in asked) {
      expect(questions, hasLength(2));
    }
    // No two share their first question: none falls back to the general.
    expect(asked.map((q) => q.first).toSet(), hasLength(sources.length));
  });

  test('Reader fixtures have distinct editorial content and stable IDs', () {
    final lessons = [...studyLessons, studyCase];
    expect(lessons.map((l) => l.id).toSet().length, lessons.length);
    expect(lessons.map((l) => l.prompt).toSet().length, lessons.length);
    expect(
        lessons.map((l) => l.paragraphs.first).toSet().length, lessons.length);
    for (final lesson in lessons) {
      expect(lesson.minutes, greaterThan(0));
      expect(lesson.summary, isNotEmpty);
      expect(lesson.paragraphs, isNotEmpty);
    }
  });
}
