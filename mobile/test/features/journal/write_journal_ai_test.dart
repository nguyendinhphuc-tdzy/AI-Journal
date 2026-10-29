import 'package:ai_diary/core/theme/app_theme.dart';
import 'package:ai_diary/features/journal/data/api_ai_service.dart';
import 'package:ai_diary/features/journal/data/quote_picker.dart';
import 'package:ai_diary/features/journal/data/journal_repository.dart';
import 'package:ai_diary/features/journal/journal_scope.dart';
import 'package:ai_diary/features/journal/presentation/ai_conversation.dart';
import 'package:ai_diary/features/journal/presentation/ai_reflection_screen.dart';
import 'package:ai_diary/features/journal/presentation/sentence_case.dart';
import 'package:ai_diary/features/journal/presentation/write_journal_screen.dart';
import 'package:ai_diary/features/onboarding/data/onboarding_scope.dart';
import 'package:ai_diary/features/onboarding/data/onboarding_store.dart';
import 'package:ai_diary/features/streak/streak_screen.dart';
import 'package:ai_diary/features/streak/streak_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_ai.dart';

late InMemoryJournalRepository _journals;

/// The editor as a signed-in account has it: AI, and the user's onboarding
/// answers (here "Chỉ viết nhật ký" and, if given, a goal).
Future<void> _pump(WidgetTester tester, FakeAi ai, {String? goal}) async {
  SharedPreferences.setMockInitialValues({
    'onboarding.completed': true,
    'onboarding.ai': 'off',
    if (goal != null) 'onboarding.goal': goal,
  });
  final onboarding = await OnboardingStore.open();
  _journals = InMemoryJournalRepository();
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(412, 915);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(AiRemoteScope(
    service: ai.service,
    child: OnboardingScope(
      store: onboarding,
      child: JournalScope(
        repository: _journals,
        child: MaterialApp(
          theme: AppTheme.light,
          home: const WriteJournalScreen(),
        ),
      ),
    ),
  ));
  await tester.pump();
}

Finder get _deeper =>
    find.widgetWithText(FilledButton, WriteJournalScreen.deeperLabel);

bool _deeperOn(WidgetTester tester) =>
    tester.widget<FilledButton>(_deeper).onPressed != null;

