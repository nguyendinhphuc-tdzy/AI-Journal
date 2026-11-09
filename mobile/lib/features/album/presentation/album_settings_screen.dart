import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../album_scope.dart';
import '../data/album.dart';
import '../data/album_auth.dart';
import '../data/album_settings.dart';
import '../data/album_unlocks.dart';
import 'album_form_parts.dart';

/// A03. The route's access guard preserves this editor while reauthenticating.
class AlbumSettingsScreen extends StatefulWidget {
  const AlbumSettingsScreen(
      {super.key, required this.album, required this.onDelete});
  final Album album;

  /// A11; true once the album is gone: the form fades out (180 ms) and the
  /// album closes back to A01.
  final Future<bool> Function() onDelete;
  static const title = 'Cài đặt album';
  static const saveLabel = 'Lưu thay đổi';
  static const revokeLabel = 'Thu hồi bài chia sẻ và khóa album';
  static const saved = 'Đã lưu thay đổi.';
  static const savedLocked = 'Đã lưu thay đổi. Album đã khóa.';
  static const lockHelp =
      'Album được khóa bằng mật khẩu 4 số của riêng album này. Bật khóa sẽ '
      'hỏi bạn đặt mật khẩu; tắt khóa cần mật khẩu hiện tại. Thay đổi áp dụng '
      'khi bạn lưu.';

  @override
  State<AlbumSettingsScreen> createState() => _AlbumSettingsScreenState();
}

class _AlbumSettingsScreenState extends State<AlbumSettingsScreen> {
  final _session = AlbumUnlocks.instance;
  late Album _saved = widget.album;
  late final _draft = AlbumSettingsDraft.session
      .putIfAbsent(widget.album.id, () => AlbumSettingsDraft(widget.album));
  late final _name = TextEditingController(text: _draft.name);

  /// The PIN chosen when the lock was turned on here; kept on save.
  String? _newPin;

  /// The saved lock's PIN was entered here, so it may be turned off.
  bool _unlockConfirmed = false;
  bool _busy = false;
  bool _retry = false;
  String? _message;
  bool _deleted = false;
  Timer? _leave;

