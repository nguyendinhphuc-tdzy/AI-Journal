import 'package:flutter/widgets.dart';

import 'data/album_auth.dart';
import 'data/album_repository.dart';
import 'data/album_sharing.dart';
import 'data/memory_photos.dart';
import 'data/memory_share.dart';
import 'presentation/album_pin_sheet.dart';

/// Hands the app's [AlbumRepository] and the albums' PIN lock ([AlbumAuth])
/// to the Album screens.
class AlbumScope extends InheritedWidget {
  const AlbumScope({
    super.key,
    required this.repository,
    this.auth,
    this.sharing = const NoAlbumPublishing(),
    this.photos,
    this.memorySharing = const NoAlbumPublishing(),
    required super.child,
  });

  final AlbumRepository repository;

  /// The albums' PINs; the app's PIN pad when not given.
  final AlbumAuth? auth;
  final AlbumSharing sharing;

  /// Photo picking and keeping; the device's when not given.
  final MemoryPhotos? photos;

  /// 24-hour posts of memories (A10); none until a share service exists.
  final MemorySharing memorySharing;

  /// Screens built without a scope (e.g. in isolation) get an in-memory one.
  static final _fallback = InMemoryAlbumRepository();
  static final _pinAuth = PinAlbumAuth();
  static final _devicePhotos = DeviceMemoryPhotos();

  static AlbumScope? _scope(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AlbumScope>();

  static AlbumRepository of(BuildContext context) =>
      _scope(context)?.repository ?? _fallback;

  static AlbumAuth authOf(BuildContext context) =>
      _scope(context)?.auth ?? _pinAuth;

  static MemoryPhotos photosOf(BuildContext context) =>
      _scope(context)?.photos ?? _devicePhotos;

  static AlbumSharing sharingOf(BuildContext context) =>
      _scope(context)?.sharing ?? const NoAlbumPublishing();

  static MemorySharing memorySharingOf(BuildContext context) =>
      _scope(context)?.memorySharing ?? const NoAlbumPublishing();

  @override
  bool updateShouldNotify(AlbumScope old) =>
      old.repository != repository ||
      old.auth != auth ||
      old.sharing != sharing ||
      old.photos != photos ||
      old.memorySharing != memorySharing;
}
