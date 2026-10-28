import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/album/album_scope.dart';
import 'features/album/data/album_repository.dart';
import 'features/album/data/album_sharing.dart';
import 'features/album/data/memory_share.dart';
import 'features/journal/data/journal_repository.dart';
import 'features/journal/journal_scope.dart';
import 'features/onboarding/data/onboarding_store.dart';
import 'features/onboarding/data/sign_in_service.dart';
import 'features/onboarding/onboarding_flow.dart';
import 'features/onboarding/presentation/first_entry_session.dart';
import 'features/social/data/friend_space.dart';
import 'features/social/data/friends_account.dart';
import 'features/social/data/friends_sharing.dart';
import 'features/sound/app_sound.dart';
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
  // Facebook login is simulated until the backend has it.
  final friends = MockFriendsAccount.instance;
  await friends.restore();
  await FriendSpace.instance.restore();
  await MockSignInService.instance.restore();
  runApp(AiDiaryApp(
      journals: journals,
      albums: albums,
      onboarding: onboarding,
      friends: friends));
}

class AiDiaryApp extends StatefulWidget {
  const AiDiaryApp(
      {super.key, this.journals, this.albums, this.onboarding, this.friends});

  /// The journal store; an in-memory one when not given (tests).
  final JournalRepository? journals;

  /// The album store; an in-memory one when not given (tests).
  final AlbumRepository? albums;

  /// When set and not completed, launch goes through onboarding.
  final OnboardingStore? onboarding;

  /// Friends on the app (Facebook login), for 24-hour shares; without it
  /// nothing can be shared (tests).
  final FriendsAccount? friends;

  @override
  State<AiDiaryApp> createState() => _AiDiaryAppState();
}

class _AiDiaryAppState extends State<AiDiaryApp> {
  late final JournalRepository _journals =
      widget.journals ?? InMemoryJournalRepository();
  late final AlbumRepository _albums =
      widget.albums ?? InMemoryAlbumRepository();

  late final MockFriendsSharing? _sharing = widget.friends == null
      ? null
      : MockFriendsSharing(widget.friends!, FriendSpace.instance);
  AlbumSharing get _albumSharing {
    final AlbumSharing? sharing = _sharing;
    return sharing ?? const NoAlbumPublishing();
  }

  MemorySharing get _memorySharing {
    final MemorySharing? sharing = _sharing;
    return sharing ?? const NoAlbumPublishing();
  }

  @override
  void initState() {
    super.initState();
    // The music, by the sound settings, from the first screen on.
    AppSound.instance.start();
  }

  @override
  Widget build(BuildContext context) {
    final onboarding = widget.onboarding;
    return JournalScope(
      repository: _journals,
      child: AlbumScope(
        repository: _albums,
        sharing: _albumSharing,
        memorySharing: _memorySharing,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          title: appName,
          theme: AppTheme.light,
          scrollBehavior: const AppScrollBehavior(),
          home: onboarding == null || onboarding.completed
              ? const AppShell()
              : OnboardingFlow(
                  store: onboarding,
                  friends: widget.friends,
                  brandName: appName,
                  // Done is saved: rebuild, and Home replaces the flow.
                  onComplete: () => setState(() {}),
                ),
        ),
      ),
    );
  }
}
