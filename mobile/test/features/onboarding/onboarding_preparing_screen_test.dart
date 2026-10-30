import 'dart:async';

import 'package:ai_diary/core/theme/app_theme.dart';
import 'package:ai_diary/features/journal/data/journal_entry.dart';
import 'package:ai_diary/features/journal/data/journal_repository.dart';
import 'package:ai_diary/features/journal/data/reflection_service.dart';
import 'package:ai_diary/features/journal/journal_scope.dart';
import 'package:ai_diary/features/onboarding/data/data_policy.dart';
import 'package:ai_diary/features/onboarding/data/onboarding_store.dart';
import 'package:ai_diary/features/onboarding/onboarding_flow.dart';
import 'package:ai_diary/features/onboarding/presentation/onboarding_ai_data_screen.dart';
import 'package:ai_diary/features/onboarding/presentation/onboarding_entry_saved_screen.dart';
import 'package:ai_diary/features/onboarding/presentation/onboarding_first_entry_screen.dart';
import 'package:ai_diary/features/onboarding/presentation/onboarding_preparing_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Reflections implements ReflectionService {
  final calls = <JournalEntry>[];
  final _pending = <Completer<Reflection>>[];

  @override
  Future<Reflection> reflect(JournalEntry entry) {
    calls.add(entry);
    final completer = Completer<Reflection>();
    _pending.add(completer);
    return completer.future;
  }

  void answer(int call, String text) => _pending[call].complete(Reflection(
      entryId: calls[call].id,
      bodyVersion: calls[call].bodyVersion,
      text: text,
      simulated: true));

  void fail(int call) => _pending[call].completeError(TimeoutException('ai'));
}

/// Saves only when the test says so.
class _SlowJournals extends InMemoryJournalRepository {
  Completer<void>? gate;

  @override
  Future<JournalEntry> create(JournalContent content) async {
    await gate?.future;
    return super.create(content);
  }
}

late _SlowJournals _journals;
late _Reflections _reflections;

Future<OnboardingStore> _pump(WidgetTester tester,
    {bool ai = true, String step = 'firstEntry'}) async {
  SharedPreferences.setMockInitialValues(
      {
        'onboarding.step': step,
        'onboarding.ai': ai ? 'on' : 'off',
        // Consent is to the current AI policy (OB06).
        if (ai) 'onboarding.aiPolicyVersion': DataPolicy.localOllama.version!,
      });
  final store = await OnboardingStore.open();
  _journals = _SlowJournals();
  _reflections = _Reflections();
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 1000);
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

Future<void> _write(WidgetTester tester, String text) async {
  await tester.tap(find.text('Điều mình đang nghĩ'));
  await _settle(tester);
  await tester.enterText(find.byType(TextField), text);
  await tester.tap(find.text('Dùng nội dung này'));
  await _settle(tester);
}

Future<void> _save(WidgetTester tester) async {
  await tester.tap(_ctaIn(OnboardingFirstEntryScreen));
  await _settle(tester);
}

