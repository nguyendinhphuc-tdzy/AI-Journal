import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../album_scope.dart';
import '../data/album.dart';
import '../data/album_auth.dart';
import '../data/album_theme.dart';
import 'album_form_parts.dart';

/// What was typed in A02 and not created yet. Kept in memory for the
/// session when the sheet closes; cleared once the album exists.
class CreateAlbumDraft {
  /// The one draft of this app session.
  static final session = CreateAlbumDraft();

  String name = '';
  String themeId = AlbumTheme.classic.id;
  bool locked = false;

  bool get isEmpty =>
      name.isEmpty && themeId == AlbumTheme.classic.id && !locked;

  void clear() {
    name = '';
    themeId = AlbumTheme.classic.id;
    locked = false;
  }
}

/// A02: name, cover theme and lock for a new album.
///
/// - The name is required after trimming, at most [maxLength] characters;
///   the error is said below the field, not only by its colour.
/// - The theme picker shows the supplied Nudaeng poses; the preview cover
///   crossfades (180 ms).
/// - "Khóa album" is offered only when the device can authenticate;
///   otherwise it is off and says the lock is not supported. Nothing is
///   presented as secure that is not.
/// - "Tạo album" ignores repeated taps while saving and keeps its size; a
///   failed save keeps the form. Closing keeps the draft for the session;
///   nothing is created before the CTA.
/// - No celebration here: the new album's Nudaeng on A01 is the only one.
class CreateAlbumSheet extends StatefulWidget {
  const CreateAlbumSheet({super.key, required this.draft});

  final CreateAlbumDraft draft;

  static const title = 'Tạo album';
  static const nameLabel = 'Tên album';
  static const nameRequired = 'Hãy đặt tên cho album.';
  static const coverLabel = 'Bìa album';
  static const lockLabel = 'Khóa album';
  static const lockHelp =
      'Album được khóa bằng mã PIN (hoặc vân tay, khuôn mặt) của máy. Bạn '
      'xác nhận một lần khi tạo, và mỗi lần mở album.';
  static const lockReason = 'Xác thực để khóa album mới';
  static const lockCanceled = 'Đã hủy xác thực. Album chưa được tạo.';
  static const lockNotSetUp =
      'Hãy đặt mã PIN khóa màn hình trong cài đặt máy để khóa album.';
  static const lockFailed =
      'Chưa xác thực được. Album chưa được tạo. Bạn thử lại nhé.';
  static const lockUnsupported = 'Tính năng khóa chưa được hỗ trợ';
  static const lockUnsupportedHelp =
      'Thiết bị này chưa xác thực được bằng vân tay, khuôn mặt hoặc khóa màn '
      'hình, nên chưa thể khóa album.';
  static const createLabel = 'Tạo album';
  static const createFailed =
      'Chưa tạo được album. Nội dung bạn nhập vẫn còn, bạn thử lại nhé.';
  static const closeTooltip = 'Đóng';
  static const maxLength = 60;

  /// Opens A02 on the root navigator (above the bottom navigation). The new
  /// album, or null when closed without creating one.
  static Future<Album?> show(BuildContext context, CreateAlbumDraft draft) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    return showModalBottomSheet<Album>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      barrierColor: Colors.black.withValues(alpha: .35),
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      sheetAnimationStyle: reduced
          ? AnimationStyle.noAnimation
          : const AnimationStyle(
              duration: Duration(milliseconds: 300),
              reverseDuration: Duration(milliseconds: 220)),
      builder: (_) => CreateAlbumSheet(draft: draft),
    );
  }

  @override
  State<CreateAlbumSheet> createState() => _CreateAlbumSheetState();
}

class _CreateAlbumSheetState extends State<CreateAlbumSheet> {
  late final _name = TextEditingController(text: widget.draft.name);
  late String _themeId = widget.draft.themeId;
  late bool _locked = widget.draft.locked;

  /// Null while checking.
  bool? _lockSupported;
  var _showNameError = false;
  var _saving = false;

  /// Why the last "Tạo album" did not create one; null when it did not fail.
  String? _error;
  final _nameFocus = FocusNode();

  CreateAlbumDraft get _draft => widget.draft;

