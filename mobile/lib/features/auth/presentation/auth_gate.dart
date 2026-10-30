import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/data/app_data.dart';
import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../album/album_scope.dart';
import '../../album/data/album_pins.dart';
import '../../album/presentation/album_pin_sheet.dart';
import '../../study/data/study_progress.dart';
import '../../album/data/album_repository.dart';
import '../../album/data/remote_album_repository.dart';
import '../../explore/data/remote_saved_places_repository.dart';
import '../../explore/data/place_lookup.dart';
import '../../album/data/memory_photos.dart';
import '../../album/data/album_settings.dart';
import '../../album/data/album_unlocks.dart';
import '../../album/data/memory_share.dart';
import '../../album/data/album_sharing.dart';
import '../../social/data/friends_sharing.dart';
import '../../messages/data/messages_repository.dart';
import '../../messages/messages_scope.dart';
import '../../journal/data/api_ai_service.dart';
import '../../journal/data/remote_journal_repository.dart';
import '../../onboarding/data/onboarding_scope.dart';
import '../../../core/theme/app_theme.dart';
import '../../../navigation/app_shell.dart';
import '../../journal/data/journal_repository.dart';
import '../../journal/journal_scope.dart';
import '../../onboarding/data/onboarding_store.dart';
import '../../onboarding/onboarding_flow.dart';
import '../../onboarding/presentation/first_entry_session.dart';
import '../../streak/streak_state.dart';
import '../data/auth_service.dart';
import '../data/guest_mode_store.dart';
import '../../onboarding/data/sign_in_service.dart';
import '../../onboarding/presentation/onboarding_sign_in_screen.dart';

/// Auth scope is above MaterialApp, so pushed routes see the active session.
class AuthScope extends InheritedWidget {
  const AuthScope({super.key, required this.auth, required super.child});
  final AuthService auth;

  static AuthService? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AuthScope>()?.auth;

  @override
  bool updateShouldNotify(AuthScope oldWidget) => oldWidget.auth != auth;
}

/// Guest mode has no Supabase user, token or cloud persistence.
class GuestScope extends InheritedWidget {
  const GuestScope({super.key, required this.onLeaveGuest, required super.child});

  final Future<void> Function() onLeaveGuest;

  static GuestScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<GuestScope>();

  @override
  bool updateShouldNotify(GuestScope oldWidget) =>
      oldWidget.onLeaveGuest != onLeaveGuest;
}

class AuthGate extends StatefulWidget {
  const AuthGate({
    super.key,
    required this.auth,
    this.showOnboarding = false,
    this.resetOnboarding = false,
  });

  final AuthService auth;
  final bool showOnboarding;
  final bool resetOnboarding;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  StreamSubscription<String?>? _subscription;
  late final Future<GuestModeStore> _guestStore = GuestModeStore.open();
  late String? _userId = widget.auth.currentUserId;
  late final SupabaseSignInAdapter _signInService =
      SupabaseSignInAdapter(widget.auth);
  bool _guestReady = false;
  bool _guestSelected = false;
  String? _localError;

  @override
  void initState() {
    super.initState();
    // Preview quotes are process-wide demo state: never carry them between
    // the guest and two different Supabase identities.
    _resetTransientPreview();
    _restoreGuest();
    _subscription = widget.auth.userChanges.listen((id) async {
      if (id != _userId) _resetTransientPreview();
      if (id != null) {
        try {
          await (await _guestStore).deactivate();
        } catch (_) {
          // Do not turn a confirmed Supabase session into a guest session.
        }
      }
      if (mounted) {
        setState(() {
          _userId = id;
          _guestSelected = id == null ? _guestSelected : false;
        });
      }
    }, onError: (Object error, StackTrace stack) {
      // OAuth can fail after returning from an external browser; surface a
      // helpful error on the login screen rather than silently ignoring it.
      if (mounted) {
        setState(() => _localError =
            'Đăng nhập chưa hoàn tất. Vui lòng thử lại.');
      }
    });
  }

  void _resetTransientPreview() {
    savedThisWeekItems.value = [];
    StreakState.shared.resetForNewLocalSession();
    AlbumSettingsDraft.session.clear();
    MemoryShareDraft.clearOnSessionChange();
    AlbumUnlocks.instance.lockAll();
  }

