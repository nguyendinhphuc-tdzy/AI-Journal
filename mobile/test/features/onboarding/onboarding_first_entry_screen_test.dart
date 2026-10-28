import 'package:ai_diary/core/theme/app_theme.dart';
import 'package:ai_diary/features/journal/data/journal_entry.dart';
import 'package:ai_diary/features/journal/data/journal_mood.dart';
import 'package:ai_diary/features/journal/data/journal_repository.dart';
import 'package:ai_diary/features/journal/data/reflection_service.dart';
import 'package:ai_diary/features/journal/journal_scope.dart';
import 'package:ai_diary/features/onboarding/data/data_policy.dart';
import 'package:ai_diary/features/onboarding/data/onboarding_store.dart';
import 'package:ai_diary/features/onboarding/onboarding_flow.dart';
import 'package:ai_diary/features/onboarding/presentation/first_entry_session.dart';
import 'package:ai_diary/features/onboarding/presentation/onboarding_ai_data_screen.dart';
import 'package:ai_diary/features/onboarding/presentation/onboarding_first_entry_screen.dart';
import 'package:ai_diary/features/onboarding/presentation/onboarding_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Fails on demand, to exercise save and draft errors.
class _FlakyJournals extends InMemoryJournalRepository {
  var failSave = false;
  var failDraft = false;

  @override
  Future<JournalEntry> create(JournalContent content) {
    if (failSave) throw StateError('offline');
    return super.create(content);
  }

  @override
  Future<void> saveDraft(String key, JournalDraft draft) {
    if (failDraft) throw StateError('disk full');
    return super.saveDraft(key, draft);
  }
}

late _FlakyJournals _journals;

Future<OnboardingStore> _pump(
  WidgetTester tester, {
  Map<String, Object> values = const {
    'onboarding.step': 'firstEntry',
    'onboarding.ai': 'off',
  },
  Size size = const Size(390, 844),
  double textScale = 1,
  ReflectionService? reflections,
}) async {
  SharedPreferences.setMockInitialValues(values);
  final store = await OnboardingStore.open();
  _journals = _FlakyJournals();
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  tester.view.padding = const FakeViewPadding(top: 47, bottom: 34);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(JournalScope(
    repository: _journals,
    child: MaterialApp(
      theme: AppTheme.light,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: OnboardingFlow(
          store: store, brandName: 'AI Diary', reflections: reflections),
    ),
  ));
  await tester.pump(const Duration(seconds: 2));
  return store;
}

Finder get _cta => find.descendant(
    of: find.byType(OnboardingFirstEntryScreen),
    matching: find.byType(FilledButton));
Finder get _skip => find.widgetWithText(TextButton, 'Để mình viết sau');

String _ctaLabel(WidgetTester tester) =>
    (tester.widget<FilledButton>(_cta).child! as Text).data!;
bool _enabled(WidgetTester tester) =>
    tester.widget<FilledButton>(_cta).onPressed != null;

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

Future<void> _openBlank(WidgetTester tester, String placeholderOrValue) async {
  await tester.ensureVisible(find.text(placeholderOrValue));
  await tester.tap(find.text(placeholderOrValue));
  await _settle(tester);
}

/// Opens a text blank, types, confirms with "Dùng nội dung này".
Future<void> _fill(WidgetTester tester, String placeholder, String text) async {
  await _openBlank(tester, placeholder);
  await tester.enterText(find.byType(TextField), text);
  await tester.tap(find.text('Dùng nội dung này'));
  await _settle(tester);
}

