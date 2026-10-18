import 'package:ai_diary/core/theme/app_theme.dart';
import 'package:ai_diary/features/onboarding/data/onboarding_store.dart';
import 'package:ai_diary/features/onboarding/onboarding_flow.dart';
import 'package:ai_diary/features/onboarding/presentation/nudaeng_chasing_cockroach.dart';
import 'package:ai_diary/features/onboarding/presentation/onboarding_nickname_screen.dart';
import 'package:ai_diary/features/onboarding/presentation/onboarding_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _size = Size(430, 1100);
const _bottomInset = 34.0;

/// Where every step's Nudaeng stands: above the dock of a step with two
/// actions (16 + CTA 56 + 4 + text action 48 + 4), plus the 12 gap.
const _feetLine = 1100 - _bottomInset - (16 + 56 + 4 + 48 + 4) - 12;

/// Nudaeng's figure on screen for the [step] route: x of the feet, from the
/// top of the head to the feet.
Future<Rect> _figure(WidgetTester tester, String step) async {
  SharedPreferences.setMockInitialValues({'onboarding.step': step});
  final store = await OnboardingStore.open();
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = _size;
  tester.view.padding = const FakeViewPadding(top: 47, bottom: _bottomInset);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.light,
    // No breath, so the figure is measured at rest.
    builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: child!),
    home: OnboardingFlow(store: store, brandName: 'AI Diary'),
  ));
  await tester.pump(const Duration(seconds: 2));
  final (Finder sprite, Size canvas, double head, Offset feet) =
      step == 'nickname'
          ? (
              find.byType(NudaengChasingCockroach),
              const Size(306, 319),
              2.0,
              const Offset(136, 275),
            )
          : (
              find.bySemanticsLabel('Nudaeng ôm đàn'),
              const Size(1254, 1254),
              92.0,
              const Offset(600, 1194),
            );
  final box = tester.getRect(sprite);
  final k = box.width / canvas.width;
  final x = box.left + feet.dx * k;
  return Rect.fromLTRB(x, box.top + head * k, x, box.top + feet.dy * k);
}

void main() {
  for (final step in ['nickname', 'purpose']) {
    testWidgets('$step: Nudaeng 96 high, feet centred on the shared line',
        (tester) async {
      final figure = await _figure(tester, step);
      expect(figure.height, closeTo(OnboardingMascot.figureHeight, .5));
      expect(figure.bottom, closeTo(_feetLine, .5),
          reason: 'same spot whether or not the step has "Để sau"');
      expect(figure.left, closeTo(_size.width / 2, .5));
    });
  }

  for (final step in ['nickname', 'purpose']) {
    testWidgets('$step: shared ground, horizon just above the feet line',
        (tester) async {
      await _figure(tester, step);
      final ground = tester.getRect(find.byType(OnboardingGround));
      expect(ground.bottom, _size.height, reason: 'runs under the actions');
      // Box top = horizon (16 above the feet) less the 6 px wave crest.
      expect(ground.top, closeTo(_feetLine - 16 - 6, .5));
    });
  }

  testWidgets('Ground hides while the keyboard is open', (tester) async {
    SharedPreferences.setMockInitialValues({'onboarding.step': 'nickname'});
    final store = await OnboardingStore.open();
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = _size;
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: OnboardingFlow(store: store, brandName: 'AI Diary'),
    ));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(OnboardingGround), findsNothing);
    expect(find.byType(NudaengChasingCockroach), findsNothing);
  });

  testWidgets('OB02 bubble greets the nickname as it is typed', (tester) async {
    await _figure(tester, 'nickname');
    expect(find.text('Chào bạn!'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '  Ely ');
    await tester.pump();
    expect(find.text('Chào Ely!'), findsOneWidget);
    expect(OnboardingNicknameScreen.greeting(''), 'Chào bạn!');
    // Above Nudaeng's head.
    final bubble = tester.getRect(find.byType(MascotBubble));
    expect(bubble.bottom, lessThan(_feetLine - OnboardingMascot.figureHeight));
  });

  testWidgets('Bubble hides first when room is short', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(300, 300);
    addTearDown(tester.view.reset);
    const frame =
        MascotFrame(canvas: Size(100, 100), headTop: 0, feet: Offset(50, 100));
    const need = OnboardingMascot.figureHeight + OnboardingMascot.gap;
    for (final (height, bubble) in [
      (need + OnboardingMascot.bubbleRoom - 1, false),
      (need + OnboardingMascot.bubbleRoom, true),
    ]) {
      await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 300,
            height: height,
            child: const OnboardingMascot(
              frame: frame,
              bubble: MascotBubble(text: 'Chào bạn!'),
              child: ColoredBox(color: Color(0xFF000000)),
            ),
          ),
        ),
      ));
      expect(find.byType(ColoredBox), findsOneWidget, reason: 'mascot stays');
      expect(find.byType(MascotBubble).evaluate().isNotEmpty, bubble,
          reason: 'room $height');
    }
  });

  testWidgets('Too little room: hidden, never shrunk', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(300, 300);
    addTearDown(tester.view.reset);
    const frame =
        MascotFrame(canvas: Size(100, 100), headTop: 0, feet: Offset(50, 100));
    for (final height in [OnboardingMascot.figureHeight + 11, 180.0]) {
      await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 300,
            height: height,
            child: const OnboardingMascot(
                frame: frame, child: ColoredBox(color: Color(0xFF000000))),
          ),
        ),
      ));
      final shown = find.byType(ColoredBox).evaluate().isNotEmpty;
      expect(shown, height >= OnboardingMascot.figureHeight + 12,
          reason: 'room $height');
      if (shown) {
        expect(tester.getSize(find.byType(ColoredBox)).height,
            closeTo(OnboardingMascot.figureHeight, .5));
      }
    }
  });
}
