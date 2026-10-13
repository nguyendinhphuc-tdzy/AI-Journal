import 'package:ai_diary/features/study/data/study_mock_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Challenge association is idempotent and excludes lesson practice', () {
    final session = StudyMockSession();
    const task = StudyWritingContext(
        kind: 'challenge',
        sourceId: 'task-1',
        challenge: challengeId,
        taskIndex: 0);
    final first = session.save('Nhật ký đầu tiên', challengePrompts[0], task);
    final retry = session.save('Nhật ký đầu tiên', challengePrompts[0], task);
    session.save('Thực hành riêng', studyLessons[0].prompt,
        StudyWritingContext(kind: 'lesson', sourceId: studyLessons[0].id));
    expect(retry.id, first.id);
    expect(session.challengeEntries, [first]);
    expect(session.entryForTask(0)?.content, 'Nhật ký đầu tiên');
    expect(session.entryForTask(1), isNull);
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
