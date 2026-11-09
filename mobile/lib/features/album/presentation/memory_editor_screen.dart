import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/widgets/app_delete_dialog.dart';
import '../../../core/widgets/app_ui.dart';
import '../../onboarding/presentation/frame_sequence.dart';
import '../album_scope.dart';
import '../data/album.dart';
import '../data/album_repository.dart';
import '../data/memory.dart';
import '../data/memory_photos.dart';
import 'album_backdrop.dart';
import 'album_form_parts.dart';
import 'album_start_screen.dart';
import 'photo_picker_flow.dart';

/// Where the photo of the memory being edited stands.
enum _PhotoState { none, loading, ready, failed }

/// A06: create or edit one memory, on a sheet of paper.
///
/// - Optional title; a full-width 4:3 photo slot that is itself the "add
///   photo" action (the system picker opens only when it is tapped); "Ghi
///   chú về kỷ niệm" typed right here; the memory's date (its own, apart from
///   when it was created or edited); an optional place (E05).
/// - Valid with a ready photo or a non-blank note; a title, date or place
///   alone is not a memory. While the photo loads, or after it failed
///   (Retry / Remove), saving waits; the note is never touched.
/// - The draft is kept 800 ms after the last change; it is not a memory.
///   Back keeps it; when it cannot be kept the user chooses: keep writing,
///   try again, or discard.
/// - "Lưu kỷ niệm" sits above the keyboard. One save at a time: repeated
///   taps make one memory. Creating makes exactly one, editing keeps the id;
///   a failed save keeps everything on screen.
/// - Nudaeng never over the photo or the text: ND09 writes a few strokes in
///   the header corner the first time the note is focused (1 s), then hides
///   while the keyboard is open. (ND08, the head turn below a new photo, was
///   dropped on 27/10/2026: it added nothing.)
/// - The photo's "…" opens the app's sheet: "Thay ảnh", "Xóa ảnh".
class MemoryEditorScreen extends StatefulWidget {
  const MemoryEditorScreen({
    super.key,
    required this.album,
    this.memoryId,
    this.intent = MemoryStartIntent.photo,
    required this.onSaved,
    required this.onPickPlace,
  });

  final Album album;

  /// The memory being edited; null for a new one.
  final String? memoryId;
  final MemoryStartIntent intent;

  /// After a successful save (A08 next).
  final ValueChanged<Memory> onSaved;

  /// E05 from the current place; the chosen place, or null when the user
  /// came back without one (the current one stays).
  final Future<MemoryPlace?> Function(MemoryPlace? current) onPickPlace;

  static const newTitle = 'Kỷ niệm mới';
  static const editTitle = 'Chỉnh sửa kỷ niệm';
  static const titleLabel = 'Tiêu đề (không bắt buộc)';
  static const addPhotoLabel = 'Thêm ảnh';
  static const replacePhotoLabel = 'Thay ảnh';
  static const removePhotoLabel = 'Xóa ảnh';
  static const photoLoading = 'Đang thêm ảnh…';
  static const photoFailed = 'Chưa thêm được ảnh. Ghi chú của bạn vẫn còn.';
  static const retryLabel = 'Thử lại';
  static const cameraDenied =
      'Chưa có quyền dùng máy ảnh. Bạn vẫn có thể chọn ảnh từ thư viện hoặc '
      'chỉ viết ghi chú. Muốn chụp ảnh, hãy bật quyền máy ảnh trong Cài đặt '
      'của máy.';
  static const libraryDenied =
      'Chưa mở được thư viện ảnh. Bạn vẫn có thể viết ghi chú. Hãy kiểm tra '
      'quyền ảnh trong Cài đặt của máy.';
  static const noteLabel = 'Ghi chú về kỷ niệm';
  static const dateLabel = 'Ngày';
  static const addPlaceLabel = 'Thêm địa điểm';
  static const saveLabel = 'Lưu kỷ niệm';
  static const needContent =
      'Thêm một ảnh hoặc viết vài dòng ghi chú để lưu kỷ niệm.';
  static const needNote =
      'Kỷ niệm trong album trên tài khoản cần vài dòng ghi chú. Bạn viết '
      'thêm rồi lưu nhé.';
  static const waitPhoto = 'Đợi ảnh thêm xong rồi lưu nhé.';
  static const fixPhoto = 'Hãy thử lại hoặc xóa ảnh lỗi trước khi lưu.';
  static const saveFailed =
      'Chưa lưu được kỷ niệm. Nội dung và ảnh vẫn còn đây, bạn thử lại nhé.';
  static const draftSaving = 'Đang lưu nháp…';
  static const draftSaved = 'Đã lưu nháp';
  static const draftFailed = 'Chưa lưu được nháp';
  static const autosaveDelay = Duration(milliseconds: 800);

