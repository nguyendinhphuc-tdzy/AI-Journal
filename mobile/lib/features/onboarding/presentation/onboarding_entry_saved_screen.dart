import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../journal/data/journal_entry.dart';
import '../../journal/data/reflection_service.dart';
import '../../journal/presentation/sentence_case.dart';
import '../data/onboarding_store.dart';
import 'first_entry_session.dart';
import 'first_reflection.dart';
import 'onboarding_widgets.dart';

/// OB09: the saved first entry and, when AI is on, its reflection. One
/// layout for every variant, so the CTA stays put:
/// - AI ready: reflection card ("Gợi ý từ AI");
/// - AI off: the entry only, no AI card and no nudge to turn it on;
/// - AI pending or failed: "Phản hồi AI chưa sẵn sàng." with "Xem sau" or
///   "Thử lại".
/// The real entry is always shown; "Tiếp tục" always works. No confetti or
/// celebration: the entry may be about something hard.
class OnboardingEntrySavedScreen extends StatefulWidget {
  const OnboardingEntrySavedScreen({
    super.key,
    required this.session,
    required this.reflection,
    required this.aiEnabled,
    required this.onBack,
    required this.onContinue,
  });

  final FirstEntrySession session;
  final FirstReflection reflection;
  final bool aiEnabled;
  final VoidCallback onBack;
  final VoidCallback onContinue;

  static const savedLabel = 'Nhật ký đã lưu';
  static const aiTitle = 'Một góc nhìn từ điều bạn vừa viết.';
  static const plainTitle = 'Bạn đã ghi lại những dòng đầu tiên.';
  static const aiLabel = 'Góc nhìn từ AI';
  static const simulatedLabel = 'mô phỏng';
  static const notReady = 'Phản hồi AI chưa sẵn sàng.';
  static const retryLabel = 'Thử lại';
  static const laterLabel = 'Xem sau';
  static const laterNote = 'Bạn có thể quay lại đây để xem khi phản hồi xong.';
  static const entryLabel = 'Nhật ký của bạn';
  static const moodPrefix = 'Bạn chọn';
  static const continueLabel = 'Tiếp tục';

  static const mascotAsset = 'assets/Deimage/Nudaeng writing-transparent.png';

  @override
  State<OnboardingEntrySavedScreen> createState() =>
      _OnboardingEntrySavedScreenState();
}

class _OnboardingEntrySavedScreenState
    extends State<OnboardingEntrySavedScreen> {
  /// "Xem sau": stop showing the wait; a late result still appears.
  var _waitDismissed = false;

  @override
  void initState() {
    super.initState();
    widget.session.load();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Listenable.merge([widget.session, widget.reflection]),
        builder: (context, _) {
          final entry = widget.session.saved;
          return OnboardingStepScaffold(
            step: OnboardingStep.entrySaved,
            onBack: widget.onBack,
            content:
                entry == null ? const SizedBox(height: 240) : _content(entry),
            stage: const StaggerItem(order: 6, child: _Stage()),
            actions: [
              StaggerItem(
                order: 7,
                child: OnboardingCta(
                  label: OnboardingEntrySavedScreen.continueLabel,
                  onPressed: widget.onContinue,
                ),
              ),
            ],
          );
        },
      );

  Widget _content(JournalEntry entry) {
    final mood = entry.content.mood;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const StaggerItem(order: 1, child: _SavedLabel()),
          const SizedBox(height: 12),
          StaggerItem(
            order: 1,
            child: Semantics(
              header: true,
              child: Text(
                widget.aiEnabled
                    ? OnboardingEntrySavedScreen.aiTitle
                    : OnboardingEntrySavedScreen.plainTitle,
                style: _Text.title,
              ),
            ),
          ),
          if (mood != null) ...[
            const SizedBox(height: 12),
            StaggerItem(
              order: 2,
              child: _Chip(
                  '${OnboardingEntrySavedScreen.moodPrefix}: ${mood.label}'),
            ),
          ],
          if (widget.aiEnabled) ...[
            const SizedBox(height: AppSpacing.md),
            StaggerItem(order: 3, child: _reflection(entry)),
          ],
          const SizedBox(height: AppSpacing.md),
          StaggerItem(order: 4, child: _EntryPreview(entry)),
        ],
      ),
    );
  }

  Widget _reflection(JournalEntry entry) {
    final result = widget.reflection.resultFor(entry);
    if (result != null) return _ReflectionCard(result);
    final pending = widget.reflection.status == ReflectionStatus.pending;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            if (pending && !_waitDismissed) ...[
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.primaryAction),
              ),
              const SizedBox(width: 12),
            ],
            const Expanded(
              child:
                  Text(OnboardingEntrySavedScreen.notReady, style: _Text.body),
            ),
          ]),
          if (pending && _waitDismissed)
            const Padding(
              padding: EdgeInsets.only(top: AppSpacing.xs),
              child:
                  Text(OnboardingEntrySavedScreen.laterNote, style: _Text.meta),
            )
          else
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primaryAction,
                  minimumSize: const Size(48, 48),
                  textStyle: _Text.action,
                ),
                // Retry asks again for this same entry; nothing new is saved.
                onPressed: pending
                    ? () => setState(() => _waitDismissed = true)
                    : () => widget.reflection.request(entry),
                child: Text(pending
                    ? OnboardingEntrySavedScreen.laterLabel
                    : OnboardingEntrySavedScreen.retryLabel),
              ),
            ),
        ],
      ),
    );
  }
}

