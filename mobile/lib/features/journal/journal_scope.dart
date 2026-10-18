import 'package:flutter/widgets.dart';

import 'data/journal_repository.dart';

/// Hands the app's [JournalRepository] to Home, the editor and onboarding.
class JournalScope extends InheritedWidget {
  const JournalScope(
      {super.key, required this.repository, required super.child});

  final JournalRepository repository;

  /// Screens built without a scope (e.g. in isolation) get an in-memory one.
  static final _fallback = InMemoryJournalRepository();

  static JournalRepository of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<JournalScope>()?.repository ??
      _fallback;

  @override
  bool updateShouldNotify(JournalScope old) => old.repository != repository;
}
