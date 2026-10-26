import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/data/app_data.dart';
import '../../../core/network/api_client.dart';
import '../../album/album_scope.dart';
import '../../album/data/album_repository.dart';
import '../../journal/data/api_ai_service.dart';
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
import 'auth_screen.dart';

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
    });
  }

  void _resetTransientPreview() {
    savedThisWeekItems.value = [];
    StreakState.shared.resetForNewLocalSession();
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
      home: AuthScreen(
        auth: widget.auth,
        onContinueAsGuest: _continueAsGuest,
        initialError: _localError,
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
      ? ApiClient(accessTokenProvider: () async =>
          (widget.auth as SupabaseAuthService)
              .client.auth.currentSession?.accessToken)
      : null;
  late final ApiAIService? _ai = _api == null ? null : ApiAIService(_api!);

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
    final journals = await LocalJournalRepository.open(userId: widget.userId);
    final albums = await LocalAlbumRepository.open(userId: widget.userId);
    final onboarding = await OnboardingStore.open(userId: widget.userId);
    if (widget.resetOnboarding) {
      await onboarding.reset();
      await journals.deleteDraft(FirstEntrySession.draftKey);
    }
    return (journals: journals, albums: albums, onboarding: onboarding);
  }

  @override
  void dispose() {
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
            home: data.onboarding.completed
                ? const AppShell()
                : OnboardingFlow(
                    store: data.onboarding,
                    brandName: 'Nhật ký AI',
                    // Only remote when the session is authenticated; onboarding
                    // itself enforces the user's AI choice.
                    reflections: _ai,
                    onComplete: () => setState(() {}),
                  ),
          );
          final scoped = OnboardingScope(
            store: data.onboarding,
            child: JournalScope(
              repository: data.journals,
              child: AlbumScope(
                repository: data.albums,
                child: app,
              ),
            ),
          );
          final session = widget.auth != null
              ? AuthScope(auth: widget.auth!, child: scoped)
              : GuestScope(onLeaveGuest: widget.onLeaveGuest!, child: scoped);
          return _ai == null
              ? session
              : AiRemoteScope(service: _ai!, child: session);
        },
      );
}
