import 'package:ai_diary/core/widgets/app_ui.dart';
import 'package:ai_diary/features/home/presentation/home_screen.dart';
import 'package:ai_diary/features/home/presentation/widgets/home_scene_hero.dart';
import 'package:ai_diary/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final size in [
    const Size(412, 915),
    const Size(320, 640),
    const Size(640, 320)
  ]) {
    testWidgets('Home: large scene, prompt over the sky, at $size',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      tester.view.padding = const FakeViewPadding(top: 44, bottom: 34);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetPadding);
      await tester.pumpWidget(const AiDiaryApp());
      await tester.pumpAndSettle();

      final home = find.byType(HomeScreen);
      final hero = find.byKey(const ValueKey('home-reflection'));
      final heroRect = tester.getRect(hero);
      // Full width, at least 1.6 × as tall, its sky up under the status bar.
      expect(heroRect.width, tester.getSize(home).width);
      expect(heroRect.height, greaterThanOrEqualTo(heroRect.width * 1.6));
      expect(heroRect.top, 0);

      // Greeting, date, streak and profile at the top of the scene.
      final header =
          find.descendant(of: hero, matching: find.byType(AppPageHeader));
      expect(header, findsOneWidget);
      // ...while the header itself starts below the status bar.
      expect(tester.getTopLeft(header).dy, greaterThanOrEqualTo(44));
      expect(find.text(HomeScreen.greeting(null)), findsOneWidget);
      expect(find.text(HomeScreen.formatDate(DateTime.now())), findsOneWidget);
      expect(find.byTooltip(HomeScreen.profileTooltip), findsOneWidget);

      // The prompt and its actions stay above the street's rooftops.
      final panorama = HomeSceneHero.panoramaHeight(heroRect.width);
      final rooftops =
          heroRect.bottom - panorama * HomeSceneHero.buildingsShare;
      final start = find.widgetWithText(FilledButton, HomeScreen.startLabel);
      expect(start, findsOneWidget);
      expect(tester.getSize(start).height, greaterThanOrEqualTo(48));
      expect(tester.getRect(start).bottom, lessThanOrEqualTo(rooftops + .5));
      expect(tester.getTopLeft(find.text(HomeScreen.reflectionTitle)).dy,
          greaterThan(tester.getRect(header).bottom));

      // Nudaeng on the street, below the prompt, inside the scene.
      final rider = find.byKey(const ValueKey('home-scene-rider'));
      expect(tester.getRect(rider).top, greaterThan(rooftops));
      expect(heroRect.contains(tester.getCenter(rider)), isTrue);

      // "Tuần này" below the scene; the page scrolls, the bar stays put.
      final scroll = find.byKey(const PageStorageKey('home-scroll'));
      final navRect = tester.getRect(find.byType(NavigationBar));
      await tester.scrollUntilVisible(find.text('Ghi chú tuần này'), 200,
          scrollable:
              find.descendant(of: scroll, matching: find.byType(Scrollable)));
      await tester.pumpAndSettle();
      expect(find.text(HomeScreen.weekTitle), findsOneWidget);
      expect(find.byKey(const ValueKey('this-week-panel')), findsOneWidget);
      expect(tester.getRect(find.byType(NavigationBar)), navRect);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('The first section starts right under the sheet', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(412, 915);
    tester.view.padding = const FakeViewPadding(top: 44, bottom: 34);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const AiDiaryApp());
    await tester.pumpAndSettle();
    final hero = tester.getRect(find.byKey(const ValueKey('home-reflection')));
    final scrollable = find.descendant(
        of: find.byKey(const PageStorageKey('home-scroll')),
        matching: find.byType(Scrollable));
    await tester.scrollUntilVisible(find.text(HomeScreen.weekTitle), 200,
        scrollable: scrollable);
    await tester.pumpAndSettle();
    final scrolled = tester.state<ScrollableState>(scrollable).position.pixels;
    final title = tester
        .getRect(find.text(HomeScreen.weekTitle))
        .shift(Offset(0, scrolled));
    // The sheet's rounded top begins [lip] above the hero's bottom: its
    // title a small step below the curve, not after a band of empty sheet.
    expect(title.top - (hero.bottom - HomeSceneHero.lip),
        inInclusiveRange(HomeSceneHero.lip, HomeSceneHero.lip + 16));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Large text: the scene grows, the prompt still clears it',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 640);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(const AiDiaryApp());
    await tester.pumpAndSettle();
    final hero = tester.getRect(find.byKey(const ValueKey('home-reflection')));
    expect(hero.height, greaterThan(hero.width * 1.6));
    final rooftops = hero.bottom -
        HomeSceneHero.panoramaHeight(hero.width) * HomeSceneHero.buildingsShare;
    expect(
        tester
            .getRect(find.widgetWithText(FilledButton, HomeScreen.startLabel))
            .bottom,
        lessThanOrEqualTo(rooftops + .5));
    // The streak and profile move above the greeting instead of squeezing.
    expect(
        tester.getRect(find.byTooltip(HomeScreen.profileTooltip)).bottom,
        lessThanOrEqualTo(
            tester.getTopLeft(find.text(HomeScreen.greeting(null))).dy));
    expect(tester.takeException(), isNull);
  });
}
