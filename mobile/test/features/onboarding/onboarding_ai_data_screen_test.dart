import 'package:ai_diary/core/theme/app_theme.dart';
import 'package:ai_diary/features/onboarding/data/data_policy.dart';
import 'package:ai_diary/features/onboarding/data/onboarding_store.dart';
import 'package:ai_diary/features/onboarding/onboarding_flow.dart';
import 'package:ai_diary/features/onboarding/presentation/onboarding_ai_data_screen.dart';
import 'package:ai_diary/features/onboarding/presentation/onboarding_features_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<OnboardingStore> _pump(
  WidgetTester tester, {
  String step = 'aiAndData',
  Size size = const Size(390, 844),
  double textScale = 1,
  bool reducedMotion = false,
}) async {
  SharedPreferences.setMockInitialValues({'onboarding.step': step});
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

Finder get _withAi => find.widgetWithText(FilledButton, 'Tiếp tục với AI');
Finder get _journalOnly => find.widgetWithText(TextButton, 'Chỉ viết nhật ký');

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

String _allText(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((text) => text.data ?? '')
    .join('\n')
    .toLowerCase();

void main() {
  testWidgets('Title, demo label and the three sections from the policy',
      (tester) async {
    await _pump(tester);
    expect(find.text(OnboardingAiDataScreen.title), findsOneWidget);
    expect(find.text('Bước 5/9'), findsOneWidget);
    expect(DataPolicy.current.approved, isFalse);
    expect(find.text(OnboardingAiDataScreen.demoLabel), findsOneWidget,
        reason: 'unapproved copy is labelled as a demo');
    for (final (heading, body) in [
      (OnboardingAiDataScreen.storageHeading, DataPolicy.current.storage),
      (OnboardingAiDataScreen.aiHeading, DataPolicy.current.aiRequest),
      (OnboardingAiDataScreen.choiceHeading, DataPolicy.choiceNote),
    ]) {
      expect(find.text(heading), findsOneWidget);
      expect(find.text(body), findsOneWidget);
    }
    expect(DataPolicy.choiceNote,
        'Bạn vẫn có thể viết và lưu nhật ký khi không dùng phản hồi AI.');
  });

  testWidgets('Makes no unconfirmed privacy claims', (tester) async {
    await _pump(tester);
    final text = _allText(tester);
    for (final claim in [
      'chỉ lưu trên thiết bị',
      'mã hóa',
      'huấn luyện',
      'được bảo mật',
    ]) {
      expect(text, isNot(contains(claim)), reason: claim);
    }
    expect(find.byIcon(Icons.lock_outline), findsNothing);
    expect(find.byIcon(Icons.lock), findsNothing);
  });

  testWidgets('No policy link until a real one exists', (tester) async {
    await _pump(tester);
    expect(DataPolicy.current.policyUrl, isNull);
    expect(find.text('Cách app dùng dữ liệu'), findsNothing);
  });

  testWidgets('Two explicit paths; no pre-set toggle', (tester) async {
    await _pump(tester);
    expect(_withAi, findsOneWidget);
    expect(_journalOnly, findsOneWidget);
    expect(find.byType(Switch), findsNothing);
    expect(find.byType(Checkbox), findsNothing);
    expect(tester.widget<FilledButton>(_withAi).onPressed, isNotNull);
  });

  testWidgets('Tiếp tục với AI: AI on (no version yet) → OB07', (tester) async {
    final store = await _pump(tester);
    expect(store.aiEnabled, isNull, reason: 'nothing chosen on arrival');
    await tester.tap(_withAi);
    await _settle(tester);
    expect(store.aiEnabled, isTrue);
    expect(store.aiPolicyVersion, isNull,
        reason: 'the demo copy has no policy version');
    expect(store.step, OnboardingStep.firstEntry);
  });

  testWidgets('Chỉ viết nhật ký: AI off → OB07', (tester) async {
    final store = await _pump(tester);
    await tester.tap(_journalOnly);
    await _settle(tester);
    expect(store.aiEnabled, isFalse);
    expect(store.step, OnboardingStep.firstEntry);
  });

  testWidgets('The choice is about AI only: no other consent recorded',
      (tester) async {
    await _pump(tester);
    await tester.tap(_withAi);
    await _settle(tester);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys(), {'onboarding.step', 'onboarding.ai'});
  });

  test('With an approved policy the version is kept; off clears it', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await OnboardingStore.open();
    await store.saveAiChoice(enabled: true, policyVersion: '2026-10-01');
    expect(store.aiPolicyVersion, '2026-10-01');
    await store.saveAiChoice(enabled: false, policyVersion: '2026-10-01');
    expect(store.aiEnabled, isFalse);
    expect(store.aiPolicyVersion, isNull);
  });

  testWidgets('Approved policy: no demo label', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: OnboardingAiDataScreen(
        policy: DataPolicy(
          approved: true,
          version: '2026-10-01',
          storage: 'A',
          aiRequest: 'B',
          policyUrl: Uri.parse('https://example.com/policy'),
        ),
        onBack: () {},
        onChoose: (_) {},
      ),
    ));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text(OnboardingAiDataScreen.demoLabel), findsNothing);
    expect(find.text('A'), findsOneWidget);
  });

  testWidgets('Back → OB05', (tester) async {
    final store = await _pump(tester);
    await tester.tap(find.byTooltip('Quay lại'));
    await _settle(tester);
    expect(store.step, OnboardingStep.features);
    expect(find.text(OnboardingFeaturesScreen.title), findsOneWidget);
    expect(store.aiEnabled, isNull, reason: 'Back is not a choice');
  });

  testWidgets('Desk stays put from OB05 to OB06', (tester) async {
    await _pump(tester,
        step: 'features', size: const Size(430, 1300), reducedMotion: true);
    final ob05 = tester.getRect(find
        .bySemanticsLabel('Nudaeng ngồi bàn xem hướng dẫn trên điện thoại'));
    await tester.tap(find.text(OnboardingFeaturesScreen.continueLabel));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    final ob06 = tester
        .getRect(find.bySemanticsLabel('Nudaeng ngồi bàn xé một mẩu giấy'));
    expect(ob06, ob05, reason: 'same crop, size and spot');
  });

  for (final size in const [Size(360, 640), Size(390, 844), Size(430, 932)]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('OB06 fits $size at text scale $scale', (tester) async {
        await _pump(tester, size: size, textScale: scale);
        expect(tester.takeException(), isNull);
        expect(tester.getRect(_journalOnly).bottom,
            lessThanOrEqualTo(size.height));
        expect(tester.getSize(_journalOnly).height, greaterThanOrEqualTo(48));
      });
    }
  }
}
