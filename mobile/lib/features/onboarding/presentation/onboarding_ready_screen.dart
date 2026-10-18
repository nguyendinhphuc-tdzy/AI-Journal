import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../reminders/data/reminder_service.dart';
import '../data/onboarding_store.dart';
import 'first_entry_session.dart';
import 'onboarding_widgets.dart';

/// OB11: a gentle invitation into the app, in place of the sample app's
/// 7-day pledge and signature. No promise to write, no checkbox, no "SIGNED";
/// the nickname is only how Nudaeng addresses the user. Nothing enrolls in
/// a Study challenge.
///
/// The summary tells what is actually true: the first entry saved, a draft
/// kept, or nothing written; the reminders the OS accepted at OB10, or that
/// they can be set later.
///
/// "Vào không gian của mình" asks [onEnter] to save onboarding as done and
/// open Home. When that fails the screen stays, with a message and "Thử lại";
/// nothing is dropped, and the next launch resumes here.
class OnboardingReadyScreen extends StatefulWidget {
  const OnboardingReadyScreen({
    super.key,
    required this.nickname,
    required this.session,
    required this.reminders,
    required this.remindersSimulated,
    required this.onBack,
    required this.onEnter,
  });

  /// Saved OB02 nickname; null when left empty.
  final String? nickname;

  /// OB07 state: the saved entry and the draft.
  final FirstEntrySession session;

  /// Reminders actually scheduled at OB10 (maybe none).
  final Map<ReminderSlot, ReminderTime> reminders;

  /// The reminders come from the stand-in service, not real notifications.
  final bool remindersSimulated;

  final VoidCallback onBack;

  /// Saves onboarding as done and leaves for Home; false when it could not
  /// be saved.
  final Future<bool> Function() onEnter;

  static const title = 'Một khoảng nhỏ dành cho bạn.';
  static const invitation =
      'Bạn có thể quay lại khi muốn ghi vài dòng, lưu một kỷ niệm hoặc nhìn '
      'lại ngày của mình. Nudaeng sẽ ở đây cùng bạn.';
  static const entrySaved = 'Nhật ký đầu tiên đã được lưu.';
  static const draftKept = 'Bạn có một bản nháp để tiếp tục khi sẵn sàng.';
  static const noEntry = 'Bạn có thể bắt đầu nhật ký đầu tiên ở Home.';
  static const remindersLater = 'Bạn có thể đặt lời nhắc sau.';
  static const simulatedNote = 'Bản thử nghiệm: chưa có thông báo thật.';
  static const enterLabel = 'Vào không gian của mình';
  static const retryLabel = 'Thử lại';
  static const enterFailed =
      'Chưa lưu được để vào app. Mọi thứ bạn đã chọn vẫn được giữ, bạn thử '
      'lại nhé.';

  /// "Vy ơi," above the title; nothing without a nickname.
  static String greeting(String nickname) => '$nickname ơi,';

  /// "Lời nhắc buổi sáng lúc 08:00 và buổi tối lúc 21:00 đã được bật."
  static String remindersOn(Map<ReminderSlot, ReminderTime> reminders) =>
      'Lời nhắc ${[
        for (final slot in ReminderSlot.values)
          if (reminders[slot] case final time?)
            '${slot.label} lúc ${time.label}'
      ].join(' và ')} đã được bật.';

  static const mascotAsset = 'assets/Deimage/ob11-nudaeng-yarn.png';

  /// Nudaeng knitting a jumper, cut from "Nudaeng OB11.jpg"
  /// (`tool/build_ob11_layer.py`). The yarn runs off to the right.
  static const mascotFrame = MascotFrame(
    canvas: Size(355, 221),
    headTop: 2,
    feet: Offset(118, 216),
  );

  @override
  State<OnboardingReadyScreen> createState() => _OnboardingReadyScreenState();
}

class _OnboardingReadyScreenState extends State<OnboardingReadyScreen> {
  var _busy = false;
  var _failed = false;

  @override
  void initState() {
    super.initState();
    widget.session.load();
  }