Future<void> _ask(WidgetTester tester) async {
  await tester.tap(find.text(WriteJournalScreen.deeperLabel));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _save(WidgetTester tester) async {
  await tester.tap(find.text(WriteJournalScreen.finishLabel));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Xác nhận'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  setUp(StreakState.shared.reset);

  group('sentenceCase', () {
    test('raises the first letter of each sentence, Vietnamese included', () {
      expect(sentenceCase('hòa bình'), 'Hòa bình');
      expect(sentenceCase('đôi khi vậy. ổn mà! ừ? ở đây… và thế'),
          'Đôi khi vậy. Ổn mà! Ừ? Ở đây… Và thế');
      expect(sentenceCase('một dòng\nhai dòng'), 'Một dòng\nHai dòng');
    });

    test('leaves the rest as written', () {
      expect(sentenceCase('"bạn" nghĩ sao? AI, 3.5 điểm'),
          '"Bạn" nghĩ sao? AI, 3.5 điểm');
      expect(sentenceCase('Đã viết hoa.'), 'Đã viết hoa.');
      expect(sentenceCase(''), '');
    });
  });

  group('AiConversation', () {
    ({String question, String answer}) round(int i, int length) =>
        (question: 'Q$i?', answer: 'a$i' * length);

    test('all of it when it fits', () {
      final text = AiConversation(
        prompt: 'P?',
        entry: 'mở đầu',
        rounds: [round(1, 3), round(2, 3)],
        goal: 'Hiểu bản thân rõ hơn.',
      ).text();
      expect(text,
          'Câu hỏi: P?\nTrả lời: mở đầu\n'
          'Câu hỏi: Q1?\nTrả lời: a1a1a1\n'
          'Câu hỏi: Q2?\nTrả lời: a2a2a2\n'
          'Người viết muốn viết nhật ký để: Hiểu bản thân rõ hơn.');
    });

    test('too long: the start and latest whole, older shortened, then left '
        'out with a note', () {
      final rounds = [for (var i = 1; i <= 12; i++) round(i, 150)];
      final text = AiConversation(prompt: 'P?', entry: 'mở đầu', rounds: rounds)
          .text(budget: 2000);
      expect(text.length, lessThanOrEqualTo(2000 + 60));
      expect(text, startsWith('Câu hỏi: P?\nTrả lời: mở đầu\n(Đã lược bớt '));
      expect(text, endsWith('Câu hỏi: Q12?\nTrả lời: ${'a12' * 150}'),
          reason: 'the latest answer whole');
      expect(text, contains('Câu hỏi: Q11?\nTrả lời: ${'a11' * 150}'));
      expect(text, contains('…'), reason: 'older answers shortened');
      expect(text, isNot(contains('Câu hỏi: Q1?')), reason: 'oldest left out');
    });

    test('a very long entry is cut to half the budget', () {
      final text =
          AiConversation(prompt: 'P?', entry: 'x' * 9000).text(budget: 6000);
      expect(text.length, lessThanOrEqualTo(6000));
      expect(text, endsWith('…'));
    });
  });

  testWidgets('Signed in: AI reflects on save even after "Chỉ viết nhật ký"',
      (tester) async {
    final ai = FakeAi();
    await _pump(tester, ai);
    await tester.enterText(find.byType(TextField), 'Chiều nay đi dạo.');
    await _save(tester);
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(AiReflectionScreen), findsOneWidget);
    expect(ai.reflectionSent,
        ['Câu hỏi: Hôm nay bạn cảm thấy thế nào?\nTrả lời: Chiều nay đi dạo.']);
    // The AI's lower-case words, shown with capitals.
    expect(find.text('Nhẹ nhõm'), findsOneWidget);
    expect(find.text('Bạn đã cho mình một buổi chiều chậm lại.'),
        findsOneWidget);
    expect(find.text('Điều gì giúp bạn thấy nhẹ lòng nhất hôm nay?'),
        findsOneWidget);
    expect(await _journals.entries(), hasLength(1));
  });

  testWidgets('Nhìn lại cùng bạn: the AI asks from what was written',
      (tester) async {
    final ai = FakeAi(questions: [
      'điều gì khiến bạn thấy chán?',
      'lúc nào bạn thấy đỡ hơn?',
    ]);
    await _pump(tester, ai, goal: 'understandMyself');
    expect(_deeperOn(tester), isFalse, reason: 'nothing written yet');

    await tester.enterText(find.byType(TextField), 'Chán quá đi');
    await tester.pump();
    await _ask(tester);
    expect(ai.deeperSent.single,
        'Câu hỏi: Hôm nay bạn cảm thấy thế nào?\n'
        'Trả lời: Chán quá đi\n'
        'Người viết muốn viết nhật ký để: Hiểu bản thân rõ hơn.');
    expect(find.text('Điều gì khiến bạn thấy chán?'), findsOneWidget);
    expect(find.text('Chán quá đi'), findsOneWidget, reason: 'kept above');
    expect(
        tester.widget<TextField>(find.byType(TextField)).decoration!.hintText,
        'Chia sẻ suy nghĩ của bạn...');
    expect(_deeperOn(tester), isFalse, reason: 'answer this one first');

    // Answered: one question deeper, with the whole conversation.
    await tester.enterText(find.byType(TextField), 'Việc học dồn lại');
    await tester.pump();
    expect(_deeperOn(tester), isTrue);
    await _ask(tester);
    expect(ai.deeperSent[1],
        'Câu hỏi: Hôm nay bạn cảm thấy thế nào?\n'
        'Trả lời: Chán quá đi\n'
        'Câu hỏi: Điều gì khiến bạn thấy chán?\n'
        'Trả lời: Việc học dồn lại\n'
        'Người viết muốn viết nhật ký để: Hiểu bản thân rõ hơn.');
    expect(find.text('Lúc nào bạn thấy đỡ hơn?'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Khi đi bộ');
    await tester.pump();
    await _save(tester);
    expect((await _journals.entries()).single.body,
        'Chán quá đi\n\n'
        'Điều gì khiến bạn thấy chán?\nViệc học dồn lại\n\n'
        'Lúc nào bạn thấy đỡ hơn?\nKhi đi bộ',
        reason: 'the AI questions are kept with the answers');
  });

  testWidgets('No limit: after ${WriteJournalScreen.deepNudgeAfter} questions '
      'a gentle note to save, and asking still works', (tester) async {
    final ai = FakeAi();
    await _pump(tester, ai);
    await tester.enterText(find.byType(TextField), 'Một ngày dài');
    await tester.pump();
    for (var i = 0; i < WriteJournalScreen.deepNudgeAfter; i++) {
      expect(find.text(WriteJournalScreen.deepNudge), findsNothing);
      await _ask(tester);
      await tester.enterText(find.byType(TextField), 'Trả lời $i');
      await tester.pump();
    }
    expect(find.text(WriteJournalScreen.deepNudge), findsOneWidget);
    expect(_deeperOn(tester), isTrue);
    await _ask(tester);
    expect(ai.deeperSent, hasLength(WriteJournalScreen.deepNudgeAfter + 1));
  });

  testWidgets('Turned off in Hồ sơ: nothing sent, the streak, and a note',
      (tester) async {
    final ai = FakeAi();
    await _pump(tester, ai);
    final store = await OnboardingStore.open();
    await store.saveAiInApp(false);
    await tester.enterText(find.byType(TextField), 'Riêng tư');
    await tester.pump();
    await _ask(tester);
    expect(find.text(WriteJournalScreen.aiOff), findsOneWidget);
    expect(ai.deeperSent, isEmpty);
    await _save(tester);
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(AiReflectionScreen), findsNothing);
    expect(find.byType(StreakScreen), findsOneWidget);
    expect(ai.reflectionSent, isEmpty);
    expect(await _journals.entries(), hasLength(1));
  });

  testWidgets('Analysis reads the questions too; "Nhật ký" shows them',
      (tester) async {
    final ai = FakeAi(questions: ['vì sao vậy?']);
    await _pump(tester, ai);
    await tester.enterText(find.byType(TextField), 'Chán quá đi');
    await tester.pump();
    await _ask(tester);
    await tester.enterText(find.byType(TextField), 'Bài nhiều');
    await tester.pump();
    await _save(tester);
    await tester.pump(const Duration(seconds: 1));
    expect(ai.reflectionSent.single,
        'Câu hỏi: Hôm nay bạn cảm thấy thế nào?\n'
        'Trả lời: Chán quá đi\n'
        'Câu hỏi: Vì sao vậy?\n'
        'Trả lời: Bài nhiều');
    expect((await _journals.entries()).single.body,
        'Chán quá đi\n\nVì sao vậy?\nBài nhiều');
    await tester.tap(find.text('Nhật ký'));
    await tester.pump();
    expect(find.text('Hôm nay bạn cảm thấy thế nào?'), findsOneWidget);
    expect(find.text('Vì sao vậy?'), findsOneWidget);
    expect(find.text('Bài nhiều'), findsOneWidget);
  });

  testWidgets('Analysis, then the backend\'s quote, then the streak',
      (tester) async {
    final ai = FakeAi(analysis: {
      ...FakeAi.reflection,
      'title': 'né tránh chuyện học',
      'analysis': 'có vẻ chuyện học đang nặng hơn một phần bình thường.',
      'topics': ['học tập', 'né tránh'],
      'quote': {'text': 'Một câu đã kiểm chứng.', 'author': 'Tác giả A'},
    });
    await _pump(tester, ai);
    await tester.enterText(find.byType(TextField), 'Không muốn nghĩ tới trường');
    await _save(tester);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Né tránh chuyện học'), findsOneWidget);
    expect(find.text('Có vẻ chuyện học đang nặng hơn một phần bình thường.'),
        findsOneWidget);
    expect(find.text('Điều chúng mình nhận thấy'), findsOneWidget);
    expect(find.text('Bạn đã cho mình một buổi chiều chậm lại.'), findsOneWidget);
    expect(find.text('Tâm trạng: Nhẹ nhõm'), findsOneWidget);
    expect(find.text('Chủ đề: Học tập'), findsOneWidget);
    expect(find.text('Chủ đề: Né tránh'), findsOneWidget);
    expect(find.text('Một câu đã kiểm chứng.'), findsNothing,
        reason: 'the quote comes after the analysis');

    await tester.tap(find.text('Tiếp tục'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Một câu đã kiểm chứng.'), findsOneWidget);
    expect(find.text('– Tác giả A'), findsOneWidget,
        reason: 'a short dash, never an em dash');
    expect(find.text('Theodore Roosevelt'), findsNothing);
    await tester.tap(find.text('Tiếp tục'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(StreakScreen), findsOneWidget);
  });

  testWidgets('No quote from the backend: the team\'s quote that fits the '
      'analysis', (tester) async {
    final ai = FakeAi(analysis: {
      ...FakeAi.reflection,
      'emotion': 'áp lực',
      'observation': 'việc học dồn lại khiến bạn thấy ngợp.',
    });
    await _pump(tester, ai);
    await tester.enterText(find.byType(TextField), 'Bài tập nhiều quá');
    await _save(tester);
    await tester.pump(const Duration(seconds: 1));
    final expected = const QuotePicker().pick(
        AiAnalysis.fromJson(ai.analysis.cast<String, dynamic>()),
        entry: 'Bài tập nhiều quá',
        seed: 'Bài tập nhiều quá')!;
    expect(expected.tags, contains('áp lực'));
    await tester.tap(find.text('Tiếp tục'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text(expected.text), findsOneWidget);
    expect(find.text('– ${expected.author}'), findsOneWidget);
    expect(find.text('Theodore Roosevelt'), findsNothing);
  });

  testWidgets('Nothing fits and no backend quote: never a made-up one, on to '
      'the streak', (tester) async {
    final ai = FakeAi(analysis: {
      'emotion': 'bình thường',
      'observation': 'một ngày như mọi ngày.',
      'reflection': 'đôi khi ngày bình thường cũng đáng ghi lại.',
      'question': 'điều gì nhỏ bé bạn muốn giữ lại?',
    });
    await _pump(tester, ai);
    await tester.enterText(find.byType(TextField), 'Không có gì đặc biệt');
    await _save(tester);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Bình thường'), findsOneWidget,
        reason: 'title: the emotion');
    await tester.tap(find.text('Tiếp tục'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Theodore Roosevelt'), findsNothing);
    expect(find.byType(StreakScreen), findsOneWidget);
  });

  testWidgets('The AI does not answer: say so, keep the text, try again',
      (tester) async {
    final ai = FakeAi()..failNextDeeper = true;
    await _pump(tester, ai);
    await tester.enterText(find.byType(TextField), 'Hơi mệt');
    await tester.pump();
    await _ask(tester);
    expect(find.text(WriteJournalScreen.deeperFailed), findsOneWidget);
    expect(find.text('Hơi mệt'), findsOneWidget);
    expect(
        tester.widget<TextField>(find.byType(TextField)).decoration!.hintText,
        'Bắt đầu viết...',
        reason: 'no question was added');
    expect(_deeperOn(tester), isTrue);

    await _ask(tester);
    expect(find.text('Điều gì khiến bạn thấy như vậy?'), findsOneWidget);
  });
}