class _SavedLabel extends StatelessWidget {
  const _SavedLabel();

  @override
  Widget build(BuildContext context) => const Align(
        alignment: Alignment.centerLeft,
        child: _Chip(OnboardingEntrySavedScreen.savedLabel,
            icon: Icons.check_circle_outline_rounded),
      );
}

class _Chip extends StatelessWidget {
  const _Chip(this.text, {this.icon});

  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(AppRadius.small),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (icon != null) ...[
              ExcludeSemantics(
                child: Icon(icon, size: 18, color: AppColors.primaryAction),
              ),
              const SizedBox(width: 6),
            ],
            Flexible(child: Text(text, style: _Text.chip)),
          ]),
        ),
      );
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: AppColors.border),
        ),
        child: child,
      );
}

/// Static text, labelled as AI (and as simulated when it is the stand-in).
class _ReflectionCard extends StatelessWidget {
  const _ReflectionCard(this.reflection);

  final Reflection reflection;

  @override
  Widget build(BuildContext context) => _Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              reflection.simulated
                  ? '${OnboardingEntrySavedScreen.aiLabel} · '
                      '${OnboardingEntrySavedScreen.simulatedLabel}'
                  : OnboardingEntrySavedScreen.aiLabel,
              style: _Text.label,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(sentenceCase(reflection.text), style: _Text.reading),
          ],
        ),
      );
}

/// The entry as saved, so it is clear the original text is kept. Long text
/// folds to six lines, with "Xem toàn bộ".
class _EntryPreview extends StatefulWidget {
  const _EntryPreview(this.entry);

  final JournalEntry entry;

  @override
  State<_EntryPreview> createState() => _EntryPreviewState();
}

class _EntryPreviewState extends State<_EntryPreview> {
  var _expanded = false;

  /// Long enough to fold: more than six lines or ~240 characters. (No
  /// measuring: the step's scroll view needs intrinsic sizes.)
  bool get _long =>
      '\n'.allMatches(widget.entry.body).length >= 6 ||
      widget.entry.body.length > 240;

  @override
  Widget build(BuildContext context) {
    final fold = _long && !_expanded;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(OnboardingEntrySavedScreen.entryLabel, style: _Text.label),
          const SizedBox(height: AppSpacing.xs),
          Text(
            widget.entry.body,
            style: _Text.reading,
            maxLines: fold ? 6 : null,
            overflow: fold ? TextOverflow.ellipsis : null,
          ),
          if (_long)
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primaryAction,
                minimumSize: const Size(48, 48),
                padding: EdgeInsets.zero,
                textStyle: _Text.action,
              ),
              onPressed: () => setState(() => _expanded = !_expanded),
              child: Text(_expanded ? 'Thu gọn' : 'Xem toàn bộ'),
            ),
        ],
      ),
    );
  }
}

abstract final class _Text {
  static const title = TextStyle(
    fontFamily: 'Nunito',
    fontSize: 28,
    fontWeight: FontWeight.w700,
    height: 1.25,
    color: AppColors.textPrimary,
  );
  static const chip = TextStyle(
    fontFamily: 'BeVietnamPro',
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 20 / 14,
    color: AppColors.textPrimary,
  );
  static const label = TextStyle(
    fontFamily: 'BeVietnamPro',
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 20 / 14,
    color: AppColors.primaryAction,
  );
  static const reading = TextStyle(
    fontFamily: 'BeVietnamPro',
    fontSize: 16,
    height: 1.5,
    color: AppColors.textPrimary,
  );
  static const body = TextStyle(
    fontFamily: 'BeVietnamPro',
    fontSize: 16,
    height: 1.5,
    color: AppColors.textPrimary,
  );
  static const meta = TextStyle(
    fontFamily: 'BeVietnamPro',
    fontSize: 14,
    height: 20 / 14,
    color: AppColors.textSecondary,
  );
  static const action = TextStyle(
    fontFamily: 'BeVietnamPro',
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.5,
  );
}

/// The desk again, Nudaeng writing ([deskScene], as OB05–OB07).
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
        OnboardingEntrySavedScreen.mascotAsset,
        cacheWidth: decodeWidth,
        semanticLabel: 'Nudaeng ngồi bàn viết nhật ký',
      ),
    );
  }
}
