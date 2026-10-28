import 'package:ai_diary/features/profile/profile_screen.dart';
import 'package:ai_diary/features/profile/data/writing_preferences.dart';
import 'package:ai_diary/features/profile/widgets/setting_editor.dart';
import 'package:ai_diary/features/onboarding/data/onboarding_store.dart';
import 'package:ai_diary/features/onboarding/data/journal_goal.dart';
import 'package:ai_diary/features/journal/data/journal_repository.dart';
import 'package:ai_diary/features/journal/presentation/write_journal_screen.dart';
import 'package:ai_diary/features/journal/presentation/ai_reflection_screen.dart';
import 'package:ai_diary/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> openSetting(WidgetTester tester, String name) async {
    const keys = {
      'Bạn bè gọi bạn là gì?': 'what do friends call you?',
      'Cỡ chữ': 'text size',
      'Chọn con đường truyền cảm hứng': 'pick your inspirations path',
      'Rung phản hồi': 'haptic',
    };
    final setting = find.byKey(ValueKey('setting-item-${keys[name] ?? name}'));
    await tester.scrollUntilVisible(setting, 150,
        scrollable: find
            .descendant(
                of: find.byType(ProfileScreen),
                matching: find.byType(Scrollable))
            .first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(setting);
    await tester.pumpAndSettle();
    await tester.tap(setting);
    await tester.pumpAndSettle();
  }

  Future<void> pick(WidgetTester tester, String label) async {
    await tester.tap(find.descendant(
        of: find.byType(SettingEditor), matching: find.text(label)));
    await tester.pumpAndSettle();
  }

  Future<void> select(WidgetTester tester, String label) async {
    await pick(tester, label);
    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'Nickname validates, cancels, and persists without resetting onboarding',
      (tester) async {
    final store = await OnboardingStore.open();
    await store.saveNickname('Trâm');
    await store.complete();
    await tester.pumpWidget(const MaterialApp(home: ProfileScreen()));
    await tester.pumpAndSettle();
    await openSetting(tester, 'Bạn bè gọi bạn là gì?');
    await tester.enterText(find.byType(TextFormField), 'x' * 31);
    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();
    expect(find.text('Biệt danh tối đa 30 ký tự.'), findsOneWidget);
    expect(store.nickname, 'Trâm');
    await tester.tap(find.text('Hủy'));
    await tester.pumpAndSettle();
    await openSetting(tester, 'Bạn bè gọi bạn là gì?');
    await tester.enterText(find.byType(TextFormField), '  Trâm 🌷  ');
    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();
    expect((await OnboardingStore.open()).nickname, 'Trâm 🌷');
    expect(store.completed, isTrue);
  });

  testWidgets(
      'Text size reaches the journal; paper is switched inside the entry',
      (tester) async {
    await tester.pumpWidget(const AiDiaryApp());
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Ảnh đại diện hồ sơ'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('setting-item-paper')), findsNothing);
    await openSetting(tester, 'Cỡ chữ');
    await select(tester, '24 px');
    await tester.tap(find.byTooltip('Đóng'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Viết nhật ký'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Viết nhật ký'));
    await tester.pumpAndSettle();
    expect(
        tester.widget<TextField>(find.byType(TextField)).style!.fontSize, 24);
    expect((await WritingPreferences.open()).paper, JournalPaper.doPaper);
    await tester.tap(find.byTooltip('Đổi nền nhật ký'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Giấy cũ'));
    await tester.pumpAndSettle();
    expect((await WritingPreferences.open()).paper, JournalPaper.aged);
  });

  testWidgets(
      'AI declined in onboarding saves entry without opening reflection',
      (tester) async {
    await (await OnboardingStore.open()).saveAiChoice(enabled: false);
    final journals = InMemoryJournalRepository();
    await tester.pumpWidget(AiDiaryApp(journals: journals));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Viết nhật ký'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Viết nhật ký'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Today I feel peaceful.');
    await tester.tap(find.text('Lưu nhật ký'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xác nhận'));
    await tester.pumpAndSettle();
    expect((await journals.entries()).single.body, 'Today I feel peaceful.');
    expect(find.byType(AiReflectionScreen), findsNothing);
    expect(find.byType(WriteJournalScreen), findsNothing);
  });

  testWidgets('Choices persist and cancelling keeps the saved one',
      (tester) async {
    final store = await OnboardingStore.open();
    await store.saveGoal(JournalGoal.sortThoughts);
    await tester.pumpWidget(const MaterialApp(home: ProfileScreen()));
    await tester.pumpAndSettle();
    await openSetting(tester, 'Chọn con đường truyền cảm hứng');
    // The saved choice is marked; another one is only marked once tapped.
    final saved =
        find.byKey(ValueKey('setting-option-${JournalGoal.sortThoughts.name}'));
    final other = find
        .byKey(ValueKey('setting-option-${JournalGoal.recordDailyLife.name}'));
    expect(tester.getSemantics(saved), isSemantics(isSelected: true));
    await pick(tester, JournalGoal.recordDailyLife.label);
    expect(tester.getSemantics(other), isSemantics(isSelected: true));
    expect(tester.getSemantics(saved), isSemantics(isSelected: false));
    await tester.tap(find.text('Hủy'));
    await tester.pumpAndSettle();
    expect((await OnboardingStore.open()).goal, JournalGoal.sortThoughts);
    await openSetting(tester, 'Chọn con đường truyền cảm hứng');
    await select(tester, JournalGoal.recordDailyLife.label);
    expect((await OnboardingStore.open()).goal, JournalGoal.recordDailyLife);
    expect(
        tester
            .widget<Text>(find.byKey(
                const ValueKey('setting-value-pick your inspirations path')))
            .data,
        JournalGoal.recordDailyLife.label);
    await openSetting(tester, 'Rung phản hồi');
    await select(tester, 'Bật');
    expect((await WritingPreferences.open()).haptic, isTrue);
  });

  testWidgets('Save failure keeps editor open with entered text',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SettingEditor(
      title: 'nickname',
      initial: 'Trâm',
      save: (_) async => throw StateError('disk'),
    ))));
    await tester.enterText(find.byType(TextFormField), 'New name');
    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();
    expect(find.text('Chưa lưu được. Hãy thử lại.'), findsOneWidget);
    expect(find.text('New name'), findsOneWidget);
  });

  test('Haptic setting gates platform feedback and survives reopening',
      () async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      calls.add(call);
      return null;
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
    final prefs = await WritingPreferences.open();
    await prefs.feedback();
    expect(calls, isEmpty);
    await prefs.saveHaptic(true);
    await (await WritingPreferences.open()).feedback();
    expect(calls.single.method, 'HapticFeedback.vibrate');
    await prefs.saveHaptic(false);
    await prefs.feedback();
    expect(calls, hasLength(1));
  });
}
