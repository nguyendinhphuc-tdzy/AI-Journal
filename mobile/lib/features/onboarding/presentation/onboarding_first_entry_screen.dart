import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../journal/data/guided_template.dart';
import '../../journal/data/journal_entry.dart';
import '../../journal/data/journal_mood.dart';
import '../data/onboarding_store.dart';
import 'first_entry_session.dart';
import 'onboarding_widgets.dart';

/// OB07: the first guided journal entry. Sentences with blanks on a paper
/// card; each blank opens a sheet (mood: single choice; text: multiline).
/// One text blank is enough to save; a mood alone is not.
///
/// Saving writes the shared journal store; once saved, this step edits that
/// same entry ("Lưu thay đổi"), or moves on without saving when nothing
/// changed ("Tiếp tục"). AI is not called here: that waits for the next
/// step, and only when the user chose AI.
class OnboardingFirstEntryScreen extends StatefulWidget {
  const OnboardingFirstEntryScreen({
    super.key,
    required this.session,
    required this.onBack,
    required this.onDone,
    required this.onSkip,
  });

  final FirstEntrySession session;
  final VoidCallback onBack;

  /// After a successful save, or "Tiếp tục" on an unchanged saved entry.
  final ValueChanged<JournalEntry> onDone;

  /// "Để mình viết sau", once any draft is safe (or was let go).
  final VoidCallback onSkip;

  static const title = 'Bắt đầu từ điều bạn đang cảm thấy.';
  static const body =
      'Không cần viết thật hay. Chỉ cần một điều bạn muốn ghi lại.';
  static const helper =
      'Bạn chỉ cần viết ở một ô. Những phần còn lại là tùy chọn.';
  static const saveLabel = 'Lưu nhật ký đầu tiên';
  static const saveChangesLabel = 'Lưu thay đổi';
  static const continueLabel = 'Tiếp tục';

  /// While the save commits; nothing says "saved" yet.
  static const savingLabel = 'Đang lưu nhật ký của bạn…';
  static const retryLabel = 'Thử lại';
  static const skipLabel = 'Để mình viết sau';
  static const draftSaved = 'Bản nháp đã được giữ';
  static const draftFailed = 'Chưa giữ được bản nháp';
  static const saveFailed =
      'Chưa lưu được nhật ký. Nội dung của bạn vẫn còn ở đây.';

  static const mascotAsset = 'assets/Deimage/Nudaeng writing-transparent.png';

  @override
  State<OnboardingFirstEntryScreen> createState() =>
      _OnboardingFirstEntryScreenState();
}

