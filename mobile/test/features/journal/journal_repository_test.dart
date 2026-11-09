import 'package:ai_diary/features/journal/data/guided_template.dart';
import 'package:ai_diary/features/journal/data/journal_entry.dart';
import 'package:ai_diary/features/journal/data/journal_mood.dart';
import 'package:ai_diary/features/journal/data/journal_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _template = GuidedTemplate.firstEntry;

JournalContent _content(Map<String, String> fields, {JournalMood? mood}) =>
    JournalContent(
      body: _template.render(mood: mood, fields: fields),
      mood: mood,
      guided: GuidedValues.of(_template, fields),
    );

void main() {
  group('First-entry template', () {
    test('renders filled blanks only: no placeholders, no half sentences', () {
      final body = _template.render(
        mood: JournalMood.calm,
        fields: {'cause': ' trời mát ', 'thought': '   ', 'hope': 'đi biển!'},
      );
      expect(body,
          'Lúc này mình cảm thấy bình yên.\nCó lẽ vì trời mát.\nTrong vài ngày tới, mình muốn đi biển!');
      for (final slot in _template.slots) {
        expect(body, isNot(contains(slot.placeholder)));
      }
      expect(body, isNot(contains('Một điều đang ở trong đầu mình là')));
    });

    test('a mood alone is not enough; one text blank is', () {
      expect(_template.hasText({}), isFalse);
      expect(_template.hasText({'cause': '  '}), isFalse);
      expect(_template.hasText({'hope': 'nghỉ ngơi'}), isTrue);
    });

    test('keeps the template id, version and only real values', () {
      final guided =
          GuidedValues.of(_template, {'cause': ' x ', 'thought': ''});
      expect(guided.templateId, 'onboarding_first_entry');
      expect(guided.templateVersion, 1);
      expect(guided.fields, {'cause': 'x'});
    });
  });

  group('Repository', () {
    test('create, then update the same id; body version goes up', () async {
      final journals = InMemoryJournalRepository();
      final first = await journals.create(_content({'cause': 'a'}));
      expect(first.bodyVersion, 1);
      final same = await journals.update(first.id, _content({'cause': 'a'}));
      expect(same.bodyVersion, 1, reason: 'unchanged content');
      final edited = await journals.update(first.id, _content({'cause': 'b'}));
      expect(edited.id, first.id);
      expect(edited.bodyVersion, 2);
      expect((await journals.entries()).single.body, 'Có lẽ vì b.');
    });

    test('delete removes only that entry', () async {
      final journals = InMemoryJournalRepository();
      final first = await journals.create(_content({'cause': 'a'}));
      final second = await journals.create(_content({'cause': 'b'}));
      var notified = 0;
      journals.addListener(() => notified++);
      await journals.delete(first.id);
      expect([for (final entry in await journals.entries()) entry.id],
          [second.id]);
      expect(await journals.entry(first.id), isNull);
      expect(notified, 1);
      expect(() => journals.delete(first.id), throwsStateError);
    });

    test('drafts are never entries', () async {
      final journals = InMemoryJournalRepository();
      await journals.saveDraft(
          'k',
          JournalDraft(
              fields: const {'cause': 'a'}, updatedAt: DateTime(2026)));
      expect(await journals.entries(), isEmpty);
      expect((await journals.draft('k'))!.fields, {'cause': 'a'});
      await journals.deleteDraft('k');
      expect(await journals.draft('k'), isNull);
    });

    test('newest first; listeners hear about saves', () async {
      final journals = InMemoryJournalRepository();
      var heard = 0;
      journals.addListener(() => heard++);
      final a = await journals.create(_content({'cause': 'a'}));
      await Future<void>.delayed(const Duration(milliseconds: 2));
      final b = await journals.create(_content({'cause': 'b'}));
      expect((await journals.entries()).map((e) => e.id), [b.id, a.id]);
      expect(heard, 2);
    });

    test('on-device store keeps entries, structure and mood', () async {
      SharedPreferences.setMockInitialValues({});
      final journals = await LocalJournalRepository.open();
      final saved = await journals
          .create(_content({'thought': 'công việc'}, mood: JournalMood.tired));
      final reopened = await LocalJournalRepository.open();
      final entry = (await reopened.entry(saved.id))!;
      expect(entry.content.mood, JournalMood.tired);
      expect(entry.content.guided!.fields, {'thought': 'công việc'});
      expect(entry.body, contains('mệt'));
    });
  });
}
