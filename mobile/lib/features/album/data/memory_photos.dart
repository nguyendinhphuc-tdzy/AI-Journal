import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import 'album_unlocks.dart';

/// Where a memory's photo comes from (A07).
enum PhotoSource {
  /// The operating system's photo picker: no broad photo permission (on
  /// Android the system photo picker; limited access works as the OS allows).
  library,

  /// The system camera app, only after the user chose it.
  camera,
}

/// The user (or the system) refused access to [source].
class PhotoAccessDenied implements Exception {
  const PhotoAccessDenied(this.source);
  final PhotoSource source;
}

/// Photos for memories: the operating system's own picker or camera, then a
/// copy the app keeps, so the memory never points at a temporary file.
abstract interface class MemoryPhotos {
  /// Whether "Chụp ảnh" can be offered.
  bool get hasCamera;

  /// The picked (or taken) file; null when the user closed the picker.
  /// Throws [PhotoAccessDenied] when access was refused.
  Future<String?> pick([PhotoSource source = PhotoSource.library]);

  /// Copies [sourcePath] into the app's own storage; the kept path.
  Future<String> keep(String sourcePath);
}

/// Photos the app kept can be removed again (a memory or album deleted).
/// Optional: a [MemoryPhotos] without it leaves the files.
abstract interface class MemoryPhotoCleanup {
  /// Removes a photo [MemoryPhotos.keep] made; anything else is left alone.
  Future<void> discard(String keptPath);
}

class DeviceMemoryPhotos implements MemoryPhotos, MemoryPhotoCleanup {
  DeviceMemoryPhotos([ImagePicker? picker], {this.userId})
      : _picker = picker ?? ImagePicker();

  /// Keep the guest and each signed-in user's images in separate folders.
  final String? userId;

  Future<Directory> _ownFolder() async {
    final base = (await getApplicationDocumentsDirectory()).path;
    return Directory('$base/album_photos'
        '${userId == null ? '' : '/$userId'}');
  }

  /// Explicit guest exit only: do not remove another user's files.
  static Future<void> discardGuestFolder() async {
    final base = (await getApplicationDocumentsDirectory()).path;
    final folder = Directory('$base/album_photos/local-guest');
    if (await folder.exists()) await folder.delete(recursive: true);
  }

  final ImagePicker _picker;
  final _random = math.Random();

  @override
  bool get hasCamera {
    try {
      return _picker.supportsImageSource(ImageSource.camera);
    } catch (_) {
      return false;
    }
  }

  @override
  Future<String?> pick([PhotoSource source = PhotoSource.library]) async {
    try {
      // The system picker or camera pauses the app; that is not leaving the
      // album.
      final file = await AlbumUnlocks.instance
          .duringSystemPrompt(() => _picker.pickImage(
                source: source == PhotoSource.camera
                    ? ImageSource.camera
                    : ImageSource.gallery,
                // Large enough for a full-width photo; storage stays
                // reasonable. Colours are left as they are.
                maxWidth: 2048,
                maxHeight: 2048,
                imageQuality: 90,
                requestFullMetadata: false,
              ));
      return file?.path;
    } on PlatformException catch (error) {
      if (error.code.endsWith('access_denied')) {
        throw PhotoAccessDenied(source);
      }
      rethrow;
    }
  }

  @override
  Future<String> keep(String sourcePath) async {
    final dir = await _ownFolder();
    await dir.create(recursive: true);
    final dot = sourcePath.lastIndexOf('.');
    final ext = dot < 0 ? '.jpg' : sourcePath.substring(dot);
    final name = '${DateTime.now().microsecondsSinceEpoch}-'
        '${_random.nextInt(1 << 32)}$ext';
    final kept = await File(sourcePath).copy('${dir.path}/$name');
    return kept.path;
  }

  @override
  Future<void> discard(String keptPath) async {
    final dir = '${(await _ownFolder()).path}/';
    // Only the app's own copies, never a file it did not make.
    if (!keptPath.startsWith(dir) || keptPath.contains('..')) return;
    final file = File(keptPath);
    if (await file.exists()) await file.delete();
  }
}
