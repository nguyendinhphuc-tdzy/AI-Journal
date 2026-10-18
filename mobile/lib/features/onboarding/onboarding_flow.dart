import 'package:flutter/material.dart';

import '../journal/data/journal_entry.dart';
import '../journal/data/reflection_service.dart';
import '../journal/journal_scope.dart';
import '../reminders/data/reminder_service.dart';
import 'data/data_policy.dart';
import 'data/journal_goal.dart';
import 'data/journaling_experience.dart';
import 'data/onboarding_store.dart';
import 'presentation/falling_petals.dart';
import 'presentation/first_entry_session.dart';
import 'presentation/first_reflection.dart';
import 'presentation/onboarding_ai_data_screen.dart';
import 'presentation/onboarding_entry_saved_screen.dart';
import 'presentation/onboarding_experience_screen.dart';
import 'presentation/onboarding_features_screen.dart';
import 'presentation/onboarding_first_entry_screen.dart';
import 'presentation/onboarding_nickname_screen.dart';
import 'presentation/onboarding_preparing_screen.dart';
import 'presentation/onboarding_purpose_screen.dart';
import 'presentation/onboarding_ready_screen.dart';
import 'presentation/onboarding_reminder_screen.dart';
import 'presentation/onboarding_welcome_screen.dart';

