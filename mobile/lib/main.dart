import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/app_config.dart';
import 'features/auth/data/auth_service.dart';
import 'features/auth/presentation/auth_gate.dart';

import 'core/theme/app_theme.dart';
import 'features/journal/data/journal_repository.dart';
import 'features/journal/journal_scope.dart';
import 'features/onboarding/data/onboarding_store.dart';
import 'features/onboarding/onboarding_flow.dart';
import 'features/onboarding/presentation/first_entry_session.dart';
import 'navigation/app_shell.dart';

const appName = 'AI Diary';

/// Opt in with `--dart-define=ONBOARDING=true`. OB11 now completes the flow;
/// making onboarding the default launch is a separate decision.
const _showOnboarding = bool.fromEnvironment('ONBOARDING');

/// Development: `--dart-define=ONBOARDING_RESET=true` starts onboarding
/// again at OB01 on every launch and hot restart (answers, progress and the
/// OB07 draft are cleared; saved journal entries are kept).
const _resetOnboarding = bool.fromEnvironment('ONBOARDING_RESET');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (AppConfig.authEnabled || AppConfig.supabaseConfigured) {
    if (!AppConfig.supabaseConfigured) {
      runApp(const MaterialApp(
        home: Scaffold(
          body: Center(child: Text(
            'Thiếu SUPABASE_URL hoặc SUPABASE_PUBLISHABLE_KEY. '
            'Không cho phép bỏ qua đăng nhập.',
            textAlign: TextAlign.center,
          )),
        ),
      ));
      return;
    }
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      anonKey: AppConfig.supabasePublishableKey,
    );
    runApp(AiDiaryApp(auth: SupabaseAuthService(Supabase.instance.client)));
    return;
  }

  // Existing non-auth demo remains available for UI development/tests.
  final journals = await LocalJournalRepository.open();
  final onboarding =
      _showOnboarding || _resetOnboarding ? await OnboardingStore.open() : null;
  if (_resetOnboarding) {
    await onboarding!.reset();
    await journals.deleteDraft(FirstEntrySession.draftKey);
  }
  runApp(AiDiaryApp(journals: journals, onboarding: onboarding));
}

class AiDiaryApp extends StatefulWidget {
  const AiDiaryApp({super.key, this.journals, this.onboarding, this.auth});

  /// Optional real Supabase auth; demo tests can omit it.
  final AuthService? auth;

  /// The journal store; an in-memory one when not given (tests).
  final JournalRepository? journals;

  /// When set and not completed, launch goes through onboarding.
  final OnboardingStore? onboarding;

  @override
  State<AiDiaryApp> createState() => _AiDiaryAppState();
}

class _AiDiaryAppState extends State<AiDiaryApp> {
  late final JournalRepository _journals =
      widget.journals ?? InMemoryJournalRepository();

  @override
  Widget build(BuildContext context) {
    if (widget.auth != null) {
      // A new MaterialApp and user-scoped JournalScope are owned by AuthGate.
      return AuthGate(
        auth: widget.auth!,
        showOnboarding: _showOnboarding,
        resetOnboarding: _resetOnboarding,
      );
    }
    final onboarding = widget.onboarding;
    return JournalScope(
      repository: _journals,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: appName,
        theme: AppTheme.light,
        home: onboarding == null || onboarding.completed
            ? const AppShell()
            : OnboardingFlow(
                store: onboarding,
                brandName: appName,
                // Done is saved: rebuild, and Home replaces the flow.
                onComplete: () => setState(() {}),
              ),
      ),
    );
  }
}
