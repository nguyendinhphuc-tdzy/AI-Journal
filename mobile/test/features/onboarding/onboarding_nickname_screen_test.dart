import 'package:ai_diary/core/theme/app_theme.dart';
import 'package:ai_diary/features/onboarding/data/nickname.dart';
import 'package:ai_diary/features/onboarding/data/onboarding_store.dart';
import 'package:ai_diary/features/onboarding/onboarding_flow.dart';
import 'package:ai_diary/features/onboarding/presentation/frame_sequence.dart';
import 'package:ai_diary/features/onboarding/presentation/nudaeng_chasing_cockroach.dart';
import 'package:ai_diary/features/onboarding/presentation/nudaeng_cockroach_idle.dart';
import 'package:ai_diary/features/onboarding/presentation/onboarding_nickname_screen.dart';
import 'package:ai_diary/features/onboarding/presentation/onboarding_welcome_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<OnboardingStore> _pump(
  WidgetTester tester, {
  Map<String, Object> values = const {'onboarding.step': 'nickname'},
  Size size = const Size(390, 844),
  double textScale = 1,
  double keyboard = 0,
  bool reducedMotion = false,
}) async {
  SharedPreferences.setMockInitialValues(values);
  final store = await OnboardingStore.open();
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  tester.view.padding = const FakeViewPadding(top: 47, bottom: 34);
  tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
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
  await tester.pump(const Duration(seconds: 1));
  return store;
}

Finder get _field => find.byType(TextField);
Finder get _cta => find.widgetWithText(FilledButton, 'Tiếp tục');

bool _enabled(WidgetTester tester) =>
    tester.widget<FilledButton>(_cta).onPressed != null;

