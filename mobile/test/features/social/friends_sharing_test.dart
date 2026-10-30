import 'dart:convert';
import 'dart:typed_data';

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
import 'package:ai_diary/features/explore/presentation/widgets/friend_post_card.dart';
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

/// `GET /friends` answering [items], `POST /memory-shares` answering a new
/// share; every request is kept in [calls] ("METHOD path body").
ApiClient _api(List<Map<String, Object?>> items, List<String> calls,
        {int photoStatus = 204}) =>
    ApiClient(
      accessTokenProvider: () async => 'token',
      client: MockClient((request) async {
        final path = request.url.path.replaceFirst(RegExp(r'^.*/api/v1'), '');
        if (request.method == 'PUT' && path.endsWith('/photo')) {
          // The bytes themselves: type and size only.
          calls.add('PUT $path '
              '${request.headers['content-type']} ${request.bodyBytes.length}');
          return http.Response('', photoStatus);
        }
        calls.add('${request.method} $path ${request.body}'.trim());
        if (request.method == 'DELETE') return http.Response('', 204);
        final body = switch ('${request.method} $path') {
          'GET /friends' => items,
          'POST /memory-shares' => {
              'id': 'share-1',
              'memory_id': null,
              'expires_at': '2026-10-31T07:00:00Z',
              'revoked': false,
            },
          _ => null,
        };
        return body == null
            ? http.Response('{}', 404)
            : http.Response(jsonEncode(body), body is Map ? 201 : 200,
                headers: {'content-type': 'application/json; charset=utf-8'});
      }),
    );

const _jpeg = [0xFF, 0xD8, 0xFF, 0xE0, 1, 2, 3, 4];

