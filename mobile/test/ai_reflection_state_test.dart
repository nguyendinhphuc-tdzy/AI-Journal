import 'package:ai_diary/core/theme/app_theme.dart';
import 'package:ai_diary/features/journal/ai_reflection_screen.dart';
import 'package:ai_diary/navigation/custom_bottom_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Loading lasts three seconds and never covers navigation',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: const AIReflectionScreen(journalContent: 'A quiet day.'),
    ));
    final overlay = find.byKey(const ValueKey('reflection-loading-overlay'));
    final nav = find.byType(CustomBottomNavigation);
    expect(overlay, findsOneWidget);
    expect(tester.getRect(overlay).bottom, tester.getRect(nav).top);
    expect(find.text('Continue'), findsNothing);
    await tester.pump(const Duration(milliseconds: 2999));
    expect(overlay, findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1));
    expect(overlay, findsNothing);
    expect(find.text("✨ Nudaeng's thought..."), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
    expect(nav, findsOneWidget);
    final assets = tester
        .widgetList<Image>(find.byType(Image))
        .map((widget) => (widget.image as AssetImage).assetName);
    expect(assets, contains('assets/images/like.gif'));
    expect(assets, isNot(contains('assets/images/loading.gif')));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Navigation remains usable while loading; delay is safe on exit',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: const AIReflectionScreen(journalContent: ''),
    ));
    await tester.tap(find.text('Study'));
    await tester.pumpAndSettle();
    expect(find.byType(AIReflectionScreen), findsNothing);
    expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        1);
    await tester.pump(const Duration(seconds: 3));
    expect(tester.takeException(), isNull);
  });
}
