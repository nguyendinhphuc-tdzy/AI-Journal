import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../album_scope.dart';
import '../data/album.dart';
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
/// - "Khóa album" asks for the album's own 4-digit PIN as it is turned on
///   (twice, `AlbumAuth.choosePin`); turning it off forgets that PIN. The
///   album is created locked with it. Nothing is presented as secure that
///   is not: the lock gates opening, it encrypts nothing.
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
      'Album được khóa bằng mật khẩu 4 số của riêng album này. Bật khóa sẽ '
      'hỏi bạn đặt mật khẩu; mỗi lần mở album cần nhập mật khẩu đó.';
  static const lockCanceled = 'Chưa đặt mật khẩu. Album chưa được tạo.';
  static const lockFailed =
      'Chưa giữ được mật khẩu. Album chưa được tạo. Bạn thử lại nhé.';
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

  /// The PIN chosen as the lock was turned on; asked again if the draft
  /// came back locked without one.
  String? _pin;
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
  void dispose() {
    _name.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  void _setTheme(String id) => setState(() => _themeId = _draft.themeId = id);

  void _setLocked(bool locked) => _locked = _draft.locked = locked;

  /// On: the album's PIN, chosen now. Off: no PIN.
  Future<void> _toggleLock(bool value) async {
    if (!value) {
      setState(() {
        _pin = null;
        _setLocked(false);
      });
      return;
    }
    final pin = await AlbumScope.authOf(context).choosePin(context);
    if (!mounted || pin == null) return;
    setState(() {
      _pin = pin;
      _setLocked(true);
    });
  }

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
    final auth = AlbumScope.authOf(context);
    if (_locked && _pin == null) {
      // Locked from the start: it opens with a PIN, chosen before anything
      // is created.
      final pin = await auth.choosePin(context);
      if (!mounted) return;
      if (pin == null) {
        setState(() {
          _saving = false;
          _error = CreateAlbumSheet.lockCanceled;
        });
        return;
      }
      _pin = pin;
    }
    final repository = AlbumScope.of(context);
    try {
      var album = await repository.create(
        name: _name.text,
        themeId: _themeId,
        locked: _locked,
      );
      if (album.locked) {
        try {
          await auth.setPin(album.id, _pin);
        } catch (_) {
          // A lock nothing can open is never kept: the album stays open
          // and can be locked again from its settings.
          album = await repository.update(album.copyWith(locked: false));
        }
      }
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
                      value: _locked,
                      enabled: !_saving,
                      onChanged: _toggleLock,
                      help: CreateAlbumSheet.lockHelp,
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
