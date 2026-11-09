import 'package:flutter/widgets.dart';

import 'onboarding_store.dart';

/// Active onboarding/preferences owner. In authenticated and guest sessions,
/// never fall back to the legacy unscoped preferences for the current user.
class OnboardingScope extends InheritedWidget {
  const OnboardingScope({
    super.key,
    required this.store,
    required super.child,
  });

  final OnboardingStore store;

  static OnboardingStore? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<OnboardingScope>()?.store;

  /// The current user's store without listening (so also from initState);
  /// the device's unscoped one only where there is no scope (local demo).
  static Future<OnboardingStore> storeOf(BuildContext context) async =>
      context.getInheritedWidgetOfExactType<OnboardingScope>()?.store ??
      await OnboardingStore.open();

  @override
  bool updateShouldNotify(OnboardingScope old) => old.store != store;
}
