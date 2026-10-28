import 'package:ai_diary/core/theme/app_theme.dart';
import 'package:ai_diary/features/journal/data/journal_repository.dart';
import 'package:ai_diary/features/journal/journal_scope.dart';
import 'package:ai_diary/features/study/data/study_mock_data.dart';
import 'package:ai_diary/features/study/data/study_progress.dart';
import 'package:ai_diary/features/study/presentation/study_screen.dart';
import 'package:ai_diary/features/study/presentation/nudaeng_artwork.dart';
import 'package:ai_diary/features/study/presentation/nudaeng_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> openStudy(WidgetTester tester,
    {double width = 390,
    double scale = 1,
    bool disableAnimations = true}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 844);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.light,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(scale),
          disableAnimations: disableAnimations),
      child: child!,
    ),
    home: const StudyScreen(),
  ));
  await tester.pumpAndSettle();
}

Future<void> tapText(WidgetTester tester, String text) async {
  if (find.text(text).evaluate().isEmpty) {
    await tester.scrollUntilVisible(find.text(text), 250,
        scrollable: find.byType(Scrollable).first);
  }
  await tester.ensureVisible(find.text(text).last);
  await tester.pumpAndSettle();
  await tester.tap(find.text(text).last);
  await tester.pumpAndSettle();
}

Future<void> joinChallenge(WidgetTester tester) async {
  await tapText(tester, 'Xem challenge');
  expect(find.text('Tham gia challenge'), findsOneWidget);
  await tapText(tester, 'Tham gia challenge');
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
}

Future<void> expectVisibleMascot(WidgetTester tester, NudaengArtwork artwork,
    {required double width, required bool animate}) async {
  final finder = find.byWidgetPredicate(
      (widget) => widget is NudaengView && widget.artwork == artwork);
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(finder, 250,
        scrollable: find.byType(Scrollable).first);
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  final imageFinder =
      find.descendant(of: finder, matching: find.byType(RawImage));
  for (var i = 0; i < 100; i++) {
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
    await tester.pump();
    if (tester.widget<RawImage>(imageFinder).image != null) break;
  }
  expect(tester.widget<RawImage>(imageFinder).image, isNotNull);
  final mascot = tester.widget<NudaengView>(finder);
  expect(mascot.width, width);
  expect(mascot.animate, animate);
  final rect = tester.getRect(finder);
  expect(rect.top, greaterThanOrEqualTo(0));
  expect(rect.bottom, lessThanOrEqualTo(844));
}

