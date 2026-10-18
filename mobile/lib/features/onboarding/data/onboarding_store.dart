import 'package:shared_preferences/shared_preferences.dart';

import '../../reminders/data/reminder_service.dart';
import 'journal_goal.dart';
import 'journaling_experience.dart';

/// Onboarding routes OB01–OB11. Names are persisted; do not rename.
enum OnboardingStep {
  welcome, // OB01
  nickname, // OB02
  purpose, // OB03
  experience, // OB04
  features, // OB05
  aiAndData, // OB06
  firstEntry, // OB07
  saving, // OB08, transient
  entrySaved, // OB09
  reminder, // OB10
  ready; // OB11

  /// Interactive routes shown in the progress bar ("Bước x/9").
  static const progressSteps = 9;

  /// 1-based progress position. OB01 has no progress; the transient OB08
  /// keeps OB07's position.
  int? get progressPosition => switch (this) {
        welcome => null,
        saving => firstEntry.progressPosition,
        _ when index < saving.index => index,
        _ => index - 1,
      };
}

/// Local onboarding state: the route to resume and whether onboarding is
/// done. Only OB11 may call [complete].
class OnboardingStore {
  OnboardingStore._(this._prefs);

  static Future<OnboardingStore> open() async =>
      OnboardingStore._(await SharedPreferences.getInstance());

  final SharedPreferences _prefs;

  static const _completedKey = 'onboarding.completed';
  static const _stepKey = 'onboarding.step';
  static const _nicknameKey = 'onboarding.nickname';
  static const _goalKey = 'onboarding.goal';
  static const _experienceKey = 'onboarding.experience';
  static const _aiKey = 'onboarding.ai';
  static const _aiPolicyKey = 'onboarding.aiPolicyVersion';
  static const _firstEntryKey = 'onboarding.firstEntryId';
  static const _remindersKey = 'onboarding.reminders';

  bool get completed => _prefs.getBool(_completedKey) ?? false;

  /// Saved route, or OB01 when no session was started.
  OnboardingStep get step =>
      OnboardingStep.values.asNameMap()[_prefs.getString(_stepKey)] ??
      OnboardingStep.welcome;

  Future<void> saveStep(OnboardingStep step) =>
      _prefs.setString(_stepKey, step.name);

  /// Saved nickname; null when the user left it empty.
  String? get nickname => _prefs.getString(_nicknameKey);

  Future<void> saveNickname(String? nickname) => nickname == null
      ? _prefs.remove(_nicknameKey)
      : _prefs.setString(_nicknameKey, nickname);

  /// OB03 goal; null when skipped ("Để sau") or not asked yet. Changing it
  /// touches nothing else: entries and drafts stay as they are.
  JournalGoal? get goal =>
      JournalGoal.values.asNameMap()[_prefs.getString(_goalKey)];

  Future<void> saveGoal(JournalGoal? goal) => goal == null
      ? _prefs.remove(_goalKey)
      : _prefs.setString(_goalKey, goal.name);

  /// OB04 answer: null when not asked yet, [JournalingExperience.unknown]
  /// after "Để sau".
  JournalingExperience? get experience =>
      JournalingExperience.values.asNameMap()[_prefs.getString(_experienceKey)];

  Future<void> saveExperience(JournalingExperience experience) =>
      _prefs.setString(_experienceKey, experience.name);

  /// OB06 AI choice: null until the user picks one of the two paths. Only
  /// about AI reflections; it is not marketing consent, notification
  /// permission or permission to publish anything.
  bool? get aiEnabled => switch (_prefs.getString(_aiKey)) {
        'on' => true,
        'off' => false,
        _ => null,
      };

  /// Policy version the AI choice was made under, when the policy has one.
  String? get aiPolicyVersion => _prefs.getString(_aiPolicyKey);

  /// Applies to the next requests only; it cannot recall anything sent
  /// before.
  Future<void> saveAiChoice(
      {required bool enabled, String? policyVersion}) async {
    await _prefs.setString(_aiKey, enabled ? 'on' : 'off');
    if (enabled && policyVersion != null) {
      await _prefs.setString(_aiPolicyKey, policyVersion);
    } else {
      await _prefs.remove(_aiPolicyKey);
    }
  }

  /// Id of the entry saved in OB07; Back to OB07 then edits that entry
  /// instead of creating another.
  String? get firstEntryId => _prefs.getString(_firstEntryKey);

  Future<void> saveFirstEntryId(String id) =>
      _prefs.setString(_firstEntryKey, id);

  /// Reminders the OS actually accepted at OB10, by slot; empty when none
  /// (skipped, turned off, refused or failed). A draft is never stored.
  Map<ReminderSlot, ReminderTime> get reminders => {
        for (final item in _prefs.getStringList(_remindersKey) ?? const [])
          if (item.split('@') case [final slot, final time])
            if (ReminderSlot.values.asNameMap()[slot] case final slot?)
              if (ReminderTime.tryParse(time) case final time?) slot: time,
      };

  Future<void> saveReminders(Map<ReminderSlot, ReminderTime> reminders) =>
      _prefs.setStringList(_remindersKey, [
        for (final MapEntry(:key, :value) in reminders.entries)
          '${key.name}@${value.label}',
      ]);

  /// Development only: forgets every onboarding answer and the progress,
  /// so the flow starts again at OB01. Journal entries are not touched.
  Future<void> reset() async {
    for (final key in _prefs.getKeys().toList()) {
      if (key.startsWith('onboarding.')) await _prefs.remove(key);
    }
  }

  /// Throws when "done" could not be saved; the saved route (OB11) then
  /// stays, so the next launch resumes there with every answer kept.
  Future<void> complete() async {
    if (!await _prefs.setBool(_completedKey, true)) {
      throw StateError('Could not save $_completedKey');
    }
    try {
      await _prefs.remove(_stepKey);
    } catch (_) {
      // Done is saved and wins at launch; a stale route is never read.
    }
  }
}
