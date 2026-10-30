import 'dart:io';
import 'dart:typed_data';

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

  /// The server needs a description on every post (a photo alone is not
  /// enough), so A10 asks for one.
  bool get needsText;
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

/// A friend's 24-hour post shared with the user (`GET /memory-shares/received`).
class FriendPost {
  const FriendPost({
    required this.id,
    required this.senderName,
    required this.text,
    required this.placeLabel,
    required this.latitude,
    required this.longitude,
    required this.expiresAt,
    this.username,
    this.title,
    this.category,
    this.hasPhoto = false,
  });

  final String id;
  final String senderName;
  final String? username;
  final String? title;
  final String text;
  final String placeLabel;
  final double latitude;
  final double longitude;
  final String? category;
  final DateTime expiresAt;
  final bool hasPhoto;

  bool isActive(DateTime now) => now.isBefore(expiresAt);

  static FriendPost? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['share_id'];
    final text = json['text'];
    final place = json['place'];
    final expires = DateTime.tryParse('${json['expires_at']}');
    if (id is! String || text is! String || place is! Map || expires == null) {
      return null;
    }
    final label = place['label'];
    final lat = place['latitude'];
    final lon = place['longitude'];
    if (label is! String || lat is! num || lon is! num) return null;
    final name = json['display_name'];
    final username = json['username'];
    return FriendPost(
      id: id,
      senderName: name is String && name.trim().isNotEmpty
          ? name.trim()
          : username is String && username.isNotEmpty
              ? '@$username'
              : 'Người dùng AI-Journal',
      username: username is String && username.isNotEmpty ? username : null,
      title: json['title'] as String?,
      text: text,
      placeLabel: label,
      latitude: lat.toDouble(),
      longitude: lon.toDouble(),
      category: json['category'] as String?,
      expiresAt: expires,
      hasPhoto: json['has_photo'] == true,
    );
  }
}

/// The image type the server accepts, from the file's first bytes; null
/// for anything else.
String? photoType(List<int> bytes) {
  bool starts(List<int> sig) =>
      bytes.length >= sig.length &&
      [for (var i = 0; i < sig.length; i++) bytes[i] == sig[i]].every((b) => b);
  if (starts(const [0xFF, 0xD8, 0xFF])) return 'image/jpeg';
  if (starts(const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])) {
    return 'image/png';
  }
  if (bytes.length >= 12 &&
      String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
      String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP') {
    return 'image/webp';
  }
  return null;
}

/// The signed-in account's friends (`GET /friends`, accepted only) and the
/// 24-hour posts sent to them (`/memory-shares`). The server keeps a
/// snapshot: title, text (required, ≤ 300), place, category and the photo
/// (sent after the post, `PUT /memory-shares/{id}/photo`, ≤ 3 MB); never the
/// private note. Which memory a post came from is kept on this device for
/// the run (memories are device-only, so no `memory_id` is sent).
class RemoteFriendsSharing implements AlbumSharing, FriendsSharing {
  RemoteFriendsSharing(this.api,
      {DateTime Function()? clock, Future<List<int>> Function(String)? readPhoto})
      : _clock = clock ?? DateTime.now,
        _readPhoto = readPhoto ?? ((path) => File(path).readAsBytes());

  final ApiClient api;

  /// The memory's photo on this device, by path.
  final Future<List<int>> Function(String path) _readPhoto;

  /// The server's limit for a post's photo.
  static const photoMaxBytes = 3 * 1024 * 1024;
  final DateTime Function() _clock;

  var _friends = const <AppFriend>[];

  /// Posts made in this run, by id.
  final _posts = <String, SharedMemoryPost>{};

  @override
  List<AppFriend> get pickable => _friends;

  @override
  bool get canPublish => true;

  @override
  bool get needsText => true;

  /// Everyone who can be picked, as one audience; A10 narrows it down.
  @override
  Future<List<ShareAudience>> audiences() async {
    final items = await api.getList('/friends', requireAuth: true);
    _friends = List.unmodifiable(items.map(AppFriend.fromApi).nonNulls);
    return _friends.isEmpty ? const [] : [friendsAudience(_friends)];
  }