  Future<void> _restoreGuest() async {
    try {
      final guest = await _guestStore;
      if (!mounted) return;
      setState(() {
        _guestSelected = _userId == null && guest.isActive;
        _guestReady = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _guestReady = true;
        _localError = 'Không thể đọc chế độ khách trên thiết bị.';
      });
    }
  }

  Future<void> _continueAsGuest() async {
    if (_userId != null) return;
    final guest = await _guestStore;
    await guest.enter();
    _resetTransientPreview();
    if (!mounted) return;
    setState(() {
      _guestSelected = true;
      _localError = null;
    });
  }

  Future<void> _leaveGuest() async {
    final guest = await _guestStore;
    // Remove guest-owned album photo copies before clearing guest metadata.
    // Failure must not pretend that all private guest content was deleted.
    await DeviceMemoryPhotos.discardGuestFolder();
    await guest.leaveAndDiscard();
    _resetTransientPreview();
    if (!mounted) return;
    setState(() {
      _guestSelected = false;
      _localError = null;
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_guestReady) {
      return const MaterialApp(
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }
    if (_userId != null) {
      return _LocalSessionHome(
        key: ValueKey('auth-$_userId'),
        userId: _userId!,
        auth: widget.auth,
        resetOnboarding: widget.resetOnboarding,
      );
    }
    if (_guestSelected) {
      return _LocalSessionHome(
        key: const ValueKey('device-guest'),
        userId: GuestModeStore.userId,
        onLeaveGuest: _leaveGuest,
        resetOnboarding: widget.resetOnboarding,
      );
    }
    return MaterialApp(
      title: 'AI Diary',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      scrollBehavior: const AppScrollBehavior(),
      home: OnboardingSignInScreen(
        service: _signInService,
        realAuth: true,
        initialError: _localError,
        onBack: () {},
        onDone: () {}, // AuthGate reacts to the Supabase session stream.
        onGuest: _continueAsGuest,
      ),
    );
  }
}

class _LocalSessionHome extends StatefulWidget {
  const _LocalSessionHome({
    super.key,
    required this.userId,
    this.auth,
    this.onLeaveGuest,
    required this.resetOnboarding,
  }) : assert((auth == null) != (onLeaveGuest == null));

  final String userId;
  final AuthService? auth;
  final Future<void> Function()? onLeaveGuest;
  final bool resetOnboarding;

  @override
  State<_LocalSessionHome> createState() => _LocalSessionHomeState();
}

class _LocalSessionHomeState extends State<_LocalSessionHome> {
  // Only real authenticated Supabase sessions can request remote AI.
  // Never attach a network provider to guest or test fake-auth sessions.
  late final ApiClient? _api = widget.auth is SupabaseAuthService
      ? ApiClient(
          accessTokenProvider: () async => (widget.auth as SupabaseAuthService)
              .client.auth.currentSession?.accessToken,
          accessTokenRefresher: () async =>
              (await (widget.auth as SupabaseAuthService)
                      .client.auth.refreshSession())
                  .session?.accessToken,
        )
      : null;
  late final ApiAIService? _ai = _api == null ? null : ApiAIService(_api);

  /// Messages between friends; guests have none.
  late final MessagesController? _messages = _api == null
      ? null
      : MessagesController(
          RemoteMessagesRepository(_api, myId: widget.userId));

  /// A10's audience and posts: the account's friends on the app. Guests
  /// have none.
  late final RemoteFriendsSharing? _friendsSharing =
      _api == null ? null : RemoteFriendsSharing(_api);

  late final Future<({
    JournalRepository journals,
    AlbumRepository albums,
    OnboardingStore onboarding
  })> _data = _prepare();

  Future<({
    JournalRepository journals,
    AlbumRepository albums,
    OnboardingStore onboarding
  })> _prepare() async {
    final localJournals =
        await LocalJournalRepository.open(userId: widget.userId);
    // Account-owned entries already on this device remain visible without
    // automatic upload; new entries always use cloud while it is enabled.
    // Guest and fake-auth sessions remain local-only.
    JournalRepository journals = localJournals;
    final api = _api;
    if (api != null && AppConfig.journalCloudEnabled) {
      final remote = RemoteJournalRepository(
          client: api, localDrafts: localJournals);
      if ((await localJournals.entries()).isEmpty) {
        journals = remote;
      } else {
        journals = CombinedJournalRepository(
            local: localJournals, remote: remote);
      }
    }
    final localAlbums = await LocalAlbumRepository.open(userId: widget.userId);
    // Existing local/photo albums remain visible alongside new cloud albums.
    // They are never uploaded or re-assigned to the cloud.
    AlbumRepository albums = localAlbums;
    if (api != null && AppConfig.albumCloudEnabled) {
      final remote = RemoteAlbumRepository(client: api, localDrafts: localAlbums, userId: widget.userId);
      albums = CombinedAlbumRepository(local: localAlbums, remote: remote);
    }
    final onboarding = await OnboardingStore.open(userId: widget.userId);
    // Existing users completed OB02 before cloud profiles existed. Migrate
    // their nickname once when the cloud display name is still missing.
    // Never overwrite a name intentionally changed on another device.
    if (api != null && onboarding.nickname != null) {
      try {
        final profile = await api.getJson('/me', requireAuth: true);
        if (profile['display_name'] == null) {
          await api.patchJson('/me', {
            'display_name': onboarding.nickname,
          }, requireAuth: true);
        }
      } catch (_) {
        // Offline sessions still have their device-only onboarding data.
      }
    }
    if (widget.resetOnboarding) {
      await onboarding.reset();
      await journals.deleteDraft(FirstEntrySession.draftKey);
    }
    return (journals: journals, albums: albums, onboarding: onboarding);
  }

  @override
  void dispose() {
    _messages?.dispose();
    _api?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder(
        future: _data,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const MaterialApp(
              home: Scaffold(body: Center(
                child: Text('Không thể mở dữ liệu cục bộ. Thử khởi động lại.'),
              )),
            );
          }
          if (!snapshot.hasData) {
            return const MaterialApp(
              home: Scaffold(body: Center(child: CircularProgressIndicator())),
            );
          }

          final data = snapshot.data!;
          final app = MaterialApp(
            title: 'Nhật ký AI',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            scrollBehavior: const AppScrollBehavior(),
            home: data.onboarding.completed
                ? const AppShell()
                : OnboardingFlow(
                    store: data.onboarding,
                    brandName: 'Nhật ký AI',
                    // Only remote when the session is authenticated; onboarding
                    // itself enforces the user's AI choice.
                    reflections: _ai,
                    skipAccountStep: true,
                    onNicknameSaved: _api == null ? null : (nickname) async {
                      if (nickname != null && nickname.isNotEmpty) {
                        await _api.patchJson('/me', {
                          'display_name': nickname,
                        }, requireAuth: true);
                      }
                    },
                    onComplete: () => setState(() {}),
                  ),
          );
          final scoped = OnboardingScope(
            store: data.onboarding,
            child: JournalScope(
              repository: data.journals,
              child: AlbumScope(
                repository: data.albums,
                auth: PinAlbumAuth(LocalAlbumPins(userId: widget.userId)),
                photos: DeviceMemoryPhotos.forUser(widget.userId),
                // Deleting a memory or album also revokes its posts.
                sharing:
                    _friendsSharing ?? const NoAlbumPublishing() as AlbumSharing,
                memorySharing: _friendsSharing ??
                    const NoAlbumPublishing() as MemorySharing,
                child: app,
              ),
            ),
          );
          final userScoped = StudyProgressScope(
            repository: LocalStudyProgressStore(userId: widget.userId),
            child: scoped,
          );
          final session = widget.auth != null
              ? AuthScope(auth: widget.auth!, child: userScoped)
              : GuestScope(onLeaveGuest: widget.onLeaveGuest!, child: userScoped);
          final privatePlaces = _api != null && AppConfig.placesCloudEnabled
              ? SavedPlacesScope(
                  repository: RemoteSavedPlacesRepository(_api),
                  child: session,
                )
              : session;
          final withPlaceLookup = _api != null
              ? PlaceLookupScope(lookup: RemotePlaceLookup(_api), child: privatePlaces)
              : privatePlaces;
          final withStreak = _api == null
              ? withPlaceLookup
              : StreakApiScope(client: _api, child: withPlaceLookup);
          final messages = _messages;
          final withMessages = messages == null
              ? withStreak
              : MessagesScope(controller: messages, child: withStreak);
          return _ai == null
              ? withMessages
              : AiRemoteScope(service: _ai, child: withMessages);
        },
      );
}
