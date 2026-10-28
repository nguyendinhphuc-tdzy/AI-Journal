import 'package:ai_diary/features/auth/data/guest_mode_store.dart';
import 'package:ai_diary/features/journal/data/journal_entry.dart';
import 'package:ai_diary/features/journal/data/journal_repository.dart';
import 'package:ai_diary/features/onboarding/data/onboarding_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('Guest mode persists on-device only and can be fully discarded',
      () async {
    SharedPreferences.setMockInitialValues({});
    final guest = await GuestModeStore.open();
    expect(guest.isActive, isFalse);
    await guest.enter();
    expect((await GuestModeStore.open()).isActive, isTrue);

    final journal =
        await LocalJournalRepository.open(userId: GuestModeStore.userId);
    await journal.create(const JournalContent(body: 'Chỉ lưu trên máy.'));
    final onboarding =
        await OnboardingStore.open(userId: GuestModeStore.userId);
    await onboarding.saveNickname('Khách');
    await onboarding.complete();

    final prefs = await SharedPreferences.getInstance();
    // These stores have different historical prefixes from users.<id>.
    await prefs.setString('study.progress.local-guest', '{"joined":true}');
    await prefs.setString('album.pin.local-guest.album-id', 'salt:hash');
    await prefs.setString('study.progress.signed-in-user', '{"joined":true}');
    await prefs.setString('album.pin.signed-in-user.album-id', 'other:hash');
    await prefs.setString('study.progress', '{"legacy":true}');
    await prefs.setString('album.pin.old-demo-album', 'demo:hash');

    final other = await LocalJournalRepository.open(userId: 'signed-in-user');
    expect(await other.entries(), isEmpty);

    await guest.leaveAndDiscard();
    expect(guest.isActive, isFalse);
    expect((await LocalJournalRepository.open(
        userId: GuestModeStore.userId)).entries(), completion(isEmpty));
    final reopened =
        await OnboardingStore.open(userId: GuestModeStore.userId);
    expect(reopened.nickname, isNull);
    expect(reopened.completed, isFalse);
    expect((await LocalJournalRepository.open()).entries(),
        completion(isEmpty));
    expect(prefs.containsKey('study.progress.local-guest'), isFalse);
    expect(prefs.containsKey('album.pin.local-guest.album-id'), isFalse);
    expect(prefs.containsKey('study.progress.signed-in-user'), isTrue);
    expect(prefs.containsKey('album.pin.signed-in-user.album-id'), isTrue);
    expect(prefs.containsKey('study.progress'), isTrue);
    expect(prefs.containsKey('album.pin.old-demo-album'), isTrue);
  });

  test('Guest data never appears under a real account ID', () async {
    SharedPreferences.setMockInitialValues({});
    final guest =
        await LocalJournalRepository.open(userId: GuestModeStore.userId);
    await guest.create(const JournalContent(body: 'Guest entry'));
    final member = await LocalJournalRepository.open(userId: 'user-uuid');
    await member.create(const JournalContent(body: 'Member entry'));

    final allGuest = await guest.entries();
    final allMember = await member.entries();
    expect(allGuest.single.body, 'Guest entry');
    expect(allMember.single.body, 'Member entry');
  });
}
