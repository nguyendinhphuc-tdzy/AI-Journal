import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../reminders/data/reminder_service.dart';
import '../data/onboarding_store.dart';
import 'onboarding_widgets.dart';

/// One OB10 row as edited: on or off, and its time. Only a draft: nothing
/// is scheduled until "Lưu lời nhắc".
@immutable
class ReminderChoice {
  const ReminderChoice({required this.enabled, required this.time});

  final bool enabled;
  final ReminderTime time;

  ReminderChoice copyWith({bool? enabled, ReminderTime? time}) =>
      ReminderChoice(enabled: enabled ?? this.enabled, time: time ?? this.time);

  /// Both rows, on where [saved] has a reminder; otherwise off at the
  /// default time (08:00, 21:00).
  static Map<ReminderSlot, ReminderChoice> draftFrom(
          Map<ReminderSlot, ReminderTime> saved) =>
      {
        for (final slot in ReminderSlot.values)
          slot: ReminderChoice(
            enabled: saved.containsKey(slot),
            time: saved[slot] ?? slot.defaultTime,
          ),
      };
}

/// OB10: optional daily reminders, morning and evening, both off at first.
///
/// Toggles and the time pickers change only the draft. "Lưu lời nhắc" (at
/// least one on) is the only place that asks for notification permission:
/// the system prompt shows then if it was never asked; once refused it is
/// not asked again, and "Mở cài đặt" is offered instead. Then each chosen
/// slot is scheduled daily (stable id, from its next occurrence) and only
/// what the OS accepted is reported to [onDone]. "Để sau" applies nothing.
/// With both off the CTA is "Tiếp tục không nhắc".
class OnboardingReminderScreen extends StatefulWidget {
  const OnboardingReminderScreen({
    super.key,
    required this.service,
    required this.initialDraft,
    required this.onChanged,
    required this.onBack,
    required this.onDone,
    required this.onSkip,
  });

  final ReminderService service;
  final Map<ReminderSlot, ReminderChoice> initialDraft;
  final ValueChanged<Map<ReminderSlot, ReminderChoice>> onChanged;
  final VoidCallback onBack;

  /// To OB11 with the reminders actually scheduled (maybe none).
  final ValueChanged<Map<ReminderSlot, ReminderTime>> onDone;

  /// "Để sau": to OB11, nothing applied.
  final VoidCallback onSkip;

  static const title = 'Bạn muốn được nhắc vào lúc nào?';
  static const helper = 'Bạn có thể đặt lời nhắc hoặc để sau.';
  static const saveLabel = 'Lưu lời nhắc';
  static const savingLabel = 'Đang lưu lời nhắc…';
  static const withoutLabel = 'Tiếp tục không nhắc';
  static const laterLabel = 'Để sau';
  static const continueLabel = 'Tiếp tục';
  static const retryLabel = 'Thử lại';
  static const settingsLabel = 'Mở cài đặt';
  static const blocked =
      'Chưa bật được thông báo. Bạn có thể đổi trong Cài đặt.';
  static const settingsFailed =
      'Chưa mở được Cài đặt. Bạn có thể bật thông báo trong Cài đặt của máy.';

  /// Shown once reminders are "saved" by the stand-in, so nobody waits for
  /// a notification that will not come. (Not on the screen itself: the
  /// line would leave no room for Nudaeng on 390×844.)
  static const simulatedNote =
      'Bản thử nghiệm: lời nhắc chỉ được mô phỏng, chưa có thông báo thật.';

  static const slotTitles = {
    ReminderSlot.morning: 'Buổi sáng',
    ReminderSlot.evening: 'Buổi tối',
  };
  static const slotDescriptions = {
    ReminderSlot.morning:
        'Dành một chút thời gian để ghi điều bạn muốn bắt đầu',
    ReminderSlot.evening: 'Nhìn lại ngày hôm nay bằng vài dòng',
  };

