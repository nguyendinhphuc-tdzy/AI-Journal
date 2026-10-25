import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/album/album_scope.dart';
import 'features/album/data/album_repository.dart';
import 'features/journal/data/journal_repository.dart';
import 'features/journal/journal_scope.dart';
import 'features/onboarding/data/onboarding_store.dart';
import 'features/onboarding/onboarding_flow.dart';
import 'features/onboarding/presentation/first_entry_session.dart';
import 'navigation/app_shell.dart';

const appName = 'Nhật ký AI';

/// Opt in with `--dart-define=ONBOARDING=true`. OB11 now completes the flow;
/// making onboarding the default launch is a separate decision.
const _showOnboarding = bool.fromEnvironment('ONBOARDING');

/// Development: `--dart-define=ONBOARDING_RESET=true` starts onboarding
/// again at OB01 on every launch and hot restart (answers, progress and the
/// OB07 draft are cleared; saved journal entries are kept).
const _resetOnboarding = bool.fromEnvironment('ONBOARDING_RESET');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final journals = await LocalJournalRepository.open();
  final albums = await LocalAlbumRepository.open();
  final onboarding =
      _showOnboarding || _resetOnboarding ? await OnboardingStore.open() : null;
  if (_resetOnboarding) {
    await onboarding!.reset();
    await journals.deleteDraft(FirstEntrySession.draftKey);
  }
  runApp(
      AiDiaryApp(journals: journals, albums: albums, onboarding: onboarding));
}

class AiDiaryApp extends StatefulWidget {
  const AiDiaryApp({super.key, this.journals, this.albums, this.onboarding});

  /// The journal store; an in-memory one when not given (tests).
  final JournalRepository? journals;

  /// The album store; an in-memory one when not given (tests).
  final AlbumRepository? albums;

  /// When set and not completed, launch goes through onboarding.
  final OnboardingStore? onboarding;

  @override
  State<AiDiaryApp> createState() => _AiDiaryAppState();
}

class _AiDiaryAppState extends State<AiDiaryApp> {
  late final JournalRepository _journals =
      widget.journals ?? InMemoryJournalRepository();
  late final AlbumRepository _albums =
      widget.albums ?? InMemoryAlbumRepository();

  @override
  Widget build(BuildContext context) {
    final onboarding = widget.onboarding;
    return JournalScope(
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
                  // Done is saved: rebuild, and Home replaces the flow.
                  onComplete: () => setState(() {}),
                ),
        ),
      ),
    );
  }
}
