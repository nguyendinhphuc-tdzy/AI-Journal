import 'package:ai_diary/core/theme/app_theme.dart';
import 'package:ai_diary/features/onboarding/data/onboarding_store.dart';
import 'package:ai_diary/features/onboarding/onboarding_flow.dart';
import 'package:ai_diary/features/onboarding/presentation/falling_petals.dart';
import 'package:ai_diary/features/onboarding/presentation/onboarding_sign_in_screen.dart';
import 'package:ai_diary/features/onboarding/presentation/onboarding_welcome_screen.dart';
import 'package:ai_diary/features/onboarding/presentation/onboarding_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<OnboardingStore> _pump(WidgetTester tester,
    {bool reducedMotion = false}) async {
  SharedPreferences.setMockInitialValues({});
  final store = await OnboardingStore.open();
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.light,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: reducedMotion),
      child: child!,
    ),
    home: OnboardingFlow(store: store, brandName: 'AI Diary'),
  ));
  await tester.pump(const Duration(seconds: 1));
  return store;
}

Finder get _start => find.text(OnboardingWelcomeScreen.startLabel);
Finder get _ob01 => find.text(OnboardingWelcomeScreen.title);

/// What comes after OB01: the sign-in.
Finder get _ob02 => find.text(OnboardingSignInScreen.title);

/// Entrance opacity of the stagger item holding [text].
double _entrance(WidgetTester tester, String text) {
  final item =
      find.ancestor(of: find.text(text), matching: find.byType(StaggerItem));
  return tester
      .widget<FadeTransition>(find
          .descendant(of: item.first, matching: find.byType(FadeTransition))
          .first)
      .opacity
      .value;
}

void main() {
  testWidgets('Wind first, then the sign-in; session saved at once',
      (tester) async {
    final store = await _pump(tester);
    await tester.tap(_start);
    await tester.pump();
    expect(store.step, OnboardingStep.signIn, reason: 'saved on tap');

    await tester.pump(const Duration(milliseconds: 250));
    expect(_ob01, findsOneWidget, reason: 'petals blow away on OB01 first');
    expect(_ob02, findsNothing);
    expect(find.byType(PetalGust), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 400));
    expect(_ob02, findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    expect(_ob01, findsNothing);
  });

  testWidgets('The sign-in parts appear one after another', (tester) async {
    await _pump(tester);
    await tester.tap(_start);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 560));
    expect(_ob02, findsOneWidget);
    // Up a moment: the title (order 1) leads the form's paper (order 3).
    await tester.pump(const Duration(milliseconds: 200));
    final title = _entrance(tester, OnboardingSignInScreen.title);
    final form = _entrance(tester, OnboardingSignInScreen.later);
    expect(title, greaterThan(form), reason: 'title leads the form');
    expect(form, lessThan(1));

    await tester.pump(OnboardingStagger.total);
    expect(_entrance(tester, OnboardingSignInScreen.title), 1);
    expect(_entrance(tester, OnboardingSignInScreen.later), 1);
  });

  testWidgets('Extra taps during the wind are ignored', (tester) async {
    final store = await _pump(tester);
    await tester.tap(_start);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(_start, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
    expect(_ob02, findsOneWidget);
    expect(store.step, OnboardingStep.signIn);
  });

  testWidgets('Back during the wind stays on OB01, petals back',
      (tester) async {
    final store = await _pump(tester);
    await tester.tap(_start);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 650));
    await tester.tap(find.byTooltip('Quay lại'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(_ob01, findsOneWidget);
    expect(_ob02, findsNothing);
    expect(store.step, OnboardingStep.welcome);
    final gust = tester.widget<FallingPetals>(find.byType(FallingPetals)).gust;
    expect(gust!.value, 0, reason: 'petals fall normally again');
  });

  testWidgets('Next step fades in over the last, which stays opaque',
      (tester) async {
    await _pump(tester);
    await tester.tap(_start);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 2));
    expect(_ob01, findsNothing, reason: 'wind and fade are over');
    await tester.tap(find.byTooltip('Quay lại'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 140));
    double screenOpacity(Finder text) => tester
        .widget<Opacity>(
            find.ancestor(of: text, matching: find.byType(Opacity)).last)
        .opacity;
    expect(screenOpacity(_ob02), 1, reason: 'no see-through moment');
    expect(screenOpacity(_ob01), inExclusiveRange(0, 1));
    await tester.pump(const Duration(seconds: 2));
    expect(_ob02, findsNothing);
  });

  testWidgets('Reduced motion: no wind, no stagger', (tester) async {
    await _pump(tester, reducedMotion: true);
    await tester.tap(_start);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    expect(find.byType(PetalGust), findsNothing);
    expect(_ob02, findsOneWidget);
    expect(_entrance(tester, OnboardingSignInScreen.title), 1);
  });
}