  /// ND09: the supplied writing pose with ink strokes appearing.
  static final writeFrames = [
    for (var i = 1; i <= 6; i++)
      'assets/Deimage/album-write-frame-${i.toString().padLeft(2, '0')}.png',
  ];
  static const writeDurations = [
    Duration(milliseconds: 120),
    Duration(milliseconds: 170),
    Duration(milliseconds: 170),
    Duration(milliseconds: 170),
    Duration(milliseconds: 170),
    Duration(milliseconds: 200),
  ];

  /// Draft key for [album]'s new memory, or the memory being edited.
  static String draftKey(String albumId, String? memoryId) =>
      memoryId == null ? 'new-$albumId' : 'edit-$memoryId';

  @override
  State<MemoryEditorScreen> createState() => _MemoryEditorScreenState();
}

enum _Nudaeng { none, writing }

class _MemoryEditorScreenState extends State<MemoryEditorScreen> {
  final _title = TextEditingController();
  final _note = TextEditingController();
  final _noteFocus = FocusNode();
  late AlbumRepository _repository;

  var _loaded = false;
  Memory? _original;
  DateTime _date = DateTime.now();
  MemoryPlace? _place;
  String? _photoPath;
  var _photo = _PhotoState.none;
  String? _pendingSource;

  Timer? _autosave;
  String? _draftStatus;
  var _dirty = false;
  var _saving = false;
  String? _message;

  var _nudaeng = _Nudaeng.none;
  var _wroteOnce = false;

  /// A new photo each time: it fades in afresh.
  var _photoRun = 0;
  Timer? _nudaengTimer;

  /// Why the last photo source could not be used (access refused).
  String? _accessNote;

  String get _draftKey =>
      MemoryEditorScreen.draftKey(widget.album.id, widget.memoryId);

  MemoryContent get _content => MemoryContent(
        title: _title.text.trim().isEmpty ? null : _title.text.trim(),
        note: _note.text.trim().isEmpty ? null : _note.text,
        photoPath: _photo == _PhotoState.ready ? _photoPath : null,
        displayDate: _date,
        place: _place,
      );

