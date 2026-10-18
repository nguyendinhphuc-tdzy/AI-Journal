import 'package:ai_diary/core/theme/app_colors.dart';
import 'package:ai_diary/core/theme/app_theme.dart';
import 'package:ai_diary/features/onboarding/data/journal_goal.dart';
import 'package:ai_diary/features/onboarding/data/onboarding_store.dart';
import 'package:ai_diary/features/onboarding/onboarding_flow.dart';
import 'package:ai_diary/features/onboarding/presentation/onboarding_nickname_screen.dart';
import 'package:ai_diary/features/onboarding/presentation/onboarding_purpose_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<OnboardingStore> _pump(
  WidgetTester tester, {
  Map<String, Object> values = const {'onboarding.step': 'purpose'},
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
Finder _option(JournalGoal goal) => find.text(goal.label);

bool _enabled(WidgetTester tester) =>
    tester.widget<FilledButton>(_cta).onPressed != null;

/// Scrolls [goal] into view (the list can run under the fold), then taps.
Future<void> _pick(WidgetTester tester, JournalGoal goal) async {
  await tester.ensureVisible(_option(goal));
  await tester.pump();
  await tester.tap(_option(goal));
  await _settle(tester);
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

/// The card's Material (fill + border) for [goal].
Material _card(WidgetTester tester, JournalGoal goal) =>
    tester.widget<Material>(find
        .ancestor(of: _option(goal), matching: find.byType(Material))
        .first);

void main() {
  testWidgets('Copy, progress, five options, nothing preselected',
      (tester) async {
    await _pump(tester);
    expect(find.text('Rất vui được gặp bạn.'), findsOneWidget);
    expect(find.text(OnboardingPurposeScreen.title), findsOneWidget);
    expect(find.text(OnboardingPurposeScreen.helper), findsOneWidget);
    expect(find.text('Bước 2/9'), findsOneWidget);
    expect(JournalGoal.values.map((g) => g.label), [
      'Hiểu bản thân rõ hơn.',
      'Ghi lại cuộc sống hằng ngày.',
      'Sắp xếp những suy nghĩ trong đầu.',
      'Nhìn lại sự thay đổi của mình.',
      'Một lý do khác.',
    ]);
    for (final goal in JournalGoal.values) {
      expect(_option(goal), findsOneWidget);
      expect(_card(tester, goal).color, AppColors.surface);
    }
    expect(_enabled(tester), isFalse, reason: 'enabled after a choice');
    expect(_skip, findsOneWidget);
  });

  testWidgets('Eyebrow greets the saved nickname', (tester) async {
    await _pump(tester,
        values: {'onboarding.step': 'purpose', 'onboarding.nickname': 'Vy'});
    expect(find.text('Rất vui được gặp Vy.'), findsOneWidget);
  });

  testWidgets('Picking only selects: no auto-next, single choice',
      (tester) async {
    final store = await _pump(tester);
    await _pick(tester, JournalGoal.sortThoughts);
    expect(find.text(OnboardingPurposeScreen.title), findsOneWidget,
        reason: 'still on OB03');
    expect(store.step, OnboardingStep.purpose);
    expect(store.goal, isNull, reason: 'nothing saved before Tiếp tục');
    expect(_enabled(tester), isTrue);
    expect(
        _card(tester, JournalGoal.sortThoughts).color, AppColors.primaryLight);

    await _pick(tester, JournalGoal.recordDailyLife);
    expect(_card(tester, JournalGoal.recordDailyLife).color,
        AppColors.primaryLight);
    expect(_card(tester, JournalGoal.sortThoughts).color, AppColors.surface);
  });

  testWidgets('Selected is more than colour: radio fills, border thickens',
      (tester) async {
    await _pump(tester);
    await _pick(tester, JournalGoal.understandMyself);
    final selected = _card(tester, JournalGoal.understandMyself).shape
        as RoundedRectangleBorder;
    final other =
        _card(tester, JournalGoal.other).shape as RoundedRectangleBorder;
    expect(selected.side.width, 2);
    expect(selected.side.color, AppColors.primaryAction);
    expect(other.side.width, 1);
    expect(selected.borderRadius, BorderRadius.circular(20));
    expect(
      tester.getSemantics(
          find.bySemanticsLabel(JournalGoal.understandMyself.label)),
      isSemantics(
        hasCheckedState: true,
        isChecked: true,
        isInMutuallyExclusiveGroup: true,
        hasTapAction: true,
      ),
    );
  });

  testWidgets('Whole card is the hit area, at least 64 high', (tester) async {
    await _pump(tester);
    final card = find
        .ancestor(
            of: _option(JournalGoal.other), matching: find.byType(InkWell))
        .first;
    expect(tester.getSize(card).height, greaterThanOrEqualTo(64));
    // Tap near the left edge, away from the label's centre and the radio.
    await tester.ensureVisible(card);
    await tester.pump();
    final rect = tester.getRect(card);
    await tester.tapAt(Offset(rect.left + 6, rect.center.dy));
    await _settle(tester);
    expect(_card(tester, JournalGoal.other).color, AppColors.primaryLight);
  });

  testWidgets('Tiếp tục saves the goal, then OB04', (tester) async {
    final store = await _pump(tester);
    await _pick(tester, JournalGoal.seeMyChanges);
    await tester.tap(_cta);
    await _settle(tester);
    expect(store.goal, JournalGoal.seeMyChanges);
    expect(store.step, OnboardingStep.experience);
    expect(find.text(OnboardingPurposeScreen.title), findsNothing);
  });

  testWidgets('"Một lý do khác" needs no free text', (tester) async {
    final store = await _pump(tester);
    await _pick(tester, JournalGoal.other);
    expect(find.byType(TextField), findsNothing);
    await tester.tap(_cta);
    await _settle(tester);
    expect(store.goal, JournalGoal.other);
  });

  testWidgets('Để sau: OB04 with no goal, clears an earlier one',
      (tester) async {
    final store = await _pump(tester,
        values: {'onboarding.step': 'purpose', 'onboarding.goal': 'other'});
    expect(_card(tester, JournalGoal.other).color, AppColors.primaryLight,
        reason: 'resumes the saved choice');
    await tester.tap(_skip);
    await _settle(tester);
    expect(store.goal, isNull);
    expect(store.step, OnboardingStep.experience);
  });

  testWidgets('Back to OB02 keeps the choice', (tester) async {
    await _pump(tester);
    await _pick(tester, JournalGoal.sortThoughts);
    await tester.tap(find.byTooltip('Quay lại'));
    await _settle(tester);
    expect(find.text(OnboardingNicknameScreen.title), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Tiếp tục'));
    await _settle(tester);
    expect(
        _card(tester, JournalGoal.sortThoughts).color, AppColors.primaryLight);
  });

  testWidgets('Changing the goal touches no other data', (tester) async {
    final store = await _pump(tester, values: {
      'onboarding.step': 'purpose',
      'onboarding.nickname': 'Vy',
      'onboarding.goal': 'understandMyself',
      'journal.draft': 'Một bản nháp',
    });
    await _pick(tester, JournalGoal.recordDailyLife);
    await tester.tap(_cta);
    await _settle(tester);
    final prefs = await SharedPreferences.getInstance();
    expect(store.goal, JournalGoal.recordDailyLife);
    expect(store.nickname, 'Vy');
    expect(prefs.getString('journal.draft'), 'Một bản nháp');
  });

  testWidgets('Nudaeng with the guitar under the list, 96 high',
      (tester) async {
    // Tall enough for the test font's larger text; no breath while measuring.
    SharedPreferences.setMockInitialValues({'onboarding.step': 'purpose'});
    final store = await OnboardingStore.open();
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(430, 1100);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!),
      home: OnboardingFlow(store: store, brandName: 'AI Diary'),
    ));
    await tester.pump(const Duration(seconds: 2));
    final mascot = find.bySemanticsLabel('Nudaeng ôm đàn');
    expect(mascot, findsOneWidget);
    // Head (92) to feet (1194) of the 1254 px image.
    final image = tester.getRect(find.byType(Image));
    expect(image.height * (1194 - 92) / 1254, closeTo(96, .5));
    final lastCard = tester.getRect(find
        .ancestor(
            of: _option(JournalGoal.other), matching: find.byType(InkWell))
        .first);
    expect(image.top + image.height * 92 / 1254, greaterThan(lastCard.bottom),
        reason: 'under the list');
  });

  for (final size in const [Size(360, 640), Size(390, 844), Size(430, 932)]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('OB03 fits $size at text scale $scale', (tester) async {
        await _pump(tester, size: size, textScale: scale);
        expect(tester.takeException(), isNull);
        expect(tester.getRect(_skip).bottom, lessThanOrEqualTo(size.height));
        expect(tester.getSize(_skip).height, greaterThanOrEqualTo(48));
        expect(tester.getSize(_cta).height, greaterThanOrEqualTo(56));
        // The last option can be scrolled into view and tapped.
        await tester.scrollUntilVisible(_option(JournalGoal.other), 200,
            scrollable: find.byType(Scrollable).first);
        await tester.tap(_option(JournalGoal.other));
        await _settle(tester);
        expect(_enabled(tester), isTrue);
      });
    }
  }
}
