import 'album.dart';
import 'album_repository.dart';
import 'album_sharing.dart';

/// Session-only drafts; never copied into the repository until a save succeeds.
class AlbumSettingsDraft {
  AlbumSettingsDraft(Album album)
      : name = album.name,
        themeId = album.themeId,
        locked = album.locked;

  static final session = <String, AlbumSettingsDraft>{};
  String name;
  String themeId;
  bool locked;

  bool differsFrom(Album album) =>
      name.trim() != album.name ||
      themeId != album.themeId ||
      locked != album.locked;
}

class ShareRevocationRequired implements Exception {}

class AlbumSettingsFailure implements Exception {
  const AlbumSettingsFailure(this.message);
  final String message;
}

/// Commits only settings. The publication barrier spans revocation, its
/// confirmation and the lock write. A failed write never restores a share.
class AlbumSettingsWriter {
  const AlbumSettingsWriter(this.repository, this.sharing);
  final AlbumRepository repository;
  final AlbumSharing sharing;

  Future<Album> save(String id, AlbumSettingsDraft draft,
      {required bool revokeShares, required bool Function() mayCommit}) async {
    Future<Album> commit() async {
      if (!mayCommit()) {
        throw const AlbumSettingsFailure('Hãy xác thực lại trước khi lưu.');
      }
      try {
        return await repository.updateSettings(id,
            name: draft.name, themeId: draft.themeId, locked: draft.locked);
      } catch (_) {
        throw const AlbumSettingsFailure(
            'Chưa lưu được thay đổi. Trạng thái khóa chưa thay đổi. Hãy thử lại.');
      }
    }

    if (!draft.locked) return commit();
    return sharing.withPublicationBlocked(id, () async {
      if (!mayCommit()) {
        throw const AlbumSettingsFailure('Hãy xác thực lại trước khi lưu.');
      }
      bool active;
      try {
        active = await sharing.hasActiveShares(id);
      } catch (_) {
        throw const AlbumSettingsFailure(
            'Chưa kiểm tra được bài chia sẻ. Album chưa được khóa. Hãy thử lại.');
      }
      if (active) {
        if (!revokeShares) throw ShareRevocationRequired();
        if (!mayCommit()) {
          throw const AlbumSettingsFailure('Hãy xác thực lại trước khi lưu.');
        }
        try {
          await sharing.revokeAll(id);
          if (await sharing.hasActiveShares(id)) {
            throw StateError('still public');
          }
        } catch (_) {
          throw const AlbumSettingsFailure(
              'Chưa xác nhận thu hồi hết bài chia sẻ. Album chưa được khóa. '
              'Hãy thử lại; một số bài có thể đã được thu hồi.');
        }
        try {
          return await commit();
        } catch (_) {
          throw const AlbumSettingsFailure(
              'Đã thu hồi bài chia sẻ nhưng chưa lưu được khóa. '
              'Album chưa được khóa. Hãy thử lại.');
        }
      }
      return commit();
    });
  }
}