  @override
  void initState() {
    super.initState();
    _title.addListener(_changed);
    _note.addListener(_changed);
    _noteFocus.addListener(_noteFocusChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _repository = AlbumScope.of(context);
    _load();
  }

  Future<void> _load() async {
    final memoryId = widget.memoryId;
    final original = memoryId == null
        ? null
        : await _repository.memory(widget.album.id, memoryId);
    MemoryDraft? draft;
    try {
      draft = await _repository.memoryDraft(_draftKey);
    } catch (_) {
      // A draft that cannot be read is like none; the saved memory stays.
    }
    if (!mounted) return;
    final content = draft?.content ?? original?.content;
    _original = original;
    if (content != null) {
      _title.text = content.title ?? '';
      _note.text = content.note ?? '';
      _date = content.displayDate;
      _place = content.place;
      _photoPath = content.photoPath;
      _photo = content.photoPath == null ? _PhotoState.none : _PhotoState.ready;
    }
    setState(() {
      _loaded = true;
      _dirty = false;
      if (draft != null) _draftStatus = MemoryEditorScreen.draftSaved;
    });
    if (widget.intent == MemoryStartIntent.note && memoryId == null) {
      _noteFocus.requestFocus();
    }
  }

  void _changed() {
    if (!_loaded) return;
    setState(() {
      _dirty = true;
      _message = null;
    });
    _autosave?.cancel();
    _autosave = Timer(MemoryEditorScreen.autosaveDelay, _keepDraft);
  }

  /// Keeps what is on screen as a draft. False when it could not be kept.
  Future<bool> _keepDraft() async {
    _autosave?.cancel();
    if (!_dirty) return true;
    if (mounted) setState(() => _draftStatus = MemoryEditorScreen.draftSaving);
    try {
      await _repository.saveMemoryDraft(
          _draftKey, MemoryDraft(content: _content, updatedAt: DateTime.now()));
      if (mounted) setState(() => _draftStatus = MemoryEditorScreen.draftSaved);
      return true;
    } catch (_) {
      if (mounted) {
        setState(() => _draftStatus = MemoryEditorScreen.draftFailed);
      }
      return false;
    }
  }

  void _noteFocusChanged() {
    if (!_noteFocus.hasFocus || _wroteOnce) return;
    _wroteOnce = true;
    if (_nudaeng != _Nudaeng.none || MediaQuery.disableAnimationsOf(context)) {
      return;
    }
    setState(() => _nudaeng = _Nudaeng.writing);
    _nudaengTimer?.cancel();
    _nudaengTimer = Timer(const Duration(milliseconds: 1000), () {
      if (mounted && _nudaeng == _Nudaeng.writing) {
        setState(() => _nudaeng = _Nudaeng.none);
      }
    });
  }

  /// A07: source, system picker or camera, preview, "Dùng ảnh". Closing
  /// anywhere keeps the photo already there.
  Future<void> _pickPhoto() async {
    if (_photo == _PhotoState.loading || _saving) return;
    final PhotoPick result;
    try {
      result = await PhotoPickerFlow.run(context,
          replacing: _photo == _PhotoState.ready);
    } catch (_) {
      if (mounted) setState(() => _photo = _PhotoState.failed);
      return;
    }
    if (!mounted) return;
    switch (result) {
      case PhotoPicked(:final path):
        setState(() => _accessNote = null);
        _pendingSource = path;
        await _keepPhoto();
      case PhotoPickDenied(:final source):
        // Said once, in words; no popup again. The note still works.
        setState(() => _accessNote = source == PhotoSource.camera
            ? MemoryEditorScreen.cameraDenied
            : MemoryEditorScreen.libraryDenied);
      case PhotoPickCanceled():
        break;
    }
  }

  Future<void> _keepPhoto() async {
    final source = _pendingSource;
    if (source == null) return;
    final photos = AlbumScope.photosOf(context);
    setState(() => _photo = _PhotoState.loading);
    try {
      final kept = await photos.keep(source);
      if (!mounted) return;
      _pendingSource = null;
      _photoPath = kept;
      setState(() {
        _photo = _PhotoState.ready;
        _photoRun++;
      });
      _changed();
    } catch (_) {
      if (mounted) setState(() => _photo = _PhotoState.failed);
    }
  }

  void _removePhoto() {
    _pendingSource = null;
    _photoPath = null;
    setState(() => _photo = _PhotoState.none);
    _changed();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(1900),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'Ngày của kỷ niệm',
      cancelText: 'Hủy',
      confirmText: 'Chọn',
    );
    if (picked == null || !mounted) return;
    setState(() => _date = picked);
    _changed();
  }

  Future<void> _pickPlace() async {
    final place = await widget.onPickPlace(_place);
    if (place == null || !mounted) return;
    setState(() => _place = place);
    _changed();
  }

