import 'package:ai_diary/core/theme/app_theme.dart';
import 'package:ai_diary/features/onboarding/data/build_features.dart';
import 'package:ai_diary/features/onboarding/data/onboarding_store.dart';
import 'package:ai_diary/features/onboarding/onboarding_flow.dart';
import 'package:ai_diary/features/onboarding/presentation/onboarding_experience_screen.dart';
import 'package:ai_diary/features/onboarding/presentation/onboarding_features_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<OnboardingStore> _pump(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  double textScale = 1,
  bool reducedMotion = false,
}) async {
  SharedPreferences.setMockInitialValues({'onboarding.step': 'features'});
  final store = await OnboardingStore.open();
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  tester.view.padding = const FakeViewPadding(top: 47, bottom: 34);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.light,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
          disableAnimations: reducedMotion),
      child: child!,
    ),
    home: OnboardingFlow(store: store, brandName: 'AI Diary'),
  ));
  await tester.pump(const Duration(seconds: 2));
  return store;
}

Finder get _cta => find.widgetWithText(FilledButton, 'Xem cách hoạt động');

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

void main() {
  testWidgets('Copy, progress and the three cards of this build',
      (tester) async {
    await _pump(tester);
    expect(find.text(OnboardingFeaturesScreen.title), findsOneWidget);
    expect(find.text('Bước 4/9'), findsOneWidget);
    for (final (title, body) in const [
      ('Gợi ý để bắt đầu', 'Một câu hỏi nhỏ giúp bạn tìm điều muốn viết.'),
      (
        'Phản hồi AI khi bạn chọn',
        'Xem một góc nhìn gợi mở từ nội dung bạn gửi để phản hồi.'
      ),
      (
        'Giữ lại những điều đáng nhớ',
        'Lưu ảnh và ghi chú trong Album riêng của bạn.'
      ),
    ]) {
      expect(find.text(title), findsOneWidget);
      expect(find.text(body), findsOneWidget);
    }
    expect(find.byType(TextButton), findsNothing, reason: 'no "Để sau" here');
  });

  test('Cards follow the build: each has a flag', () {
    expect(OnboardingFeaturesScreen.cards.map((c) => c.available), [
      BuildFeatures.writingPrompts,
      BuildFeatures.aiReflection,
      BuildFeatures.album,
    ]);
  });

  testWidgets('Study/places line only when both modules ship', (tester) async {
    await _pump(tester);
    expect(find.text(OnboardingFeaturesScreen.more),
        OnboardingFeaturesScreen.showMore ? findsOneWidget : findsNothing);
    expect(OnboardingFeaturesScreen.showMore,
        BuildFeatures.study && BuildFeatures.places);
  });

  testWidgets('Icons come from one outline set', (tester) async {
    await _pump(tester);
    final icons = tester
        .widgetList<Icon>(find.descendant(
            of: find.byType(OnboardingFeaturesScreen),
            matching: find.byType(Icon)))
        .map((icon) => icon.icon)
        .toList();
    expect(
        icons,
        containsAll(<IconData>[
          Icons.lightbulb_outline_rounded,
          Icons.chat_bubble_outline_rounded,
          Icons.photo_library_outlined,
        ]));
  });

  testWidgets('Nothing advances on its own', (tester) async {
    final store = await _pump(tester);
    await tester.pump(const Duration(seconds: 30));
    expect(find.text(OnboardingFeaturesScreen.title), findsOneWidget);
    expect(store.step, OnboardingStep.features);
    expect(find.byType(PageView), findsNothing, reason: 'no carousel');
  });

  testWidgets('Xem cách hoạt động → OB06', (tester) async {
    final store = await _pump(tester);
    await tester.tap(_cta);
    await _settle(tester);
    expect(store.step, OnboardingStep.aiAndData);
    expect(find.text(OnboardingFeaturesScreen.title), findsNothing);
  });

  testWidgets('Back → OB04', (tester) async {
    final store = await _pump(tester);
    await tester.tap(find.byTooltip('Quay lại'));
    await _settle(tester);
    expect(store.step, OnboardingStep.experience);
    expect(find.text(OnboardingExperienceScreen.title), findsOneWidget);
  });

  testWidgets('Nudaeng at its desk, 120 high, under the cards', (tester) async {
    await _pump(tester, size: const Size(430, 1100), reducedMotion: true);
    final image = tester.getRect(find
        .bySemanticsLabel('Nudaeng ngồi bàn xem hướng dẫn trên điện thoại'));
    final k = image.width / 518;
    expect((488 - 2) * k, closeTo(120, .5));
    expect(image.left + 259 * k, closeTo(215, .5));
    final lastCard = tester.getRect(find
        .ancestor(
            of: find.text('Giữ lại những điều đáng nhớ'),
            matching: find.byType(Container))
        .first);
    expect(image.top, greaterThan(lastCard.bottom));
  });

  for (final size in const [Size(360, 640), Size(390, 844), Size(430, 932)]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('OB05 fits $size at text scale $scale', (tester) async {
        await _pump(tester, size: size, textScale: scale);
        expect(tester.takeException(), isNull);
        expect(tester.getRect(_cta).bottom, lessThanOrEqualTo(size.height));
        expect(tester.getSize(_cta).height, greaterThanOrEqualTo(56));
      });
    }
  }
}
