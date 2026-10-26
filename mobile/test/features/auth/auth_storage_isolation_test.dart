import 'package:ai_diary/features/album/data/album_repository.dart';
import 'package:ai_diary/features/auth/data/guest_mode_store.dart';
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
  test('Album metadata is scoped per account and never reads legacy data',
      () async {
    SharedPreferences.setMockInitialValues({});
    final legacy = await LocalAlbumRepository.open();
    await legacy.create(name: 'Legacy demo album');
    final a = await LocalAlbumRepository.open(userId: 'user-a');
    final b = await LocalAlbumRepository.open(userId: 'user-b');
    await a.create(name: 'A private album');
    expect((await a.albums()).single.name, 'A private album');
    expect(await b.albums(), isEmpty);
    expect((await legacy.albums()).single.name, 'Legacy demo album');
  });

  test('Exiting guest clears only guest Journal and Album metadata',
      () async {
    SharedPreferences.setMockInitialValues({});
    final guest = await GuestModeStore.open();
    await guest.enter();
    final guestAlbum = await LocalAlbumRepository.open(
        userId: GuestModeStore.userId);
    final ownerAlbum = await LocalAlbumRepository.open(userId: 'owner');
    await guestAlbum.create(name: 'Guest album');
    await ownerAlbum.create(name: 'Owner album');
    await guest.leaveAndDiscard();
    expect((await (await LocalAlbumRepository.open(
        userId: GuestModeStore.userId)).albums()), isEmpty);
    expect((await (await LocalAlbumRepository.open(
        userId: 'owner')).albums()).single.name, 'Owner album');
  });

}
