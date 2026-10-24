import 'album_repository.dart';
import 'album_sharing.dart';
import 'memory.dart';
import 'memory_photos.dart';
import 'memory_share.dart';

/// Why a deletion did not happen; the object is still there.
class DeletionFailure implements Exception {
  const DeletionFailure(this.message);
  final String message;
}

/// A11: deletes a memory or an album. Any public post goes first, and is
/// confirmed gone, so no active post outlives what it was made from; only
/// then is the memory or album removed (one write). Photos the app kept are
/// removed afterwards, best effort. There is no undo.
class AlbumDeletion {
  const AlbumDeletion({
    required this.repository,
    required this.albumSharing,
    required this.memorySharing,
    this.photos,
  });

  final AlbumRepository repository;
  final AlbumSharing albumSharing;
  final MemorySharing memorySharing;
  final MemoryPhotos? photos;

  static const memoryFailed =
      'Chưa xóa được kỷ niệm. Kỷ niệm vẫn còn nguyên, bạn thử lại nhé.';
  static const memoryRevokeFailed =
      'Chưa gỡ được bài chia sẻ của kỷ niệm này nên chưa xóa. Kỷ niệm vẫn '
      'còn, bạn thử lại nhé.';
  static const memoryRevokedNotDeleted =
      'Đã gỡ bài chia sẻ nhưng chưa xóa được kỷ niệm. Kỷ niệm vẫn còn, bạn '
      'thử lại nhé.';
  static const albumFailed =
      'Chưa xóa được album. Album và các kỷ niệm vẫn còn nguyên, bạn thử lại '
      'nhé.';
  static const albumRevokeFailed =
      'Chưa gỡ hết bài chia sẻ của album nên chưa xóa. Album vẫn còn; một số '
      'bài có thể đã được gỡ. Bạn thử lại nhé.';
  static const albumRevokedNotDeleted =
      'Đã gỡ bài chia sẻ nhưng chưa xóa được album. Album và các kỷ niệm vẫn '
      'còn, bạn thử lại nhé.';

  Future<void> deleteMemory(String albumId, String memoryId) async {
    final memory = await _memory(albumId, memoryId);
    if (memory == null) return;
    var revoked = false;
    try {
      final active = await memorySharing.activePost(memoryId);
      if (active != null) {
        await memorySharing.revoke(active.id);
        revoked = true;
      }
      if (await memorySharing.activePost(memoryId) != null) {
        throw StateError('still public');
      }
    } catch (_) {
      throw const DeletionFailure(memoryRevokeFailed);
    }
    try {
      await repository.deleteMemory(albumId, memoryId);
    } catch (_) {
      throw DeletionFailure(revoked ? memoryRevokedNotDeleted : memoryFailed);
    }
    await _discardPhotos([memory]);
  }

  /// The album and all its memories. Publication stays blocked while its
  /// posts are revoked and the album removed.
  Future<void> deleteAlbum(String albumId) async {
    final List<Memory> memories;
    try {
      memories = await repository.memories(albumId);
    } catch (_) {
      throw const DeletionFailure(albumFailed);
    }
    await albumSharing.withPublicationBlocked(albumId, () async {
      var revoked = false;
      try {
        if (await albumSharing.hasActiveShares(albumId)) {
          await albumSharing.revokeAll(albumId);
          revoked = true;
          if (await albumSharing.hasActiveShares(albumId)) {
            throw StateError('still public');
          }
        }
      } catch (_) {
        throw const DeletionFailure(albumRevokeFailed);
      }
      try {
        await repository.deleteAlbum(albumId);
      } catch (_) {
        throw DeletionFailure(revoked ? albumRevokedNotDeleted : albumFailed);
      }
    });
    await _discardPhotos(memories);
  }

  Future<Memory?> _memory(String albumId, String memoryId) async {
    try {
      return await repository.memory(albumId, memoryId);
    } catch (_) {
      throw const DeletionFailure(memoryFailed);
    }
  }

  /// After the delete is committed: a file left behind is not worth failing
  /// it for.
  Future<void> _discardPhotos(List<Memory> memories) async {
    final cleanup = photos;
    if (cleanup is! MemoryPhotoCleanup) return;
    for (final memory in memories) {
      final path = memory.content.photoPath;
      if (path == null) continue;
      try {
        await (cleanup as MemoryPhotoCleanup).discard(path);
      } catch (_) {}
    }
  }
}
