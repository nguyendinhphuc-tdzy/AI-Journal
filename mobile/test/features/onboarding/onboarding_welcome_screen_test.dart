import 'package:ai_diary/core/theme/app_theme.dart';
import 'package:ai_diary/features/onboarding/data/onboarding_store.dart';
import 'package:ai_diary/features/onboarding/onboarding_flow.dart';
import 'package:ai_diary/features/onboarding/presentation/falling_petals.dart';
import 'package:ai_diary/features/onboarding/presentation/nudaeng_umbrella_blink.dart';
import 'package:ai_diary/features/onboarding/presentation/onboarding_nickname_screen.dart';
import 'package:ai_diary/features/onboarding/presentation/onboarding_sign_in_screen.dart';
import 'package:ai_diary/features/onboarding/presentation/onboarding_welcome_screen.dart';
import 'package:ai_diary/main.dart';
import 'package:ai_diary/navigation/app_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<OnboardingStore> _store([Map<String, Object> values = const {}]) {
  SharedPreferences.setMockInitialValues(values);
  return OnboardingStore.open();
}

Future<void> _pump(
  WidgetTester tester, {
  OnboardingStore? store,
  Size size = const Size(390, 844),
  double textScale = 1,
  bool reducedMotion = false,
}) async {
  store ??= await _store();
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  tester.view.padding = const FakeViewPadding(top: 47, bottom: 34);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.light,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(textScale),
        disableAnimations: reducedMotion,
      ),
      child: child!,
    ),
    home: OnboardingFlow(store: store, brandName: 'AI Diary'),
  ));
  // Petals tick forever, so advance a fixed time instead of settling.
  await tester.pump(const Duration(seconds: 3));
}

/// Index of the blink frame currently painted.
int _visibleFrame(WidgetTester tester) {
  final layers = tester
      .widgetList<Opacity>(find.descendant(
          of: find.byType(NudaengUmbrellaBlink),
          matching: find.byType(Opacity)))
      // Frame layers only, not the wrapper that fades frames out for a rest.
      .where((layer) => layer.child is Image)
      .toList();
  return layers.indexWhere((layer) => layer.opacity == 1);
}

