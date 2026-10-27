import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/app_config.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/data/auth_service.dart';
import 'features/auth/presentation/auth_gate.dart';
import 'features/album/album_scope.dart';
import 'features/album/data/album_repository.dart';
import 'features/journal/data/api_ai_service.dart';
import 'features/sound/app_sound.dart';
import 'features/journal/data/journal_repository.dart';
import 'features/journal/journal_scope.dart';
import 'features/onboarding/data/onboarding_scope.dart';
import 'features/onboarding/data/onboarding_store.dart';
import 'features/onboarding/onboarding_flow.dart';
import 'features/onboarding/presentation/first_entry_session.dart';
import 'navigation/app_shell.dart';

const appName = 'Nhật ký AI';
const _showOnboarding = bool.fromEnvironment('ONBOARDING');
const _resetOnboarding = bool.fromEnvironment('ONBOARDING_RESET');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // An explicitly requested Auth flow or release build fails closed if the
  // public URL/publishable key are missing. No local demo in release.
  if (kReleaseMode || AppConfig.authEnabled || AppConfig.supabaseConfigured) {
    if (!AppConfig.supabaseConfigured) {
      runApp(const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text('Thiếu cấu hình Supabase Auth. Không thể đăng nhập.'),
          ),
        ),
      ));
      return;
    }
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      publishableKey: AppConfig.supabasePublishableKey,
    );
    runApp(AiDiaryApp(
      auth: SupabaseAuthService(Supabase.instance.client),
    ));
    return;
  }

  // Preserve the original unscoped local demo and its existing data.
  final journals = await LocalJournalRepository.open();
  final albums = await LocalAlbumRepository.open();
  final onboarding =
      _showOnboarding || _resetOnboarding ? await OnboardingStore.open() : null;
  if (_resetOnboarding) {
    await onboarding!.reset();
    await journals.deleteDraft(FirstEntrySession.draftKey);
  }
  runApp(AiDiaryApp(
    journals: journals,
    albums: albums,
    onboarding: onboarding,
  ));
}

class AiDiaryApp extends StatefulWidget {
  const AiDiaryApp({
    super.key,
    this.journals,
    this.albums,
    this.onboarding,
    this.ai,
    this.auth,
  });

  /// Injected fake auth in tests, real Supabase Auth in configured builds.
  final AuthService? auth;

  final JournalRepository? journals;
  final AlbumRepository? albums;
  final OnboardingStore? onboarding;

  /// An explicit, authenticated AI service (not present for device-only demo).
  final ApiAIService? ai;

  @override
  State<AiDiaryApp> createState() => _AiDiaryAppState();
}

class _AiDiaryAppState extends State<AiDiaryApp> {
  @override
  void initState() {
    super.initState();
    // New sound UI from PR29 must start in AuthGate as well as local demo.
    AppSound.instance.start();
  }

  late final JournalRepository _journals =
      widget.journals ?? InMemoryJournalRepository();
  late final AlbumRepository _albums =
      widget.albums ?? InMemoryAlbumRepository();

  @override
  Widget build(BuildContext context) {
    if (widget.auth != null) {
      // AuthGate owns user-scoped Journal, Album, onboarding and AI service.
      return AuthGate(
        auth: widget.auth!,
        showOnboarding: _showOnboarding,
        resetOnboarding: _resetOnboarding,
      );
    }

    final onboarding = widget.onboarding;
    final app = JournalScope(
      repository: _journals,
      child: AlbumScope(
        repository: _albums,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          title: appName,
          theme: AppTheme.light,
          home: onboarding == null || onboarding.completed
              ? const AppShell()
              : OnboardingFlow(
                  store: onboarding,
                  brandName: appName,
                  reflections: widget.ai,
                  onComplete: () => setState(() {}),
                ),
        ),
      ),
    );
    final scoped = onboarding == null
        ? app
        : OnboardingScope(store: onboarding, child: app);
    final ai = widget.ai;
    return ai == null ? scoped : AiRemoteScope(service: ai, child: scoped);
  }
}
