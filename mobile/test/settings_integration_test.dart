import 'package:ai_diary/features/profile/profile_screen.dart';
import 'package:ai_diary/features/profile/data/writing_preferences.dart';
import 'package:ai_diary/features/profile/widgets/setting_editor.dart';
import 'package:ai_diary/features/onboarding/data/onboarding_store.dart';
import 'package:ai_diary/features/onboarding/data/journal_goal.dart';
import 'package:ai_diary/features/onboarding/data/journaling_experience.dart';
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
      'Nền giấy': 'paper',
      'Cỡ chữ': 'text size',
      'AI Chiêm nghiệm': 'ai reflections',
      'Chọn con đường truyền cảm hứng': 'pick your inspirations path',
      'Trải nghiệm viết nhật ký': 'journaling experience',
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

  Future<void> select(WidgetTester tester, String label) async {
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
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
      'Paper and text size selections reach the journal and palette persists',
      (tester) async {
    await tester.pumpWidget(const AiDiaryApp());
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Ảnh đại diện hồ sơ'));
    await tester.pumpAndSettle();
    await openSetting(tester, 'Nền giấy');
    await select(tester, 'Nền trắng');
    await openSetting(tester, 'Cỡ chữ');
    await select(tester, '24 px');
    await tester.tap(find.byTooltip('Đóng'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cùng suy ngẫm ➔'));
    await tester.pumpAndSettle();
    expect(
        tester.widget<TextField>(find.byType(TextField)).style!.fontSize, 24);
    expect((await WritingPreferences.open()).paper, isFalse);
    await tester.tap(find.byTooltip('Đổi nền nhật ký'));
    await tester.pumpAndSettle();
    expect((await WritingPreferences.open()).paper, isTrue);
  });

  testWidgets('AI disabled in settings saves entry without opening reflection',
      (tester) async {
    final journals = InMemoryJournalRepository();
    await tester.pumpWidget(AiDiaryApp(journals: journals));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Ảnh đại diện hồ sơ'));
    await tester.pumpAndSettle();
    await openSetting(tester, 'AI Chiêm nghiệm');
    await select(tester, 'Không dùng AI');
    await tester.tap(find.byTooltip('Đóng'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cùng suy ngẫm ➔'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Today I feel peaceful.');
    await tester.tap(find.text('Hoàn tất'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xác nhận'));
    await tester.pumpAndSettle();
    expect((await journals.entries()).single.body, 'Today I feel peaceful.');
    expect(find.byType(AiReflectionScreen), findsNothing);
    expect(find.byType(WriteJournalScreen), findsNothing);
  });

  testWidgets('Choices persist and cancelling preserves AI preference',
      (tester) async {
    final store = await OnboardingStore.open();
    await store.saveAiChoice(enabled: false);
    await tester.pumpWidget(const MaterialApp(home: ProfileScreen()));
    await tester.pumpAndSettle();
    await openSetting(tester, 'Chọn con đường truyền cảm hứng');
    await select(tester, JournalGoal.recordDailyLife.label);
    await openSetting(tester, 'Trải nghiệm viết nhật ký');
    await select(tester, JournalingExperience.regular.label);
    await openSetting(tester, 'AI Chiêm nghiệm');
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dùng phản hồi AI mô phỏng').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hủy'));
    await tester.pumpAndSettle();
    expect(store.aiEnabled, isFalse);
    await openSetting(tester, 'AI Chiêm nghiệm');
    await select(tester, 'Dùng phản hồi AI mô phỏng');
    final reopened = await OnboardingStore.open();
    expect(reopened.aiEnabled, isTrue);
    expect(reopened.goal, JournalGoal.recordDailyLife);
    expect(reopened.experience, JournalingExperience.regular);
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