class _OnboardingFirstEntryScreenState
    extends State<OnboardingFirstEntryScreen> {
  FirstEntrySession get _session => widget.session;

  @override
  void initState() {
    super.initState();
    _session.load();
  }

  Future<void> _primary() async {
    final session = _session;
    if (!session.changed && session.saved != null) {
      widget.onDone(session.saved!);
      return;
    }
    final entry = await session.commit();
    if (entry != null && mounted) widget.onDone(entry);
  }

  Future<void> _skip() async {
    final session = _session;
    if (!session.hasContent || !session.changed) {
      widget.onSkip();
      return;
    }
    if (await session.flushDraft()) {
      if (mounted) widget.onSkip();
      return;
    }
    if (!mounted) return;
    // The draft could not be kept: let the user decide, never lose it
    // silently.
    final choice = await showDialog<_KeepDraft>(
      context: context,
      builder: (context) => const _KeepDraftDialog(),
    );
    switch (choice) {
      case _KeepDraft.retry:
        if (await session.flushDraft() && mounted) widget.onSkip();
      case _KeepDraft.discard:
        await session.discardDraft();
        if (mounted) widget.onSkip();
      case _KeepDraft.keepWriting || null:
        break;
    }
  }

  Future<void> _editSlot(GuidedSlot slot) async {
    final session = _session;
    if (slot.isMood) {
      final picked = await showModalBottomSheet<_MoodPick>(
        context: context,
        isScrollControlled: true,
        barrierColor: Colors.black.withValues(alpha: .35),
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(AppRadius.modal))),
        builder: (_) => _MoodSheet(selected: session.mood),
      );
      if (picked != null) session.setMood(picked.mood);
      return;
    }
    final text = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      barrierColor: Colors.black.withValues(alpha: .35),
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(AppRadius.modal))),
      builder: (_) => _TextSheet(
        slot: slot,
        initial: session.sheetDrafts[slot.id] ?? session.field(slot.id) ?? '',
        onDraft: (value) => session.sheetDrafts[slot.id] = value,
      ),
    );
    // Close keeps the old value; the unconfirmed text stays for next time.
    if (text != null) session.setField(slot.id, text);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: _session,
        builder: (context, _) {
          final session = _session;
          final saving = session.save == SaveStatus.saving;
          final label = switch (session) {
            _ when saving => OnboardingFirstEntryScreen.savingLabel,
            _ when session.save == SaveStatus.failed =>
              OnboardingFirstEntryScreen.retryLabel,
            _ when session.saved != null && !session.changed =>
              OnboardingFirstEntryScreen.continueLabel,
            _ when session.saved != null =>
              OnboardingFirstEntryScreen.saveChangesLabel,
            _ => OnboardingFirstEntryScreen.saveLabel,
          };
          return OnboardingStepScaffold(
            step: OnboardingStep.firstEntry,
            onBack: widget.onBack,
            content: _content(session),
            stage: const StaggerItem(order: 6, child: _Stage()),
            actions: [
              StaggerItem(
                order: 7,
                child: OnboardingCta(
                  label: label,
                  onPressed: saving || !session.canSave ? null : _primary,
                ),
              ),
              StaggerItem(
                order: 7,
                child: OnboardingTextAction(
                  label: OnboardingFirstEntryScreen.skipLabel,
                  onPressed: saving ? () {} : _skip,
                ),
              ),
            ],
          );
        },
      );

  Widget _content(FirstEntrySession session) {
    final error = Theme.of(context).colorScheme.error;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StaggerItem(
            order: 1,
            child: Semantics(
              header: true,
              child: const Text(OnboardingFirstEntryScreen.title,
                  style: _Text.title),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          const StaggerItem(
            order: 2,
            child: Text(OnboardingFirstEntryScreen.body, style: _Text.body),
          ),
          const SizedBox(height: AppSpacing.md),
          StaggerItem(
            order: 3,
            child: _Paper(
              template: session.template,
              mood: session.mood,
              fields: session.fields,
              enabled: session.loaded,
              onEdit: _editSlot,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          const StaggerItem(
            order: 4,
            child: Text(OnboardingFirstEntryScreen.helper, style: _Text.helper),
          ),
          if (session.save == SaveStatus.failed)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Semantics(
                liveRegion: true,
                child: Text(OnboardingFirstEntryScreen.saveFailed,
                    style: _Text.helper.copyWith(color: error)),
              ),
            ),
          StaggerItem(order: 5, child: _DraftStatus(session.draft)),
        ],
      ),
    );
  }
}

/// "Bản nháp" status: never shown as a saved entry.
class _DraftStatus extends StatelessWidget {
  const _DraftStatus(this.status);

  final DraftStatus status;

  @override
  Widget build(BuildContext context) {
    final (icon, text, color) = switch (status) {
      DraftStatus.saved => (
          Icons.edit_note_rounded,
          OnboardingFirstEntryScreen.draftSaved,
          AppColors.textSecondary
        ),
      DraftStatus.failed => (
          Icons.error_outline_rounded,
          OnboardingFirstEntryScreen.draftFailed,
          Theme.of(context).colorScheme.error
        ),
      DraftStatus.none || DraftStatus.saving => (null, null, null),
    };
    if (text == null) return const SizedBox(height: 20);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Row(children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 6),
        Expanded(child: Text(text, style: _Text.helper.copyWith(color: color))),
      ]),
    );
  }
}

/// The paper: one block per sentence, so long blanks never squeeze into a
/// single line. With large text the blanks become labelled field blocks in
/// the same order.
class _Paper extends StatelessWidget {
  const _Paper({
    required this.template,
    required this.mood,
    required this.fields,
    required this.enabled,
    required this.onEdit,
  });

  final GuidedTemplate template;
  final JournalMood? mood;
  final Map<String, String> fields;
  final bool enabled;
  final ValueChanged<GuidedSlot> onEdit;

  @override
  Widget build(BuildContext context) {
    final blocks =
        MediaQuery.textScalerOf(context).scale(16) >= 22; // ≈ 1.4× text
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, slot) in template.slots.indexed) ...[
            if (i > 0) const SizedBox(height: AppSpacing.md),
            _Sentence(
              slot: slot,
              value: slot.isMood ? mood?.label : fields[slot.id],
              asBlock: blocks,
              onTap: enabled ? () => onEdit(slot) : null,
            ),
          ],
        ],
      ),
    );
  }
}