  Future<void> _enter() async {
    if (_busy) return;
    setState(() => _busy = true);
    final ok = await widget.onEnter();
    if (!mounted || ok) return;
    setState(() {
      _busy = false;
      _failed = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final nickname = widget.nickname;
    return OnboardingStepScaffold(
      step: OnboardingStep.ready,
      onBack: widget.onBack,
      content: Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (nickname != null) ...[
              StaggerItem(
                order: 1,
                child: Text(OnboardingReadyScreen.greeting(nickname),
                    style: _Text.greeting),
              ),
              const SizedBox(height: AppSpacing.xs),
            ],
            StaggerItem(
              order: 1,
              child: Semantics(
                header: true,
                child:
                    const Text(OnboardingReadyScreen.title, style: _Text.title),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            const StaggerItem(order: 2, child: _PaperCard()),
            const SizedBox(height: AppSpacing.md),
            StaggerItem(
              order: 3,
              child: ListenableBuilder(
                listenable: widget.session,
                builder: (context, _) => _Summary(
                  session: widget.session,
                  reminders: widget.reminders,
                  remindersSimulated: widget.remindersSimulated,
                ),
              ),
            ),
            if (_failed) ...[
              const SizedBox(height: 12),
              const _Message(OnboardingReadyScreen.enterFailed),
            ],
          ],
        ),
      ),
      stage: const StaggerItem(order: 5, child: _Stage()),
      actions: [
        StaggerItem(
          order: 6,
          child: OnboardingCta(
            label: _failed
                ? OnboardingReadyScreen.retryLabel
                : OnboardingReadyScreen.enterLabel,
            // Taps while saving are ignored, without greying the button.
            onPressed: _enter,
          ),
        ),
      ],
    );
  }
}

/// The invitation, on a sheet of paper.
class _PaperCard extends StatelessWidget {
  const _PaperCard();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: AppColors.textPrimary.withValues(alpha: .06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child:
            const Text(OnboardingReadyScreen.invitation, style: _Text.reading),
      );
}

/// What is true now: the first entry, then the reminders.
class _Summary extends StatelessWidget {
  const _Summary({
    required this.session,
    required this.reminders,
    required this.remindersSimulated,
  });

  final FirstEntrySession session;
  final Map<ReminderSlot, ReminderTime> reminders;
  final bool remindersSimulated;

  @override
  Widget build(BuildContext context) {
    // A draft that could not be kept is not one.
    final draft = session.draft == DraftStatus.saved ||
        session.draft == DraftStatus.saving;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Nothing about the entry until it is known.
        if (session.loaded) ...[
          if (session.saved != null)
            const _Line(Icons.check_circle_outline_rounded,
                OnboardingReadyScreen.entrySaved),
          if (draft)
            const _Line(
                Icons.edit_note_rounded, OnboardingReadyScreen.draftKept),
          if (session.saved == null && !draft)
            const _Line(
                Icons.menu_book_outlined, OnboardingReadyScreen.noEntry),
        ],
        if (reminders.isEmpty)
          const _Line(Icons.notifications_none_rounded,
              OnboardingReadyScreen.remindersLater)
        else
          _Line(
            Icons.notifications_active_outlined,
            OnboardingReadyScreen.remindersOn(reminders),
            note:
                remindersSimulated ? OnboardingReadyScreen.simulatedNote : null,
          ),
      ],
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.icon, this.text, {this.note});

  final IconData icon;
  final String text;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final note = this.note;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(icon, size: 20, color: AppColors.primaryAction),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(text, style: _Text.line),
                if (note != null) Text(note, style: _Text.note),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Why "Vào không gian của mình" did not leave, read out when it appears.
class _Message extends StatelessWidget {
  const _Message(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Semantics(
        liveRegion: true,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.small),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ExcludeSemantics(
                child: Icon(Icons.info_outline_rounded,
                    size: 20, color: AppColors.textPrimary),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(text, style: _Text.line)),
            ],
          ),
        ),
      );
}

/// Nudaeng knitting, same size and spot as every onboarding mascot
/// ([OnboardingMascot]).
class _Stage extends StatelessWidget {
  const _Stage();

  @override
  Widget build(BuildContext context) {
    const frame = OnboardingReadyScreen.mascotFrame;
    final width =
        frame.canvas.width * OnboardingMascot.figureHeight / frame.figureHeight;
    final decodeWidth =
        (width * MediaQuery.devicePixelRatioOf(context) / 64).ceil() * 64;
    return OnboardingMascot(
      frame: frame,
      child: Image.asset(
        OnboardingReadyScreen.mascotAsset,
        cacheWidth: decodeWidth,
        semanticLabel: 'Nudaeng đang đan áo len',
      ),
    );
  }
}

abstract final class _Text {
  static const greeting = TextStyle(
    fontFamily: 'BeVietnamPro',
    fontSize: 16,
    height: 1.5,
    color: AppColors.textSecondary,
  );
  static const title = TextStyle(
    fontFamily: 'Nunito',
    fontSize: 28,
    fontWeight: FontWeight.w700,
    height: 1.25,
    color: AppColors.textPrimary,
  );
  static const reading = TextStyle(
    fontFamily: 'BeVietnamPro',
    fontSize: 16,
    height: 1.6,
    color: AppColors.textPrimary,
  );
  static const line = TextStyle(
    fontFamily: 'BeVietnamPro',
    fontSize: 14,
    height: 20 / 14,
    color: AppColors.textPrimary,
  );
  static const note = TextStyle(
    fontFamily: 'BeVietnamPro',
    fontSize: 12,
    height: 16 / 12,
    color: AppColors.textSecondary,
  );
}