/// Onboarding entry (OB01 → OB11 → Home). Resumes at the saved route and
/// saves every route change, so closing the app mid-way picks up there.
///
/// OB01 → OB02 plays a wind transition: the OB01 petals are carried off, a
/// gust of petals crosses the screen and OB02 appears part by part.
class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({
    super.key,
    required this.store,
    required this.brandName,
    this.reflections,
    this.reminders,
    this.onComplete,
  });

  final OnboardingStore store;

  /// AI reflections; the deterministic stand-in when not given.
  final ReflectionService? reflections;

  /// Local reminders (OB10); the stand-in when not given, configurable with
  /// `--dart-define=REMINDER_SIM`.
  final ReminderService? reminders;

  /// Display name from the app config; never hard-coded per screen.
  final String brandName;

  /// OB11 saved onboarding as done: replace the flow with Home.
  final VoidCallback? onComplete;

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow>
    with SingleTickerProviderStateMixin {
  late OnboardingStep _step = widget.store.step;

  /// OB01 → OB02 wind, 0 → 1. Reset to 0 when done, so OB01 shows its
  /// petals again after Back.
  late final AnimationController _gust =
      AnimationController(vsync: this, duration: PetalGust.duration)
        ..addListener(_onGust)
        ..addStatusListener((status) {
          if (status == AnimationStatus.completed) _gust.value = 0;
        });

  /// Share of the gust after which OB02 replaces OB01: the petals are already
  /// racing away, and the rest of the gust crosses OB02 as it appears.
  static const _switchAt = .34;

  /// OB02 text as typed, kept across Back so nothing is lost.
  late String _nicknameDraft = widget.store.nickname ?? '';

  /// OB03 selection, kept across Back until saved or skipped.
  late JournalGoal? _goalDraft = widget.store.goal;

  /// OB04 selection, kept across Back until saved or skipped.
  late JournalingExperience? _experienceDraft = widget.store.experience;

  /// OB07 fields, mood and draft, kept across Back; writes to the shared
  /// journal store.
  FirstEntrySession? _firstEntry;

  /// OB10 rows as edited, kept across Back; starts from what was saved.
  late Map<ReminderSlot, ReminderChoice> _reminderDraft =
      ReminderChoice.draftFrom(widget.store.reminders);

  late final ReminderService _reminders =
      widget.reminders ?? SimulatedReminderService.fromEnvironment();

  /// AI reflection on the first entry; asked only after a save, AI on.
  late final FirstReflection _reflection = FirstReflection(
      service: widget.reflections ?? MockReflectionService(),
      store: widget.store);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _firstEntry ??= FirstEntrySession(
        journals: JournalScope.of(context), store: widget.store);
  }

  /// OB07 done (saved, or unchanged). AI off: straight to OB09 (no fake
  /// "analysing" screen). AI on: ask for a reflection (reusing one for the
  /// same body version); OB08 only while it is actually running.
  void _firstEntryDone(JournalEntry entry) {
    if (widget.store.aiEnabled != true) {
      _goTo(OnboardingStep.entrySaved);
      return;
    }
    _reflection.request(entry);
    _goTo(_reflection.status == ReflectionStatus.pending
        ? OnboardingStep.saving
        : OnboardingStep.entrySaved);
  }

  void _goTo(OnboardingStep step) {
    setState(() => _step = step);
    widget.store.saveStep(step);
  }

  /// "Bắt đầu": the session is saved at once, so closing the app during the
  /// transition still resumes at OB02. Extra taps are ignored.
  void _start() {
    if (_gust.isAnimating || _step != OnboardingStep.welcome) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _goTo(OnboardingStep.nickname);
      return;
    }
    widget.store.saveStep(OnboardingStep.nickname);
    _gust.forward(from: 0);
  }

  void _onGust() {
    if (_step == OnboardingStep.welcome && _gust.value >= _switchAt) {
      setState(() => _step = OnboardingStep.nickname);
    }
  }

  @override
  void dispose() {
    _gust.dispose();
    _firstEntry?.dispose();
    _reflection.dispose();
    super.dispose();
  }

  /// Checkpoint: the nickname is saved before moving on to OB03.
  Future<void> _saveNickname(String? nickname) async {
    await widget.store.saveNickname(nickname);
    if (mounted) _goTo(OnboardingStep.purpose);
  }

  /// Saves the OB03 goal (null for "Để sau"), then OB04.
  Future<void> _saveGoal(JournalGoal? goal) async {
    _goalDraft = goal;
    await widget.store.saveGoal(goal);
    if (mounted) _goTo(OnboardingStep.experience);
  }

  /// Saves the OB04 answer ([JournalingExperience.unknown] for "Để sau"),
  /// then OB05.
  Future<void> _saveExperience(JournalingExperience experience) async {
    _experienceDraft = experience;
    await widget.store.saveExperience(experience);
    if (mounted) _goTo(OnboardingStep.features);
  }

  /// OB06: records the AI choice (and the policy version, when the policy
  /// has one) for the next requests, then OB07. Sends nothing.
  Future<void> _saveAiChoice(bool enabled) async {
    await widget.store.saveAiChoice(
        enabled: enabled, policyVersion: DataPolicy.current.version);
    // AI off from now on: stop waiting; a late response is ignored.
    if (!enabled) _reflection.cancel();
    if (mounted) _goTo(OnboardingStep.firstEntry);
  }

  /// OB10 done: records the reminders actually scheduled (maybe none), then
  /// OB11.
  Future<void> _saveReminders(Map<ReminderSlot, ReminderTime> scheduled) async {
    await widget.store.saveReminders(scheduled);
    if (mounted) _goTo(OnboardingStep.ready);
  }

  /// OB11 "Vào không gian của mình": done is saved first, then Home. False
  /// when it could not be saved; OB11 stays and offers a retry.
  Future<bool> _complete() async {
    try {
      await widget.store.complete();
    } catch (_) {
      return false;
    }
    widget.onComplete?.call();
    return true;
  }

  /// The step Back returns to. OB08 is transient and skipped; OB10 returns to
  /// the saved entry, or to OB07 when the user chose to write later.
  OnboardingStep _previous(OnboardingStep step) => switch (step) {
        OnboardingStep.saving ||
        OnboardingStep.entrySaved =>
          OnboardingStep.firstEntry,
        OnboardingStep.reminder => widget.store.firstEntryId == null
            ? OnboardingStep.firstEntry
            : OnboardingStep.entrySaved,
        _ => OnboardingStep.values[step.index - 1],
      };

  void _back() {
    if (_step == OnboardingStep.welcome) return;
    final previous = _previous(_step);
    // Back before the gust is over: stop it, or it would switch again.
    if (previous == OnboardingStep.welcome) _gust.value = 0;
    _goTo(previous);
  }

  /// The next step fades in over the current one, which stays fully drawn
  /// underneath until removed. A plain cross-fade leaves both half see-through
  /// halfway, so the background dims and the top bar blinks between steps.
  static Widget _fadeInOver(Widget child, Animation<double> animation) =>
      AnimatedBuilder(
        animation: animation,
        child: child,
        builder: (context, child) => Opacity(
          opacity:
              animation.status == AnimationStatus.reverse ? 1 : animation.value,
          child: child,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    final flow = PopScope(
      canPop: _step == OnboardingStep.welcome,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: AnimatedSwitcher(
        duration: Duration(milliseconds: reduced ? 120 : 280),
        transitionBuilder: _fadeInOver,
        child: KeyedSubtree(
          key: ValueKey(_step),
          child: switch (_step) {
            OnboardingStep.welcome => OnboardingWelcomeScreen(
                brandName: widget.brandName,
                onStart: _start,
                gust: _gust,
              ),
            OnboardingStep.nickname => OnboardingNicknameScreen(
                initialValue: _nicknameDraft,
                onChanged: (value) => _nicknameDraft = value,
                onBack: _back,
                onContinue: _saveNickname,
              ),
            OnboardingStep.purpose => OnboardingPurposeScreen(
                nickname: widget.store.nickname,
                initialGoal: _goalDraft,
                onChanged: (goal) => _goalDraft = goal,
                onBack: _back,
                onContinue: _saveGoal,
                onSkip: () => _saveGoal(null),
              ),
            OnboardingStep.experience => OnboardingExperienceScreen(
                initialExperience: _experienceDraft,
                onChanged: (experience) => _experienceDraft = experience,
                onBack: _back,
                onContinue: _saveExperience,
                onSkip: () => _saveExperience(JournalingExperience.unknown),
              ),
            OnboardingStep.features => OnboardingFeaturesScreen(
                onBack: _back,
                onContinue: () => _goTo(OnboardingStep.aiAndData),
              ),
            OnboardingStep.aiAndData => OnboardingAiDataScreen(
                onBack: _back,
                onChoose: _saveAiChoice,
              ),
            OnboardingStep.firstEntry => OnboardingFirstEntryScreen(
                session: _firstEntry!,
                onBack: _back,
                // AI only after a successful save, and only when chosen.
                onDone: _firstEntryDone,
                onSkip: () => _goTo(OnboardingStep.reminder),
              ),
            OnboardingStep.saving => OnboardingPreparingScreen(
                reflection: _reflection,
                onBack: _back,
                onLeave: () => _goTo(OnboardingStep.entrySaved),
              ),
            OnboardingStep.entrySaved => OnboardingEntrySavedScreen(
                session: _firstEntry!,
                reflection: _reflection,
                aiEnabled: widget.store.aiEnabled == true,
                onBack: _back,
                onContinue: () => _goTo(OnboardingStep.reminder),
              ),
            OnboardingStep.reminder => OnboardingReminderScreen(
                service: _reminders,
                initialDraft: _reminderDraft,
                onChanged: (draft) => _reminderDraft = draft,
                onBack: _back,
                onDone: _saveReminders,
                // "Để sau": the draft is not applied.
                onSkip: () => _goTo(OnboardingStep.ready),
              ),
            OnboardingStep.ready => OnboardingReadyScreen(
                nickname: widget.store.nickname,
                session: _firstEntry!,
                reminders: widget.store.reminders,
                remindersSimulated: _reminders.simulated,
                onBack: _back,
                onEnter: _complete,
              ),
          },
        ),
      ),
    );
    if (reduced) return flow;
    return Stack(
      fit: StackFit.expand,
      children: [flow, PetalGust(gust: _gust)],
    );
  }
}