  /// "Chưa tạo được lời nhắc buổi tối." / "… buổi sáng và buổi tối."
  static String failedMessage(Iterable<ReminderSlot> failed) =>
      'Chưa tạo được lời nhắc '
      '${[
        for (final slot in ReminderSlot.values)
          if (failed.contains(slot)) slot.label
      ].join(' và ')}.';

  /// "Lời nhắc buổi sáng lúc 08:00 đã được đặt."
  static String scheduledMessage(Map<ReminderSlot, ReminderTime> scheduled) =>
      '${[
        for (final MapEntry(:key, :value) in scheduled.entries)
          'Lời nhắc ${key.label} lúc ${value.label}'
      ].join(', ')} đã được đặt.';

  static const mascotAsset = 'assets/Deimage/ob10-nudaeng-balloons.png';
  static const decorAsset = 'assets/Deimage/ob10-remind-decor.png';

  /// Nudaeng holding the balloons, cut from "Nudaeng remind.png"
  /// (`tool/build_remind_layers.py`). The balloons rise above the head.
  static const mascotFrame = MascotFrame(
    canvas: Size(748, 1081),
    headTop: 497,
    feet: Offset(459, 1078),
  );

  @override
  State<OnboardingReminderScreen> createState() =>
      _OnboardingReminderScreenState();
}

/// What the last "Lưu lời nhắc" ended with, when it did not leave.
sealed class _Outcome {
  const _Outcome();
}

/// No permission: nothing was scheduled.
class _Blocked extends _Outcome {
  const _Blocked(this.permission, {this.settingsFailed = false});

  final NotificationPermission permission;

  /// "Mở cài đặt" was tried and Settings did not open.
  final bool settingsFailed;
}

/// Some chosen slots were not scheduled.
class _Partial extends _Outcome {
  const _Partial({required this.failed, required this.scheduled});

  final Set<ReminderSlot> failed;
  final Map<ReminderSlot, ReminderTime> scheduled;
}

class _OnboardingReminderScreenState extends State<OnboardingReminderScreen> {
  late Map<ReminderSlot, ReminderChoice> _draft = {...widget.initialDraft};
  _Outcome? _outcome;
  var _busy = false;

  /// Back from Settings: if notifications are now allowed, offer saving
  /// again.
  late final AppLifecycleListener _lifecycle =
      AppLifecycleListener(onResume: _recheck);

