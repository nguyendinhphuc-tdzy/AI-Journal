import 'package:ai_diary/features/journal/data/journal_entry.dart';
import 'package:ai_diary/features/journal/data/journal_repository.dart';
import 'package:ai_diary/features/onboarding/data/onboarding_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('Local journal content is separated by authenticated user ID',
      () async {
    SharedPreferences.setMockInitialValues({});
    final a = await LocalJournalRepository.open(userId: 'a');
    final b = await LocalJournalRepository.open(userId: 'b');
    await a.create(const JournalContent(body: 'Private entry for A'));
    expect(await b.entries(), isEmpty);
    expect((await (await LocalJournalRepository.open(userId: 'a'))
        .entries()).single.body, 'Private entry for A');
    expect((await (await LocalJournalRepository.open()).entries()), isEmpty);
  });

  test('Onboarding completion and nickname are per-user', () async {
    SharedPreferences.setMockInitialValues({});
    final a = await OnboardingStore.open(userId: 'a');
    final b = await OnboardingStore.open(userId: 'b');
    await a.saveNickname('A');
    await a.complete();
    expect(a.completed, isTrue);
    expect(b.nickname, isNull);
    expect(b.completed, isFalse);
    await b.saveNickname('B');
    await a.reset();
    expect(a.completed, isFalse);
    expect(b.nickname, 'B');
  });
}
