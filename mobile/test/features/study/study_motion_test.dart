import 'package:ai_diary/core/theme/app_theme.dart';
import 'package:ai_diary/features/study/presentation/study_motion.dart';
import 'package:ai_diary/features/study/presentation/study_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'study_screen_test.dart' show openStudy, joinChallenge, tapText;

Future<void> pumpStudy(WidgetTester tester,
    {bool reduced = false, bool tickers = true}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.light,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
      child: child!,
    ),
    home: TickerMode(enabled: tickers, child: const StudyScreen()),
  ));
}

double entranceOpacity(WidgetTester tester) => tester
    .widget<Opacity>(find
        .descendant(
            of: find.byType(StudyEntrance), matching: find.byType(Opacity))
        .first)
    .opacity;

void main() {
  testWidgets(
      'S01 enters once in 280 ms, usable at once, and waits for its tab',
      (tester) async {
    await pumpStudy(tester, tickers: false);
    await tester.pump(const Duration(seconds: 1));
    // A hidden tab has not spent its entrance yet.
    expect(entranceOpacity(tester), 0);
    await pumpStudy(tester);
    await tester.pump(const Duration(milliseconds: 16));
    expect(entranceOpacity(tester), inExclusiveRange(0, 1));
    // Controls work mid-entrance; nothing waits for the animation.
    await tester.tap(find.byTooltip('Giới thiệu Học tập'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(entranceOpacity(tester), 1);
    await tester.pumpAndSettle();
    expect(find.text('Đã hiểu'), findsOneWidget);
  });

  testWidgets('Reduced motion skips the entrance and press scale',
      (tester) async {
    await pumpStudy(tester, reduced: true);
    await tester.pump();
    expect(entranceOpacity(tester), 1);
    final card = find.text('Gỡ rối suy nghĩ');
    await tester.ensureVisible(card);
    final gesture = await tester.startGesture(tester.getCenter(card));
    await tester.pump(const Duration(milliseconds: 80));
    final scale = tester
        .widget<Transform>(
            find.ancestor(of: card, matching: find.byType(Transform)).first)
        .transform
        .entry(0, 0);
    expect(scale, 1);
    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('Cards press to 0.98 in 80 ms and recover in 120 ms',
      (tester) async {
    await openStudy(tester, disableAnimations: false);
    final card = find.text('Gỡ rối suy nghĩ');
    await tester.ensureVisible(card);
    await tester.pumpAndSettle();
    final transform = find.descendant(
        of: find
            .ancestor(of: card, matching: find.byType(StudyPressable))
            .first,
        matching: find.byType(Transform));
    double scale() =>
        tester.widget<Transform>(transform.first).transform.entry(0, 0);
    final gesture = await tester.startGesture(tester.getCenter(card));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    expect(scale(), closeTo(.98, .001));
    await gesture.cancel();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    expect(scale(), 1);
  });

  testWidgets('Detail routes take 280 ms, or a 120 ms fade when reduced',
      (tester) async {
    await openStudy(tester, disableAnimations: false);
    await tapText(tester, 'Gỡ rối suy nghĩ');
    final route = ModalRoute.of(tester.element(find.text('CÁC BƯỚC MẪU')))!;
    expect(route, isA<StudyRoute<void>>());
    expect(route.transitionDuration, const Duration(milliseconds: 280));
    expect(route.reverseTransitionDuration, route.transitionDuration);

    await openStudy(tester);
    await tapText(tester, 'Gỡ rối suy nghĩ');
    final reducedRoute =
        ModalRoute.of(tester.element(find.text('CÁC BƯỚC MẪU')))!;
    expect(reducedRoute.transitionDuration, StudyMotion.reducedFade);
  });

  testWidgets('Editor explains why its actions are disabled', (tester) async {
    await openStudy(tester);
    await joinChallenge(tester);
    await tapText(tester, 'Viết nhiệm vụ này');
    const reason = 'Viết vài dòng để dùng các nút bên dưới.';
    expect(find.text(reason), findsOneWidget);
    expect(
        tester
            .widget<OutlinedButton>(
                find.widgetWithText(OutlinedButton, 'Suy ngẫm sâu hơn'))
            .onPressed,
        isNull);
    final before = tester.getTopLeft(find.text('Hoàn tất'));
    await tester.enterText(find.byType(TextField), 'Một buổi chiều yên.');
    await tester.pump();
    expect(find.text(reason), findsNothing);
    // The reserved line keeps the actions from jumping.
    expect(tester.getTopLeft(find.text('Hoàn tất')), before);
  });
}