  @override
  void initState() {
    super.initState();
    _lifecycle;
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  bool get _anyOn => _draft.values.any((choice) => choice.enabled);

  ReminderService get _service => widget.service;

  void _edit(ReminderSlot slot, ReminderChoice choice) {
    setState(() {
      _draft = {..._draft, slot: choice};
      // An edit starts over: the old message no longer applies.
      _outcome = null;
    });
    widget.onChanged(_draft);
  }

  Future<void> _pickTime(ReminderSlot slot) async {
    final choice = _draft[slot]!;
    final picked = await showTimePicker(
      context: context,
      initialTime:
          TimeOfDay(hour: choice.time.hour, minute: choice.time.minute),
      // Typing is easier than the two-ring 24h dial; the dial stays one tap away.
      initialEntryMode: TimePickerEntryMode.input,
      helpText: 'Giờ nhắc ${slot.label}',
      cancelText: 'Hủy',
      confirmText: 'Chọn',
      hourLabelText: 'Giờ',
      minuteLabelText: 'Phút',
      errorInvalidText: 'Giờ chưa hợp lệ',
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked == null || !mounted) return;
    _edit(
        slot, choice.copyWith(time: ReminderTime(picked.hour, picked.minute)));
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _outcome = null;
    });
    var permission = await _service.permission();
    // The only place the system prompt can appear, and only once.
    if (permission == NotificationPermission.notDetermined) {
      permission = await _service.requestPermission();
    }
    if (!mounted) return;
    if (permission != NotificationPermission.granted) {
      setState(() {
        _busy = false;
        _outcome = _Blocked(permission);
      });
      return;
    }
    final scheduled = <ReminderSlot, ReminderTime>{};
    final failed = <ReminderSlot>{};
    for (final slot in ReminderSlot.values) {
      final choice = _draft[slot]!;
      try {
        if (choice.enabled) {
          await _service.scheduleDaily(slot, choice.time);
          scheduled[slot] = choice.time;
        } else {
          await _service.cancel(slot);
        }
      } on Object {
        if (choice.enabled) failed.add(slot);
      }
    }
    if (!mounted) return;
    if (failed.isEmpty) {
      if (_service.simulated) {
        // Floats above where the next step's actions sit.
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text(OnboardingReminderScreen.simulatedNote),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              OnboardingStepScaffold.feetLineFromBottom(context) -
                  MediaQuery.paddingOf(context).bottom),
        ));
      }
      // Stays busy: leaving now, a second tap must not save again.
      widget.onDone(scheduled);
      return;
    }
    setState(() {
      _busy = false;
      _outcome = _Partial(failed: failed, scheduled: scheduled);
    });
  }

  /// Both off, or notifications blocked: no reminder is left behind.
  Future<void> _continueWithout() async {
    if (_busy) return;
    setState(() => _busy = true);
    for (final slot in ReminderSlot.values) {
      try {
        await _service.cancel(slot);
      } on Object {
        // Nothing to undo; a reminder that cannot be cancelled is not ours
        // to report here.
      }
    }
    if (mounted) widget.onDone(const {});
  }

  Future<void> _openSettings() async {
    final opened = await _service.openSettings();
    if (opened || !mounted) return;
    // Said in the message, not a snack bar that would cover the actions.
    if (_outcome case _Blocked(:final permission)) {
      setState(() => _outcome = _Blocked(permission, settingsFailed: true));
    }
  }

  Future<void> _recheck() async {
    if (_outcome is! _Blocked) return;
    final permission = await _service.permission();
    if (mounted &&
        _outcome is _Blocked &&
        permission == NotificationPermission.granted) {
      setState(() => _outcome = null);
    }
  }

  List<Widget> _actions() {
    final outcome = _outcome;
    Widget primary(String label, VoidCallback? onPressed) =>
        OnboardingCta(label: label, onPressed: _busy ? null : onPressed);
    Widget secondary(String label, VoidCallback onPressed) =>
        OnboardingTextAction(label: label, onPressed: onPressed);
    return switch (outcome) {
      _ when _busy => [primary(OnboardingReminderScreen.savingLabel, null)],
      _Blocked(:final permission) => [
          primary(OnboardingReminderScreen.continueLabel, _continueWithout),
          if (permission == NotificationPermission.denied)
            secondary(OnboardingReminderScreen.settingsLabel, _openSettings),
        ],
      _Partial(:final scheduled) => [
          primary(OnboardingReminderScreen.retryLabel, _save),
          secondary(OnboardingReminderScreen.continueLabel,
              () => widget.onDone(scheduled)),
        ],
      null when _anyOn => [
          primary(OnboardingReminderScreen.saveLabel, _save),
          secondary(OnboardingReminderScreen.laterLabel, widget.onSkip),
        ],
      null => [
          primary(OnboardingReminderScreen.withoutLabel, _continueWithout),
        ],
    };
  }

  @override
  Widget build(BuildContext context) {
    final layout = MediaQuery.textScalerOf(context).scale(16) > 20
        ? _CardLayout.stacked
        : MediaQuery.sizeOf(context).width < 380
            ? _CardLayout.compact
            : _CardLayout.row;
    final outcome = _outcome;
    final actions = _actions();
    return OnboardingStepScaffold(
      step: OnboardingStep.reminder,
      onBack: widget.onBack,
      backdrop: const _Decor(),
      content: Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            StaggerItem(
              order: 1,
              child: Semantics(
                header: true,
                child: const Text(OnboardingReminderScreen.title,
                    style: _Text.title),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            const StaggerItem(
              order: 2,
              child: Text(OnboardingReminderScreen.helper, style: _Text.helper),
            ),
            const SizedBox(height: AppSpacing.md),
            for (final (i, slot) in ReminderSlot.values.indexed) ...[
              if (i > 0) const SizedBox(height: 12),
              StaggerItem(
                order: 3 + i,
                child: _SlotCard(
                  slot: slot,
                  choice: _draft[slot]!,
                  layout: layout,
                  enabled: !_busy,
                  onToggle: (on) =>
                      _edit(slot, _draft[slot]!.copyWith(enabled: on)),
                  onPickTime: () => _pickTime(slot),
                ),
              ),
            ],
            if (outcome != null) ...[
              const SizedBox(height: 12),
              _Message(outcome),
            ],
          ],
        ),
      ),
      stage: const StaggerItem(order: 6, child: _Stage()),
      actions: [
        for (final (i, action) in actions.indexed)
          StaggerItem(order: 7 + i, child: action),
      ],
    );
  }
}

