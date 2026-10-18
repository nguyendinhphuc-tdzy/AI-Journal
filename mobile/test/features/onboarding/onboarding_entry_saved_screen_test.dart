import 'dart:async';

import 'package:ai_diary/core/theme/app_theme.dart';
import 'package:ai_diary/features/journal/data/journal_entry.dart';
import 'package:ai_diary/features/journal/data/journal_repository.dart';
import 'package:ai_diary/features/journal/data/reflection_service.dart';
import 'package:ai_diary/features/journal/journal_scope.dart';
import 'package:ai_diary/features/onboarding/data/onboarding_store.dart';
import 'package:ai_diary/features/onboarding/onboarding_flow.dart';
import 'package:ai_diary/features/onboarding/presentation/onboarding_ai_data_screen.dart';
import 'package:ai_diary/features/onboarding/presentation/onboarding_entry_saved_screen.dart';
import 'package:ai_diary/features/onboarding/presentation/onboarding_first_entry_screen.dart';
import 'package:ai_diary/features/onboarding/presentation/onboarding_preparing_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Answers when the test says so; can fail.
class _Reflections implements ReflectionService {
  final calls = <(String, int)>[];
  final _pending = <Completer<Reflection>>[];
  var fail = false;

  @override
  Future<Reflection> reflect(JournalEntry entry) {
    calls.add((entry.id, entry.bodyVersion));
    final completer = Completer<Reflection>();
    _pending.add(completer);
    if (fail) completer.completeError(StateError('timeout'));
    return completer.future;
  }

  void answer(int call, String text) => _pending[call].complete(Reflection(
        entryId: calls[call].$1,
        bodyVersion: calls[call].$2,
        text: text,
        simulated: true,
      ));
}

late InMemoryJournalRepository _journals;
late _Reflections _reflections;

