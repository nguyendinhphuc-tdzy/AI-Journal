import 'package:ai_diary/core/theme/app_theme.dart';
import 'package:ai_diary/features/journal/data/api_ai_service.dart';
import 'package:ai_diary/features/journal/data/journal_repository.dart';
import 'package:ai_diary/features/journal/journal_scope.dart';
import 'package:ai_diary/features/journal/presentation/ai_reflection_screen.dart';
import 'package:ai_diary/features/journal/presentation/write_journal_screen.dart';
import 'package:ai_diary/features/onboarding/data/onboarding_scope.dart';
import 'package:ai_diary/features/onboarding/data/onboarding_store.dart';
import 'package:ai_diary/features/profile/profile_screen.dart';
import 'package:ai_diary/features/streak/streak_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_ai.dart';

/// Small phone, phone, landscape; normal and large text.
const _sizes = [Size(320, 568), Size(390, 844), Size(844, 390)];
const _scales = [1.0, 2.0];

const _long = 'Có vẻ chuyện học đang nặng hơn một phần bình thường của ngày: '
    'bài tập dồn lại, điểm số khiến bạn lo, và việc nghĩ tới trường trở thành '
    'điều bạn muốn tránh. Điều đó dễ hiểu khi mọi thứ đến cùng một lúc.';

Future<void> _pump(WidgetTester tester, Widget home, FakeAi ai,
    {required Size size, required double scale}) async {
  SharedPreferences.setMockInitialValues({'onboarding.completed': true});
  final onboarding = await OnboardingStore.open();
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(AiRemoteScope(
    service: ai.service,
    child: OnboardingScope(
      store: onboarding,
      child: JournalScope(
        repository: InMemoryJournalRepository(),
        child: MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: home,
        ),
      ),
    ),
  ));
  await tester.pump();
}

/// Scrolls the screen until [finder] is built and shown.
Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    // Back to the top first: it may be above what is shown.
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 5000));
    await tester.pump();
  }
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(finder, 150,
        scrollable: find.byType(Scrollable).first);
  }
  await tester.ensureVisible(finder.first);
  await tester.pump();
}

/// [finder] can be reached: on screen, scrolling to it if need be.
Future<void> _reach(WidgetTester tester, Finder finder, Size size) async {
  await _scrollTo(tester, finder);
  await tester.pump();
  expect(tester.getRect(finder.first).bottom, lessThanOrEqualTo(size.height));
}

void main() {
  setUp(StreakState.shared.reset);

  for (final size in _sizes) {
    for (final scale in _scales) {
      testWidgets('Write: six questions deep fits $size at $scale',
          (tester) async {
        await _pump(tester, const WriteJournalScreen(), FakeAi(), size: size,
            scale: scale);
        await tester.enterText(find.byType(TextField), _long);
        await tester.pump();
        for (var i = 0; i < 6; i++) {
          await tester.tap(find.text(WriteJournalScreen.deeperLabel));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
          await tester.enterText(find.byType(TextField), '$_long $i');
          await tester.pump();
        }
        expect(tester.takeException(), isNull);
        expect(find.text(WriteJournalScreen.deepNudge), findsOneWidget);
        await _reach(tester, find.text(WriteJournalScreen.finishLabel), size);
      });

      testWidgets('Analysis and quote fit $size at $scale', (tester) async {
        final ai = FakeAi(analysis: {
          ...FakeAi.reflection,
          'title': 'né tránh chuyện học và áp lực điểm số',
          'analysis': _long,
          'topics': ['học tập', 'áp lực', 'né tránh'],
          'quote': {
            'text': 'Hành trình ngàn dặm bắt đầu từ một bước chân.',
            'author': 'Lão Tử',
          },
        });
        await _pump(
            tester,
            AiReflectionScreen(
              journalContent: _long,
              entryParts: const [
                (question: WriteJournalScreen.prompt, answer: _long),
                (question: 'Vì sao vậy?', answer: _long),
              ],
              remote: ai.service,
            ),
            ai,
            size: size,
            scale: scale);
        await tester.pump(const Duration(seconds: 1));
        expect(tester.takeException(), isNull);
        await _reach(tester, find.text('Tiếp tục'), size);

        await _scrollTo(tester, find.text('Nhật ký'));
        await tester.tap(find.text('Nhật ký'));
        await tester.pump(const Duration(milliseconds: 500));
        expect(tester.takeException(), isNull);

        await _scrollTo(tester, find.text('Tiếp tục'));
        await tester.tap(find.text('Tiếp tục'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));
        expect(find.text('– Lão Tử'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await _reach(tester, find.text('Tiếp tục'), size);
      });

      testWidgets('"Phản hồi AI" in Hồ sơ fits $size at $scale',
          (tester) async {
        await _pump(tester, const ProfileScreen(), FakeAi(),
            size: size, scale: scale);
        await tester.pumpAndSettle();
        final row = find.byKey(const ValueKey('setting-item-ai replies'));
        await _scrollTo(tester, row);
        await tester.pumpAndSettle();
        await tester.tap(row);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text(ProfileScreen.aiRepliesNote), findsOneWidget);
        await _reach(tester, find.text('Lưu'), size);
      });
    }
  }
}
