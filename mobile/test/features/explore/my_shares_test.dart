import 'dart:convert';

import 'package:ai_diary/core/network/api_client.dart';
import 'package:ai_diary/core/theme/app_theme.dart';
import 'package:ai_diary/features/album/data/memory.dart';
import 'package:ai_diary/features/album/data/memory_share.dart';
import 'package:ai_diary/features/explore/presentation/widgets/places_sheet.dart';
import 'package:ai_diary/features/social/data/app_friend.dart';
import 'package:ai_diary/features/social/data/friends_sharing.dart';
import 'package:ai_diary/features/social/data/my_shares.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

MyShare _share(String id, DateTime sharedAt, {DateTime? revokedAt}) => MyShare(
      id: id,
      memoryId: 'mem-$id',
      albumId: 'a',
      title: 'Bài $id',
      text: 'Mô tả $id',
      placeLabel: 'UEH',
      latitude: 10.78,
      longitude: 106.69,
      category: 'Cà phê học bài',
      recipientIds: const ['u1'],
      recipientNames: const ['Tường Vy'],
      sharedAt: sharedAt,
      expiresAt: sharedAt.add(const Duration(hours: 24)),
      revokedAt: revokedAt,
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('The archive keeps shares per account, between runs; ended ones too',
      () async {
    final now = DateTime.now();
    final archive = MySharesArchive(userId: 'lili');
    await archive.add(_share('old', now.subtract(const Duration(days: 2))));
    await archive.add(_share('new', now.subtract(const Duration(hours: 1))));
    await archive.revoke('old', now);
    expect([for (final s in archive.shares.value) s.id], ['new', 'old']);
    expect(archive.activeFor('mem-new', now)?.id, 'new');
    expect(archive.activeFor('mem-old', now), isNull);

    final again = MySharesArchive(userId: 'lili');
    await again.load();
    expect([for (final s in again.shares.value) s.id], ['new', 'old']);
    expect(again.byId('old')!.revokedAt, isNotNull);
    expect(again.byId('new')!.recipientNames, ['Tường Vy']);

    final other = MySharesArchive(userId: 'tdzy');
    await other.load();
    expect(other.shares.value, isEmpty, reason: 'another account');
  });

  test('A post is kept in the archive, and known again after a restart',
      () async {
    final archive = MySharesArchive(userId: 'lili', keep: false);
    final calls = <String>[];
    ApiClient api() => ApiClient(
          accessTokenProvider: () async => 'token',
          client: MockClient((request) async {
            final path =
                request.url.path.replaceFirst(RegExp(r'^.*/api/v1'), '');
            calls.add('${request.method} $path');
            if (request.method == 'DELETE') return http.Response('', 204);
            final body = path == '/friends'
                ? [
                    {'user_id': 'u1', 'status': 'accepted',
                      'display_name': 'Tường Vy'}
                  ]
                : {
                    'id': 'share-1',
                    'expires_at': DateTime.now()
                        .toUtc()
                        .add(const Duration(hours: 24))
                        .toIso8601String(),
                  };
            return http.Response(jsonEncode(body), 200,
                headers: {'content-type': 'application/json; charset=utf-8'});
          }),
        );
    final sharing = RemoteFriendsSharing(api(), archive: archive);
    await sharing.audiences();
    await sharing.publish(SharePayload(
      albumId: 'a',
      memoryId: 'mem-1',
      audience: friendsAudience([const AppFriend('u1', 'Tường Vy')]),
      place: const MemoryPlace(label: 'UEH', latitude: 10.78, longitude: 106.69),
      category: ShareCategory.studyCafe,
      title: 'Buồn ngủ',
      text: 'Học bài',
    ));
    final kept = archive.byId('share-1')!;
    expect(kept.recipientNames, ['Tường Vy']);
    expect(kept.category, 'Cà phê học bài');
    expect(kept.memoryId, 'mem-1');

    // The app restarts: a new service, the same archive.
    final later = RemoteFriendsSharing(api(), archive: archive);
    final active = await later.activePost('mem-1');
    expect(active?.id, 'share-1');
    expect(active!.payload.category, ShareCategory.studyCafe);
    expect(await later.hasActiveShares('a'), isTrue);
    await later.revoke('share-1');
    expect(calls.last, 'DELETE /memory-shares/share-1');
    expect(archive.byId('share-1')!.revokedAt, isNotNull,
        reason: 'kept, as taken down');
    expect(await later.activePost('mem-1'), isNull);
  });

  testWidgets('"Đã chia sẻ": on now first, then the rest by day',
      (tester) async {
    final now = DateTime.now();
    final shares = [
      _share('a', now.subtract(const Duration(hours: 2))),
      _share('b', now.subtract(const Duration(days: 3))),
    ];
    bool? view;
    MyShare? chosen;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 900);
    addTearDown(tester.view.reset);
    final controller = DraggableScrollableController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: PlacesSheet(
          controller: controller,
          collapsed: .2,
          places: const [],
          savedCount: 0,
          selectedId: null,
          cardKeys: const {},
          community: false,
          onCommunity: (_) {},
          onSelect: (_) {},
          onDetails: (_) {},
          onShare: (_) {},
          onAdd: () {},
          onClearFilters: () {},
          shares: shares,
          sharedView: true,
          onView: (v) => view = v,
          onSelectShare: (s) => chosen = s,
        ),
      ),
    ));
    await tester.pumpAndSettle();
    controller.jumpTo(PlacesSheet.full);
    await tester.pumpAndSettle();
    expect(find.text(PlacesSheetText.sharedTab(2)), findsOneWidget);
    expect(find.text(PlacesSheetText.sharingNow), findsOneWidget);
    expect(find.text('Bài a'), findsOneWidget);
    expect(find.text('Bài b'), findsOneWidget);
    expect(find.text('${PlacesSheetText.ended} · UEH'), findsOneWidget);
    final onNow = tester.getTopLeft(find.text('Bài a')).dy;
    final ended = tester.getTopLeft(find.text('Bài b')).dy;
    expect(onNow < ended, isTrue);
    await tester.tap(find.text('Bài b'));
    expect(chosen?.id, 'b');
    await tester.tap(find.text(PlacesSheetText.savedTab(0)));
    expect(view, isFalse);
  });
}
