import 'package:flutter/foundation.dart';

import 'memory.dart';

/// The map categories of the Share wireframe. No choice is "Chưa phân loại";
/// nothing is put in Food by default.
enum ShareCategory {
  food('Food', 'Ăn uống'),
  entertainment('Entertainment', 'Giải trí'),
  studyCafe('Study Cafe', 'Cà phê học bài');

  const ShareCategory(this.id, this.label);

  /// The value Explore filters by.
  final String id;
  final String label;

  static const uncategorized = 'Chưa phân loại';
}

/// Who can see a 24-hour post. Names come from the sharing service; the app
/// never makes one up (the product has not settled on audiences yet).
@immutable
class ShareAudience {
  const ShareAudience({required this.id, required this.label, this.detail});

  final String id;
  final String label;

  /// A line saying who that is, e.g. how many people.
  final String? detail;

  @override
  bool operator ==(Object other) => other is ShareAudience && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Exactly what a 24-hour post shows: a snapshot taken when the user taps
/// "Chia sẻ trong 24 giờ". Editing the memory later does not change it.
@immutable
class SharePayload {
  const SharePayload({
    required this.albumId,
    required this.memoryId,
    required this.audience,
    required this.place,
    this.category,
    this.title,
    this.photoPath,
    this.text,
  });

  final String albumId;
  final String memoryId;
  final ShareAudience audience;

  /// Confirmed by the user in A10 (or E05), never a GPS default.
  final MemoryPlace place;
  final ShareCategory? category;
  final String? title;

  /// The memory's photo, when it has one.
  final String? photoPath;

  /// The description written (or picked from the note) for this post; never
  /// the whole private note by default.
  final String? text;

  bool get hasContent => photoPath != null || (text ?? '').trim().isNotEmpty;
}

/// Where a post stands (A12).
enum PostState { active, expired, revoked }

/// A post the service accepted. [expiresAt] and [revokedAt] are the
/// server's, not computed here; screens fetch the post again rather than
/// trusting the device clock alone.
@immutable
class SharedMemoryPost {
  const SharedMemoryPost({
    required this.id,
    required this.payload,
    required this.publishedAt,
    required this.expiresAt,
    this.revokedAt,
  });

  final String id;
  final SharePayload payload;
  final DateTime publishedAt;
  final DateTime expiresAt;

  /// Taken off the map by its owner (or with its memory or album).
  final DateTime? revokedAt;

  String get memoryId => payload.memoryId;

  PostState stateAt(DateTime now) => revokedAt != null
      ? PostState.revoked
      : now.isBefore(expiresAt)
          ? PostState.active
          : PostState.expired;

  bool isActive(DateTime now) => stateAt(now) == PostState.active;
}

/// Posts taken off the map: one post (A12), or every post of a deleted
/// memory or album (A11). Screens showing such a post drop it.
@immutable
class ShareRemoval {
  const ShareRemoval({this.postId, this.memoryId, this.albumId});

  final String? postId;
  final String? memoryId;
  final String? albumId;

  bool matches(SharedMemoryPost post) =>
      post.id == postId ||
      post.memoryId == memoryId ||
      post.payload.albumId == albumId;
}

/// The post could not be made: no sharing service yet, offline, or the
/// service said no. Nothing was shared.
class ShareUnavailable implements Exception {
  const ShareUnavailable();
}

/// The 24-hour share service (A10, later A12). A memory has at most one
/// active post.
abstract interface class MemorySharing {
  /// Who a post can be shown to; empty when sharing is not set up.
  Future<List<ShareAudience>> audiences();

  /// The memory's active post, if any.
  Future<SharedMemoryPost?> activePost(String memoryId);

  /// Publishes [payload] for 24 hours from now (the server decides). With
  /// [replacing], that post is taken down in the same operation and the new
  /// one gets a new expiry. Throws [ShareUnavailable] when nothing was
  /// shared. A real service must refuse a post for a locked album
  /// (`AlbumSharing.withPublicationBlocked`).
  Future<SharedMemoryPost> publish(SharePayload payload, {String? replacing});

  /// The post as the server has it now (expired or revoked included); null
  /// when the server no longer knows it.
  Future<SharedMemoryPost?> post(String postId);

  /// Takes the post off the map; the memory and its private place stay.
  /// Returns the revoked post. Throws [ShareUnavailable] when it could not.
  Future<SharedMemoryPost> revoke(String postId);
}

/// What was chosen in A10 for one memory and not shared yet. In memory for
/// the app session; Close keeps it, a successful post clears it. Separate
/// from the memory and its A06 draft.
class MemoryShareDraft {
  MemoryShareDraft._();

  static final _session = <String, MemoryShareDraft>{};

  static MemoryShareDraft of(String memoryId) =>
      _session.putIfAbsent(memoryId, MemoryShareDraft._);

  static void discard(String memoryId) => _session.remove(memoryId);

  @visibleForTesting
  static void reset() => _session.clear();

  String? audienceId;
  MemoryPlace? place;
  ShareCategory? category;
  String text = '';
}
