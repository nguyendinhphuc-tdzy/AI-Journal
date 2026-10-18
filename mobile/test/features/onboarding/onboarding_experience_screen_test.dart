import 'package:ai_diary/core/theme/app_colors.dart';
import 'package:ai_diary/core/theme/app_theme.dart';
import 'package:ai_diary/features/onboarding/data/journal_goal.dart';
import 'package:ai_diary/features/onboarding/data/journaling_experience.dart';
import 'package:ai_diary/features/onboarding/data/onboarding_store.dart';
import 'package:ai_diary/features/onboarding/onboarding_flow.dart';
import 'package:ai_diary/features/onboarding/presentation/onboarding_experience_screen.dart';
import 'package:ai_diary/features/onboarding/presentation/onboarding_purpose_screen.dart';
import 'package:ai_diary/features/onboarding/presentation/onboarding_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<OnboardingStore> _pump(
  WidgetTester tester, {
  Map<String, Object> values = const {'onboarding.step': 'experience'},
  Size size = const Size(390, 844),
  double textScale = 1,
}) async {
  SharedPreferences.setMockInitialValues(values);
  final store = await OnboardingStore.open();
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  tester.view.padding = const FakeViewPadding(top: 47, bottom: 34);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.light,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: OnboardingFlow(store: store, brandName: 'AI Diary'),
  ));
  await tester.pump(const Duration(seconds: 2));
  return store;
}

Finder get _cta => find.widgetWithText(FilledButton, 'Tiếp tục');
Finder get _skip => find.widgetWithText(TextButton, 'Để sau');
Finder _option(JournalingExperience e) => find.text(e.label);

bool _enabled(WidgetTester tester) =>
    tester.widget<FilledButton>(_cta).onPressed != null;

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

Future<void> _pick(WidgetTester tester, JournalingExperience e) async {
  await tester.ensureVisible(_option(e));
  await tester.pump();
  await tester.tap(_option(e));
  await _settle(tester);
}

bool _selected(WidgetTester tester, JournalingExperience e) => tester
    .widget<OnboardingOptionCard>(find.ancestor(
        of: _option(e), matching: find.byType(OnboardingOptionCard)))
    .selected;

void main() {
  test('Saved values: beginner, occasional, regular, unknown', () {
    expect(JournalingExperience.values.map((e) => e.name),
        ['beginner', 'occasional', 'regular', 'unknown']);
    expect(JournalingExperience.options,
        isNot(contains(JournalingExperience.unknown)));
  });

  testWidgets('Copy, progress, three cards with descriptions', (tester) async {
    await _pump(tester);
    expect(find.text(OnboardingExperienceScreen.title), findsOneWidget);
    expect(find.text('Bước 3/9'), findsOneWidget);
    for (final (label, description) in const [
      ('Mình mới bắt đầu', 'Mình muốn có một chút hướng dẫn'),
      ('Mình viết tùy lúc', 'Mình muốn dễ quay lại hơn'),
      ('Mình đã viết khá đều', 'Mình muốn thử cách viết sâu hơn'),
    ]) {
      expect(find.text(label), findsOneWidget);
      expect(find.text(description), findsOneWidget);
    }
    expect(find.byType(OnboardingOptionCard), findsNWidgets(3),
        reason: 'the same card component as OB03');
    expect(_enabled(tester), isFalse);
    expect(_skip, findsOneWidget);
  });

  testWidgets('Picking only selects; single choice', (tester) async {
    final store = await _pump(tester);
    await _pick(tester, JournalingExperience.occasional);
    expect(find.text(OnboardingExperienceScreen.title), findsOneWidget);
    expect(store.experience, isNull, reason: 'nothing saved yet');
    expect(_enabled(tester), isTrue);
    await _pick(tester, JournalingExperience.regular);
    expect(_selected(tester, JournalingExperience.regular), isTrue);
    expect(_selected(tester, JournalingExperience.occasional), isFalse);
  });

  testWidgets('Selected description stays readable on Primary Light',
      (tester) async {
    await _pump(tester);
    await _pick(tester, JournalingExperience.beginner);
    final selected = tester
        .widget<Text>(find.text(JournalingExperience.beginner.description));
    final other = tester
        .widget<Text>(find.text(JournalingExperience.regular.description));
    expect(selected.style!.color, AppColors.textPrimary);
    expect(other.style!.color, AppColors.textSecondary);
  });

  for (final e in JournalingExperience.options) {
    testWidgets('Tiếp tục saves ${e.name}, then OB05', (tester) async {
      final store = await _pump(tester);
      await _pick(tester, e);
      await tester.tap(_cta);
      await _settle(tester);
      expect(store.experience, e);
      expect(store.step, OnboardingStep.features);
    });
  }

  testWidgets('Để sau saves unknown, then OB05', (tester) async {
    final store = await _pump(tester);
    await tester.tap(_skip);
    await _settle(tester);
    expect(store.experience, JournalingExperience.unknown);
    expect(store.step, OnboardingStep.features);
  });

  testWidgets('Resume after Để sau: nothing shown as selected', (tester) async {
    await _pump(tester, values: {
      'onboarding.step': 'experience',
      'onboarding.experience': 'unknown',
    });
    for (final e in JournalingExperience.options) {
      expect(_selected(tester, e), isFalse);
    }
    expect(_enabled(tester), isFalse);
  });

  testWidgets('Resume prefills a saved answer', (tester) async {
    await _pump(tester, values: {
      'onboarding.step': 'experience',
      'onboarding.experience': 'regular',
    });
    expect(_selected(tester, JournalingExperience.regular), isTrue);
  });

  testWidgets('Back to OB03 keeps both choices', (tester) async {
    await _pump(tester, values: {
      'onboarding.step': 'experience',
      'onboarding.goal': 'sortThoughts',
    });
    await _pick(tester, JournalingExperience.beginner);
    await tester.tap(find.byTooltip('Quay lại'));
    await _settle(tester);
    expect(find.text(OnboardingPurposeScreen.title), findsOneWidget);
    expect(
        tester
            .widget<OnboardingOptionCard>(find.ancestor(
                of: find.text(JournalGoal.sortThoughts.label),
                matching: find.byType(OnboardingOptionCard)))
            .selected,
        isTrue);
    await tester.tap(_cta);
    await _settle(tester);
    expect(_selected(tester, JournalingExperience.beginner), isTrue);
  });

  testWidgets('Nudaeng in its scarf, on the shared feet line', (tester) async {
    await _pump(tester, size: const Size(430, 1100));
    final image = tester.getRect(find.bySemanticsLabel('Nudaeng quàng khăn'));
    // Head (3) to feet (532) of the 435×536 cut-out.
    final k = image.width / 435;
    expect((532 - 3) * k, closeTo(OnboardingMascot.figureHeight, 3),
        reason: 'breathing may stretch it up to 2%');
    expect(image.left + 223 * k, closeTo(215, 1), reason: 'feet centred');
  });

  for (final size in const [Size(360, 640), Size(390, 844), Size(430, 932)]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('OB04 fits $size at text scale $scale', (tester) async {
        await _pump(tester, size: size, textScale: scale);
        expect(tester.takeException(), isNull);
        expect(tester.getRect(_skip).bottom, lessThanOrEqualTo(size.height));
        await _pick(tester, JournalingExperience.regular);
        expect(_enabled(tester), isTrue);
      });
    }
  }
}