/// How a reminder card arranges its parts, so the description keeps a
/// readable width.
enum _CardLayout {
  /// One row: icon, text, time, switch.
  row,

  /// Narrow screens: time and switch move up beside the title, the
  /// description runs below at full width.
  compact,

  /// Large text: time and switch on a line of their own.
  stacked,
}

class _SlotCard extends StatelessWidget {
  const _SlotCard({
    required this.slot,
    required this.choice,
    required this.layout,
    required this.enabled,
    required this.onToggle,
    required this.onPickTime,
  });

  final ReminderSlot slot;
  final ReminderChoice choice;
  final _CardLayout layout;
  final bool enabled;
  final ValueChanged<bool> onToggle;
  final VoidCallback onPickTime;

  @override
  Widget build(BuildContext context) {
    final title = OnboardingReminderScreen.slotTitles[slot]!;
    final icon = Container(
      width: 40,
      height: 40,
      decoration: const BoxDecoration(
        color: AppColors.primaryLight,
        shape: BoxShape.circle,
      ),
      child: ExcludeSemantics(
        child: Icon(
          slot == ReminderSlot.morning
              ? Icons.wb_sunny_outlined
              : Icons.nightlight_outlined,
          size: 22,
          color: AppColors.primaryAction,
        ),
      ),
    );
    final titleText = Text(title, style: _Text.cardTitle);
    final description = Text(OnboardingReminderScreen.slotDescriptions[slot]!,
        style: _Text.cardBody);
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [titleText, const SizedBox(height: 2), description],
    );
    final time = _TimeButton(
      label: choice.time.label,
      semanticLabel: 'Giờ nhắc ${slot.label}, ${choice.time.label}',
      onPressed: enabled ? onPickTime : null,
    );
    final toggle = MergeSemantics(
      child: Semantics(
        label: 'Nhắc $title, ${choice.time.label}',
        child: Switch(
          value: choice.enabled,
          onChanged: enabled ? onToggle : null,
          activeTrackColor: AppColors.primaryAction,
          activeThumbColor: AppColors.surface,
          inactiveThumbColor: AppColors.textSecondary,
          inactiveTrackColor: AppColors.surface,
          trackOutlineColor: WidgetStateProperty.resolveWith((states) =>
              states.contains(WidgetState.selected)
                  ? AppColors.primaryAction
                  : AppColors.textSecondary),
        ),
      ),
    );
    return Container(
      // The thicker border when on eats into the padding, so the text never
      // re-wraps on toggle.
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, 12, AppSpacing.sm, 12) -
          EdgeInsets.all(choice.enabled ? 1 : 0),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
          color: choice.enabled ? AppColors.primaryAction : AppColors.border,
          width: choice.enabled ? 2 : 1,
        ),
      ),
      child: switch (layout) {
        _CardLayout.row => Row(
            children: [
              icon,
              const SizedBox(width: 12),
              Expanded(child: text),
              const SizedBox(width: AppSpacing.xs),
              time,
              toggle,
            ],
          ),
        _CardLayout.compact => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                icon,
                const SizedBox(width: 12),
                Expanded(child: titleText),
                time,
                toggle,
              ]),
              Padding(
                padding: const EdgeInsets.only(left: 52, right: AppSpacing.sm),
                child: description,
              ),
            ],
          ),
        _CardLayout.stacked => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  icon,
                  const SizedBox(width: 12),
                  Expanded(child: text),
                  const SizedBox(width: AppSpacing.sm),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(children: [
                const SizedBox(width: 52 - AppSpacing.sm),
                time,
                const Spacer(),
                toggle,
              ]),
            ],
          ),
      },
    );
  }
}

