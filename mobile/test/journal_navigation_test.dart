import 'package:shared_preferences/shared_preferences.dart';
import 'package:ai_diary/features/journal/presentation/write_journal_screen.dart';
import 'package:ai_diary/features/profile/data/writing_preferences.dart';
import 'package:ai_diary/main.dart';
import 'package:ai_diary/navigation/custom_bottom_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _openJournal(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(412, 915);
  tester.view.padding = const FakeViewPadding(top: 44, bottom: 34);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetPadding);
  await tester.pumpWidget(const AiDiaryApp());
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('Cùng suy ngẫm'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Cùng suy ngẫm'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('The journal is a full page: no tab bar, Close returns Home',
      (tester) async {
    await _openJournal(tester);
    expect(find.byType(CustomBottomNavigation), findsNothing);
    final page = tester.getRect(find.byType(WriteJournalScreen));
    for (final child in [
      find.text('Nhật ký hôm nay'),
      find.byType(TextField),
      find.text('Hoàn tất'),
      find.text('Suy ngẫm sâu hơn'),
    ]) {
      final rect = tester.getRect(child);
      expect(page.contains(rect.topLeft), isTrue);
      expect(page.contains(rect.bottomRight), isTrue);
    }
    // The actions sit above the home indicator.
    expect(tester.getRect(find.text('Hoàn tất')).bottom,
        lessThanOrEqualTo(915 - 34));
    expect(find.byIcon(Icons.attach_file), findsNothing);
    expect(find.byIcon(Icons.image_outlined), findsOneWidget);
    expect(find.byIcon(Icons.mic_none_outlined), findsOneWidget);
    // Nothing to go deeper on yet.
    FilledButton deeper() => tester.widget<FilledButton>(find.ancestor(
        of: find.text('Suy ngẫm sâu hơn'),
        matching: find.byType(FilledButton)));
    expect(deeper().onPressed, isNull);
    await tester.enterText(find.byType(TextField), 'Một ngày yên.');
    await tester.pump();
    expect(deeper().onPressed, isNotNull);

    await tester.tap(find.byTooltip('Đóng'));
    await tester.pumpAndSettle();
    expect(find.byType(WriteJournalScreen), findsNothing);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Paper: four sheets to pick from, the choice kept',
      (tester) async {
    await _openJournal(tester);
    // Giấy dó by default.
    expect(find.byKey(const ValueKey('journal-paper-doPaper')), findsOneWidget);
    expect(find.byKey(const ValueKey('journal-ruled-lines')), findsNothing);
    await tester.tap(find.byTooltip('Đổi nền nhật ký'));
    await tester.pumpAndSettle();
    expect(find.text('Nền giấy'), findsOneWidget);
    for (final paper in JournalPaper.values) {
      expect(find.byKey(ValueKey('journal-paper-option-${paper.name}')),
          findsOneWidget);
    }
    await tester.tap(find.text('Giấy kẻ'));
    await tester.pumpAndSettle();
    expect(find.text('Nền giấy'), findsNothing);
    expect((await WritingPreferences.open()).paper, JournalPaper.ruled);
    expect(find.byKey(const ValueKey('journal-paper-ruled')), findsOneWidget);
    // Rows drawn under the writing.
    expect(find.byKey(const ValueKey('journal-ruled-lines')), findsOneWidget);

    await tester.tap(find.byTooltip('Đổi nền nhật ký'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Giấy trơn'));
    await tester.pumpAndSettle();
    expect((await WritingPreferences.open()).paper, JournalPaper.plain);
    expect(find.byKey(const ValueKey('journal-paper-plain')), findsOneWidget);
    expect(find.byKey(const ValueKey('journal-ruled-lines')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test('Paper set before the choice existed carries over', () async {
    SharedPreferences.setMockInitialValues({'writing.paper': false});
    expect((await WritingPreferences.open()).paper, JournalPaper.plain);
    SharedPreferences.setMockInitialValues({'writing.paper': true});
    expect((await WritingPreferences.open()).paper, JournalPaper.doPaper);
    SharedPreferences.setMockInitialValues({});
    expect((await WritingPreferences.open()).paper, JournalPaper.doPaper);
  });
}
