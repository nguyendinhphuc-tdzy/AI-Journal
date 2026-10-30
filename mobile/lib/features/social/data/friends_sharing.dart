import '../../../core/network/api_client.dart';
import '../../album/data/album_sharing.dart';
import '../../album/data/memory_share.dart';
import 'app_friend.dart';

/// A share service whose audience is the user's friends on the app: A10
/// lets the user pick who, among them, sees the post.
abstract interface class FriendsSharing implements MemorySharing {
  /// The friends who can be picked, as of the last [audiences].
  List<AppFriend> get pickable;

  /// False while the server cannot deliver a post to friends yet: A10 still
  /// lets the user pick, and says why nothing can be sent.
  bool get canPublish;
}

const friendsAudiencePrefix = 'friends:';

/// The audience for [friends] picked in A10: its id names them.
ShareAudience friendsAudience(List<AppFriend> friends) => ShareAudience(
      id: '$friendsAudiencePrefix'
          '${[for (final f in friends) f.id].join(',')}',
      label: '${friends.length} bạn bè',
      detail: [for (final f in friends) f.name].join(', '),
    );

/// The friend ids an audience from [friendsAudience] names; empty otherwise.
List<String> friendsAudienceIds(String audienceId) =>
    audienceId.startsWith(friendsAudiencePrefix)
        ? audienceId
            .substring(friendsAudiencePrefix.length)
            .split(',')
            .where((id) => id.isNotEmpty)
            .toList()
        : const [];

/// The signed-in account's friends (`GET /friends`, accepted only). Posting
/// waits for the server: `POST /memory-shares` takes only cloud memories,
/// gives recipients the private note and has no inbox, so nothing is sent
/// (proposal in `album/README.md`).
class RemoteFriendsSharing implements AlbumSharing, FriendsSharing {
  RemoteFriendsSharing(this.api);

  final ApiClient api;

  var _friends = const <AppFriend>[];

  @override
  List<AppFriend> get pickable => _friends;

  @override
  bool get canPublish => false;

  /// Everyone who can be picked, as one audience; A10 narrows it down.
  @override
  Future<List<ShareAudience>> audiences() async {
    final items = await api.getList('/friends', requireAuth: true);
    _friends = List.unmodifiable(items.map(AppFriend.fromApi).nonNulls);
    return _friends.isEmpty ? const [] : [friendsAudience(_friends)];
  }

  @override
  Future<SharedMemoryPost?> activePost(String memoryId) async => null;

  @override
  Future<SharedMemoryPost> publish(SharePayload payload, {String? replacing}) =>
      Future.error(const ShareUnavailable());

  @override
  Future<SharedMemoryPost?> post(String postId) async => null;

  @override
  Future<SharedMemoryPost> revoke(String postId) =>
      Future.error(const ShareUnavailable());

  @override
  Future<bool> hasActiveShares(String albumId) async => false;

  @override
  Future<void> revokeAll(String albumId) async {}

  @override
  Future<T> withPublicationBlocked<T>(
          String albumId, Future<T> Function() action) =>
      action();
}

/// 24-hour posts to [friends], simulated on this device (tests and the
/// guest demo): posts kept in memory for the run, nobody else sees them.
class MockFriendsSharing implements AlbumSharing, FriendsSharing {
  MockFriendsSharing(this.friends, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  /// Friends on the app; tests change it to see who drops out.
  List<AppFriend> friends;
  final DateTime Function() _clock;

  @override
  List<AppFriend> get pickable => friends;

  @override
  bool get canPublish => true;

  final _posts = <String, SharedMemoryPost>{};
  var _next = 0;

  @override
  Future<List<ShareAudience>> audiences() async =>
      friends.isEmpty ? const [] : [friendsAudience(friends)];

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
    // Only people still friends can be shown a post.
    final allowed = {for (final f in friends) f.id};
    final chosen = friendsAudienceIds(payload.audience.id);
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