/// The time, as a button opening the picker. 48 high.
class _TimeButton extends StatelessWidget {
  const _TimeButton({
    required this.label,
    required this.semanticLabel,
    required this.onPressed,
  });

  final String label;
  final String semanticLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
        label: semanticLabel,
        hint: 'Đổi giờ',
        button: true,
        excludeSemantics: true,
        child: TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primaryAction,
            minimumSize: const Size(48, 48),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            tapTargetSize: MaterialTapTargetSize.padded,
            textStyle: _Text.time,
          ),
          child: Text(label,
              style: const TextStyle(decoration: TextDecoration.underline)),
        ),
      );
}

/// The result of the last save, read out when it appears.
class _Message extends StatelessWidget {
  const _Message(this.outcome);

  final _Outcome outcome;

  @override
  Widget build(BuildContext context) {
    final lines = switch (outcome) {
      _Blocked(:final settingsFailed) => [
          OnboardingReminderScreen.blocked,
          if (settingsFailed) OnboardingReminderScreen.settingsFailed,
        ],
      _Partial(:final failed, :final scheduled) => [
          OnboardingReminderScreen.failedMessage(failed),
          if (scheduled.isNotEmpty)
            OnboardingReminderScreen.scheduledMessage(scheduled),
        ],
    };
    return Semantics(
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
            Expanded(child: Text(lines.join(' '), style: _Text.message)),
          ],
        ),
      ),
    );
  }
}

/// Star, balloon and heart from the artwork, along the bottom behind the
/// actions.
class _Decor extends StatelessWidget {
  const _Decor();

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.bottomCenter,
        child: Image.asset(
          OnboardingReminderScreen.decorAsset,
          width: double.infinity,
          fit: BoxFit.fitWidth,
          alignment: Alignment.bottomCenter,
          excludeFromSemantics: true,
        ),
      );
}

/// Nudaeng with the balloons, same size and spot as every onboarding mascot
/// ([OnboardingMascot]); hidden whole when the balloons would not fit.
class _Stage extends StatelessWidget {
  const _Stage();

  @override
  Widget build(BuildContext context) {
    const frame = OnboardingReminderScreen.mascotFrame;
    final width =
        frame.canvas.width * OnboardingMascot.figureHeight / frame.figureHeight;
    final decodeWidth =
        (width * MediaQuery.devicePixelRatioOf(context) / 64).ceil() * 64;
    return OnboardingMascot(
      frame: frame,
      wholeCanvas: true,
      child: Image.asset(
        OnboardingReminderScreen.mascotAsset,
        cacheWidth: decodeWidth,
        semanticLabel: 'Nudaeng cầm bóng bay',
      ),
    );
  }
}

abstract final class _Text {
  static const title = TextStyle(
    fontFamily: 'Nunito',
    fontSize: 24,
    fontWeight: FontWeight.w700,
    height: 1.3,
    color: AppColors.textPrimary,
  );
  static const helper = TextStyle(
    fontFamily: 'BeVietnamPro',
    fontSize: 16,
    height: 1.5,
    color: AppColors.textSecondary,
  );
  static const cardTitle = TextStyle(
    fontFamily: 'BeVietnamPro',
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.5,
    color: AppColors.textPrimary,
  );
  static const cardBody = TextStyle(
    fontFamily: 'BeVietnamPro',
    fontSize: 14,
    height: 20 / 14,
    color: AppColors.textSecondary,
  );
  static const time = TextStyle(
    fontFamily: 'BeVietnamPro',
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.5,
  );
  static const message = TextStyle(
    fontFamily: 'BeVietnamPro',
    fontSize: 14,
    height: 20 / 14,
    color: AppColors.textPrimary,
  );
}
