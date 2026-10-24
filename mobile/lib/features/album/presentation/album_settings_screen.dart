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

  @override
  State<AlbumSettingsScreen> createState() => _AlbumSettingsScreenState();
}

class _AlbumSettingsScreenState extends State<AlbumSettingsScreen> {
  final _session = AlbumUnlocks.instance;
  late Album _saved = widget.album;
  late final _draft = AlbumSettingsDraft.session
      .putIfAbsent(widget.album.id, () => AlbumSettingsDraft(widget.album));
  late final _name = TextEditingController(text: _draft.name);
  bool? _supported;
  bool _checkingSupport = false;
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_checkingSupport) return;
    _checkingSupport = true;
    AlbumScope.authOf(context).isSupported().then((value) {
      if (mounted) setState(() => _supported = value);
    }, onError: (Object _) {
      if (mounted) setState(() => _supported = false);
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
      var authenticatedChange = false;
      if (current.locked != _draft.locked) {
        final result = await auth.authenticate(_draft.locked
            ? 'Xác thực để bật khóa album'
            : 'Xác thực để tắt khóa album');
        if (!mounted) return;
        if (result != AlbumAuthResult.success) {
          throw AlbumSettingsFailure(switch (result) {
            AlbumAuthResult.canceled => 'Đã hủy xác thực. Chưa lưu thay đổi.',
            AlbumAuthResult.notSetUp =>
              'Hãy thiết lập khóa màn hình trong cài đặt thiết bị.',
            AlbumAuthResult.notSupported =>
              'Thiết bị chưa hỗ trợ xác thực. Chưa đổi khóa.',
            _ => 'Xác thực chưa thành công. Chưa lưu thay đổi. Hãy thử lại.',
          });
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
                          supported: _supported,
                          value: _draft.locked,
                          enabled: !_busy,
                          onChanged: (value) => setState(() {
                            _draft.locked = value;
                            _remember();
                          }),
                          help:
                              'Album được khóa bằng mã PIN (hoặc vân tay, khuôn mặt) của máy. '
                              'Bật hoặc tắt khóa cần xác nhận khi lưu.',
                          unsupportedTitle: 'Tính năng khóa chưa được hỗ trợ',
                          unsupportedHelp:
                              'Thiết bị này chưa xác thực được bằng vân '
                              'tay, khuôn mặt hoặc khóa màn hình, nên chưa đổi được '
                              'khóa.',
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