void main() {
  testWidgets('AI on: OB08 only once saved; status, no percentage',
      (tester) async {
    final store = await _pump(tester);
    await _write(tester, 'x');
    await _save(tester);
    expect(store.step, OnboardingStep.saving);
    expect(store.firstEntryId, isNotNull, reason: 'entered with an entry id');
    expect(find.text(OnboardingPreparingScreen.title), findsOneWidget);
    expect(find.text(OnboardingPreparingScreen.savedLabel), findsOneWidget);
    expect(find.text('Bước 6/9'), findsOneWidget, reason: 'keeps OB07 step');
    expect(find.textContaining('%'), findsNothing);
    expect(
        tester
            .widget<CircularProgressIndicator>(
                find.byType(CircularProgressIndicator))
            .value,
        isNull,
        reason: 'indeterminate');
    expect(_reflections.calls.single.id, store.firstEntryId);
  });

  testWidgets('A fast answer goes on at once: no minimum duration',
      (tester) async {
    final store = await _pump(tester);
    await _write(tester, 'x');
    await _save(tester);
    _reflections.answer(0, 'Nhanh.');
    await tester.pump(); // one frame, no waiting
    await tester.pump();
    expect(store.step, OnboardingStep.entrySaved);
    await _settle(tester);
    expect(find.text('Nhanh.'), findsOneWidget);
  });

  testWidgets('Xem phản hồi sau → OB09 pending; then it carries on',
      (tester) async {
    final store = await _pump(tester);
    await _write(tester, 'x');
    await _save(tester);
    await tester.tap(find.text(OnboardingPreparingScreen.laterLabel));
    await _settle(tester);
    expect(store.step, OnboardingStep.entrySaved);
    expect(find.text(OnboardingEntrySavedScreen.notReady), findsOneWidget);
    _reflections.answer(0, 'Sau đó.');
    await _settle(tester);
    expect(find.text('Sau đó.'), findsOneWidget);
    await tester.tap(_ctaIn(OnboardingEntrySavedScreen));
    await _settle(tester);
    expect(store.step, OnboardingStep.reminder);
  });

  testWidgets('AI error or timeout: on to OB09 with Thử lại, entry kept',
      (tester) async {
    final store = await _pump(tester);
    await _write(tester, 'giữ nguyên');
    await _save(tester);
    _reflections.fail(0);
    await _settle(tester);
    expect(store.step, OnboardingStep.entrySaved);
    expect(find.text(OnboardingEntrySavedScreen.retryLabel), findsOneWidget);
    expect(find.textContaining('giữ nguyên'), findsOneWidget);

    await tester.tap(find.text(OnboardingEntrySavedScreen.retryLabel));
    await _settle(tester);
    expect(_reflections.calls[1].id, _reflections.calls[0].id);
    expect(
        _reflections.calls[1].bodyVersion, _reflections.calls[0].bodyVersion);
    expect(await _journals.entries(), hasLength(1), reason: 'no new save');
  });

  testWidgets('AI off: straight to OB09, never OB08', (tester) async {
    final store = await _pump(tester, ai: false);
    await _write(tester, 'x');
    await tester.tap(_ctaIn(OnboardingFirstEntryScreen));
    await tester.pump();
    expect(find.byType(OnboardingPreparingScreen), findsNothing);
    await _settle(tester);
    expect(store.step, OnboardingStep.entrySaved);
    expect(find.byType(OnboardingPreparingScreen), findsNothing);
    expect(_reflections.calls, isEmpty);
  });

  testWidgets('Back from OB08 → OB07', (tester) async {
    final store = await _pump(tester);
    await _write(tester, 'x');
    await _save(tester);
    await tester.tap(find.byTooltip('Quay lại'));
    await _settle(tester);
    expect(store.step, OnboardingStep.firstEntry);
  });

  testWidgets('OB07 saving: "Đang lưu…", Back does not cancel the save',
      (tester) async {
    final store = await _pump(tester);
    await _write(tester, 'x');
    _journals.gate = Completer<void>();
    await tester.tap(_ctaIn(OnboardingFirstEntryScreen));
    await tester.pump();
    expect(find.text(OnboardingFirstEntryScreen.savingLabel), findsOneWidget);
    expect(find.text(OnboardingPreparingScreen.savedLabel), findsNothing,
        reason: 'not "saved" before it is');

    await tester.tap(find.byTooltip('Quay lại'));
    await _settle(tester);
    expect(find.text(OnboardingAiDataScreen.title), findsOneWidget);
    _journals.gate!.complete();
    await _settle(tester);
    expect(store.step, OnboardingStep.aiAndData, reason: 'no jump on its own');
    expect(await _journals.entries(), hasLength(1), reason: 'save finished');
    expect(store.firstEntryId, isNotNull);

    await tester.tap(find.text(OnboardingAiDataScreen.continueLabel));
    await _settle(tester);
    expect(
        (tester.widget<FilledButton>(_ctaIn(OnboardingFirstEntryScreen)).child!
                as Text)
            .data,
        'Tiếp tục',
        reason: 'the saved entry, not a new one');
  });

  testWidgets('Resumed on OB08 with nothing running: no fake wait',
      (tester) async {
    final store = await _pump(tester, step: 'saving');
    await _settle(tester);
    expect(store.step, OnboardingStep.entrySaved);
  });
}
