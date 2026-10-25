import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../album_scope.dart';
import '../data/memory_photos.dart';
import 'album_form_parts.dart';

/// How A07 ended.
sealed class PhotoPick {
  const PhotoPick();
}

/// "Dùng ảnh" on this file (not kept yet; A06 keeps it).
class PhotoPicked extends PhotoPick {
  const PhotoPicked(this.path);
  final String path;
}

/// Closed anywhere along the way: the photo already there stays.
class PhotoPickCanceled extends PhotoPick {
  const PhotoPickCanceled();
}

/// Access to [source] was refused; the note is still there to write.
class PhotoPickDenied extends PhotoPick {
  const PhotoPickDenied(this.source);
  final PhotoSource source;
}

/// A07: choose (or take) a photo for a memory.
///
/// - With a camera, a sheet offers "Chọn từ thư viện" and "Chụp ảnh";
///   without one the system photo picker opens directly. Nothing is asked
///   before the user taps; the camera goes through the system camera app.
/// - The chosen photo is shown as it is (no filter) with "Dùng ảnh" and
///   "Hủy"; only "Dùng ảnh" changes the memory. Canceling never removes the
///   photo already there.
/// - No Nudaeng here; A06 plays ND08 once the new photo is ready.
abstract final class PhotoPickerFlow {
  static const sheetTitleAdd = 'Thêm ảnh';
  static const sheetTitleReplace = 'Thay ảnh';
  static const libraryLabel = 'Chọn từ thư viện';
  static const cameraLabel = 'Chụp ảnh';
  static const cancelLabel = 'Hủy';
  static const useLabel = 'Dùng ảnh';
  static const previewTitle = 'Xem ảnh';
  static const previewFailed =
      'Không xem trước được ảnh này. Bạn có thể chọn ảnh khác.';

  static Future<PhotoPick> run(BuildContext context,
      {required bool replacing}) async {
    final photos = AlbumScope.photosOf(context);
    final navigator = Navigator.of(context, rootNavigator: true);
    var source = PhotoSource.library;
    if (photos.hasCamera) {
      final chosen = await showModalBottomSheet<PhotoSource>(
        context: context,
        useRootNavigator: true,
        barrierColor: Colors.black.withValues(alpha: .35),
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        builder: (_) => _SourceSheet(replacing: replacing),
      );
      if (chosen == null) return const PhotoPickCanceled();
      source = chosen;
    }
    String? path;
    try {
      path = await photos.pick(source);
    } on PhotoAccessDenied catch (denied) {
      return PhotoPickDenied(denied.source);
    }
    if (path == null || !navigator.mounted) return const PhotoPickCanceled();
    final use = await navigator.push<bool>(MaterialPageRoute(
      settings: const RouteSettings(name: 'album/A07-preview'),
      fullscreenDialog: true,
      builder: (_) => _Preview(path: path!),
    ));
    return use == true ? PhotoPicked(path) : const PhotoPickCanceled();
  }
}

class _SourceSheet extends StatelessWidget {
  const _SourceSheet({required this.replacing});

  final bool replacing;

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Text(
                    replacing
                        ? PhotoPickerFlow.sheetTitleReplace
                        : PhotoPickerFlow.sheetTitleAdd,
                    style: AlbumFormText.title),
              ),
              const SizedBox(height: AppSpacing.sm),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.photo_library_outlined,
                    color: AppColors.primaryAction),
                title: const Text(PhotoPickerFlow.libraryLabel,
                    style: AlbumFormText.section),
                onTap: () => Navigator.pop(context, PhotoSource.library),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.photo_camera_outlined,
                    color: AppColors.primaryAction),
                title: const Text(PhotoPickerFlow.cameraLabel,
                    style: AlbumFormText.section),
                onTap: () => Navigator.pop(context, PhotoSource.camera),
              ),
              const SizedBox(height: AppSpacing.xs),
              TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    minimumSize: const Size.fromHeight(48)),
                child: const Text(PhotoPickerFlow.cancelLabel),
              ),
            ],
          ),
        ),
      );
}

/// The photo as chosen, true colours on a neutral dark ground; "Dùng ảnh" or
/// "Hủy".
class _Preview extends StatefulWidget {
  const _Preview({required this.path});

  final String path;

  @override
  State<_Preview> createState() => _PreviewState();
}

class _PreviewState extends State<_Preview> {
  var _failed = false;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.textPrimary,
        appBar: AppBar(
          backgroundColor: AppColors.textPrimary,
          foregroundColor: AppColors.surface,
          surfaceTintColor: Colors.transparent,
          leading: IconButton(
            tooltip: PhotoPickerFlow.cancelLabel,
            icon: const Icon(Icons.close_rounded),
            onPressed: () => Navigator.pop(context, false),
          ),
          title: const Text(PhotoPickerFlow.previewTitle),
        ),
        body: SafeArea(
          child: Column(children: [
            Expanded(
              child: Center(
                child: _failed
                    ? const Padding(
                        padding: EdgeInsets.all(AppSpacing.xl),
                        child: Text(PhotoPickerFlow.previewFailed,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: AppColors.surface, fontSize: 16)),
                      )
                    : Semantics(
                        image: true,
                        label: 'Ảnh bạn vừa chọn',
                        child: Image.file(
                          File(widget.path),
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted && !_failed) {
                                setState(() => _failed = true);
                              }
                            });
                            return const SizedBox.shrink();
                          },
                        ),
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.md),
              child: Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.surface,
                      side: const BorderSide(color: AppColors.surface),
                      minimumSize: const Size.fromHeight(56),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28)),
                      textStyle: AlbumFormText.button,
                    ),
                    child: const Text(PhotoPickerFlow.cancelLabel),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AlbumPrimaryButton(
                    label: PhotoPickerFlow.useLabel,
                    onPressed:
                        _failed ? null : () => Navigator.pop(context, true),
                  ),
                ),
              ]),
            ),
          ]),
        ),
      );
}