class _Sentence extends StatelessWidget {
  const _Sentence({
    required this.slot,
    required this.value,
    required this.asBlock,
    required this.onTap,
  });

  final GuidedSlot slot;
  final String? value;
  final bool asBlock;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final blank = _Blank(
      text: value ?? slot.placeholder,
      filled: value != null,
      onTap: onTap,
      semanticLabel: '${slot.prefix} ${value ?? slot.placeholder}',
      fullWidth: asBlock,
    );
    if (asBlock) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ExcludeSemantics(child: Text('${slot.prefix}…', style: _Text.prose)),
          const SizedBox(height: AppSpacing.xs),
          blank,
        ],
      );
    }
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 6,
      runSpacing: AppSpacing.xs,
      children: [
        ExcludeSemantics(child: Text(slot.prefix, style: _Text.prose)),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(child: blank),
            ExcludeSemantics(child: Text(slot.suffix, style: _Text.prose)),
          ],
        ),
      ],
    );
  }
}

/// A blank: at least 48 high, wraps long text, never wider than the paper.
class _Blank extends StatelessWidget {
  const _Blank({
    required this.text,
    required this.filled,
    required this.onTap,
    required this.semanticLabel,
    required this.fullWidth,
  });

  final String text;
  final bool filled;
  final VoidCallback? onTap;
  final String semanticLabel;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.small),
      side: BorderSide(
        color: filled ? AppColors.border : AppColors.primaryAction,
        width: filled ? 1 : 1.5,
      ),
    );
    return Semantics(
      button: true,
      label: semanticLabel,
      hint: filled ? 'Chạm để sửa' : 'Chạm để điền',
      excludeSemantics: true,
      child: Material(
        color: filled ? AppColors.background : AppColors.primaryLight,
        shape: shape,
        child: InkWell(
          onTap: onTap,
          customBorder: shape,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: 48,
              minWidth: fullWidth ? double.infinity : 0,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Text(
                text,
                style: filled
                    ? _Text.prose.copyWith(fontWeight: FontWeight.w600)
                    : _Text.prose.copyWith(color: AppColors.primaryAction),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Picked in the mood sheet; [mood] null means "left empty".
class _MoodPick {
  const _MoodPick(this.mood);

  final JournalMood? mood;
}

class _MoodSheet extends StatelessWidget {
  const _MoodSheet({required this.selected});

  final JournalMood? selected;

  static const title = 'Bạn đang cảm thấy thế nào?';
  static const helper = 'Chọn một cảm xúc gần nhất. Bạn có thể để trống.';

  @override
  Widget build(BuildContext context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _SheetHeader(title: title),
              const SizedBox(height: AppSpacing.xs),
              const Text(helper, style: _Text.helper),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final mood in JournalMood.values)
                    _MoodChip(
                      mood: mood,
                      selected: mood == selected,
                      onTap: () => Navigator.pop(context, _MoodPick(mood)),
                    ),
                ],
              ),
              if (selected != null) ...[
                const SizedBox(height: AppSpacing.md),
                OnboardingTextAction(
                  label: 'Để trống',
                  onPressed: () =>
                      Navigator.pop(context, const _MoodPick(null)),
                ),
              ],
            ],
          ),
        ),
      );
}

class _MoodChip extends StatelessWidget {
  const _MoodChip(
      {required this.mood, required this.selected, required this.onTap});