  Future<void> _save() async {
    if (_saving) return;
    final message = switch (_photo) {
      _PhotoState.loading => MemoryEditorScreen.waitPhoto,
      _PhotoState.failed => MemoryEditorScreen.fixPhoto,
      _ when !_content.isValid => MemoryEditorScreen.needContent,
      // An account album (RemoteAlbumRepository, "cloud-" ids) keeps a
      // memory only with a note; say so instead of a save that always fails.
      _ when widget.album.id.startsWith('cloud-') &&
              (_content.note?.trim().isEmpty ?? true) =>
        MemoryEditorScreen.needNote,
      _ => null,
    };
    if (message != null) {
      setState(() => _message = message);
      return;
    }
    _autosave?.cancel();
    setState(() {
      _saving = true;
      _message = null;
    });
    try {
      final original = _original;
      final memory = original == null
          ? await _repository.createMemory(widget.album.id, _content)
          : await _repository.updateMemory(
              widget.album.id, original.id, _content);
      try {
        await _repository.deleteMemoryDraft(_draftKey);
      } catch (_) {
        // Saved; a leftover draft only reopens the same text.
      }
      _dirty = false;
      if (mounted) widget.onSaved(memory);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _message = MemoryEditorScreen.saveFailed;
        });
      }
    }
  }

  Future<void> _back() async {
    if (_saving) return;
    final navigator = Navigator.of(context);
    if (!_dirty || await _keepDraft()) {
      _dirty = false;
      navigator.pop();
      return;
    }
    if (!mounted) return;
    final choice = await showDialog<_LeaveChoice>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Chưa lưu được bản nháp'),
        content: const Text(
            'Nếu rời đi bây giờ, nội dung vừa viết có thể mất. Bạn muốn làm gì?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, _LeaveChoice.discard),
              child: const Text('Bỏ thay đổi')),
          TextButton(
              onPressed: () => Navigator.pop(context, _LeaveChoice.retry),
              child: const Text('Thử lưu')),
          FilledButton(
              onPressed: () => Navigator.pop(context, _LeaveChoice.stay),
              child: const Text('Tiếp tục viết')),
        ],
      ),
    );
    switch (choice) {
      case _LeaveChoice.discard:
        _dirty = false;
        try {
          await _repository.deleteMemoryDraft(_draftKey);
        } catch (_) {}
        navigator.pop();
      case _LeaveChoice.retry:
        await _back();
      case _LeaveChoice.stay || null:
        break;
    }
  }

  @override
  void dispose() {
    _autosave?.cancel();
    _nudaengTimer?.cancel();
    _title.dispose();
    _note.dispose();
    _noteFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.primaryLight,
          surfaceTintColor: Colors.transparent,
          leading: BackButton(onPressed: _back),
          title: Text(
              widget.memoryId == null
                  ? MemoryEditorScreen.newTitle
                  : MemoryEditorScreen.editTitle,
              style: AlbumFormText.title),
        ),
        body: Stack(fit: StackFit.expand, children: [
          // The scene only around the paper; dimmed while typing.
          AnimatedOpacity(
            opacity: keyboard ? .35 : 1,
            duration: const Duration(milliseconds: 200),
            child: const AlbumBackdrop(),
          ),
          Column(children: [
            Expanded(
              child: !_loaded
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(
                          AppSpacing.md, AppSpacing.md, AppSpacing.md, 80),
                      child: _paper(keyboard),
                    ),
            ),
            _SaveBar(
              saving: _saving,
              message: _message,
              draftStatus: _draftStatus,
              onSave: _loaded ? _save : null,
            ),
          ]),
        ]),
      ),
    );
  }

  // A Material, so the date and place rows show their ink.
  Widget _paper(bool keyboard) => Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: TextField(
                    controller: _title,
                    enabled: !_saving,
                    maxLength: 80,
                    textCapitalization: TextCapitalization.sentences,
                    style: _Text.input,
                    decoration: const InputDecoration(
                      labelText: MemoryEditorScreen.titleLabel,
                      counterText: '',
                    ),
                  ),
                ),
                // ND09's corner, outside the typing area.
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: _nudaeng == _Nudaeng.writing
                      ? Padding(
                          key: const ValueKey('write'),
                          padding: const EdgeInsets.only(left: AppSpacing.sm),
                          child: SizedBox(
                            width: 72,
                            height: 63,
                            child: ExcludeSemantics(
                              child: FrameSequence(
                                frames: MemoryEditorScreen.writeFrames,
                                durations: MemoryEditorScreen.writeDurations,
                              ),
                            ),
                          ),
                        )
                      : const SizedBox.shrink(key: ValueKey('none')),
                ),
              ]),
              const SizedBox(height: AppSpacing.md),
              _PhotoSlot(
                state: _photo,
                path: _photoPath,
                enabled: !_saving,
                photoRun: _photoRun,
                onAdd: _pickPhoto,
                onRetry: _pendingSource == null ? _pickPhoto : _keepPhoto,
                onRemove: _removePhoto,
              ),
              if (_accessNote case final note?) ...[
                const SizedBox(height: AppSpacing.sm),
                AlbumFormMessage(note),
              ],
              const SizedBox(height: AppSpacing.xl),
              const Text(MemoryEditorScreen.noteLabel,
                  style: AlbumFormText.section),
              const SizedBox(height: AppSpacing.sm),
              _RuledNote(
                  controller: _note, focus: _noteFocus, enabled: !_saving),
              const SizedBox(height: AppSpacing.md),
              _DateRow(date: _date, enabled: !_saving, onTap: _pickDate),
              const Divider(height: 1, color: AppColors.border),
              _PlaceRow(
                place: _place,
                enabled: !_saving,
                onAdd: _pickPlace,
                onRemove: () {
                  setState(() => _place = null);
                  _changed();
                },
              ),
            ],
          ),
        ),
      );
}

enum _LeaveChoice { stay, retry, discard }

/// Full-width 4:3: the add-photo action when empty; the photo with a menu
/// (Thay ảnh / Xóa ảnh) when ready; its own loading and failed states.
class _PhotoSlot extends StatelessWidget {
  const _PhotoSlot({
    required this.state,
    required this.path,
    required this.enabled,
    required this.photoRun,
    required this.onAdd,
    required this.onRetry,
    required this.onRemove,
  });

