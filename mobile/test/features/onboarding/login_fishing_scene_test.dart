import 'package:ai_diary/features/onboarding/data/sign_in_service.dart';
import 'package:ai_diary/features/onboarding/presentation/login_fishing_scene.dart';
import 'package:ai_diary/features/onboarding/presentation/onboarding_sign_in_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('lake animates, reduced motion stays still', (tester) async {
    Widget scene(bool reduced) => MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: reduced),
            child: const Scaffold(body: LoginFishingScene()),
          ),
        );
    await tester.pumpWidget(scene(false));
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.binding.hasScheduledFrame, isTrue);
    await tester.pumpWidget(scene(true));
    await tester.pump(const Duration(seconds: 1));
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact login remains scrollable with keyboard and large text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final previousError = FlutterError.onError;
    FlutterError.onError = (details) {
      debugPrint(details.toString());
      previousError?.call(details);
    };
    addTearDown(() => FlutterError.onError = previousError);
    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(
          size: Size(320, 640),
          textScaler: TextScaler.linear(1.5),
          viewInsets: EdgeInsets.only(bottom: 260),
          disableAnimations: true,
        ),
        child: OnboardingSignInScreen(
          service: MockSignInService(delay: Duration.zero),
          onBack: () {},
          onDone: () {},
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text(OnboardingSignInScreen.later));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(LoginFishingScene), findsOneWidget);
  });
}
