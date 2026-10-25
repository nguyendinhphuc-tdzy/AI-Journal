import 'memory_share.dart';

/// Boundary for a future real share service. A lock operation must exclude
/// concurrent publication for this album until [action] finishes. A production
/// implementation must enforce this on the server, not just in this widget.
abstract interface class AlbumSharing {
  Future<bool> hasActiveShares(String albumId);
  Future<void> revokeAll(String albumId);
  Future<T> withPublicationBlocked<T>(
      String albumId, Future<T> Function() action);
}

/// Current app has no publishing implementation: there is no share API yet
/// (`docs/API_CONTRACT.md`). Replace this adapter when publishing is
/// connected. Never use this adapter for a repository containing remotely
/// shared albums. A10 offers no audience with it, and a publish says nothing
/// was shared.
class NoAlbumPublishing implements AlbumSharing, MemorySharing {
  const NoAlbumPublishing();

  @override
  Future<bool> hasActiveShares(String albumId) async => false;
  @override
  Future<void> revokeAll(String albumId) async {}
  @override
  Future<T> withPublicationBlocked<T>(
          String albumId, Future<T> Function() action) =>
      action();

  @override
  Future<List<ShareAudience>> audiences() async => const [];
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
}