  final _PhotoState state;
  final String? path;
  final bool enabled;
  final int photoRun;
  final VoidCallback onAdd;
  final VoidCallback onRetry;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final path = this.path;
    final slot = AspectRatio(
      aspectRatio: 4 / 3,
      child: switch (state) {
        _PhotoState.ready when path != null => Semantics(
            image: true,
            label: 'Ảnh của kỷ niệm',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(fit: StackFit.expand, children: [
                // Placeholder to photo: a 180 ms fade in place, nothing moves.
                TweenAnimationBuilder<double>(
                  key: ValueKey(photoRun),
                  tween: Tween(begin: 0, end: 1),
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 180),
                  builder: (context, t, child) =>
                      Opacity(opacity: t, child: child),
                  child: Image.file(File(path),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const _SlotMessage(
                          icon: Icons.broken_image_outlined,
                          text: 'Không mở được ảnh này.')),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Material(
                    color: AppColors.surface.withValues(alpha: .92),
                    shape: const CircleBorder(),
                    child: IconButton(
                      tooltip: 'Tùy chọn ảnh',
                      onPressed: enabled ? () => _options(context) : null,
                      icon: const Icon(Icons.more_horiz_rounded,
                          color: AppColors.textPrimary),
                    ),
                  ),
                ),
              ]),
            ),
          ),
        _PhotoState.loading => const _SlotFrame(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              SizedBox.square(
                  dimension: 28,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.4, color: AppColors.primaryAction)),
              SizedBox(height: 12),
              Text(MemoryEditorScreen.photoLoading, style: AlbumFormText.body),
            ]),
          ),
        _PhotoState.failed => _SlotFrame(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.image_not_supported_outlined,
                  size: 32, color: AppColors.textPrimary),
              const SizedBox(height: 8),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(MemoryEditorScreen.photoFailed,
                    textAlign: TextAlign.center, style: AlbumFormText.body),
              ),
              const SizedBox(height: 8),
              Row(mainAxisSize: MainAxisSize.min, children: [
                TextButton(
                    onPressed: enabled ? onRetry : null,
                    child: const Text(MemoryEditorScreen.retryLabel)),
                TextButton(
                    onPressed: enabled ? onRemove : null,
                    child: const Text(MemoryEditorScreen.removePhotoLabel)),
              ]),
            ]),
          ),
        _ => Material(
            color: AppColors.background,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AppColors.primary, width: 1.5),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: enabled ? onAdd : null,
              child: Semantics(
                button: true,
                label: MemoryEditorScreen.addPhotoLabel,
                excludeSemantics: true,
                child: const Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.add_photo_alternate_outlined,
                        size: 40, color: AppColors.primaryAction),
                    SizedBox(height: 8),
                    Text(MemoryEditorScreen.addPhotoLabel,
                        style: AlbumFormText.section),
                  ]),
                ),
              ),
            ),
          ),
      },
    );
    return slot;
  }

  /// "Thay ảnh" / "Xóa ảnh" in the app's sheet, as Home's actions; removing
  /// in the delete colour. Nothing is lost until the memory is saved.
  Future<void> _options(BuildContext context) async {
    final choice = await showAppSheet<String>(
      context,
      builder: (sheet) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Ảnh của kỷ niệm', style: AppText.sectionTitle),
          const SizedBox(height: AppSpacing.md),
          AlbumSheetAction(
            icon: Icons.photo_library_outlined,
            label: MemoryEditorScreen.replacePhotoLabel,
            onTap: () => Navigator.pop(sheet, 'replace'),
          ),
          const SizedBox(height: AppSpacing.sm),
          AlbumSheetAction(
            icon: Icons.delete_outline_rounded,
            label: MemoryEditorScreen.removePhotoLabel,
            color: AppDeleteDialog.destructive,
            onTap: () => Navigator.pop(sheet, 'remove'),
          ),
        ],
      ),
    );
    switch (choice) {
      case 'replace':
        onAdd();
      case 'remove':
        onRemove();
    }
  }
}

class _SlotFrame extends StatelessWidget {
  const _SlotFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Center(child: child),
      );
}

class _SlotMessage extends StatelessWidget {
  const _SlotMessage({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => _SlotFrame(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 32, color: AppColors.textPrimary),
          const SizedBox(height: 8),
          Text(text, style: AlbumFormText.body),
        ]),
      );
}