  Future<void> _delete() async {
    final deleted = await widget.onDelete();
    if (!deleted || !mounted) return;
    setState(() => _deleted = true);
    _leave = Timer(
        MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 180), () {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).popUntil((r) => r.isFirst);
      }
    });
  }

  bool get _dirty => _draft.differsFrom(_saved);
  bool get _valid =>
      _name.text.trim().isNotEmpty && _name.text.characters.length <= 60;

  @override
  void initState() {
    super.initState();
    _name.addListener(() {
      _draft.name = _name.text;
      _remember();
      setState(() {});
    });
  }

  void _remember() => AlbumSettingsDraft.session[widget.album.id] = _draft;

  static const _offReason = 'Nhập mật khẩu hiện tại để tắt khóa album.';

  /// Turning the lock on asks for a new PIN right away; turning a saved
  /// lock off asks for its PIN. Both apply on "Lưu thay đổi".
  Future<void> _toggleLock(bool value) async {
    final auth = AlbumScope.authOf(context);
    if (value) {
      final pin = await auth.choosePin(context);
      if (!mounted || pin == null) return;
      setState(() {
        _newPin = pin;
        _draft.locked = true;
        _remember();
      });
      return;
    }
    if (_saved.locked && !_unlockConfirmed) {
      final result =
          await auth.verify(context, widget.album.id, reason: _offReason);
      if (!mounted || result != AlbumAuthResult.success) return;
      _unlockConfirmed = true;
    }
    setState(() {
      _newPin = null;
      _draft.locked = false;
      _remember();
    });
  }

  Future<bool> _confirmRevoke() async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Album có bài chia sẻ đang hoạt động'),
          content:
              const Text('Để khóa album, cần thu hồi các bài chia sẻ trước. '
                  'Album chỉ được khóa sau khi thu hồi và lưu thành công.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Hủy')),
            FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(AlbumSettingsScreen.revokeLabel)),
          ],
        ),
      ) ??
      false;

  Future<void> _save() async {
    if (_busy || !_dirty || !_valid || !_session.foreground) return;
    final repository = AlbumScope.of(context);
    final auth = AlbumScope.authOf(context);
    final writer =
        AlbumSettingsWriter(repository, AlbumScope.sharingOf(context));
    setState(() {
      _busy = true;
      _message = null;
      _retry = false;
    });
    try {
      final current = await repository.album(widget.album.id);
      if (current == null) {
        throw const AlbumSettingsFailure('Album không còn tồn tại.');
      }
      if (!mounted) return;
      // A lock change needs its PIN: a new one to lock (asked again if
      // this draft came back without it), the saved one to unlock.
      var authenticatedChange = false;
      if (current.locked != _draft.locked) {
        if (_draft.locked) {
          final pin = _newPin ?? await auth.choosePin(context);
          if (!mounted) return;
          if (pin == null) {
            throw const AlbumSettingsFailure(
                'Chưa đặt mật khẩu. Chưa lưu thay đổi.');
          }
          _newPin = pin;
        } else if (!_unlockConfirmed) {
          final result =
              await auth.verify(context, current.id, reason: _offReason);
          if (!mounted) return;
          if (result != AlbumAuthResult.success) {
            throw AlbumSettingsFailure(result == AlbumAuthResult.canceled
                ? 'Đã hủy. Chưa lưu thay đổi.'
                : 'Chưa kiểm tra được mật khẩu. Chưa lưu thay đổi.');
          }
          _unlockConfirmed = true;
        }
        authenticatedChange = true;
      }
      if (!mounted) return;
      final revision = _session.revision;
      bool mayCommit() =>
          mounted &&
          _session.foreground &&
          revision == _session.revision &&
          (!current.locked ||
              authenticatedChange ||
              _session.isUnlocked(current.id));
      if (!mayCommit()) {
        throw const AlbumSettingsFailure('Hãy xác thực lại trước khi lưu.');
      }
      // The PIN is kept before the album locks, so a locked album always
      // has one; a failed save leaves an unused PIN, replaced next time.
      if (_draft.locked && !current.locked) {
        await auth.setPin(current.id, _newPin);
      }
      Album result;
      try {
        result = await writer.save(current.id, _draft,
            revokeShares: false, mayCommit: mayCommit);
      } on ShareRevocationRequired {
        if (!mounted || !mayCommit() || !await _confirmRevoke()) return;
        result = await writer.save(current.id, _draft,
            revokeShares: true, mayCommit: mayCommit);
      }
      if (!mounted) return;
      if (result.locked && authenticatedChange && mayCommit()) {
        _session.unlock(result.id);
      }
      if (current.locked && !result.locked) {
        // Best effort: an unlocked album never asks for it again.
        await auth.setPin(result.id, null).catchError((Object _) {});
      }
      AlbumSettingsDraft.session.remove(result.id);
      _saved = result;
      _leaveSaved(result);
    } catch (error) {
      if (mounted) {
        setState(() {
          _retry = true;
          _message = error is AlbumSettingsFailure
              ? error.message
              : 'Chưa lưu được thay đổi. Bản nháp vẫn còn. Hãy thử lại.';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Saved: back to where A03 was opened from, saying what changed. Leaving
  /// locks the album again (`AlbumRoutes`), so a lock just turned on applies
  /// at once.
  void _leaveSaved(Album result) {
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(result.locked
            ? AlbumSettingsScreen.savedLocked
            : AlbumSettingsScreen.saved),
      ));
  }

  @override
  void dispose() {
    _leave?.cancel();
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final destructive = Theme.of(context).colorScheme.error;
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          surfaceTintColor: Colors.transparent,
          title:
              const Text(AlbumSettingsScreen.title, style: AlbumFormText.title),
        ),
        body: AnimatedOpacity(
          opacity: _deleted ? 0 : 1,
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 180),
          child: IgnorePointer(
            ignoring: _deleted,
            child: SafeArea(
              child: Column(children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.lg,
                        AppSpacing.sm, AppSpacing.lg, AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AlbumFormSection(
                          child: TextField(
                            controller: _name,
                            enabled: !_busy,
                            maxLength: 60,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: InputDecoration(
                              labelText: 'Tên album',
                              errorText: _name.text.trim().isEmpty
                                  ? 'Hãy đặt tên cho album.'
                                  : null,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        AlbumFormSection(
                          title: 'Bìa album',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              AlbumCoverPreview(themeId: _draft.themeId),
                              const SizedBox(height: 12),
                              AlbumThemeGrid(
                                selected: _draft.themeId,
                                enabled: !_busy,
                                onSelected: (id) => setState(() {
                                  _draft.themeId = id;
                                  _remember();
                                }),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        AlbumLockCard(
                          title: 'Khóa album',
                          value: _draft.locked,
                          enabled: !_busy,
                          onChanged: _toggleLock,
                          help: AlbumSettingsScreen.lockHelp,
                          currentlyLocked: _saved.locked,
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        // Apart from the rest, in its own colour: never the primary.
                        OutlinedButton.icon(
                          onPressed: _busy || _deleted ? null : _delete,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: destructive,
                            side: BorderSide(
                                color: destructive.withValues(alpha: .5)),
                            minimumSize: const Size.fromHeight(48),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24)),
                            textStyle: AlbumFormText.section,
                          ),
                          icon: const Icon(Icons.delete_outline_rounded),
                          label: const Text('Xóa album'),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        const Text(
                          'Bạn sẽ xác nhận ở bước tiếp theo. Bản nháp cài đặt vẫn '
                          'được giữ.',
                          textAlign: TextAlign.center,
                          style: AlbumFormText.note,
                        ),
                      ],
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.lg,
                      AppSpacing.sm, AppSpacing.lg, AppSpacing.md),
                  decoration: const BoxDecoration(
                    color: AppColors.background,
                    border: Border(top: BorderSide(color: AppColors.border)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_message != null) ...[
                        AlbumFormMessage(_message!,
                            icon: _retry
                                ? Icons.info_outline_rounded
                                : Icons.check_circle_outline_rounded),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                      if (_retry)
                        TextButton(
                          onPressed: _busy || !_dirty ? null : _save,
                          style: TextButton.styleFrom(
                              foregroundColor: AppColors.primaryAction,
                              minimumSize: const Size.fromHeight(48)),
                          child: const Text('Thử lại'),
                        ),
                      AlbumPrimaryButton(
                        // Words, not a spinner: saving may wait on the share
                        // dialog, and the button keeps its size either way.
                        label:
                            _busy ? 'Đang lưu…' : AlbumSettingsScreen.saveLabel,
                        onPressed: !_busy && _dirty && _valid ? _save : null,
                      ),
                      if (_dirty && !_busy)
                        const Padding(
                          padding: EdgeInsets.only(top: AppSpacing.sm),
                          child: Text(
                            'Bản nháp được giữ trong phiên này khi quay lại.',
                            textAlign: TextAlign.center,
                            style: AlbumFormText.note,
                          ),
                        ),
                    ],
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