Future<OnboardingStore> _pump(WidgetTester tester,
    {required bool ai, Size size = const Size(390, 1000)}) async {
  SharedPreferences.setMockInitialValues(
      {'onboarding.step': 'firstEntry', 'onboarding.ai': ai ? 'on' : 'off'});
  final store = await OnboardingStore.open();
  _journals = InMemoryJournalRepository();
  _reflections = _Reflections();
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  tester.view.padding = const FakeViewPadding(top: 47, bottom: 34);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(JournalScope(
    repository: _journals,
    child: MaterialApp(
      theme: AppTheme.light,
      home: OnboardingFlow(
          store: store, brandName: 'AI Diary', reflections: _reflections),
    ),
  ));
  await tester.pump(const Duration(seconds: 2));
  return store;
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

Finder _ctaIn(Type screen) => find.descendant(
    of: find.byType(screen), matching: find.byType(FilledButton));

/// OB07: fill one blank (and optionally the mood), then save.
Future<void> _writeAndSave(WidgetTester tester, String text,
    {String blank = 'Điều mình đang nghĩ', String? mood}) async {
  if (mood != null) {
    await tester.tap(find.text('Chọn cảm xúc'));
    await _settle(tester);
    await tester.tap(find.text(mood));
    await _settle(tester);
  }
  await tester.ensureVisible(find.text(blank));
  await tester.tap(find.text(blank));
  await _settle(tester);
  await tester.enterText(find.byType(TextField), text);
  await tester.tap(find.text('Dùng nội dung này'));
  await _settle(tester);
  await tester.tap(_ctaIn(OnboardingFirstEntryScreen));
  await _settle(tester);
}

/// OB08 → OB09's pending variant.
Future<void> _seeLater(WidgetTester tester) async {
  await tester.tap(find.text('Xem phản hồi sau'));
  await _settle(tester);
}

void main() {
  testWidgets('AI off: saved entry and mood, no AI card, no nudge',
      (tester) async {
    final store = await _pump(tester, ai: false);
    await _writeAndSave(tester, 'mai đi học', mood: 'Lo lắng');
    expect(find.text(OnboardingEntrySavedScreen.savedLabel), findsOneWidget);
    expect(find.text(OnboardingEntrySavedScreen.plainTitle), findsOneWidget);
    expect(find.text('Bạn chọn: Lo lắng'), findsOneWidget);
    expect(find.textContaining('mai đi học'), findsOneWidget);
    expect(
        find.textContaining(OnboardingEntrySavedScreen.aiLabel), findsNothing);
    expect(find.textContaining('bật AI'), findsNothing);
    expect(_reflections.calls, isEmpty, reason: 'AI off: nothing sent');
    expect(find.text('Bước 7/9'), findsOneWidget);

    await tester.tap(_ctaIn(OnboardingEntrySavedScreen));
    await _settle(tester);
    expect(store.step, OnboardingStep.reminder);
  });

  testWidgets('AI on: waits, then the reflection; CTA does not move',
      (tester) async {
    await _pump(tester, ai: true);
    await _writeAndSave(tester, 'chuyến đi');
    await _seeLater(tester);
    expect(find.text(OnboardingEntrySavedScreen.aiTitle), findsOneWidget);
    expect(find.text(OnboardingEntrySavedScreen.notReady), findsOneWidget);
    expect(find.text(OnboardingEntrySavedScreen.laterLabel), findsOneWidget);
    expect(find.textContaining('chuyến đi'), findsOneWidget,
        reason: 'the real entry is shown while waiting');
    await tester.pump(const Duration(seconds: 2)); // entrance done
    final waiting = tester.getRect(_ctaIn(OnboardingEntrySavedScreen));
    expect(
        tester
            .widget<FilledButton>(_ctaIn(OnboardingEntrySavedScreen))
            .onPressed,
        isNotNull,
        reason: 'Tiếp tục always works');

    _reflections.answer(0, 'Có lẽ điều này đáng để viết thêm.');
    await _settle(tester);
    expect(find.text('Gợi ý từ AI · mô phỏng'), findsOneWidget);
    expect(find.text('Có lẽ điều này đáng để viết thêm.'), findsOneWidget);
    expect(find.text(OnboardingEntrySavedScreen.notReady), findsNothing);
    expect(find.textContaining('chuyến đi'), findsOneWidget);
    expect(tester.getRect(_ctaIn(OnboardingEntrySavedScreen)), waiting);
  });

  testWidgets('Xem sau stops the wait; a late result still shows',
      (tester) async {
    await _pump(tester, ai: true);
    await _writeAndSave(tester, 'x');
    await _seeLater(tester);
    await tester.tap(find.text(OnboardingEntrySavedScreen.laterLabel));
    await _settle(tester);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text(OnboardingEntrySavedScreen.laterNote), findsOneWidget);
    _reflections.answer(0, 'Đến muộn nhưng đúng bản.');
    await _settle(tester);
    expect(find.text('Đến muộn nhưng đúng bản.'), findsOneWidget);
  });

  testWidgets('AI error: Thử lại asks again, no duplicate entry',
      (tester) async {
    await _pump(tester, ai: true);
    _reflections.fail = true;
    await _writeAndSave(tester, 'x');
    expect(find.text(OnboardingEntrySavedScreen.notReady), findsOneWidget);
    expect(find.text(OnboardingEntrySavedScreen.retryLabel), findsOneWidget);
    _reflections.fail = false;
    await tester.tap(find.text(OnboardingEntrySavedScreen.retryLabel));
    await _settle(tester);
    expect(_reflections.calls, hasLength(2));
    expect(_reflections.calls[1], _reflections.calls[0], reason: 'same entry');
    _reflections.answer(1, 'Lần này được rồi.');
    await _settle(tester);
    expect(find.text('Lần này được rồi.'), findsOneWidget);
    expect(await _journals.entries(), hasLength(1));
  });

  testWidgets('A late answer for the old text never shows on new text',
      (tester) async {
    await _pump(tester, ai: true);
    await _writeAndSave(tester, 'bản một');
    await tester.tap(find.byTooltip('Quay lại'));
    await _settle(tester);
    await tester.tap(find.text('bản một'));
    await _settle(tester);
    await tester.enterText(find.byType(TextField), 'bản hai');
    await tester.tap(find.text('Dùng nội dung này'));
    await _settle(tester);
    await tester.tap(_ctaIn(OnboardingFirstEntryScreen));
    await _settle(tester);
    expect(_reflections.calls.map((c) => c.$2), [1, 2]);

    _reflections.answer(0, 'Phản hồi cho bản một.');
    await _settle(tester);
    expect(find.text('Phản hồi cho bản một.'), findsNothing);
    expect(find.text(OnboardingPreparingScreen.title), findsOneWidget,
        reason: 'still waiting for the new version');
    _reflections.answer(1, 'Phản hồi cho bản hai.');
    await _settle(tester);
    expect(find.text('Phản hồi cho bản hai.'), findsOneWidget);
    expect((await _journals.entries()).single.bodyVersion, 2);
  });

  testWidgets('Same text again: reuses the reflection, no new request',
      (tester) async {
    await _pump(tester, ai: true);
    await _writeAndSave(tester, 'x');
    _reflections.answer(0, 'Một góc nhìn.');
    await _settle(tester);
    await tester.tap(find.byTooltip('Quay lại'));
    await _settle(tester);
    await tester.tap(_ctaIn(OnboardingFirstEntryScreen)); // "Tiếp tục"
    await _settle(tester);
    expect(_reflections.calls, hasLength(1));
    expect(find.text('Một góc nhìn.'), findsOneWidget);
  });

  testWidgets('AI switched off while waiting: the answer is ignored',
      (tester) async {
    await _pump(tester, ai: true);
    await _writeAndSave(tester, 'x');
    await tester.tap(find.byTooltip('Quay lại')); // OB07
    await _settle(tester);
    await tester.tap(find.byTooltip('Quay lại')); // OB06
    await _settle(tester);
    await tester.tap(find.text(OnboardingAiDataScreen.journalOnlyLabel));
    await _settle(tester);
    await tester.tap(_ctaIn(OnboardingFirstEntryScreen)); // "Tiếp tục"
    await _settle(tester);
    _reflections.answer(0, 'Không được hiện.');
    await _settle(tester);
    expect(find.text(OnboardingEntrySavedScreen.plainTitle), findsOneWidget);
    expect(find.text('Không được hiện.'), findsNothing);
    expect(_reflections.calls, hasLength(1), reason: 'nothing new sent');
  });

  test('Stand-in reflection: tentative, never the screenshot text', () {
    final entry = JournalEntry(
      id: 'e',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      bodyVersion: 1,
      content: const JournalContent(
        body: 'x',
        guided: GuidedValues(
            templateId: 't', templateVersion: 1, fields: {'cause': 'x'}),
      ),
    );
    final text = MockReflectionService.textFor(entry);
    expect(text, isNot(contains('Overwhelmed')));
    expect(text, isNot(contains('áp lực')));
    expect(RegExp(r'có thể|có lẽ|đôi khi', caseSensitive: false).hasMatch(text),
        isTrue,
        reason: 'open, not conclusive');
    expect(
        RegExp(r'[\u{1F300}-\u{1FAFF}]', unicode: true).hasMatch(text), isFalse,
        reason: 'no emoji');
  });

  for (final size in const [Size(360, 640), Size(390, 844), Size(430, 932)]) {
    testWidgets('OB09 fits $size', (tester) async {
      await _pump(tester, ai: true, size: size);
      await _writeAndSave(tester, 'một câu khá dài để xem bố cục có ổn không');
      _reflections.answer(
          0, 'Có lẽ đây là một khởi đầu.\n\nĐôi khi vậy là đủ.');
      await _settle(tester);
      expect(tester.takeException(), isNull);
      expect(tester.getRect(_ctaIn(OnboardingEntrySavedScreen)).bottom,
          lessThanOrEqualTo(size.height));
    });
  }
}
