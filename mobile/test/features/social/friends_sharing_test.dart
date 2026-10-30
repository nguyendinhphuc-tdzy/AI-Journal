import 'dart:convert';

import 'package:ai_diary/core/network/api_client.dart';
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
import 'package:ai_diary/features/social/data/app_friend.dart';
import 'package:ai_diary/features/social/data/friends_sharing.dart';
import 'package:ai_diary/features/social/presentation/friend_space_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef _I = OnboardingSignInScreen;

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

/// A memory's share sheet over [sharing].
Future<void> _openShare(WidgetTester tester, MemorySharing sharing) async {
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

/// `GET /friends` answering [items]; every request is counted in [paths].
ApiClient _api(List<Map<String, Object?>> items, List<String> paths) =>
    ApiClient(
      accessTokenProvider: () async => 'token',
      client: MockClient((request) async {
        paths.add('${request.method} ${request.url.path}');
        return http.Response(jsonEncode(items), 200,
            headers: {'content-type': 'application/json; charset=utf-8'});
      }),
    );

const _minhAnh = AppFriend('u1', 'Minh Anh');
const _giaHuy = AppFriend('u2', 'Gia Huy');

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  /// OB01 → "Bắt đầu" → the sign-in (reduced motion: no wind).
  Future<(OnboardingStore, MockSignInService)> openSignIn(
      WidgetTester tester) async {
    final store = await OnboardingStore.open();
    final service = MockSignInService(delay: Duration.zero);
    _phone(tester);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!),
      home: OnboardingFlow(store: store, brandName: 'AI', signIn: service),
    ));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text(OnboardingWelcomeScreen.startLabel));
    await tester.pumpAndSettle();
    return (store, service);
  }

  testWidgets('Bắt đầu → sign-in; email checked, then on to the nickname',
      (tester) async {
    final (store, service) = await openSignIn(tester);
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
    final (_, service) = await openSignIn(tester);
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

  testWidgets('No Facebook; forgot, "Để sau", then Google', (tester) async {
    final (_, service) = await openSignIn(tester);
    expect(find.textContaining('Facebook'), findsNothing);
    expect(find.byIcon(Icons.facebook_rounded), findsNothing);
    await _tapIn(tester, find.text(_I.forgot));
    expect(find.text(_I.forgotBody), findsOneWidget);
    await _tapIn(tester, find.text(_I.forgotDone));

    await _tapIn(tester, find.text(_I.later));
    expect(service.user.value, isNull);
    expect(find.text(OnboardingNicknameScreen.title), findsOneWidget);
    // Back from the nickname: the sign-in again; Google this time.
    await _tapIn(tester, find.byTooltip('Quay lại'));
    await _tapIn(tester, find.text(_I.google));
    expect(service.user.value?.method, SignInMethod.google);
  });

  test('A friend from GET /friends: accepted only, named as on the app', () {
    expect(
        AppFriend.fromApi({
          'user_id': 'u1',
          'status': 'accepted',
          'display_name': ' Minh Anh ',
          'username': 'minhanh',
        })?.name,
        'Minh Anh');
    expect(
        AppFriend.fromApi(
                {'user_id': 'u2', 'status': 'accepted', 'username': 'giahuy'})
            ?.name,
        '@giahuy');
    expect(AppFriend.fromApi({'user_id': 'u2', 'status': 'accepted'})?.name,
        'Người dùng AI-Journal');
    expect(AppFriend.fromApi({'user_id': 'u3', 'status': 'pending'}), isNull,
        reason: 'a request is not a friend yet');
    expect(AppFriend.fromApi({'status': 'accepted'}), isNull);
    expect(AppFriend.fromApi('nope'), isNull);
    expect(const AppFriend('u2', '@giahuy').initials, 'G');
    expect(_minhAnh.initials, 'MA');
  });

  testWidgets('Share: no Facebook; pick some friends; it posts',
      (tester) async {
    await _openShare(tester, MockFriendsSharing([_minhAnh, _giaHuy]));
    expect(find.textContaining('Facebook'), findsNothing);
    expect(find.byIcon(Icons.facebook_rounded), findsNothing);
    // Every friend starts ticked.
    expect(find.text(ShareMemorySheet.picked(2, 2)), findsOneWidget);
    await _tapIn(tester, find.byKey(const ValueKey('share-to-u2')));
    expect(find.text(ShareMemorySheet.picked(1, 2)), findsOneWidget);
    await _tapIn(
        tester, find.text(ShareMemorySheet.useMemoryPlace('Hồ Xuân Hương')));
    await _tapIn(tester, find.text(ShareMemorySheet.publishLabel).last);
    await tester.pump(ShareMemorySheet.successHold);
    await tester.pumpAndSettle();
    final post = AlbumRoutes.published.value;
    expect(post, isNotNull);
    expect(friendsAudienceIds(post!.payload.audience.id), ['u1']);
  });

  testWidgets('Share without friends on the app: says where to find them',
      (tester) async {
    await _openShare(tester, MockFriendsSharing([]));
    expect(find.text(ShareMemorySheet.friendsEmpty), findsOneWidget);
    expect(find.text(ShareMemorySheet.friendsBlocker), findsOneWidget);
    expect(find.textContaining('Facebook'), findsNothing);
  });

  testWidgets(
      'Signed in: the picker lists real friends; nothing is sent until the '
      'server can deliver', (tester) async {
    final paths = <String>[];
    final api = _api([
      {
        'user_id': 'u1',
        'status': 'accepted',
        'direction': 'outgoing',
        'display_name': 'Minh Anh',
        'username': 'minhanh',
      },
      {
        'user_id': 'u3',
        'status': 'pending',
        'direction': 'incoming',
        'display_name': 'Chưa đồng ý',
      },
    ], paths);
    addTearDown(api.close);
    final sharing = RemoteFriendsSharing(api);
    await _openShare(tester, sharing);
    expect(paths.single, allOf(startsWith('GET '), endsWith('/friends')));
    expect(find.byKey(const ValueKey('share-to-u1')), findsOneWidget);
    expect(find.byKey(const ValueKey('share-to-u3')), findsNothing,
        reason: 'a pending request is not a friend');
    expect(find.text(ShareMemorySheet.picked(1, 1)), findsOneWidget);
    await _tapIn(
        tester, find.text(ShareMemorySheet.useMemoryPlace('Hồ Xuân Hương')));
    // Everything chosen; the dock says why it cannot be sent, and the
    // button stays off.
    expect(find.text(ShareMemorySheet.notDelivered), findsOneWidget);
    final button = find.text(ShareMemorySheet.publishLabel).last;
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(AlbumRoutes.published.value, isNull);
    expect(paths, hasLength(1), reason: 'no POST of any kind');
    await expectLater(
        sharing.publish(SharePayload(
          albumId: 'a',
          memoryId: 'm',
          audience: friendsAudience([_minhAnh]),
          place: const MemoryPlace(label: 'X', latitude: 1, longitude: 2),
          text: 'Xin chào',
        )),
        throwsA(isA<ShareUnavailable>()));
  });

  testWidgets('Friends without an account: no sample friends, how to get them',
      (tester) async {
    _phone(tester);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
              onPressed: () => openFriendSpace(context),
              child: const Text('Bạn bè')),
        ),
      ),
    ));
    await _tapIn(tester, find.text('Bạn bè'));
    expect(find.byType(FriendsNeedAccountScreen), findsOneWidget);
    expect(find.text(FriendSpaceText.needsAccountBody), findsOneWidget);
    expect(find.textContaining('Facebook'), findsNothing);
  });

  testWidgets('Profile: no Facebook row', (tester) async {
    await tester.pumpWidget(
        MaterialApp(theme: AppTheme.light, home: const ProfileScreen()));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('setting-item-facebook')), findsNothing);
    expect(find.textContaining('Facebook'), findsNothing);
    expect(find.byIcon(Icons.facebook_rounded), findsNothing);
  });

  test('Posts reach only people who are still friends', () async {
    final sharing = MockFriendsSharing([],
        clock: () => DateTime(2026, 10, 28, 9));
    expect(await sharing.audiences(), isEmpty, reason: 'no friends yet');
    sharing.friends = [_minhAnh];
    SharePayload to(List<AppFriend> friends) => SharePayload(
          albumId: 'a',
          memoryId: 'm',
          audience: friendsAudience(friends),
          place: const MemoryPlace(label: 'X', latitude: 1, longitude: 2),
          text: 'Xin chào',
        );
    await expectLater(
        sharing.publish(to([_giaHuy])), throwsA(isA<ShareUnavailable>()),
        reason: 'not a friend');
    final post = await sharing.publish(to([_minhAnh]));
    expect(post.expiresAt, DateTime(2026, 10, 29, 9));
    expect(await sharing.hasActiveShares('a'), isTrue);
    await sharing.revokeAll('a');
    expect(await sharing.activePost('m'), isNull);
  });
}
