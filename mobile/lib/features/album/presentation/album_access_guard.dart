import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../album_scope.dart';
import '../data/album.dart';
import '../data/album_repository.dart';
import '../data/album_unlocks.dart';
import 'album_unlock_screen.dart';

/// Keeps the pending destination and its draft mounted, but neither paints nor
/// exposes its semantics while the session is invalid or the app is obscured.
/// All album destination routes go through this guard, including direct opens.
class AlbumAccessGuard extends StatefulWidget {
  const AlbumAccessGuard(
      {super.key, required this.albumId, required this.builder});
  final String albumId;
  final Widget Function(Album album) builder;

  /// Albums just deleted whose screens are leaving: they keep showing what
  /// they had until their routes are gone (A11).
  static final departing = <String>{};

  @override
  State<AlbumAccessGuard> createState() => _AlbumAccessGuardState();
}

class _AlbumAccessGuardState extends State<AlbumAccessGuard> {
  final _session = AlbumUnlocks.instance;
  AlbumRepository? _repository;
  Album? _album;
  Widget? _content;
  bool _loading = true;
  bool _failed = false;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    _session.addListener(_refreshSession);
  }

  void _refreshSession() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final repository = AlbumScope.of(context);
    if (repository == _repository) return;
    _repository?.removeListener(_load);
    _repository = repository..addListener(_load);
    _load();
  }

  Future<void> _load() async {
    final request = ++_request;
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final album = await _repository!.album(widget.albumId);
      if (album == null &&
          _album != null &&
          AlbumAccessGuard.departing.contains(widget.albumId)) {
        if (mounted && request == _request) setState(() => _loading = false);
        return;
      }
      if (mounted && request == _request) {
        setState(() {
          _album = album;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted && request == _request) {
        setState(() {
          _failed = true;
          _loading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _repository?.removeListener(_load);
    _session.removeListener(_refreshSession);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allowed = !_loading &&
        !_failed &&
        _album != null &&
        _session.foreground &&
        (!_album!.locked || _session.isUnlocked(widget.albumId));
    if (allowed) _content ??= widget.builder(_album!);
    return Stack(fit: StackFit.expand, children: [
      if (_content != null)
        Offstage(
            offstage: !allowed,
            child: TickerMode(enabled: allowed, child: _content!)),
      if (!allowed)
        if (!_loading &&
            !_failed &&
            _album != null &&
            !_album!.locked &&
            !_session.foreground)
          Scaffold(
              backgroundColor: AppColors.background,
              appBar: AppBar(title: const Text('Album')),
              body: const Center(child: Text('Quay lại ứng dụng để tiếp tục.')))
        else if (!_loading && !_failed && _album != null)
          AlbumUnlockScreen(
              albumId: widget.albumId, onUnlocked: _refreshSession)
        else
          Scaffold(
              backgroundColor: AppColors.background,
              appBar: AppBar(title: const Text('Album')),
              body: Center(
                  child: _loading
                      ? const CircularProgressIndicator()
                      : Column(mainAxisSize: MainAxisSize.min, children: [
                          Text(_failed
                              ? 'Chưa tải được album.'
                              : 'Album không còn tồn tại.'),
                          if (_failed)
                            TextButton(
                                onPressed: _load, child: const Text('Thử lại')),
                        ]))),
    ]);
  }
}
