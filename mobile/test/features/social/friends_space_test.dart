import 'package:ai_diary/core/theme/app_theme.dart';
import 'package:ai_diary/features/album/album_scope.dart';
import 'package:ai_diary/features/album/data/album_repository.dart';
import 'package:ai_diary/features/album/data/album_unlocks.dart';
import 'package:ai_diary/features/album/data/memory.dart';
import 'package:ai_diary/features/album/data/memory_photos.dart';
import 'package:ai_diary/features/album/data/memory_share.dart';
import 'package:ai_diary/features/album/presentation/album_routes.dart';
import 'package:ai_diary/features/album/presentation/album_start_screen.dart';
import 'package:ai_diary/features/album/presentation/share_memory_sheet.dart';
import 'package:ai_diary/features/onboarding/data/onboarding_store.dart';
import 'package:ai_diary/features/onboarding/data/sign_in_service.dart';
import 'package:ai_diary/features/onboarding/onboarding_flow.dart';
import 'package:ai_diary/features/onboarding/presentation/onboarding_nickname_screen.dart';
import 'package:ai_diary/features/onboarding/presentation/onboarding_sign_in_screen.dart';
import 'package:ai_diary/features/onboarding/presentation/onboarding_welcome_screen.dart';
import 'package:ai_diary/features/profile/profile_screen.dart';
import 'package:ai_diary/features/social/data/friend_space.dart';
import 'package:ai_diary/features/social/data/friends_account.dart';
import 'package:ai_diary/features/social/data/friends_sharing.dart';
import 'package:ai_diary/features/social/presentation/facebook_login_screen.dart';
import 'package:ai_diary/features/social/presentation/friend_space_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef _L = FacebookLoginText;
typedef _I = OnboardingSignInScreen;
typedef _S = FriendSpaceText;

class _Photos implements MemoryPhotos {
  @override
  bool get hasCamera => false;
  @override
  Future<String?> pick([PhotoSource source = PhotoSource.library]) async =>
      null;
  @override
  Future<String> keep(String sourcePath) async => sourcePath;
}

void _phone(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.reset);
}