/// The note, typed in place: body 16/24 over very faint ruled lines that
/// follow the text's own lines.
class _RuledNote extends StatelessWidget {
  const _RuledNote(
      {required this.controller, required this.focus, required this.enabled});

  final TextEditingController controller;
  final FocusNode focus;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final line = MediaQuery.textScalerOf(context).scale(16) * 1.5;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: CustomPaint(
        painter: _RulePainter(line: line),
        child: TextField(
          controller: controller,
          focusNode: focus,
          enabled: enabled,
          minLines: 5,
          maxLines: null,
          keyboardType: TextInputType.multiline,
          textCapitalization: TextCapitalization.sentences,
          style: _Text.note,
          decoration: const InputDecoration.collapsed(
            hintText: 'Hôm nay có điều gì bạn muốn giữ lại?',
          ).copyWith(
            hintStyle: _Text.note.copyWith(color: AppColors.textSecondary),
          ),
        ),
      ),
    );
  }
}

class _RulePainter extends CustomPainter {
  const _RulePainter({required this.line});

  final double line;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.border.withValues(alpha: .7)
      ..strokeWidth = 1;
    for (var y = line - 2; y < size.height; y += line) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_RulePainter old) => old.line != line;
}

class _DateRow extends StatelessWidget {
  const _DateRow(
      {required this.date, required this.enabled, required this.onTap});

  final DateTime date;
  final bool enabled;
  final VoidCallback onTap;

  static String format(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: EdgeInsets.zero,
        enabled: enabled,
        leading: const Icon(Icons.calendar_today_outlined,
            color: AppColors.textPrimary),
        title: const Text(MemoryEditorScreen.dateLabel,
            style: AlbumFormText.bodyStrong),
        trailing: Text(format(date), style: _Text.value),
        onTap: onTap,
      );
}

class _PlaceRow extends StatelessWidget {
  const _PlaceRow({
    required this.place,
    required this.enabled,
    required this.onAdd,
    required this.onRemove,
  });

  final MemoryPlace? place;
  final bool enabled;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final place = this.place;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      enabled: enabled,
      leading: const Icon(Icons.place_outlined, color: AppColors.textPrimary),
      title: Text(place?.label ?? MemoryEditorScreen.addPlaceLabel,
          style: AlbumFormText.bodyStrong),
      trailing: place == null
          ? const Icon(Icons.chevron_right_rounded,
              color: AppColors.textPrimary)
          : IconButton(
              tooltip: 'Xóa địa điểm',
              onPressed: enabled ? onRemove : null,
              icon: const Icon(Icons.close_rounded)),
      onTap: onAdd,
    );
  }
}

/// Sticky above the keyboard: what is wrong (next to the button), the draft
/// state, and "Lưu kỷ niệm".
class _SaveBar extends StatelessWidget {
  const _SaveBar({
    required this.saving,
    required this.message,
    required this.draftStatus,
    required this.onSave,
  });

  final bool saving;
  final String? message;
  final String? draftStatus;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    final message = this.message;
    final draft = draftStatus;
    return Container(
      padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.md +
              (MediaQuery.viewInsetsOf(context).bottom > 0
                  ? 0
                  : MediaQuery.paddingOf(context).bottom)),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (message != null) ...[
            AlbumFormMessage(message),
            const SizedBox(height: AppSpacing.sm),
          ],
          if (draft != null) ...[
            Semantics(
              liveRegion: true,
              child:
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(
                    draft == MemoryEditorScreen.draftFailed
                        ? Icons.info_outline_rounded
                        : Icons.edit_note_rounded,
                    size: 16,
                    color: AppColors.textPrimary),
                const SizedBox(width: 6),
                Text(draft, style: AlbumFormText.note),
              ]),
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
          AlbumPrimaryButton(
            label: MemoryEditorScreen.saveLabel,
            onPressed: onSave,
            busy: saving,
          ),
        ],
      ),
    );
  }
}

abstract final class _Text {
  static const input = TextStyle(
    fontFamily: 'BeVietnamPro',
    fontSize: 16,
    height: 1.5,
    color: AppColors.textPrimary,
  );
  static const note = TextStyle(
    fontFamily: 'BeVietnamPro',
    fontSize: 16,
    height: 1.5,
    color: AppColors.textPrimary,
  );
  static const value = TextStyle(
    fontFamily: 'BeVietnamPro',
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.5,
    color: AppColors.primaryAction,
  );
}