  @override
  void initState() {
    super.initState();
    _name.addListener(() => _draft.name = _name.text);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_lockSupported != null) return;
    AlbumScope.authOf(context).isSupported().then((supported) {
      if (!mounted) return;
      setState(() {
        _lockSupported = supported;
        // A lock that cannot be opened is never kept on.
        if (!supported) _setLocked(false);
      });
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  void _setTheme(String id) => setState(() => _themeId = _draft.themeId = id);

  void _setLocked(bool locked) => _locked = _draft.locked = locked;

  Future<void> _create() async {
    if (_saving) return;
    if (_name.text.trim().isEmpty) {
      setState(() => _showNameError = true);
      _nameFocus.requestFocus();
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    if (_locked && _lockSupported == true) {
      // Locked from the start: confirm with the device's own PIN, fingerprint
      // or face, so the owner knows what will open it. Nothing is created
      // unless that succeeds.
      final result = await AlbumScope.authOf(context)
          .authenticate(CreateAlbumSheet.lockReason);
      if (!mounted) return;
      if (result != AlbumAuthResult.success) {
        setState(() {
          _saving = false;
          _error = switch (result) {
            AlbumAuthResult.canceled => CreateAlbumSheet.lockCanceled,
            AlbumAuthResult.notSetUp => CreateAlbumSheet.lockNotSetUp,
            _ => CreateAlbumSheet.lockFailed,
          };
        });
        return;
      }
    }
    try {
      final album = await AlbumScope.of(context).create(
        name: _name.text,
        themeId: _themeId,
        locked: _locked && _lockSupported == true,
      );
      _draft.clear();
      if (mounted) Navigator.of(context).pop(album);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = CreateAlbumSheet.createFailed;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final nameError = _showNameError && _name.text.trim().isEmpty
        ? CreateAlbumSheet.nameRequired
        : null;
    // Shrinks above the keyboard; the CTA stays visible.
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: .78,
        minChildSize: .5,
        maxChildSize: .95,
        builder: (context, scroll) => Column(
          children: [
            const _Grip(),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl, 0, AppSpacing.sm, AppSpacing.xs),
              child: Row(children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: const Text(CreateAlbumSheet.title,
                        style: AlbumFormText.title),
                  ),
                ),
                IconButton(
                  tooltip: CreateAlbumSheet.closeTooltip,
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded,
                      color: AppColors.textPrimary),
                ),
              ]),
            ),
            Expanded(
              child: SingleChildScrollView(
                controller: scroll,
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xl, AppSpacing.sm, AppSpacing.xl, AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _name,
                      focusNode: _nameFocus,
                      maxLength: CreateAlbumSheet.maxLength,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.done,
                      enabled: !_saving,
                      onChanged: (_) => setState(() => _error = null),
                      onSubmitted: (_) => _create(),
                      decoration: InputDecoration(
                        labelText: CreateAlbumSheet.nameLabel,
                        errorText: nameError,
                        errorMaxLines: 2,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    AlbumFormSection(
                      title: CreateAlbumSheet.coverLabel,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          AlbumCoverPreview(themeId: _themeId),
                          const SizedBox(height: 12),
                          AlbumThemeGrid(
                            selected: _themeId,
                            enabled: !_saving,
                            onSelected: _setTheme,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    AlbumLockCard(
                      title: CreateAlbumSheet.lockLabel,
                      supported: _lockSupported,
                      value: _locked,
                      enabled: !_saving,
                      onChanged: (value) => setState(() => _setLocked(value)),
                      help: CreateAlbumSheet.lockHelp,
                      unsupportedTitle: CreateAlbumSheet.lockUnsupported,
                      unsupportedHelp: CreateAlbumSheet.lockUnsupportedHelp,
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.sm,
                  AppSpacing.xl,
                  AppSpacing.md +
                      (MediaQuery.viewInsetsOf(context).bottom > 0
                          ? 0
                          : MediaQuery.paddingOf(context).bottom)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Next to the CTA, where the eye is after tapping it.
                  if (_error case final error?) ...[
                    AlbumFormMessage(error),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  // Repeated taps while saving do nothing; the size holds.
                  AlbumPrimaryButton(
                    label: CreateAlbumSheet.createLabel,
                    onPressed: _create,
                    busy: _saving,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Grip extends StatelessWidget {
  const _Grip();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: AppSpacing.sm),
        child: Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: AppColors.border,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );
}
