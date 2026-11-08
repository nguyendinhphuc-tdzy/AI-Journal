import 'dart:io';
import 'dart:ui' show Color;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'reminder_service.dart';

/// The reminder service for this device: real notifications on Android;
/// the stand-in elsewhere (tests, desktop) or when `REMINDER_SIM` picks a
/// branch to try.
ReminderService defaultReminderService() =>
    Platform.isAndroid && const String.fromEnvironment('REMINDER_SIM').isEmpty
        ? LocalReminderService()
        : SimulatedReminderService.fromEnvironment();

/// OB10's daily reminders as real Android notifications
/// (flutter_local_notifications). Each slot repeats every day at its local
/// wall-clock time, in the device's time zone; inexact, so no exact-alarm
/// permission is needed (it may come a few minutes late while the phone
/// sleeps). The plugin schedules them again after a reboot or an update.
class LocalReminderService implements ReminderService {
  LocalReminderService({
    FlutterLocalNotificationsPlugin? plugin,
    DateTime Function()? clock,
  })  : _plugin = plugin ?? FlutterLocalNotificationsPlugin(),
        _clock = clock ?? DateTime.now;

  final FlutterLocalNotificationsPlugin _plugin;
  final DateTime Function() _clock;

  /// The system prompt was shown once from here; after that a "no" means
  /// refused, and only Settings changes it.
  static const _askedKey = 'reminders.permissionAsked';

  static const _channelId = 'daily_reminders';
  static const _channelName = 'Nhắc viết nhật ký';
  static const _channelDescription =
      'Lời nhắc buổi sáng và buổi tối bạn đặt trong ứng dụng.';
  static const _title = 'Nhật ký AI';

  /// AppColors.primaryAction, as the push notifications use.
  static const _accent = Color(0xFF2E6E78);

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      icon: 'ic_stat_notify',
      color: _accent,
      // Says nothing about the entries, but stays off the lock screen like
      // the rest of the journal.
      visibility: NotificationVisibility.private,
    ),
  );

  late final Future<void> _ready = _init();

  Future<void> _init() async {
    tzdata.initializeTimeZones();
    try {
      final zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone.identifier));
    } catch (_) {
      // An id the database does not know: the app's home market.
      tz.setLocalLocation(tz.getLocation('Asia/Ho_Chi_Minh'));
    }
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_stat_notify'),
      ),
    );
  }

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  @override
  bool get simulated => false;

  @override
  Future<NotificationPermission> permission() async {
    try {
      await _ready;
      final android = _android;
      if (android == null) return NotificationPermission.unavailable;
      final enabled = await android.areNotificationsEnabled();
      if (enabled == null) return NotificationPermission.unavailable;
      if (enabled) return NotificationPermission.granted;
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_askedKey) == true
          ? NotificationPermission.denied
          : NotificationPermission.notDetermined;
    } catch (_) {
      return NotificationPermission.unavailable;
    }
  }

  @override
  Future<NotificationPermission> requestPermission() async {
    final current = await permission();
    if (current != NotificationPermission.notDetermined) return current;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_askedKey, true);
      // Android 13+: the system prompt, unless the OS already holds a
      // refusal (e.g. from the push prompt after sign-in). Older: whether
      // notifications are on.
      final granted = await _android?.requestNotificationsPermission();
      return granted == true
          ? NotificationPermission.granted
          : NotificationPermission.denied;
    } catch (_) {
      return NotificationPermission.unavailable;
    }
  }

  @override
  Future<ScheduledReminder> scheduleDaily(
      ReminderSlot slot, ReminderTime time) async {
    try {
      await _ready;
      final first = time.nextAfter(_clock());
      await _plugin.zonedSchedule(
        id: slot.id,
        scheduledDate: tz.TZDateTime(tz.local, first.year, first.month,
            first.day, time.hour, time.minute),
        notificationDetails: _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        title: _title,
        body: ReminderService.message,
        // Every day at this hour and minute.
        matchDateTimeComponents: DateTimeComponents.time,
      );
      return ScheduledReminder(slot: slot, time: time, firstAt: first);
    } catch (error) {
      throw ReminderScheduleException(slot, error);
    }
  }

  @override
  Future<void> cancel(ReminderSlot slot) async {
    await _ready;
    await _plugin.cancel(id: slot.id);
  }

  @override
  Future<bool> openSettings() async {
    try {
      await _ready;
      return await _android?.openAppNotificationSettings() ?? false;
    } catch (_) {
      return false;
    }
  }
}
