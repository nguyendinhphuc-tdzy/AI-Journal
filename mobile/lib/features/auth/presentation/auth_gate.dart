import 'dart:async';

import 'package:flutter/material.dart';

import '../../../navigation/app_shell.dart';
import '../../journal/data/journal_repository.dart';
import '../../journal/journal_scope.dart';
import '../../onboarding/data/onboarding_store.dart';
import '../../onboarding/onboarding_flow.dart';
import '../../onboarding/presentation/first_entry_session.dart';
import '../data/auth_service.dart';
import 'auth_screen.dart';

/// Exposes the authenticated session to the Profile logout control.
class AuthScope extends InheritedWidget {
  const AuthScope({super.key, required this.auth, required super.child});
  final AuthService auth;

  static AuthService? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AuthScope>()?.auth;

  @override
  bool updateShouldNotify(AuthScope oldWidget) => oldWidget.auth != auth;
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
  late String? _userId = widget.auth.currentUserId;

  @override
  void initState() {
    super.initState();
    _subscription = widget.auth.userChanges.listen((id) {
      if (mounted) setState(() => _userId = id);
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AuthScope(
        auth: widget.auth,
        child: _userId == null
            ? AuthScreen(auth: widget.auth)
            : _SignedInHome(
                key: ValueKey(_userId),
                userId: _userId!,
                showOnboarding: widget.showOnboarding,
                resetOnboarding: widget.resetOnboarding,
              ),
      );
}

class _SignedInHome extends StatefulWidget {
  const _SignedInHome({
    super.key,
    required this.userId,
    required this.showOnboarding,
    required this.resetOnboarding,
  });
  final String userId;
  final bool showOnboarding;
  final bool resetOnboarding;

  @override
  State<_SignedInHome> createState() => _SignedInHomeState();
}

class _SignedInHomeState extends State<_SignedInHome> {
  late final Future<({JournalRepository journals, OnboardingStore? onboarding})>
      _data = _prepare();

  Future<({JournalRepository journals, OnboardingStore? onboarding})>
      _prepare() async {
    final journals = await LocalJournalRepository.open(userId: widget.userId);
    final onboarding = widget.showOnboarding || widget.resetOnboarding
        ? await OnboardingStore.open(userId: widget.userId)
        : null;
    if (widget.resetOnboarding) {
      await onboarding!.reset();
      await journals.deleteDraft(FirstEntrySession.draftKey);
    }
    return (journals: journals, onboarding: onboarding);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder(
        future: _data,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
                child: Text('Không thể mở dữ liệu. Thử khởi động lại.'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data!;
          final onboarding = data.onboarding;
          return JournalScope(
            repository: data.journals,
            child: onboarding == null || onboarding.completed
                ? const AppShell()
                : OnboardingFlow(
                    store: onboarding,
                    brandName: 'AI Diary',
                    onComplete: () => setState(() {}),
                  ),
          );
        },
      );
}