Future<void> _tapContinue(WidgetTester tester) async {
  await tester.tap(_cta);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

void main() {
  group('Nickname rules', () {
    test('trims both ends; empty becomes null', () {
      expect(Nickname.normalize('  Vy  '), 'Vy');
      expect(Nickname.normalize('   '), isNull);
      expect(Nickname.normalize(''), isNull);
    });

    test('counts graphemes: Vietnamese marks and emoji count once', () {
      // "ệ" typed as e + combining circumflex + combining dot below.
      expect(Nickname.length('Nguyện'), 6);
      expect(Nickname.length('Tường Vy'), 8);
      expect(Nickname.length('👩🏽‍💻🐶'), 2);
      expect(Nickname.isTooLong('🐶' * 30), isFalse);
      expect(Nickname.isTooLong('🐶' * 31), isTrue);
      expect(Nickname.isTooLong('${'a' * 30}   '), isFalse,
          reason: 'trailing spaces are trimmed first');
    });
  });

  testWidgets('OB02 copy, progress, no default name, no autofocus',
      (tester) async {
    await _pump(tester);
    expect(find.text(OnboardingNicknameScreen.eyebrow), findsOneWidget);
    expect(find.text(OnboardingNicknameScreen.title), findsOneWidget);
    expect(find.text(OnboardingNicknameScreen.label), findsOneWidget);
    expect(find.text(OnboardingNicknameScreen.hint), findsOneWidget);
    expect(find.text(OnboardingNicknameScreen.helper), findsOneWidget);
    expect(find.text('Bước 1/9'), findsOneWidget);
    expect(find.byTooltip('Quay lại'), findsOneWidget);
    final field = tester.widget<TextField>(_field);
    expect(field.controller!.text, isEmpty);
    expect(field.autofocus, isFalse);
    expect(field.focusNode!.hasFocus, isFalse);
    expect(tester.testTextInput.isVisible, isFalse);
    expect(_enabled(tester), isTrue, reason: 'empty is valid');
    expect(find.byType(NudaengChasingCockroach), findsOneWidget);
  });

  testWidgets('Tapping the field focuses it; Done only closes the keyboard',
      (tester) async {
    final store = await _pump(tester);
    await tester.tap(_field);
    await tester.pump();
    expect(tester.widget<TextField>(_field).focusNode!.hasFocus, isTrue);
    await tester.enterText(_field, 'Vy');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.widget<TextField>(_field).focusNode!.hasFocus, isFalse);
    expect(find.text(OnboardingNicknameScreen.title), findsOneWidget,
        reason: 'still on OB02');
    expect(store.step, OnboardingStep.nickname);
    expect(store.nickname, isNull, reason: 'nothing saved before Tiếp tục');
  });

  testWidgets('Tiếp tục saves the trimmed nickname, then OB03', (tester) async {
    final store = await _pump(tester);
    await tester.enterText(_field, '  Tường Vy 🌿  ');
    await tester.pump();
    await _tapContinue(tester);
    expect(store.nickname, 'Tường Vy 🌿');
    expect(store.step, OnboardingStep.purpose);
    expect(find.text(OnboardingNicknameScreen.title), findsNothing);
  });

  testWidgets('Empty or spaces only: saves null and moves on', (tester) async {
    final store = await _pump(tester,
        values: {'onboarding.step': 'nickname', 'onboarding.nickname': 'Cũ'});
    await tester.enterText(_field, '   ');
    await tester.pump();
    await _tapContinue(tester);
    expect(store.nickname, isNull);
    expect(store.step, OnboardingStep.purpose);
  });

  testWidgets('Over 30 characters: message and Tiếp tục waits', (tester) async {
    final store = await _pump(tester);
    await tester.enterText(_field, 'a' * 31);
    await tester.pump();
    expect(
        find.text(OnboardingNicknameScreen.tooLongMessage(31)), findsOneWidget);
    expect(find.text(OnboardingNicknameScreen.helper), findsNothing);
    expect(_enabled(tester), isFalse);
    expect(tester.widget<TextField>(_field).controller!.text, 'a' * 31,
        reason: 'never cut what the user typed');

    await tester.enterText(_field, 'a' * 30);
    await tester.pump();
    expect(_enabled(tester), isTrue);
    expect(find.text(OnboardingNicknameScreen.helper), findsOneWidget);
    await _tapContinue(tester);
    expect(store.nickname, 'a' * 30);
  });

  testWidgets('Back returns to OB01 and keeps the text', (tester) async {
    final store = await _pump(tester);
    await tester.enterText(_field, 'Vy');
    await tester.pump();
    await tester.tap(find.byTooltip('Quay lại'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text(OnboardingWelcomeScreen.title), findsOneWidget);
    expect(store.step, OnboardingStep.welcome);

    await tester.tap(find.text(OnboardingWelcomeScreen.startLabel));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.widget<TextField>(_field).controller!.text, 'Vy');
  });

  testWidgets('Resume prefills the saved nickname', (tester) async {
    await _pump(tester,
        values: {'onboarding.step': 'nickname', 'onboarding.nickname': 'Vy'});
    expect(tester.widget<TextField>(_field).controller!.text, 'Vy');
  });

  testWidgets('Keyboard open: mascot collapses, CTA stays above keyboard',
      (tester) async {
    const size = Size(390, 844);
    await _pump(tester, size: size, keyboard: 336);
    expect(tester.takeException(), isNull);
    expect(find.byType(NudaengChasingCockroach), findsNothing);
    final cta = tester.getRect(_cta);
    expect(cta.bottom, lessThanOrEqualTo(size.height - 336));
  });

  for (final size in const [Size(360, 640), Size(390, 844), Size(430, 932)]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('OB02 fits $size at text scale $scale', (tester) async {
        await _pump(tester, size: size, textScale: scale);
        expect(tester.takeException(), isNull);
        final cta = tester.getRect(_cta);
        expect(cta.bottom, lessThanOrEqualTo(size.height));
        expect(cta.height, greaterThanOrEqualTo(56));
        expect(cta.width, size.width - 40);
        expect(tester.getSize(_field).height, greaterThanOrEqualTo(56));
        final back = tester.getSize(find.byTooltip('Quay lại'));
        expect(back.width, greaterThanOrEqualTo(48));
        expect(back.height, greaterThanOrEqualTo(48));
      });
    }
  }

  /// Opacity of the chase frames: 1 while running, 0 once the idle shows.
  double chaseOpacity(WidgetTester tester) => tester
      .widget<Opacity>(find
          .descendant(
              of: find.byType(NudaengChasingCockroach),
              matching: find.byType(Opacity))
          .first)
      .opacity;

  Matrix4 spriteTransform(WidgetTester tester) => tester
      .widget<Transform>(find
          .ancestor(
              of: find.byType(NudaengChasingCockroach),
              matching: find.byType(Transform))
          .first)
      .transform;

  /// Opacity of the idle pose: 0 while running, 1 at rest.
  double restOpacity(WidgetTester tester) => tester
      .widget<Opacity>(find
          .ancestor(
              of: find.byType(NudaengCockroachIdle),
              matching: find.byType(Opacity))
          .first)
      .opacity;

  testWidgets('Run eases out, hands over to the idle at once, then replays',
      (tester) async {
    final durations = NudaengChasingCockroach.frameDurations;
    expect(NudaengChasingCockroach.frames, hasLength(12));
    expect(durations.sublist(9).map((d) => d.inMilliseconds), [200, 240, 300],
        reason: 'the run slows down before it stops');
    final total = durations.fold(Duration.zero, (a, b) => a + b);
    expect(total, const Duration(milliseconds: 2270));
    expect(FrameSequence.frameAt(durations, const Duration(milliseconds: 1000)),
        5);

    await _pump(tester);
    expect(find.byType(NudaengCockroachIdle), findsOneWidget,
        reason: 'mounted early, so it is decoded before it shows');
    expect(
        tester
            .widget<NudaengCockroachIdle>(find.byType(NudaengCockroachIdle))
            .active,
        isFalse);
    expect((chaseOpacity(tester), restOpacity(tester)), (1.0, 0.0));

    // Through the end of the run (2.27 s): never a frame where both layers
    // are part-visible, which is what read as a flash.
    for (var i = 0; i < 100; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      final pair = (chaseOpacity(tester), restOpacity(tester));
      expect(pair == (1.0, 0.0) || pair == (0.0, 1.0), isTrue,
          reason: 'at ${1000 + i * 16} ms: $pair');
    }
    expect((chaseOpacity(tester), restOpacity(tester)), (0.0, 1.0));
    expect(
        tester
            .widget<NudaengCockroachIdle>(find.byType(NudaengCockroachIdle))
            .active,
        isTrue);

    var replayed = false;
    for (var i = 0; i < 600 && !replayed; i++) {
      await tester.pump(const Duration(milliseconds: 20));
      replayed = chaseOpacity(tester) == 1;
    }
    expect(replayed, isTrue, reason: 'the cockroach runs again later');
    expect(restOpacity(tester), 0);
  });

  testWidgets('Nudaeng breathes from the feet', (tester) async {
    await _pump(tester);
    final scales = <double>{};
    for (var i = 0; i < 15; i++) {
      await tester.pump(const Duration(milliseconds: 200));
      scales.add((spriteTransform(tester).storage[5] * 1000).round() / 1000);
    }
    expect(scales.length, greaterThan(3), reason: 'keeps moving');
    expect(scales.reduce((a, b) => a > b ? a : b), lessThanOrEqualTo(1.02));
    expect(scales.reduce((a, b) => a < b ? a : b), greaterThanOrEqualTo(1));
  });

  testWidgets('Reduced motion: still idle pose, no breathing', (tester) async {
    await _pump(tester, reducedMotion: true);
    expect(find.byType(NudaengCockroachIdle), findsOneWidget);
    expect(spriteTransform(tester).storage[5], 1);
  });
}