/// A 1×1 transparent PNG.
final _png = Uint8List.fromList(base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII='));

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
      'Signed in: real friends; the post goes to the server as a snapshot '
      '(description needed, photo sent after it, no private note)', (tester) async {
    final calls = <String>[];
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
    ], calls);
    addTearDown(api.close);
    final sharing = RemoteFriendsSharing(api, readPhoto: (_) async => _jpeg);
    await _openShare(tester, sharing);
    expect(calls.single, 'GET /friends');
    expect(find.byKey(const ValueKey('share-to-u1')), findsOneWidget);
    expect(find.byKey(const ValueKey('share-to-u3')), findsNothing,
        reason: 'a pending request is not a friend');
    expect(find.text(ShareMemorySheet.picked(1, 1)), findsOneWidget);
    await _tapIn(
        tester, find.text(ShareMemorySheet.useMemoryPlace('Hồ Xuân Hương')));
    // The server needs a description, photo or not; said.
    expect(find.text(ShareMemorySheet.needs([ShareMemorySheet.needText])),
        findsOneWidget);
    await tester.enterText(
        find.widgetWithText(TextField, ShareMemorySheet.textHintNote),
        'Chiều nay đẹp quá');
    await _tapIn(tester, find.text('Ăn uống'));
    await _tapIn(tester, find.text(ShareMemorySheet.publishLabel).last);
    await tester.pump(ShareMemorySheet.successHold);
    await tester.pumpAndSettle();
    final post = AlbumRoutes.published.value;
    expect(post?.id, 'share-1');
    expect(post!.expiresAt, DateTime.utc(2026, 10, 31, 7));
    expect(calls.last, 'PUT /memory-shares/share-1/photo image/jpeg 8',
        reason: 'the photo goes with it');
    final sent = calls[calls.length - 2];
    expect(sent, startsWith('POST /memory-shares '));
    final body = jsonDecode(sent.substring('POST /memory-shares '.length))
        as Map<String, dynamic>;
    expect(body, {
      'recipient_ids': ['u1'],
      'title': 'Chiều ở Đà Lạt',
      'text': 'Chiều nay đẹp quá',
      'place': {'label': 'Hồ Xuân Hương', 'latitude': 11.94, 'longitude': 108.44},
      'category': 'Ăn uống',
    });
    expect(sent, isNot(contains('Ly ca cao')), reason: 'private note');
    expect(await sharing.activePost(post.memoryId), isNotNull);
  });

  testWidgets('The photo could not go: the post is taken down, nothing shared',
      (tester) async {
    final calls = <String>[];
    final api = _api([
      {'user_id': 'u1', 'status': 'accepted', 'display_name': 'Minh Anh'},
    ], calls, photoStatus: 413);
    addTearDown(api.close);
    await _openShare(
        tester, RemoteFriendsSharing(api, readPhoto: (_) async => _jpeg));
    await _tapIn(
        tester, find.text(ShareMemorySheet.useMemoryPlace('Hồ Xuân Hương')));
    await tester.enterText(
        find.widgetWithText(TextField, ShareMemorySheet.textHintNote), 'Chào');
    await _tapIn(tester, find.text(ShareMemorySheet.publishLabel).last);
    expect(AlbumRoutes.published.value, isNull);
    expect(find.text(ShareMemorySheet.unavailable), findsOneWidget);
    expect(calls.last, 'DELETE /memory-shares/share-1');
  });

  test('Photo types the server takes, by their first bytes', () {
    expect(photoType(_jpeg), 'image/jpeg');
    expect(photoType(const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0]),
        'image/png');
    expect(photoType('RIFF0000WEBPVP8 '.codeUnits), 'image/webp');
    expect(photoType('GIF89a'.codeUnits), isNull);
    expect(photoType(const []), isNull);
  });

  testWidgets("A friend's post: the photo large; a tap opens it full screen",
      (tester) async {
    _phone(tester);
    final post = FriendPost.fromJson({
      'share_id': 's1',
      'title': 'Buồn ngủ',
      'text': 'Học bài ở UEH',
      'place': {'label': 'UEH', 'latitude': 10.78, 'longitude': 106.69},
      'category': 'Cà phê học bài',
      'expires_at': '2030-10-31T07:00:00Z',
      'display_name': 'Tường Vy',
      'username': 'tdzy',
      'has_photo': true,
    })!;
    expect(post.hasPhoto, isTrue);
    var closed = false;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: Center(
          child: FriendPostCard(
              post: post,
              photo: Future.value(_png),
              onClose: () => closed = true),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Buồn ngủ'), findsOneWidget);
    expect(find.text('Tường Vy (@tdzy) chia sẻ'), findsOneWidget);
    expect(find.text('Học bài ở UEH'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    await tester.tap(find.bySemanticsLabel(FriendPostText.openPhoto));
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsOneWidget);
    await tester.tap(find.byTooltip(FriendPostText.closePhoto));
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsNothing);
    await tester.tap(find.byTooltip(FriendPostText.closeTooltip));
    expect(closed, isTrue);
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

  test("Friends' posts from GET /memory-shares/received: named, active only",
      () {
    final post = FriendPost.fromJson({
      'share_id': 's1',
      'memory_id': null,
      'title': 'Buồn ngủ',
      'text': 'Tôi muốn ngủ thật nhiều',
      'place': {'label': 'UEH', 'latitude': 10.78, 'longitude': 106.69},
      'category': 'Cà phê học bài',
      'expires_at': '2026-10-31T07:00:00Z',
      'sender_id': 'u1',
      'display_name': 'Tường Vy',
      'username': 'tdzy',
    })!;
    expect(post.senderName, 'Tường Vy');
    expect(post.username, 'tdzy');
    expect(post.placeLabel, 'UEH');
    expect(post.isActive(DateTime.utc(2026, 10, 31, 6)), isTrue);
    expect(post.isActive(DateTime.utc(2026, 10, 31, 8)), isFalse);
    expect(
        FriendPost.fromJson({
          'share_id': 's2',
          'text': 'x',
          'place': {'label': 'X', 'latitude': 1, 'longitude': 2},
          'expires_at': '2026-10-31T07:00:00Z',
          'username': 'giahuy',
        })!.senderName,
        '@giahuy');
    expect(FriendPost.fromJson({'share_id': 's3', 'text': 'x'}), isNull,
        reason: 'no place');
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
