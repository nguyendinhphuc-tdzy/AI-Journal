import 'package:ai_diary/core/theme/app_theme.dart';
import 'package:ai_diary/features/journal/ai_reflection_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget app() => MaterialApp(
      theme: AppTheme.light,
      home: const AIReflectionScreen(journalContent: 'My original entry.'),
    );

void main() {
  testWidgets('Loading changes at 3 seconds and insight at 7 seconds',
      (tester) async {
    await tester.pumpWidget(app());
    expect(find.text('Cancel analysis'), findsOneWidget);
    expect(find.text('Continue'), findsNothing);
    await tester.pump(const Duration(milliseconds: 2999));
    expect(find.text('Theodore Roosevelt'), findsNothing);
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.text('Theodore Roosevelt'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    expect(find.text('Cancel analysis'), findsNothing);
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(find.text('Saved'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 3499));
    expect(find.text('Your Reflection'), findsNothing);
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.text('Your Reflection'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('Theodore Roosevelt'), findsNothing);
    expect(find.text('What we noticed'), findsOneWidget);
    await tester.tap(find.text('Entry'));
    await tester.pumpAndSettle();
    expect(find.text('My original entry.'), findsOneWidget);
    expect(find.text('What we noticed'), findsNothing);
    await tester.tap(find.text('Analysis'));
    await tester.pumpAndSettle();
    expect(find.text('What we noticed'), findsOneWidget);
    await tester.tap(find.byWidgetPredicate(
        (widget) => widget is IconButton && widget.tooltip == 'Helpful'));
    await tester.pump();
    expect(
        tester
            .widget<IconButton>(find.byWidgetPredicate((widget) =>
                widget is IconButton && widget.tooltip == 'Helpful'))
            .isSelected,
        isTrue);
    await tester.tap(find.byWidgetPredicate(
        (widget) => widget is IconButton && widget.tooltip == 'Not helpful'));
    await tester.pump();
    expect(
        tester
            .widget<IconButton>(find.byWidgetPredicate((widget) =>
                widget is IconButton && widget.tooltip == 'Helpful'))
            .isSelected,
        isFalse);
    expect(
        tester
            .widget<IconButton>(find.byWidgetPredicate((widget) =>
                widget is IconButton && widget.tooltip == 'Not helpful'))
            .isSelected,
        isTrue);
    expect(tester.takeException(), isNull);
  });

  for (final size in [const Size(320, 640), const Size(640, 320)]) {
    testWidgets('Continue skips quote and all stages fit $size',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(app());
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Your Reflection'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Entry'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 4));
      expect(find.text('My original entry.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Cancel returns to writer and delayed callbacks are safe',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
          builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            const AIReflectionScreen(journalContent: 'Draft'),
                      )),
                  child: const Text('Open reflection'),
                ),
              )),
    ));
    await tester.tap(find.text('Open reflection'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel analysis'));
    await tester.pumpAndSettle();
    expect(find.byType(AIReflectionScreen), findsNothing);
    expect(find.text('Open reflection'), findsOneWidget);
    await tester.pump(const Duration(seconds: 7));
    expect(tester.takeException(), isNull);
  });
}
