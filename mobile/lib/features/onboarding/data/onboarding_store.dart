import 'package:shared_preferences/shared_preferences.dart';

import '../../reminders/data/reminder_service.dart';
import 'journal_goal.dart';
import 'data_policy.dart';
import 'journaling_experience.dart';

/// Onboarding routes OB01–OB11. Names are persisted; do not rename.
enum OnboardingStep {
  welcome, // OB01
  signIn, // OB01b: account (email, Google, Facebook), or later
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

  /// 1-based progress position. OB01 and the sign-in before the questions
  /// have no progress; the transient OB08 keeps OB07's position.
  int? get progressPosition => switch (this) {
        welcome || signIn => null,
        saving => firstEntry.progressPosition,
        _ when index < saving.index => index - 1,
        _ => index - 2,
      };
}

/// Local onboarding state: the route to resume and whether onboarding is
/// done. Only OB11 may call [complete].
class OnboardingStore {
  OnboardingStore._(this._prefs, this.userId);

  final String? userId;
  String _key(String key) => userId == null ? key : 'account.$userId.$key';
  bool get consentedToRemoteAi => aiEnabled == true &&
      aiPolicyVersion == DataPolicy.localOllama.version;

  static Future<OnboardingStore> open({String? userId}) async =>
      OnboardingStore._(await SharedPreferences.getInstance(), userId);

  final SharedPreferences _prefs;

  static const _completedKey = 'onboarding.completed';
  static const _stepKey = 'onboarding.step';
  static const _nicknameKey = 'onboarding.nickname';
  static const _goalKey = 'onboarding.goal';
  static const _experienceKey = 'onboarding.experience';
  static const _aiKey = 'onboarding.ai';
  static const _aiPolicyKey = 'onboarding.aiPolicyVersion';
  static const _aiInAppKey = 'onboarding.aiInApp';
  static const _firstEntryKey = 'onboarding.firstEntryId';
  static const _remindersKey = 'onboarding.reminders';

  bool get completed => _prefs.getBool(_key(_completedKey)) ?? false;

  /// Saved route, or OB01 when no session was started.
  OnboardingStep get step =>
      OnboardingStep.values.asNameMap()[_prefs.getString(_key(_stepKey))] ??
      OnboardingStep.welcome;

  Future<void> saveStep(OnboardingStep step) =>
      _prefs.setString(_key(_stepKey), step.name);

  /// Saved nickname; null when the user left it empty.
  String? get nickname => _prefs.getString(_key(_nicknameKey));

  Future<void> saveNickname(String? nickname) => nickname == null
      ? _prefs.remove(_key(_nicknameKey))
      : _prefs.setString(_key(_nicknameKey), nickname);

  /// OB03 goal; null when skipped ("Để sau") or not asked yet. Changing it
  /// touches nothing else: entries and drafts stay as they are.
  JournalGoal? get goal =>
      JournalGoal.values.asNameMap()[_prefs.getString(_key(_goalKey))];

  Future<void> saveGoal(JournalGoal? goal) => goal == null
      ? _prefs.remove(_key(_goalKey))
      : _prefs.setString(_key(_goalKey), goal.name);

  /// OB04 answer: null when not asked yet, [JournalingExperience.unknown]
  /// after "Để sau".
  JournalingExperience? get experience =>
      JournalingExperience.values.asNameMap()[_prefs.getString(_key(_experienceKey))];

  Future<void> saveExperience(JournalingExperience experience) =>
      _prefs.setString(_key(_experienceKey), experience.name);

  /// OB06 AI choice: null until the user picks one of the two paths. Only
  /// about AI reflections; it is not marketing consent, notification
  /// permission or permission to publish anything.
  bool? get aiEnabled => switch (_prefs.getString(_key(_aiKey))) {
        'on' => true,
        'off' => false,
        _ => null,
      };

  /// Policy version the AI choice was made under, when the policy has one.
  String? get aiPolicyVersion => _prefs.getString(_key(_aiPolicyKey));

  /// Applies to the next requests only; it cannot recall anything sent
  /// before.
  Future<void> saveAiChoice(
      {required bool enabled, String? policyVersion}) async {
    await _prefs.setString(_key(_aiKey), enabled ? 'on' : 'off');
    if (enabled && policyVersion != null) {
      await _prefs.setString(_key(_aiPolicyKey), policyVersion);
    } else {
      await _prefs.remove(_key(_aiPolicyKey));
    }
  }

  /// Hồ sơ's "Phản hồi AI": AI in the app (on save, "Nhìn lại cùng bạn")
  /// for a signed-in account. On unless turned off there; the onboarding
  /// choice does not turn it off.
  bool get aiInApp => _prefs.getString(_key(_aiInAppKey)) != 'off';

  Future<void> saveAiInApp(bool on) =>
      _prefs.setString(_key(_aiInAppKey), on ? 'on' : 'off');

  /// Id of the entry saved in OB07; Back to OB07 then edits that entry
  /// instead of creating another.
  String? get firstEntryId => _prefs.getString(_key(_firstEntryKey));

  Future<void> saveFirstEntryId(String id) =>
      _prefs.setString(_key(_firstEntryKey), id);

  /// Reminders the OS actually accepted at OB10, by slot; empty when none
  /// (skipped, turned off, refused or failed). A draft is never stored.
  Map<ReminderSlot, ReminderTime> get reminders => {
        for (final item in _prefs.getStringList(_key(_remindersKey)) ?? const [])
          if (item.split('@') case [final slot, final time])
            if (ReminderSlot.values.asNameMap()[slot] case final slot?)
              if (ReminderTime.tryParse(time) case final time?) slot: time,
      };

  Future<void> saveReminders(Map<ReminderSlot, ReminderTime> reminders) =>
      _prefs.setStringList(_key(_remindersKey), [
        for (final MapEntry(:key, :value) in reminders.entries)
          '${key.name}@${value.label}',
      ]);

  /// Development only: forgets every onboarding answer and the progress,
  /// so the flow starts again at OB01. Journal entries are not touched.
  Future<void> reset() async {
    for (final key in _prefs.getKeys().toList()) {
      if (userId == null ? key.startsWith('onboarding.')
          : key.startsWith('account.$userId.onboarding.')) {
        await _prefs.remove(key);
      }
    }
  }

  /// Throws when "done" could not be saved; the saved route (OB11) then
  /// stays, so the next launch resumes there with every answer kept.
  Future<void> complete() async {
    if (!await _prefs.setBool(_key(_completedKey), true)) {
      throw StateError('Could not save $_completedKey');
    }
    try {
      await _prefs.remove(_key(_stepKey));
    } catch (_) {
      // Done is saved and wins at launch; a stale route is never read.
    }
  }
}