  final JournalMood mood;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final shape = StadiumBorder(
      side: BorderSide(
        color: selected ? AppColors.primaryAction : AppColors.border,
        width: selected ? 2 : 1,
      ),
    );
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      label: mood.label,
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: selected ? AppColors.primaryLight : AppColors.surface,
        shape: shape,
        child: InkWell(
          onTap: onTap,
          customBorder: shape,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (selected) ...[
                    const Icon(Icons.check_rounded,
                        size: 18, color: AppColors.primaryAction),
                    const SizedBox(width: 6),
                  ],
                  Text(mood.label,
                      style: _Text.prose.copyWith(
                          fontWeight:
                              selected ? FontWeight.w600 : FontWeight.w400)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Multiline sheet for one blank. "Dùng nội dung này" returns the text;
/// Close returns nothing (old value kept). Typing is reported through
/// [onDraft] so reopening shows it again.
class _TextSheet extends StatefulWidget {
  const _TextSheet(
      {required this.slot, required this.initial, required this.onDraft});

  final GuidedSlot slot;
  final String initial;
  final ValueChanged<String> onDraft;

  static const confirmLabel = 'Dùng nội dung này';

  @override
  State<_TextSheet> createState() => _TextSheetState();
}

class _TextSheetState extends State<_TextSheet> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initial)..addListener(_changed);

  // The pen (or eraser) while typing comes from AppSound, as in every
  // text field.
  void _changed() => widget.onDraft(_controller.text);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SheetHeader(
                    title: widget.slot.sheetTitle ?? widget.slot.placeholder),
                const SizedBox(height: AppSpacing.md),
                ExcludeSemantics(
                  child: Text('${widget.slot.prefix}…', style: _Text.label),
                ),
                const SizedBox(height: AppSpacing.sm),
                Semantics(
                  label: widget.slot.prefix,
                  child: TextField(
                    controller: _controller,
                    autofocus: true,
                    minLines: 4,
                    maxLines: 8,
                    keyboardType: TextInputType.multiline,
                    textCapitalization: TextCapitalization.sentences,
                    style: _Text.prose,
                    cursorColor: AppColors.primaryAction,
                    decoration: InputDecoration(
                      hintText: widget.slot.placeholder,
                      hintStyle:
                          _Text.prose.copyWith(color: AppColors.textSecondary),
                      filled: true,
                      fillColor: AppColors.background,
                      contentPadding: const EdgeInsets.all(AppSpacing.md),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.input),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.input),
                        borderSide: const BorderSide(
                            color: AppColors.primaryAction, width: 2),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                OnboardingCta(
                  label: _TextSheet.confirmLabel,
                  onPressed: () => Navigator.pop(context, _controller.text),
                ),
              ],
            ),
          ),
        ),
      );
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(title, style: _Text.sheetTitle),
            ),
          ),
          IconButton(
            tooltip: 'Đóng',
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded),
            color: AppColors.textPrimary,
            constraints: const BoxConstraints.tightFor(width: 48, height: 48),
          ),
        ],
      );
}

enum _KeepDraft { keepWriting, retry, discard }

class _KeepDraftDialog extends StatelessWidget {
  const _KeepDraftDialog();

  @override
  Widget build(BuildContext context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Chưa giữ được bản nháp', style: _Text.sheetTitle),
        content: const Text(
            'Nếu đi tiếp bây giờ, phần bạn vừa viết có thể mất.',
            style: _Text.body),
        actionsOverflowDirection: VerticalDirection.down,
        actionsOverflowButtonSpacing: AppSpacing.xs,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, _KeepDraft.keepWriting),
            child: const Text('Tiếp tục viết'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, _KeepDraft.retry),
            child: const Text('Thử giữ bản nháp'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, _KeepDraft.discard),
            child: const Text('Bỏ bản nháp'),
          ),
        ],
      );
}

abstract final class _Text {
  static const title = TextStyle(
    fontFamily: 'Nunito',
    fontSize: 28,
    fontWeight: FontWeight.w700,
    height: 1.25,
    color: AppColors.textPrimary,
  );
  static const body = TextStyle(
    fontFamily: 'BeVietnamPro',
    fontSize: 16,
    height: 1.5,
    color: AppColors.textSecondary,
  );
  static const prose = TextStyle(
    fontFamily: 'BeVietnamPro',
    fontSize: 16,
    height: 1.5,
    color: AppColors.textPrimary,
  );
  static const label = TextStyle(
    fontFamily: 'BeVietnamPro',
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 20 / 14,
    color: AppColors.textPrimary,
  );
  static const helper = TextStyle(
    fontFamily: 'BeVietnamPro',
    fontSize: 14,
    height: 20 / 14,
    color: AppColors.textSecondary,
  );
  static const sheetTitle = TextStyle(
    fontFamily: 'BeVietnamPro',
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.4,
    color: AppColors.textPrimary,
  );
}

/// The desk once more, Nudaeng now writing ([deskScene], as OB05–OB06).
class _Stage extends StatelessWidget {
  const _Stage();

  @override
  Widget build(BuildContext context) {
    final width =
        deskScene.canvas.width * deskSceneHeight / deskScene.figureHeight;
    final decodeWidth =
        (width * MediaQuery.devicePixelRatioOf(context) / 64).ceil() * 64;
    return OnboardingMascot(
      frame: deskScene,
      height: deskSceneHeight,
      child: Image.asset(
        OnboardingFirstEntryScreen.mascotAsset,
        cacheWidth: decodeWidth,
        semanticLabel: 'Nudaeng ngồi bàn viết nhật ký',
      ),
    );
  }
}
