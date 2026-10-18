import 'package:flutter/foundation.dart';

/// A local wall-clock time for a daily reminder. No time zone on purpose:
/// 08:00 stays 08:00 when the user travels or the clocks change.
@immutable
class ReminderTime {
  const ReminderTime(this.hour, this.minute)
      : assert(hour >= 0 && hour < 24),
        assert(minute >= 0 && minute < 60);

  final int hour;
  final int minute;

  /// "08:00"; the persisted form too.
  String get label =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  static ReminderTime? tryParse(String text) {
    final parts = text.split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
    return ReminderTime(hour, minute);
  }

  /// The first local time after [now] at this hour and minute: today if it
  /// is still ahead, otherwise tomorrow. A daily reminder starts there.
  DateTime nextAfter(DateTime now) {
    final today = DateTime(now.year, now.month, now.day, hour, minute);
    return today.isAfter(now)
        ? today
        : DateTime(now.year, now.month, now.day + 1, hour, minute);
  }

  @override
  bool operator ==(Object other) =>
      other is ReminderTime && other.hour == hour && other.minute == minute;

  @override
  int get hashCode => Object.hash(hour, minute);

  @override
  String toString() => label;
}

/// The two daily reminders offered in onboarding (OB10). [id] is the
/// notification id: stable, so saving again replaces the same reminder
/// instead of adding another. Names are persisted; do not rename.
enum ReminderSlot {
  morning(id: 1001, defaultTime: ReminderTime(8, 0), label: 'buổi sáng'),
  evening(id: 1002, defaultTime: ReminderTime(21, 0), label: 'buổi tối');

  const ReminderSlot({
    required this.id,
    required this.defaultTime,
    required this.label,
  });

  final int id;
  final ReminderTime defaultTime;

  /// Lower case, for sentences: "Chưa tạo được lời nhắc buổi tối."
  final String label;
}

/// Notification permission as the OS reports it.
enum NotificationPermission {
  /// Never asked: [ReminderService.requestPermission] shows the system
  /// prompt.
  notDetermined,
  granted,

  /// Refused: the system prompt will not show again; only Settings can
  /// change it.
  denied,

  /// Notifications cannot be used here (no support, or blocked by policy).
  unavailable,
}

/// A reminder the OS has accepted.
@immutable
class ScheduledReminder {
  const ScheduledReminder({
    required this.slot,
    required this.time,
    required this.firstAt,
  });

  final ReminderSlot slot;
  final ReminderTime time;

  /// The first time it fires; then daily at [time].
  final DateTime firstAt;
}

/// Thrown when one reminder could not be scheduled.
class ReminderScheduleException implements Exception {
  const ReminderScheduleException(this.slot, [this.cause]);

  final ReminderSlot slot;
  final Object? cause;

  @override
  String toString() => 'ReminderScheduleException(${slot.name}: $cause)';
}

/// Local daily reminders. A real implementation wraps the platform plugin
/// (e.g. flutter_local_notifications and an app-settings opener; not in the
/// project yet, see the onboarding README).
abstract interface class ReminderService {
  /// One text for every reminder; it says nothing about the entries.
  static const message = 'Một chút thời gian dành cho nhật ký của bạn';

  /// True for the stand-in: no real notification will appear.
  bool get simulated;

  /// Current permission. Never shows a prompt.
  Future<NotificationPermission> permission();

  /// Shows the system prompt when the permission was never asked; otherwise
  /// returns the current state without prompting again.
  Future<NotificationPermission> requestPermission();

  /// Schedules [slot] daily at [time] (local wall-clock), from the next
  /// occurrence. Replaces any reminder with the slot's id. Throws
  /// [ReminderScheduleException] on failure.
  Future<ScheduledReminder> scheduleDaily(ReminderSlot slot, ReminderTime time);

  /// Removes the slot's reminder, if any. Needs no permission.
  Future<void> cancel(ReminderSlot slot);

  /// Opens the app's notification settings. False when it could not.
  Future<bool> openSettings();
}

/// Stand-in until the notification plugin is added. Nothing is shown to the
/// user: there is no system prompt (it is never faked), and no notification
/// will appear. Each state is explicit so every OB10 branch can be tried:
/// [permission] is the current state, [answer] what the "prompt" returns,
/// [failing] the slots whose scheduling fails.
class SimulatedReminderService implements ReminderService {
  SimulatedReminderService({
    this.status = NotificationPermission.notDetermined,
    this.answer = NotificationPermission.granted,
    Set<ReminderSlot>? failing,
    DateTime Function()? clock,
  })  : failing = failing ?? {},
        _clock = clock ?? DateTime.now;

  /// Development: `--dart-define=REMINDER_SIM=<state>` picks the branch to
  /// try on a device: `denied`, `refuse` (the prompt is refused),
  /// `unavailable`, `fail-morning`, `fail-evening` or `fail-all`. Anything
  /// else: never asked, then granted.
  factory SimulatedReminderService.fromEnvironment() =>
      switch (const String.fromEnvironment('REMINDER_SIM')) {
        'denied' =>
          SimulatedReminderService(status: NotificationPermission.denied),
        'refuse' =>
          SimulatedReminderService(answer: NotificationPermission.denied),
        'unavailable' =>
          SimulatedReminderService(status: NotificationPermission.unavailable),
        'fail-morning' =>
          SimulatedReminderService(failing: {ReminderSlot.morning}),
        'fail-evening' =>
          SimulatedReminderService(failing: {ReminderSlot.evening}),
        'fail-all' =>
          SimulatedReminderService(failing: ReminderSlot.values.toSet()),
        _ => SimulatedReminderService(),
      };

  NotificationPermission status;
  NotificationPermission answer;
  final Set<ReminderSlot> failing;
  final DateTime Function() _clock;

  /// What the OS would hold now, by slot.
  final scheduled = <ReminderSlot, ScheduledReminder>{};

  /// How often a real system prompt would have been shown.
  var prompts = 0;

  /// How often Settings would have been opened.
  var settingsOpened = 0;

  @override
  bool get simulated => true;

  @override
  Future<NotificationPermission> permission() async => status;

  @override
  Future<NotificationPermission> requestPermission() async {
    if (status == NotificationPermission.notDetermined) {
      prompts++;
      status = answer;
    }
    return status;
  }

  @override
  Future<ScheduledReminder> scheduleDaily(
      ReminderSlot slot, ReminderTime time) async {
    if (status != NotificationPermission.granted) {
      throw ReminderScheduleException(slot, 'permission ${status.name}');
    }
    if (failing.contains(slot)) {
      throw ReminderScheduleException(slot, 'simulated failure');
    }
    return scheduled[slot] = ScheduledReminder(
        slot: slot, time: time, firstAt: time.nextAfter(_clock()));
  }

  @override
  Future<void> cancel(ReminderSlot slot) async => scheduled.remove(slot);

  /// There is nothing to open in the stand-in.
  @override
  Future<bool> openSettings() async {
    settingsOpened++;
    return false;
  }
}