void main() {
  testWidgets('Copy, progress, four sentences, Save waits for text',
      (tester) async {
    await _pump(tester);
    expect(find.text(OnboardingFirstEntryScreen.title), findsOneWidget);
    expect(find.text(OnboardingFirstEntryScreen.body), findsOneWidget);
    expect(find.text(OnboardingFirstEntryScreen.helper), findsOneWidget);
    expect(find.text('Bước 6/9'), findsOneWidget);
    for (final text in [
      'Lúc này mình cảm thấy',
      'Chọn cảm xúc',
      'Có lẽ vì',
      'Điều khiến mình cảm thấy vậy',
      'Một điều đang ở trong đầu mình là',
      'Điều mình đang nghĩ',
      'Trong vài ngày tới, mình muốn',
      'Một điều mình mong đợi',
    ]) {
      expect(find.text(text), findsOneWidget, reason: text);
    }
    expect(_ctaLabel(tester), 'Lưu nhật ký đầu tiên');
    expect(_enabled(tester), isFalse);
    expect(find.text('Finished!'), findsNothing);
    expect(find.text('✨ Go Deeper'), findsNothing, reason: 'no Go Deeper here');
  });

  testWidgets('Mood sheet: single choice; a mood alone cannot save',
      (tester) async {
    await _pump(tester);
    await _openBlank(tester, 'Chọn cảm xúc');
    for (final mood in JournalMood.values) {
      expect(find.text(mood.label), findsOneWidget);
    }
    await tester.tap(find.text('Vui'));
    await _settle(tester);
    expect(find.text('Vui'), findsOneWidget, reason: 'shown in the sentence');
    expect(find.text('Chọn cảm xúc'), findsNothing);
    expect(_enabled(tester), isFalse);

    await _openBlank(tester, 'Vui');
    await tester.tap(find.text('Để trống'));
    await _settle(tester);
    expect(find.text('Chọn cảm xúc'), findsOneWidget, reason: 'can be empty');
  });

  testWidgets('Text sheet: Close keeps the old value and the typing',
      (tester) async {
    await _pump(tester);
    await _openBlank(tester, 'Điều khiến mình cảm thấy vậy');
    expect(find.text('Điều gì khiến bạn cảm thấy vậy?'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'trời mưa');
    await tester.tap(find.byTooltip('Đóng'));
    await _settle(tester);
    expect(find.text('Điều khiến mình cảm thấy vậy'), findsOneWidget,
        reason: 'not confirmed');
    expect(_enabled(tester), isFalse);

    await _openBlank(tester, 'Điều khiến mình cảm thấy vậy');
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'trời mưa',
        reason: 'the sheet keeps its own draft');
    await tester.tap(find.text('Dùng nội dung này'));
    await _settle(tester);
    expect(find.text('trời mưa'), findsOneWidget);
    expect(_enabled(tester), isTrue);
  });

  testWidgets('Autosaves a draft after 800 ms idle; not an entry',
      (tester) async {
    await _pump(tester);
    await _fill(tester, 'Điều mình đang nghĩ', 'công việc');
    expect(await _journals.draft(FirstEntrySession.draftKey), isNull,
        reason: 'not before the idle delay');
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pump();
    final draft = (await _journals.draft(FirstEntrySession.draftKey))!;
    expect(draft.fields, {'thought': 'công việc'});
    expect(await _journals.entries(), isEmpty);
    expect(find.text(OnboardingFirstEntryScreen.draftSaved), findsOneWidget);
  });

  testWidgets('Save: structured values + readable body; draft cleared',
      (tester) async {
    final store = await _pump(tester);
    await _openBlank(tester, 'Chọn cảm xúc');
    await tester.tap(find.text('Bình yên'));
    await _settle(tester);
    await _fill(tester, 'Một điều mình mong đợi', 'ngủ sớm hơn');
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(_cta);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    final entry = (await _journals.entries()).single;
    expect(entry.content.mood, JournalMood.calm);
    expect(entry.content.guided!.templateId, 'onboarding_first_entry');
    expect(entry.content.guided!.templateVersion, 1);
    expect(entry.content.guided!.fields, {'hope': 'ngủ sớm hơn'});
    expect(entry.body,
        'Lúc này mình cảm thấy bình yên.\nTrong vài ngày tới, mình muốn ngủ sớm hơn.');
    expect(store.firstEntryId, entry.id);
    expect(await _journals.draft(FirstEntrySession.draftKey), isNull);
    expect(store.step, OnboardingStep.entrySaved, reason: 'AI off → OB09');
  });

  testWidgets('AI on: after the save, OB08', (tester) async {
    final store = await _pump(tester,
        values: {
          'onboarding.step': 'firstEntry',
          'onboarding.ai': 'on',
          'onboarding.aiPolicyVersion': DataPolicy.localOllama.version!,
        },
        reflections: MockReflectionService());
    await _fill(tester, 'Điều mình đang nghĩ', 'x');
    await tester.tap(_cta);
    await _settle(tester);
    expect(store.step, OnboardingStep.saving, reason: 'OB08 while AI works');
    await tester.pump(const Duration(seconds: 4)); // the stand-in AI
  });

  testWidgets('Saving: label changes at once, repeated taps save once',
      (tester) async {
    await _pump(tester);
    await _fill(tester, 'Điều mình đang nghĩ', 'x');
    await tester.tap(_cta);
    await tester.pump(Duration.zero);
    await tester.tap(_cta, warnIfMissed: false);
    await tester.tap(_cta, warnIfMissed: false);
    await _settle(tester);
    expect(await _journals.entries(), hasLength(1));
  });

  testWidgets('Save error: stays with the content, Retry same intent',
      (tester) async {
    final store = await _pump(tester);
    await _fill(tester, 'Điều mình đang nghĩ', 'x');
    _journals.failSave = true;
    await tester.tap(_cta);
    await _settle(tester);
    expect(find.text(OnboardingFirstEntryScreen.saveFailed), findsOneWidget);
    expect(_ctaLabel(tester), 'Thử lại');
    expect(find.text('x'), findsOneWidget);
    expect(store.step, OnboardingStep.firstEntry);
    expect(await _journals.entries(), isEmpty);

    _journals.failSave = false;
    await tester.tap(_cta);
    await _settle(tester);
    expect(await _journals.entries(), hasLength(1));
    expect(store.step, OnboardingStep.entrySaved);
  });

  testWidgets('Để mình viết sau with nothing written: OB10, no entry',
      (tester) async {
    final store = await _pump(tester);
    await tester.tap(_skip);
    await _settle(tester);
    expect(store.step, OnboardingStep.reminder);
    expect(await _journals.entries(), isEmpty);
  });

  testWidgets('Để mình viết sau keeps the draft, creates no entry',
      (tester) async {
    final store = await _pump(tester);
    await _fill(tester, 'Điều mình đang nghĩ', 'mai đi học');
    await tester.tap(_skip);
    await _settle(tester);
    expect(store.step, OnboardingStep.reminder);
    expect(await _journals.entries(), isEmpty);
    expect((await _journals.draft(FirstEntrySession.draftKey))!.fields,
        {'thought': 'mai đi học'});
  });

  testWidgets('Draft cannot be kept: ask; "Bỏ bản nháp" lets it go',
      (tester) async {
    final store = await _pump(tester);
    _journals.failDraft = true;
    await _fill(tester, 'Điều mình đang nghĩ', 'x');
    await tester.tap(_skip);
    await _settle(tester);
    for (final option in ['Tiếp tục viết', 'Thử giữ bản nháp', 'Bỏ bản nháp']) {
      expect(find.text(option), findsOneWidget);
    }
    await tester.tap(find.text('Tiếp tục viết'));
    await _settle(tester);
    expect(store.step, OnboardingStep.firstEntry);
    expect(find.text('x'), findsOneWidget);

    await tester.tap(_skip);
    await _settle(tester);
    await tester.tap(find.text('Bỏ bản nháp'));
    await _settle(tester);
    expect(store.step, OnboardingStep.reminder);
    expect(await _journals.entries(), isEmpty);
  });

  testWidgets('Back to OB06 and return: fields and mood kept', (tester) async {
    await _pump(tester);
    await _openBlank(tester, 'Chọn cảm xúc');
    await tester.tap(find.text('Mệt'));
    await _settle(tester);
    await _fill(tester, 'Điều mình đang nghĩ', 'deadline');
    await tester.tap(find.byTooltip('Quay lại'));
    await _settle(tester);
    expect(find.text(OnboardingAiDataScreen.title), findsOneWidget);
    // Change the AI choice on the way back: the text stays.
    await tester.tap(find.text(OnboardingAiDataScreen.withAiLabel));
    await _settle(tester);
    expect(find.text('Mệt'), findsOneWidget);
    expect(find.text('deadline'), findsOneWidget);
  });

  testWidgets('Saved, then Back: same entry, Tiếp tục / Lưu thay đổi',
      (tester) async {
    final store = await _pump(tester);
    await _fill(tester, 'Điều mình đang nghĩ', 'a');
    await tester.tap(_cta);
    await _settle(tester);
    final id = store.firstEntryId;
    await tester.tap(find.byTooltip('Quay lại'));
    await _settle(tester);
    expect(store.step, OnboardingStep.firstEntry);
    expect(_ctaLabel(tester), 'Tiếp tục');

    await tester.tap(_cta);
    await _settle(tester);
    expect(await _journals.entries(), hasLength(1), reason: 'no new entry');
    expect((await _journals.entries()).single.bodyVersion, 1);

    await tester.tap(find.byTooltip('Quay lại'));
    await _settle(tester);
    await _fill(tester, 'a', 'b');
    expect(_ctaLabel(tester), 'Lưu thay đổi');
    await tester.tap(_cta);
    await _settle(tester);
    final entry = (await _journals.entries()).single;
    expect(entry.id, id);
    expect(entry.bodyVersion, 2);
    expect(entry.body, 'Một điều đang ở trong đầu mình là b.');
  });

  testWidgets('Ground hides when the content reaches it', (tester) async {
    await _pump(tester, size: const Size(360, 640));
    await tester.pump();
    expect(find.byType(OnboardingGround), findsNothing,
        reason: 'text never sits on the drawing');
  });

  testWidgets('Large text: labelled field blocks, same order', (tester) async {
    await _pump(tester, textScale: 1.6, size: const Size(390, 1400));
    expect(find.text('Có lẽ vì…'), findsOneWidget);
    expect(find.text('Trong vài ngày tới, mình muốn…'), findsOneWidget);
    final cause = tester.getRect(find.text('Có lẽ vì…'));
    final hope = tester.getRect(find.text('Trong vài ngày tới, mình muốn…'));
    expect(cause.top, lessThan(hope.top));
  });

  testWidgets('Blanks wrap inside the paper; at least 48 high', (tester) async {
    await _pump(tester, size: const Size(360, 900));
    await _fill(tester, 'Điều mình đang nghĩ',
        'một điều rất dài để xem ô có xuống dòng hay không khi màn hình hẹp');
    expect(tester.takeException(), isNull);
    final blank = find
        .ancestor(
            of: find.textContaining('một điều rất dài'),
            matching: find.byType(InkWell))
        .first;
    final rect = tester.getRect(blank);
    expect(rect.right, lessThanOrEqualTo(360 - 20));
    expect(rect.height, greaterThanOrEqualTo(48));
  });

  for (final size in const [Size(360, 640), Size(390, 844), Size(430, 932)]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('OB07 fits $size at text scale $scale', (tester) async {
        await _pump(tester, size: size, textScale: scale);
        expect(tester.takeException(), isNull);
        expect(tester.getRect(_skip).bottom, lessThanOrEqualTo(size.height));
      });
    }
  }
}