void main() {
  testWidgets(
      'S01 cards carry no mascot; S02 page-turns on every open, then fidgets',
      (tester) async {
    await openStudy(tester, disableAnimations: false);
    // The banner is the only Nudaeng on S01; content cards stay minimal.
    final s01Mascots = find.byType(NudaengView);
    expect(s01Mascots, findsOneWidget);
    expect(
        tester.widget<NudaengView>(s01Mascots).artwork, NudaengArtwork.study);
    final title = find.text('Viết điều biết ơn mỗi ngày');
    await tester.ensureVisible(title);
    await tester.pumpAndSettle();
    await tester.tap(title);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    final mascot = find.byWidgetPredicate(
        (w) => w is NudaengView && w.artwork == NudaengArtwork.courseDetail);
    final raw = find.descendant(of: mascot, matching: find.byType(RawImage));
    // Decode assets without advancing the fake animation clock. Page-turn
    // frames are 264:323; the hugging pose (344:355) never appears here.
    for (var attempt = 0; attempt < 100; attempt++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump();
      final frame = tester.widget<RawImage>(raw).image;
      if (frame != null) expect(frame.height / frame.width, greaterThan(1.15));
      if (tester.binding.transientCallbackCount > 0) break;
    }
    expect(tester.binding.transientCallbackCount, greaterThan(0));
    final first = tester.widget<RawImage>(raw).image!;
    await tester.pump(const Duration(milliseconds: 450));
    final next = tester.widget<RawImage>(raw).image!;
    expect(identical(first, next), isFalse);
    // At 2 s the page-turn returns to its own first frame; no dissolve.
    await tester.pump(const Duration(milliseconds: 1650));
    expect(tester.widgetList<RawImage>(raw), hasLength(1));
    final idle = tester.widget<RawImage>(raw).image!;
    expect(idle.width, first.width);
    expect(idle.height, first.height);
    // Rive-style idle: rest for at least 3 s, then a hand-drawn fidget.
    await tester.pump(const Duration(milliseconds: 2700));
    expect(tester.widget<RawImage>(raw).image, same(idle));
    expect(tester.binding.transientCallbackCount, 0);
    var fidgeted = false;
    for (var i = 0; i < 40 && !fidgeted; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      fidgeted = !identical(tester.widget<RawImage>(raw).image, idle);
    }
    expect(fidgeted, isTrue);
    await tester.pump(const Duration(milliseconds: 2100));
    expect(tester.widget<RawImage>(raw).image, same(idle));
    // Reopening the detail plays the page-turn again.
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(title);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    for (var attempt = 0; attempt < 100; attempt++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump();
      if (tester.binding.transientCallbackCount > 0) break;
    }
    final again = tester.widget<RawImage>(raw).image!;
    await tester.pump(const Duration(milliseconds: 450));
    expect(identical(tester.widget<RawImage>(raw).image, again), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'Xem challenge plays the head-tilt hand-off once, then opens S04 unjoined',
      (tester) async {
    await openStudy(tester, disableAnimations: false);
    await tester.tap(find.text('Xem challenge'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    final loading = find.byWidgetPredicate((w) =>
        w is NudaengView && w.artwork == NudaengArtwork.challengeLoading);
    expect(loading, findsOneWidget);
    expect(find.text('Tham gia challenge'), findsNothing);
    final raw = find.descendant(of: loading, matching: find.byType(RawImage));
    for (var i = 0; i < 100; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump();
      if (tester.widget<RawImage>(raw).image != null &&
          tester.binding.transientCallbackCount > 0) {
        break;
      }
    }
    final first = tester.widget<RawImage>(raw).image!;
    await tester.pump(const Duration(milliseconds: 500));
    expect(identical(tester.widget<RawImage>(raw).image, first), isFalse);
    // The 1.6 s GIF finishes, then S04 replaces the hand-off.
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pumpAndSettle();
    expect(loading, findsNothing);
    expect(find.text('Tham gia challenge'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Challenge gợi ý'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'Task preview is read-only, current opens editor, done entry remains accessible while paused',
      (tester) async {
    await openStudy(tester);
    await joinChallenge(tester);
    await tapText(tester, 'Nhiệm vụ 3');
    expect(find.text('Xem trước nhiệm vụ'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, 1000));
    await tester.pumpAndSettle();
    await tapText(tester, 'Nhiệm vụ 1');
    expect(find.byType(TextField), findsOneWidget);
    await tester.enterText(
        find.byType(TextField), 'Nội dung cần giữ nguyên sau khi lưu.');
    await tapText(tester, 'Hoàn tất');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    await tapText(tester, 'Về challenge');
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tapText(tester, 'Tạm dừng');
    await tapText(tester, 'Nhiệm vụ 1');
    expect(find.text('Nhật ký đã viết'), findsOneWidget);
    expect(find.text('Nội dung cần giữ nguyên sau khi lưu.'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, 1200));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(FilledButton, 'Tiếp tục challenge'),
        findsOneWidget);
    expect(find.text('1/7 nhiệm vụ đã hoàn thành'), findsOneWidget);
    await tapText(tester, 'Tiếp tục challenge');
    await tapText(tester, 'Viết nhiệm vụ này');
    await tester.enterText(find.byType(TextField), 'Bản nháp cần giữ khi rời.');
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tapText(tester, 'Rời challenge');
    expect(find.textContaining('những gì bạn đã viết vẫn được giữ'),
        findsOneWidget);
    await tapText(tester, 'Rời challenge');
    expect(find.text('Đã rời challenge'), findsOneWidget);
    await tapText(tester, 'Xem challenge');
    await tapText(tester, 'Tiếp tục challenge');
    await tapText(tester, 'Tiếp tục bản nháp');
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Bản nháp cần giữ khi rời.');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'Out-of-order reading completes only after all lessons; rereading retains progress',
      (tester) async {
    await openStudy(tester);
    await tapText(tester, 'Viết điều biết ơn mỗi ngày');
    const last = 'Giữ lại điều bạn muốn mang sang ngày mai';
    await tester.scrollUntilVisible(find.text(last), 250);
    await tapText(tester, last);
    await tester.scrollUntilVisible(find.text('Đánh dấu đã đọc'), 250);
    await tapText(tester, 'Đánh dấu đã đọc');
    expect(find.text('Bạn đã học xong khóa này'), findsNothing);
    expect(find.text('Đã đọc'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tapText(tester, 'Tiếp tục học');
    expect(find.text('Nhìn thấy điều nhỏ đang nâng đỡ bạn'), findsWidgets);
    await tester.scrollUntilVisible(find.text('Đánh dấu đã đọc'), 250);
    await tapText(tester, 'Đánh dấu đã đọc');
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tapText(tester, 'Tiếp tục học');
    expect(find.text('Viết một lời cảm ơn thật cụ thể'), findsWidgets);
    await tester.scrollUntilVisible(find.text('Đánh dấu đã đọc'), 250);
    await tapText(tester, 'Đánh dấu đã đọc');
    expect(find.text('Bạn đã học xong khóa này'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Về khóa học'), 250);
    await tapText(tester, 'Về khóa học');
    expect(find.text('Viết thực hành'), findsOneWidget);
    await tester.scrollUntilVisible(find.text(last), 250);
    await tapText(tester, last);
    await tester.scrollUntilVisible(find.text('Đã đọc'), 250);
    expect(find.text('Đánh dấu đã đọc'), findsNothing);
    expect(find.text('Bạn đã học xong khóa này'), findsNothing);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, 1200));
    await tester.pumpAndSettle();
    expect(find.text('3/3 bài đã đọc'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'Task animation requires a new save; final task goes to S06, revisit is static',
      (tester) async {
    await openStudy(tester);
    await joinChallenge(tester);
    NudaengView progressMascot() =>
        tester.widget<NudaengView>(find.byWidgetPredicate((w) =>
            w is NudaengView && w.artwork == NudaengArtwork.challengeProgress));
    expect(progressMascot().animate, isFalse);
    for (var task = 0; task < 7; task++) {
      await tapText(tester, 'Viết nhiệm vụ này');
      await tester.enterText(
          find.byType(TextField), 'Nội dung nhiệm vụ ${task + 1}');
      await tapText(tester, 'Hoàn tất');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(find.text('Phản hồi cho bạn'), findsOneWidget);
      await tapText(tester, 'Về challenge');
      if (task == 6) {
        expect(find.text('Bạn đã hoàn thành challenge'), findsOneWidget);
        final mascot = tester.widget<NudaengView>(find.byType(NudaengView));
        expect(mascot.artwork, NudaengArtwork.challengeCompletion);
        expect(mascot.animate, isTrue);
      } else {
        await tester.drag(find.byType(ListView).first, const Offset(0, 1000));
        await tester.pumpAndSettle();
        expect(progressMascot().animate, isTrue);
        await tester.pageBack();
        await tester.pumpAndSettle();
        await tapText(tester, 'Tiếp tục challenge');
        expect(progressMascot().animate, isFalse);
      }
    }
    await tapText(tester, 'Xem nhật ký đã viết');
    expect(find.text('Nhật ký của challenge'), findsOneWidget);
    await tapText(tester, 'Nhiệm vụ 7');
    expect(find.text('Nội dung nhiệm vụ 7'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tapText(tester, 'Xem kết quả');
    expect(
        tester.widget<NudaengView>(find.byType(NudaengView)).animate, isFalse);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    final banner = find.byKey(const ValueKey('challenge-banner'));
    expect(banner, findsOneWidget);
    expect(ModalRoute.of(tester.element(banner))!.isCurrent, isTrue);
    expect(ModalRoute.of(tester.element(banner))!.isFirst, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'Course and reader show their specified mascots; reopening animates again',
      (tester) async {
    await openStudy(tester);
    await tapText(tester, 'Viết điều biết ơn mỗi ngày');
    await expectVisibleMascot(tester, NudaengArtwork.courseDetail,
        width: 108, animate: true);
    final courseState = tester.state(find.byType(NudaengView));
    await tester.drag(find.byType(ListView), const Offset(0, -1000));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, 1000));
    await tester.pumpAndSettle();
    expect(tester.state(find.byType(NudaengView)), same(courseState));
    await tapText(tester, 'Bắt đầu học');
    await expectVisibleMascot(tester, NudaengArtwork.lesson,
        width: 64, animate: false);
    expect(find.text('Thử viết từ bài học này'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(tester.state(find.byType(NudaengView)), same(courseState));
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tapText(tester, 'Viết điều biết ơn mỗi ngày');
    await expectVisibleMascot(tester, NudaengArtwork.courseDetail,
        width: 108, animate: true);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Framework has the book mascot and no lesson list',
      (tester) async {
    await openStudy(tester);
    await tester.scrollUntilVisible(find.text('Gỡ rối suy nghĩ'), 250,
        scrollable: find.byType(Scrollable).first);
    await tapText(tester, 'Gỡ rối suy nghĩ');
    await expectVisibleMascot(tester, NudaengArtwork.courseDetail,
        width: 108, animate: true);
    expect(find.text('CÁC BƯỚC MẪU'), findsOneWidget);
    expect(find.text('BÀI HỌC'), findsNothing);
    expect(find.text('Viết theo phương pháp này'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Standalone article shows the static reader mascot',
      (tester) async {
    await openStudy(tester);
    const title = 'Nhìn lại những điều nhỏ đã làm được';
    await tester.scrollUntilVisible(find.text(title), 250,
        scrollable: find.byType(Scrollable).first);
    await tapText(tester, title);
    await expectVisibleMascot(tester, NudaengArtwork.lesson,
        width: 64, animate: false);
    expect(tester.takeException(), isNull);
  });

  for (final width in [360.0, 390.0, 430.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('Study fits $width px with text scale $scale',
          (tester) async {
        await openStudy(tester, width: width, scale: scale);
        expect(find.text('7 nhiệm vụ'), findsOneWidget);
        expect(find.byKey(const ValueKey('challenge-banner')), findsOneWidget);
        final title = tester.widget<Text>(find.text('Học tập'));
        expect(title.style!.fontFamily, 'Nunito');
        final button = find.widgetWithText(FilledButton, 'Xem challenge');
        expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
        await tester.drag(find.byType(ListView).first, const Offset(0, -650));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('Large text supports filter chips and challenge child routes',
      (tester) async {
    await openStudy(tester, width: 360, scale: 2);
    await tester.scrollUntilVisible(find.text('Khóa học'), 300,
        scrollable: find.byType(Scrollable).first);
    await tapText(tester, 'Khóa học');
    expect(find.text('Viết điều biết ơn mỗi ngày'), findsOneWidget);
    expect(find.text('Gỡ rối suy nghĩ'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.drag(find.byType(ListView).first, const Offset(0, 1200));
    await tester.pumpAndSettle();
    await joinChallenge(tester);
    expect(find.text('Challenge của bạn'), findsOneWidget);
    await tester.drag(find.byType(ListView).first, const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Viewing suggestion does not enroll; paused banner stays paused',
      (tester) async {
    await openStudy(tester);
    await tapText(tester, 'Xem challenge');
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Challenge gợi ý'), findsOneWidget);
    await joinChallenge(tester);
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tapText(tester, 'Tạm dừng');
    expect(find.textContaining('Challenge đang tạm dừng.'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Đã tạm dừng'), findsOneWidget);
    expect(
        find.widgetWithText(OutlinedButton, 'Xem challenge'), findsOneWidget);
    await tapText(tester, 'Xem challenge');
    expect(find.textContaining('Challenge đang tạm dừng.'), findsOneWidget);
    final write = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Viết nhiệm vụ này'));
    expect(write.onPressed, isNull);
    await tapText(tester, 'Tiếp tục challenge');
    expect(find.textContaining('Challenge đang tạm dừng.'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Draft resumes from S05; saving updates progress and next task',
      (tester) async {
    await openStudy(tester);
    await joinChallenge(tester);
    await tapText(tester, 'Viết nhiệm vụ này');
    await tester.enterText(
        find.byType(TextField), 'Biết ơn một buổi sáng yên bình.');
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Tiếp tục bản nháp'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tapText(tester, 'Tiếp tục challenge');
    expect(find.text('Tiếp tục bản nháp'), findsOneWidget);
    await tapText(tester, 'Tiếp tục bản nháp');
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Biết ơn một buổi sáng yên bình.');
    await tapText(tester, 'Hoàn tất');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    await tapText(tester, 'Về challenge');
    await tester.drag(find.byType(ListView).first, const Offset(0, 700));
    await tester.pumpAndSettle();
    expect(find.text('1/7 nhiệm vụ đã hoàn thành'), findsOneWidget);
    expect(find.text('Nhiệm vụ 2/7'), findsOneWidget);
    expect(find.text('Tiếp tục bản nháp'), findsNothing);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('1/7 nhiệm vụ đã hoàn thành'), findsOneWidget);
    expect(
        tester
            .widget<LinearProgressIndicator>(
                find.byType(LinearProgressIndicator).first)
            .value,
        closeTo(1 / 7, .001));
    expect(tester.takeException(), isNull);
  });
  testWidgets('A task is written into the journal; progress outlives the app',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    final journals = InMemoryJournalRepository();
    final kept = InMemoryStudyProgressStore();
    Future<void> launch() async {
      await tester.pumpWidget(JournalScope(
        repository: journals,
        child: MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: StudyScreen(progress: kept),
        ),
      ));
      await tester.pumpAndSettle();
    }

    await launch();
    await joinChallenge(tester);
    await tapText(tester, 'Viết nhiệm vụ này');
    await tester.enterText(find.byType(TextField), 'Một tách trà ấm.');
    await tapText(tester, 'Hoàn tất');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    // In the journal, named by its task.
    final entry = (await journals.entries()).single;
    expect(entry.body, 'Một tách trà ấm.');
    expect(entry.content.source?.label, 'Challenge · Nhiệm vụ 1');
    expect(kept.kept?.joined, isTrue);
    expect(kept.kept?.doneTasks, {0});
    expect(kept.kept?.taskEntries, {0: entry.id});

    // Closed and opened again: the challenge is where it was.
    await tester.pumpWidget(const SizedBox());
    await launch();
    expect(find.text('Tiếp tục challenge'), findsOneWidget);
    await tapText(tester, 'Tiếp tục challenge');
    expect(find.text('1/7 nhiệm vụ đã hoàn thành'), findsOneWidget);
    // The done task opens what was written.
    await tapText(tester, 'Nhiệm vụ 1');
    expect(find.text('Một tách trà ấm.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Going deeper asks the task questions, one at a time',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    final journals = InMemoryJournalRepository();
    await tester.pumpWidget(JournalScope(
      repository: journals,
      child: MaterialApp(
        theme: AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: StudyScreen(progress: InMemoryStudyProgressStore()),
      ),
    ));
    await tester.pumpAndSettle();
    await joinChallenge(tester);
    await tapText(tester, 'Viết nhiệm vụ này');
    Finder deeper() => find.widgetWithText(OutlinedButton, 'Suy ngẫm sâu hơn');
    bool deeperOn() =>
        tester.widget<OutlinedButton>(deeper()).onPressed != null;

    await tester.enterText(find.byType(TextField), 'Một tách trà ấm.');
    await tester.pump();
    await tester.tap(deeper());
    await tester.pumpAndSettle();
    // The answer stays above; the task's first question, a fresh field.
    expect(find.text('Một tách trà ấm.'), findsOneWidget);
    expect(
        find.text(studyFollowUps(const StudyWritingContext(
            kind: 'challenge',
            sourceId: 'task-1',
            challenge: challengeId,
            taskIndex: 0))[0]),
        findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty);
    expect(deeperOn(), isFalse, reason: 'nothing written yet');

    await tester.enterText(find.byType(TextField), 'Lúc mưa đầu mùa.');
    await tester.pump();
    await tester.tap(deeper());
    await tester.pumpAndSettle();
    expect(find.text('Bản nháp · Suy ngẫm 2/2'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Mình cần chậm lại.');
    await tester.pump();
    expect(deeperOn(), isFalse, reason: 'no question left');
    expect(find.text('Bạn đã đi hết các câu hỏi gợi ý.'), findsOneWidget);

    await tapText(tester, 'Hoàn tất');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    // One entry, the answers in order.
    expect((await journals.entries()).single.body,
        'Một tách trà ấm.\n\nLúc mưa đầu mùa.\n\nMình cần chậm lại.');
    expect(tester.takeException(), isNull);
  });

  testWidgets('J03 suggests tomorrow for the next task and can continue now',
      (tester) async {
    await openStudy(tester);
    await joinChallenge(tester);
    await tapText(tester, 'Viết nhiệm vụ này');
    await tester.enterText(find.byType(TextField), 'Một tách trà ấm.');
    await tapText(tester, 'Hoàn tất');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    final notice = find.byKey(const ValueKey('next-task-notice'));
    expect(notice, findsOneWidget);
    expect(find.descendant(of: notice, matching: find.text('Hẹn bạn ngày mai')),
        findsOneWidget);
    expect(find.descendant(of: notice, matching: find.text('Nhiệm vụ 2/7')),
        findsOneWidget);
    expect(find.text('Về challenge'), findsOneWidget);
    await tapText(tester, 'Viết tiếp nhiệm vụ 2');
    // S05 opens the next task's editor directly; nothing is double-saved.
    expect(find.text('Nhiệm vụ 2/7'), findsWidgets);
    expect(find.byType(TextField), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).first, const Offset(0, 700));
    await tester.pumpAndSettle();
    expect(find.text('1/7 nhiệm vụ đã hoàn thành'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('S01 headings explain themselves only on demand; cards stay slim',
      (tester) async {
    await openStudy(tester);
    expect(find.text('Học cách viết và thử một challenge.'), findsNothing);
    await tester.tap(find.byTooltip('Giới thiệu Học tập'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Học cách viết qua khóa học'), findsOneWidget);
    await tapText(tester, 'Đã hiểu');
    await tester.scrollUntilVisible(
        find.byTooltip('Giới thiệu Khám phá cách viết'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.byTooltip('Giới thiệu Khám phá cách viết'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Mẫu viết dẫn bạn'), findsOneWidget);
    await tapText(tester, 'Đã hiểu');
    // Cards say what they are and how long, in the chips' words.
    expect(find.text('Khóa học · 3 bài · 12 phút'), findsOneWidget);
    expect(find.text('Mẫu viết · 8 phút'), findsOneWidget);
    expect(find.text('Bài đọc · 5 phút'), findsOneWidget);
    // The chips open on "Tất cả", not scrolled with the page.
    expect(tester.getTopLeft(find.text('Tất cả')).dx, greaterThanOrEqualTo(0));
    await tapText(tester, 'Mẫu viết');
    expect(find.text('Gỡ rối suy nghĩ'), findsOneWidget);
    expect(find.text('Viết điều biết ơn mỗi ngày'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
