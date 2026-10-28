import '../../album/data/album_sharing.dart';
import '../../album/data/memory_share.dart';
import 'friend_space.dart';
import 'friends_account.dart';

/// A share service for people in the user's space: A10 lets the user pick
/// who, among the space's unrestricted members, sees the post.
abstract interface class FriendsCircle {
  FriendsAccount get account;
  FriendSpace get space;
}

/// The audience for [friends] picked in A10: its id names them.
ShareAudience spaceAudience(List<AppFriend> friends) => ShareAudience(
      id: '${MockFriendsSharing.audiencePrefix}'
          '${[for (final f in friends) f.id].join(',')}',
      label: '${friends.length} người trong Space',
      detail: [for (final f in friends) f.name].join(', '),
    );

/// The friend ids an audience from [spaceAudience] names; empty otherwise.
List<String> spaceAudienceIds(String audienceId) =>
    audienceId.startsWith(MockFriendsSharing.audiencePrefix)
        ? audienceId
            .substring(MockFriendsSharing.audiencePrefix.length)
            .split(',')
            .where((id) => id.isNotEmpty)
            .toList()
        : const [];

/// 24-hour posts to people in the space, simulated on this device until the
/// share API exists: posts kept in memory for the run (gone after a
/// restart), nobody else sees them.
class MockFriendsSharing implements AlbumSharing, MemorySharing, FriendsCircle {
  MockFriendsSharing(this.account, this.space, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  @override
  final FriendsAccount account;
  @override
  final FriendSpace space;
  final DateTime Function() _clock;

  static const audiencePrefix = 'space:';

  /// Who can be picked now: signed in, in the space (they accepted), not
  /// restricted.
  List<AppFriend> get pickable {
    final session = account.session.value;
    if (session == null) return const [];
    return [
      for (final (friend, member) in space.of(session.friends))
        if (member.canSee) friend,
    ];
  }

  final _posts = <String, SharedMemoryPost>{};
  var _next = 0;

  /// Everyone who can be picked, as one audience; A10 narrows it down.
  @override
  Future<List<ShareAudience>> audiences() async {
    final friends = pickable;
    return friends.isEmpty ? const [] : [spaceAudience(friends)];
  }

  @override
  Future<SharedMemoryPost?> activePost(String memoryId) async {
    final now = _clock();
    for (final post in _posts.values) {
      if (post.memoryId == memoryId && post.isActive(now)) return post;
    }
    return null;
  }

  @override
  Future<SharedMemoryPost> publish(SharePayload payload,
      {String? replacing}) async {
    // Only people still in the space, unrestricted, can be shown a post.
    final allowed = {for (final f in pickable) f.id};
    final chosen = spaceAudienceIds(payload.audience.id);
    if (chosen.isEmpty || !chosen.every(allowed.contains)) {
      throw const ShareUnavailable();
    }
    final now = _clock();
    if (replacing != null) _revoke(replacing, now);
    final post = SharedMemoryPost(
      id: 'mock-post-${_next++}',
      payload: payload,
      publishedAt: now,
      expiresAt: now.add(const Duration(hours: 24)),
    );
    return _posts[post.id] = post;
  }

  @override
  Future<SharedMemoryPost?> post(String postId) async => _posts[postId];

  @override
  Future<SharedMemoryPost> revoke(String postId) async {
    final revoked = _revoke(postId, _clock());
    if (revoked == null) throw const ShareUnavailable();
    return revoked;
  }

  SharedMemoryPost? _revoke(String postId, DateTime at) {
    final post = _posts[postId];
    if (post == null) return null;
    return _posts[postId] = SharedMemoryPost(
      id: post.id,
      payload: post.payload,
      publishedAt: post.publishedAt,
      expiresAt: post.expiresAt,
      revokedAt: post.revokedAt ?? at,
    );
  }

  @override
  Future<bool> hasActiveShares(String albumId) async {
    final now = _clock();
    return _posts.values
        .any((p) => p.payload.albumId == albumId && p.isActive(now));
  }

  @override
  Future<void> revokeAll(String albumId) async {
    final now = _clock();
    for (final post in List.of(_posts.values)) {
      if (post.payload.albumId == albumId) _revoke(post.id, now);
    }
  }

  @override
  Future<T> withPublicationBlocked<T>(
          String albumId, Future<T> Function() action) =>
      action();
}