  /// A friend's post's photo ([FriendPost.hasPhoto]).
  Future<Uint8List> photo(String postId) async => Uint8List.fromList(
      await api.getBytes('/memory-shares/${Uri.encodeComponent(postId)}/photo',
          requireAuth: true));

  /// Friends' posts shared with the user and still active, newest first.
  Future<List<FriendPost>> received() async {
    final items =
        await api.getList('/memory-shares/received', requireAuth: true);
    final now = _clock();
    return List.unmodifiable(items
        .map(FriendPost.fromJson)
        .nonNulls
        .where((post) => post.isActive(now)));
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
    final recipients = friendsAudienceIds(payload.audience.id);
    final text = payload.text?.trim() ?? '';
    if (recipients.isEmpty || text.isEmpty) throw const ShareUnavailable();
    final title = payload.title?.trim();
    final Map<String, dynamic> info;
    try {
      info = await api.postJson(
          '/memory-shares',
          {
            'recipient_ids': recipients,
            if (title != null && title.isNotEmpty) 'title': title,
            'text': text,
            'place': {
              'label': payload.place.label,
              'latitude': payload.place.latitude,
              'longitude': payload.place.longitude,
            },
            if (payload.category != null) 'category': payload.category!.label,
            if (replacing != null && _posts.containsKey(replacing))
              'replacing': replacing,
          },
          requireAuth: true);
    } on ApiException catch (error) {
      // 422: someone is no longer a friend; 404: the old post is gone.
      if (error.statusCode == 422 || error.statusCode == 404) {
        throw const ShareUnavailable();
      }
      rethrow;
    }
    final id = info['id'];
    final expires = DateTime.tryParse('${info['expires_at']}');
    if (id is! String || expires == null) {
      throw const FormatException('memory share');
    }
    final photo = payload.photoPath;
    if (photo != null) {
      // The post is only right with its photo: without it, it is taken
      // down again and nothing is said to be shared.
      try {
        final bytes = await _readPhoto(photo);
        final type = photoType(bytes);
        if (type == null || bytes.length > photoMaxBytes) {
          throw const FormatException('photo');
        }
        await api.putBytes('/memory-shares/${Uri.encodeComponent(id)}/photo',
            bytes,
            contentType: type, requireAuth: true);
      } catch (_) {
        try {
          await api.deleteNoContent(
              '/memory-shares/${Uri.encodeComponent(id)}',
              requireAuth: true);
        } catch (_) {
          // It expires on its own within 24 hours.
        }
        throw const ShareUnavailable();
      }
    }
    final now = _clock();
    if (replacing != null) _revoked(replacing, now);
    return _posts[id] = SharedMemoryPost(
        id: id, payload: payload, publishedAt: now, expiresAt: expires);
  }

  @override
  Future<SharedMemoryPost?> post(String postId) async {
    final kept = _posts[postId];
    if (kept == null) return null;
    try {
      await api.getJson('/memory-shares/${Uri.encodeComponent(postId)}',
          requireAuth: true);
      return kept;
    } on ApiException catch (error) {
      // Gone from the server (expired or revoked elsewhere).
      if (error.statusCode == 404) return _revoked(postId, _clock());
      rethrow;
    }
  }

  @override
  Future<SharedMemoryPost> revoke(String postId) async {
    try {
      await api.deleteNoContent('/memory-shares/${Uri.encodeComponent(postId)}',
          requireAuth: true);
    } on ApiException catch (error) {
      if (error.statusCode != 404) throw const ShareUnavailable();
    }
    final revoked = _revoked(postId, _clock());
    if (revoked == null) throw const ShareUnavailable();
    return revoked;
  }

  SharedMemoryPost? _revoked(String postId, DateTime at) {
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
      if (post.payload.albumId == albumId && post.isActive(now)) {
        await revoke(post.id);
      }
    }
  }

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

  @override
  bool get needsText => false;

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