void main() {
  const sizes = [Size(360, 640), Size(390, 844), Size(430, 932)];

  for (final size in sizes) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('OB01 fits $size at text scale $scale', (tester) async {
        await _pump(tester, size: size, textScale: scale);
        expect(tester.takeException(), isNull);

        final cta =
            tester.getRect(find.text(OnboardingWelcomeScreen.startLabel));
        expect(cta.bottom, lessThanOrEqualTo(size.height),
            reason: 'CTA stays in the dock, never scrolled away');
        final button = tester.getSize(find.byType(FilledButton));
        expect(button.height, greaterThanOrEqualTo(56));
        expect(button.width, size.width - 40);
      });
    }
  }

  testWidgets('OB01 shows brand, copy, layers; no progress or back',
      (tester) async {
    await _pump(tester);
    expect(find.text('AI Diary'), findsOneWidget);
    expect(find.text(OnboardingWelcomeScreen.title), findsOneWidget);
    expect(find.text(OnboardingWelcomeScreen.body), findsOneWidget);
    expect(find.byType(BackButton), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.byType(FallingPetals), findsOneWidget);
    expect(find.byType(NudaengUmbrellaBlink), findsOneWidget);
    expect(find.bySemanticsLabel('Nudaeng cầm ô đứng dưới mưa cánh hoa'),
        findsOneWidget);
  });

  for (final size in sizes) {
    testWidgets('Nudaeng is whole between the text and the CTA at $size',
        (tester) async {
      await _pump(tester, size: size);
      // When the text needs the room, the page scrolls; check at the end.
      await tester.drag(
          find.byType(SingleChildScrollView), const Offset(0, -1000));
      await tester.pump();
      final frame = tester.getRect(find.byType(NudaengUmbrellaBlink));
      // Visible bounds inside the 1083×1453 frame (alpha bounds).
      final visible = Rect.fromLTRB(
        frame.left + frame.width * 31 / 1083,
        frame.top + frame.height * 33 / 1453,
        frame.left + frame.width * 1055 / 1083,
        frame.top + frame.height * 1418 / 1453,
      );
      final body = tester.getRect(find.text(OnboardingWelcomeScreen.body));
      final cta = tester.getRect(find.byType(FilledButton));
      expect(visible.top, greaterThanOrEqualTo(body.bottom),
          reason: 'umbrella');
      expect(visible.bottom, lessThanOrEqualTo(cta.top), reason: 'feet');
      expect(visible.left, greaterThanOrEqualTo(0));
      expect(visible.right, lessThanOrEqualTo(size.width));
    });
  }

  test('Blink timeline: 800 / 100 / 120 / 780 ms, then holds frame 04', () {
    int at(int ms) => NudaengUmbrellaBlink.frameAt(Duration(milliseconds: ms));
    expect([at(0), at(799), at(800), at(899), at(900), at(1019), at(1020)],
        [0, 0, 1, 1, 2, 2, 3]);
    expect(at(1799), 3);
    expect(at(60000), 3);
  });

  testWidgets('Nudaeng blinks again now and then', (tester) async {
    await _pump(tester);
    // _pump advanced 3 s, past the entry blink. Watch the next window.
    var blinks = 0;
    var closed = false;
    final window = NudaengUmbrellaBlink.maxPause + NudaengUmbrellaBlink.total;
    for (var t = Duration.zero;
        t < window * 2;
        t += const Duration(milliseconds: 20)) {
      await tester.pump(const Duration(milliseconds: 20));
      final isClosed = _visibleFrame(tester) == 2;
      if (isClosed && !closed) blinks++;
      closed = isClosed;
    }
    expect(blinks, greaterThanOrEqualTo(2), reason: 'keeps blinking');
    expect(blinks, lessThanOrEqualTo(6), reason: 'only now and then');
  });

  testWidgets('Blink passes through the closed-eye frame', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = await OnboardingStore.open();
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
        MaterialApp(home: OnboardingFlow(store: store, brandName: 'AI Diary')));
    expect(_visibleFrame(tester), 0);
    await tester.pump(const Duration(milliseconds: 850));
    expect(_visibleFrame(tester), 1);
    await tester.pump(const Duration(milliseconds: 100));
    expect(_visibleFrame(tester), 2);
    await tester.pump(const Duration(milliseconds: 120));
    expect(_visibleFrame(tester), 3);
  });

  testWidgets('Reduced motion: static frame 01, no petals', (tester) async {
    await _pump(tester, reducedMotion: true);
    expect(find.byType(FallingPetals), findsNothing);
    final images = tester.widgetList<Image>(find.byType(Image)).toList();
    expect(images, hasLength(2), reason: 'background + one character frame');
    expect((images.last.image as AssetImage).assetName,
        NudaengUmbrellaBlink.frames.first);
  });

  testWidgets('Bắt đầu saves the session, moves on; Back returns',
      (tester) async {
    final store = await _store();
    await _pump(tester, store: store);
    await tester.tap(find.text(OnboardingWelcomeScreen.startLabel));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text(OnboardingSignInScreen.title), findsOneWidget);
    expect(store.step, OnboardingStep.signIn);

    await tester.tap(find.byTooltip('Quay lại'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text(OnboardingWelcomeScreen.title), findsOneWidget);
    expect(store.step, OnboardingStep.welcome);
  });

  testWidgets('Relaunch resumes at the saved route', (tester) async {
    final store = await _store({'onboarding.step': 'nickname'});
    await _pump(tester, store: store);
    expect(find.text(OnboardingNicknameScreen.title), findsOneWidget);
    expect(find.text(OnboardingWelcomeScreen.title), findsNothing);
  });

  testWidgets('Completed onboarding launches into Home', (tester) async {
    final store = await _store({'onboarding.completed': true});
    await tester.pumpWidget(AiDiaryApp(onboarding: store));
    expect(find.byType(AppShell), findsOneWidget);
    expect(find.byType(OnboardingFlow), findsNothing);
  });

  test('reset() starts over: every onboarding key goes, entries stay',
      () async {
    final store = await _store({
      'onboarding.step': 'entrySaved',
      'onboarding.nickname': 'Vy',
      'onboarding.ai': 'on',
      'onboarding.firstEntryId': 'e1',
      'onboarding.completed': true,
      'journal.entries': '[]',
    });
    await store.reset();
    expect(store.step, OnboardingStep.welcome);
    expect(store.nickname, isNull);
    expect(store.aiEnabled, isNull);
    expect(store.firstEntryId, isNull);
    expect(store.completed, isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('journal.entries'), '[]');
  });

  test('complete() marks done and clears the saved route', () async {
    final store = await _store({'onboarding.step': 'ready'});
    await store.complete();
    expect(store.completed, isTrue);
    expect(store.step, OnboardingStep.welcome);
  });
}