Future<void> _tapIn(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Facebook's consent, "Cho phép", then on: connected.
Future<void> _logIn(WidgetTester tester) async {
  expect(find.text(_L.consentTitle), findsOneWidget);
  // The password is Facebook's to ask, never the app's.
  expect(find.byType(TextField), findsNothing);
  await _tapIn(tester, find.text(_L.allowLabel));
  expect(find.text(_L.doneTitle), findsOneWidget);
  // What comes next may keep moving (onboarding's petals): no settling.
  await tester.tap(find.text(_L.continueLabel));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

/// A memory's share sheet over [sharing].
Future<void> _openShare(WidgetTester tester, MockFriendsSharing sharing) async {
  final albums = InMemoryAlbumRepository();
  final album = await albums.create(name: 'Đà Lạt');
  final memory = await albums.createMemory(
      album.id,
      MemoryContent(
        title: 'Chiều ở Đà Lạt',
        note: 'Ly ca cao nóng.',
        photoPath: '/kept/photo.jpg',
        displayDate: DateTime(2026, 10, 12),
        place: const MemoryPlace(
            label: 'Hồ Xuân Hương', latitude: 11.94, longitude: 108.44),
      ));
  final current = (await albums.album(album.id))!;
  _phone(tester);
  addTearDown(AlbumUnlocks.instance.lockAll);
  addTearDown(AlbumStartScreen.resetPlayed);
  addTearDown(MemoryShareDraft.reset);
  addTearDown(() => AlbumRoutes.published.value = null);
  await tester.pumpWidget(AlbumScope(
    repository: albums,
    photos: _Photos(),
    memorySharing: sharing,
    sharing: sharing,
    child: MaterialApp(
      theme: AppTheme.light,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: FilledButton(
              onPressed: () => AlbumRoutes.share(context, current, memory),
              child: const Text('Mở'),
            ),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('Mở'));
  await tester.pumpAndSettle();
}

/// Scrolls the list until [text] shows; fails when it never does.
Future<void> _seen(WidgetTester tester, String text) async {
  await tester.scrollUntilVisible(find.text(text), 120,
      scrollable: find.byType(Scrollable).first, maxScrolls: 40);
  expect(find.text(text), findsOneWidget);
}

/// Back to the top of the list.
Future<void> _top(WidgetTester tester) async {
  await tester.drag(find.byType(ListView), const Offset(0, 3000));
  await tester.pumpAndSettle();
}

/// [friendId] invited, and accepted.
Future<void> _join(FriendSpace space, String friendId) async {
  await space.invite(friendId);
  await space.acceptedBy(friendId);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  /// OB01 → "Bắt đầu" → the sign-in (reduced motion: no wind).
  Future<(OnboardingStore, MockSignInService)> openSignIn(
      WidgetTester tester, MockFriendsAccount account) async {
    final store = await OnboardingStore.open();
    final service = MockSignInService(delay: Duration.zero);
    _phone(tester);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!),
      home: OnboardingFlow(
          store: store, brandName: 'AI', signIn: service, friends: account),
    ));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text(OnboardingWelcomeScreen.startLabel));
    await tester.pumpAndSettle();
    return (store, service);
  }

  testWidgets('Bắt đầu → sign-in; email checked, then on to the nickname',
      (tester) async {
    final (store, service) =
        await openSignIn(tester, MockFriendsAccount(delay: Duration.zero));
    expect(find.text(_I.title), findsOneWidget);
    expect(store.step, OnboardingStep.signIn);
    expect(find.text(_I.mockNote), findsOneWidget);
    // Nothing filled in, then a malformed email.
    await _tapIn(tester, find.text(_I.signInLabel).last);
    expect(find.text(_I.emailMissing), findsOneWidget);
    expect(find.text(_I.passwordMissing), findsOneWidget);
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'ban.email');
    await _tapIn(tester, find.text(_I.signInLabel).last);
    expect(find.text(_I.emailInvalid), findsOneWidget);
    expect(tester.widget<TextField>(fields.at(1)).obscureText, isTrue);
    await tester.enterText(fields.at(0), 'ban@email.com');
    await tester.enterText(fields.at(1), 'bimat1');
    await _tapIn(tester, find.text(_I.signInLabel).last);
    expect(service.user.value?.method, SignInMethod.email);
    expect(service.user.value?.email, 'ban@email.com');
    expect(find.text(OnboardingNicknameScreen.title), findsOneWidget);
  });

  testWidgets('Sign up asks twice and for 6 characters', (tester) async {
    final (_, service) =
        await openSignIn(tester, MockFriendsAccount(delay: Duration.zero));
    await _tapIn(tester, find.text(_I.signUpTab));
    expect(find.text(_I.confirmLabel), findsOneWidget);
    expect(find.text(_I.forgot), findsNothing);
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'ban@email.com');
    await tester.enterText(fields.at(1), '123');
    await tester.enterText(fields.at(2), '1234');
    await _tapIn(tester, find.text(_I.signUpLabel));
    expect(find.text(_I.passwordShort), findsOneWidget);
    expect(find.text(_I.confirmMismatch), findsOneWidget);
    await tester.enterText(fields.at(1), '123456');
    await tester.enterText(fields.at(2), '123456');
    await _tapIn(tester, find.text(_I.signUpLabel));
    expect(service.user.value?.method, SignInMethod.email);
  });

  testWidgets('Google, Facebook (with friends), "Để sau" and forgot',
      (tester) async {
    final account = MockFriendsAccount(delay: Duration.zero);
    var (_, service) = await openSignIn(tester, account);
    await _tapIn(tester, find.text(_I.forgot));
    expect(find.text(_I.forgotBody), findsOneWidget);
    await _tapIn(tester, find.text(_I.forgotDone));

    await _tapIn(tester, find.text(_I.facebook));
    // Refused: back on the sign-in, nothing connected.
    await _tapIn(tester, find.text(_L.denyLabel));
    expect(find.text(_I.title), findsOneWidget);
    expect(account.session.value, isNull);
    await _tapIn(tester, find.text(_I.facebook));
    await _logIn(tester);
    await tester.pumpAndSettle();
    expect(account.session.value?.friends, hasLength(8));
    expect(service.user.value?.method, SignInMethod.facebook);
    expect(find.text(OnboardingNicknameScreen.title), findsOneWidget);
  });

  testWidgets('Google signs in; "Để sau" goes on without an account',
      (tester) async {
    var (_, service) =
        await openSignIn(tester, MockFriendsAccount(delay: Duration.zero));
    await _tapIn(tester, find.text(_I.later));
    expect(service.user.value, isNull);
    expect(find.text(OnboardingNicknameScreen.title), findsOneWidget);
    // Back from the nickname: the sign-in again; Google this time.
    await _tapIn(tester, find.byTooltip('Quay lại'));
    await _tapIn(tester, find.text(_I.google));
    expect(service.user.value?.method, SignInMethod.google);
  });

  testWidgets('Facebook consent: a failure can be retried', (tester) async {
    final account = MockFriendsAccount(delay: Duration.zero);
    _phone(tester);
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light, home: FacebookLoginScreen(account: account)));
    expect(find.text(_L.mockNote), findsOneWidget);
    await _tapIn(tester, find.text(_L.simulateFailure));
    expect(find.text(_L.failedTitle), findsOneWidget);
    expect(account.session.value, isNull);
    await _tapIn(tester, find.text(_L.retryLabel));
    expect(find.text(_L.doneTitle), findsOneWidget);
  });

  testWidgets('Space: inviting waits for them; cancel; accepted joins',
      (tester) async {
    final account = MockFriendsAccount(delay: Duration.zero);
    await tester.runAsync(account.connect);
    final space = FriendSpace(keep: false, incoming: const []);
    _phone(tester);
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: FriendSpaceScreen(account: account, space: space)));
    await tester.pumpAndSettle();
    expect(find.text(_S.emptySpace), findsOneWidget);
    expect(find.text(_S.onApp(8)), findsOneWidget);

    await _tapIn(tester, find.byTooltip(_S.addTooltip('Minh Anh')));
    expect(find.text(_S.invited('Minh Anh')), findsOneWidget);
    // Not in yet: waiting, and not someone a post can go to.
    expect(space.members.value['f1']?.state, SpaceState.invited);
    await _top(tester);
    expect(find.text(_S.inSpace(0)), findsOneWidget);
    await _seen(tester, _S.pendingTitle(1));
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    // Taken back: a friend to invite again.
    await _tapIn(tester, find.byTooltip(_S.optionsTooltip('Minh Anh')));
    await _tapIn(tester, find.text(_S.cancelInviteLabel));
    expect(space.members.value.containsKey('f1'), isFalse);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    // Invited again, and (simulated) they accept: in.
    await _tapIn(tester, find.byTooltip(_S.addTooltip('Minh Anh')));
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await _tapIn(tester, find.byTooltip(_S.optionsTooltip('Minh Anh')));
    await _tapIn(tester, find.text(_S.simulateAccept));
    expect(find.text(_S.joined('Minh Anh')), findsOneWidget);
    expect(space.members.value['f1']?.canSee, isTrue);
    await _top(tester);
    expect(find.text(_S.inSpace(1)), findsOneWidget);
    expect(find.text(_S.seesShares), findsOneWidget);
  });

  testWidgets('Space: their invitations — accept joins, decline goes',
      (tester) async {
    final account = MockFriendsAccount(delay: Duration.zero);
    await tester.runAsync(account.connect);
    final space = FriendSpace(keep: false, incoming: const ['f3', 'f4']);
    _phone(tester);
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: FriendSpaceScreen(account: account, space: space)));
    await tester.pumpAndSettle();
    expect(find.text(_S.invitesTitle(2)), findsOneWidget);
    // Not offered to invite: they already asked.
    await _seen(tester, _S.onApp(6));
    await _top(tester);
    await _tapIn(tester, find.byTooltip(_S.acceptTooltip('Thảo Nhi')));
    expect(find.text(_S.joined('Thảo Nhi')), findsOneWidget);
    expect(space.members.value['f3']?.canSee, isTrue);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await _tapIn(tester, find.byTooltip(_S.declineTooltip('Bảo Long')));
    expect(space.incoming.value, isEmpty);
    expect(space.members.value.containsKey('f4'), isFalse);
    // Can be invited later.
    await _seen(tester, _S.onApp(7));
  });

  testWidgets('Space: restrict a member; remove one after a confirm',
      (tester) async {
    final account = MockFriendsAccount(delay: Duration.zero);
    await tester.runAsync(account.connect);
    final space = FriendSpace(keep: false, incoming: const []);
    await tester.runAsync(() async {
      await _join(space, 'f1');
      await _join(space, 'f2');
    });
    _phone(tester);
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: FriendSpaceScreen(account: account, space: space)));
    await tester.pumpAndSettle();
    await _tapIn(tester, find.byTooltip(_S.optionsTooltip('Gia Huy')));
    await _tapIn(tester, find.text(_S.restrictLabel));
    expect(space.members.value['f2']!.restricted, isTrue);
    expect(find.text(_S.restrictedNote), findsOneWidget);

    await _tapIn(tester, find.byTooltip(_S.optionsTooltip('Minh Anh')));
    await _tapIn(tester, find.text(_S.removeLabel));
    expect(find.text(_S.removeTitle('Minh Anh')), findsOneWidget);
    await _tapIn(tester, find.text(_S.removeLabel).last);
    expect(space.members.value.containsKey('f1'), isFalse);
    await tester.drag(find.byType(ListView), const Offset(0, 2000));
    await tester.pumpAndSettle();
    expect(find.text(_S.inSpace(1)), findsOneWidget);

    // Search narrows the lists.
    await tester.enterText(find.byType(TextField), 'khánh');
    await tester.pump();
    expect(find.text('Khánh Linh'), findsOneWidget);
    expect(find.text('Hà My'), findsNothing);
  });

  testWidgets('Space signed out: invites to sign in with Facebook',
      (tester) async {
    final account = MockFriendsAccount(delay: Duration.zero);
    _phone(tester);
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: FriendSpaceScreen(
            account: account,
            space: FriendSpace(keep: false, incoming: const []))));
    await tester.pumpAndSettle();
    expect(find.text(_S.signedOutBody), findsOneWidget);
    await _tapIn(tester, find.text(_S.signInLabel));
    await _logIn(tester);
    expect(find.text(_S.onApp(8)), findsOneWidget);
  });

  testWidgets('Share: no Facebook button; pick some of the space; it posts',
      (tester) async {
    final account = MockFriendsAccount(delay: Duration.zero);
    await tester.runAsync(account.connect);
    final space = FriendSpace(keep: false);
    await tester.runAsync(() async {
      await _join(space, 'f1');
      await _join(space, 'f2');
      await _join(space, 'f3');
      await space.restrict('f3', true);
      // Invited but not accepted yet: not offered.
      await space.invite('f4');
    });
    await _openShare(tester, MockFriendsSharing(account, space));
    expect(find.text(_L.title), findsNothing);
    expect(find.byIcon(Icons.facebook_rounded), findsNothing);
    // Restricted people are not offered; the others start ticked.
    expect(find.byKey(const ValueKey('share-to-f3')), findsNothing);
    expect(find.byKey(const ValueKey('share-to-f4')), findsNothing);
    expect(find.text(ShareMemorySheet.picked(2, 2)), findsOneWidget);
    await _tapIn(tester, find.byKey(const ValueKey('share-to-f2')));
    expect(find.text(ShareMemorySheet.picked(1, 2)), findsOneWidget);
    await _tapIn(
        tester, find.text(ShareMemorySheet.useMemoryPlace('Hồ Xuân Hương')));
    await _tapIn(tester, find.text(ShareMemorySheet.publishLabel).last);
    await tester.pump(ShareMemorySheet.successHold);
    await tester.pumpAndSettle();
    final post = AlbumRoutes.published.value;
    expect(post, isNotNull);
    expect(spaceAudienceIds(post!.payload.audience.id), ['f1']);
  });

  testWidgets('Share signed out or empty space: says where to go',
      (tester) async {
    final account = MockFriendsAccount(delay: Duration.zero);
    final space = FriendSpace(keep: false);
    await _openShare(tester, MockFriendsSharing(account, space));
    expect(find.text(ShareMemorySheet.signedOut), findsWidgets);
  });

  testWidgets('Profile: signing out asks first and empties the space',
      (tester) async {
    final account = MockFriendsAccount(delay: Duration.zero);
    await tester.runAsync(account.connect);
    await tester.runAsync(() => _join(FriendSpace.instance, 'f1'));
    addTearDown(() => FriendSpace.instance.clear());
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light, home: ProfileScreen(friends: account)));
    await tester.pumpAndSettle();
    expect(find.text(ProfileScreen.facebookOn(8)), findsOneWidget);
    await _tapIn(tester, find.byKey(const ValueKey('setting-item-facebook')));
    await _tapIn(tester, find.text(ProfileScreen.disconnectLabel));
    expect(account.session.value, isNull);
    expect(FriendSpace.instance.members.value, isEmpty);
  });

  test('The connection and the space are kept between runs', () async {
    await MockFriendsAccount(delay: Duration.zero).connect();
    final space = FriendSpace();
    await _join(space, 'f4');
    await space.restrict('f4', true);
    await space.invite('f5');
    await space.decline('f3');
    final account = MockFriendsAccount(delay: Duration.zero);
    await account.restore();
    expect(account.session.value?.friends, hasLength(8));
    final again = FriendSpace();
    await again.restore();
    expect(again.members.value['f4']?.restricted, isTrue);
    expect(again.members.value['f5']?.state, SpaceState.invited);
    expect(again.incoming.value, ['f4'], reason: 'f3 declined; f4 waits');
  });

  test('Posts reach only unrestricted people in the space', () async {
    final account = MockFriendsAccount(delay: Duration.zero);
    final space = FriendSpace(keep: false);
    final sharing = MockFriendsSharing(account, space,
        clock: () => DateTime(2026, 10, 28, 9));
    expect(await sharing.audiences(), isEmpty, reason: 'signed out');
    await account.connect();
    expect(await sharing.audiences(), isEmpty, reason: 'empty space');
    await _join(space, 'f1');
    await _join(space, 'f2');
    await space.restrict('f2', true);
    await space.invite('f5');
    SharePayload to(List<AppFriend> friends) => SharePayload(
          albumId: 'a',
          memoryId: 'm',
          audience: spaceAudience(friends),
          place: const MemoryPlace(label: 'X', latitude: 1, longitude: 2),
          text: 'Xin chào',
        );
    const restricted = AppFriend('f2', 'Gia Huy');
    await expectLater(sharing.publish(to([const AppFriend('f5', 'Quốc Bảo')])),
        throwsA(isA<ShareUnavailable>()),
        reason: 'invited, not accepted');
    await expectLater(
        sharing.publish(to([restricted])), throwsA(isA<ShareUnavailable>()));
    final post = await sharing.publish(to([const AppFriend('f1', 'Minh Anh')]));
    expect(post.expiresAt, DateTime(2026, 10, 29, 9));
    expect(await sharing.hasActiveShares('a'), isTrue);
    await sharing.revokeAll('a');
    expect(await sharing.activePost('m'), isNull);
  });
}
