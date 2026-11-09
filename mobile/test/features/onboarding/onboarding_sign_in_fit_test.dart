import 'package:ai_diary/core/theme/app_theme.dart';
import 'package:ai_diary/features/onboarding/data/sign_in_service.dart';
import 'package:ai_diary/features/onboarding/presentation/onboarding_sign_in_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The sign-in fits every screen, also wider than its form (landscape,
/// tablets), in the stand-in and the real (AuthGate) look, with an error.
void main() {
  for (final real in [false, true]) {
    for (final size in const [
      Size(320, 568),
      Size(360, 640),
      Size(390, 844),
      Size(640, 360),
      Size(800, 600),
    ]) {
      testWidgets('${real ? 'Real' : 'Stand-in'} sign-in fits $size',
          (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(MaterialApp(
          theme: AppTheme.light,
          home: OnboardingSignInScreen(
            service: MockSignInService(delay: Duration.zero),
            realAuth: real,
            initialError: real ? OnboardingSignInScreen.guestFailed : null,
            onBack: () {},
            onDone: () {},
            onGuest: real ? () async {} : null,
          ),
        ));
        await tester.pump(const Duration(seconds: 2));
        expect(tester.takeException(), isNull);
      });
    }
  }
}
