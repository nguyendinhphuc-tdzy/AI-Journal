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
    expect(find.text('Hủy phân tích'), findsOneWidget);
    expect(find.text('Tiếp tục'), findsNothing);
    await tester.pump(const Duration(milliseconds: 2999));
    expect(find.text('Theodore Roosevelt'), findsNothing);
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.text('Theodore Roosevelt'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    expect(find.text('Hủy phân tích'), findsNothing);
    await tester.tap(find.text('Lưu'));
    await tester.pump();
    expect(find.text('Đã lưu'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 3499));
    expect(find.text('Góc suy ngẫm'), findsNothing);
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.text('Góc suy ngẫm'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('Theodore Roosevelt'), findsNothing);
    expect(find.text('Chúng mình nhận thấy rằng'), findsOneWidget);
    await tester.tap(find.descendant(
      of: find.byKey(const ValueKey('reflection-insight')),
      matching: find.widgetWithText(TextButton, 'Nhật ký'),
    ));
    await tester.pumpAndSettle();
    expect(find.text('My original entry.'), findsOneWidget);
    expect(find.text('Chúng mình nhận thấy rằng'), findsNothing);
    await tester.tap(find.text('Phân tích'));
    await tester.pumpAndSettle();
    expect(find.text('Chúng mình nhận thấy rằng'), findsOneWidget);
    await tester.tap(find.byWidgetPredicate(
        (widget) => widget is IconButton && widget.tooltip == 'Hữu ích'));
    await tester.pump();
    expect(
        tester
            .widget<IconButton>(find.byWidgetPredicate((widget) =>
                widget is IconButton && widget.tooltip == 'Hữu ích'))
            .isSelected,
        isTrue);
    await tester.tap(find.byWidgetPredicate(
        (widget) => widget is IconButton && widget.tooltip == 'Chưa hữu ích'));
    await tester.pump();
    expect(
        tester
            .widget<IconButton>(find.byWidgetPredicate((widget) =>
                widget is IconButton && widget.tooltip == 'Hữu ích'))
            .isSelected,
        isFalse);
    expect(
        tester
            .widget<IconButton>(find.byWidgetPredicate((widget) =>
                widget is IconButton && widget.tooltip == 'Chưa hữu ích'))
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
      await tester.tap(find.text('Tiếp tục'));
      await tester.pumpAndSettle();
      expect(find.text('Góc suy ngẫm'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.descendant(
        of: find.byKey(const ValueKey('reflection-insight')),
        matching: find.widgetWithText(TextButton, 'Nhật ký'),
      ));
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
    await tester.tap(find.text('Hủy phân tích'));
    await tester.pumpAndSettle();
    expect(find.byType(AIReflectionScreen), findsNothing);
    expect(find.text('Open reflection'), findsOneWidget);
    await tester.pump(const Duration(seconds: 7));
    expect(tester.takeException(), isNull);
  });
}
