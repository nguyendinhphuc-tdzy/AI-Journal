import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:ai_diary/features/home/data/home_scene_settings.dart';
import 'package:ai_diary/features/home/presentation/widgets/home_scene_hero.dart';
import 'package:ai_diary/features/profile/profile_screen.dart';
import 'package:ai_diary/features/profile/widgets/setting_editor.dart';
import 'package:ai_diary/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef _Hero = HomeSceneHero;

/// Seconds of the ramp-up, after which the scene moves at full pace.
final _ramp = _Hero.rampUp.inMilliseconds / 1000;
final _widthTime = _Hero.widthTime.inMilliseconds / 1000;

/// Seconds of travel [t] seconds after a start (ramp included).
double _covered(double t) => t >= _ramp ? t - _ramp / 2 : t * t / (2 * _ramp);

const _content = ValueKey('content');

Future<void> _pump(
  WidgetTester tester, {
  double width = 390,
  double contentHeight = 240,
  bool reduced = false,
  bool ticking = true,
  HomeScene scene = HomeScene.street,
  SceneEffect effect = SceneEffect.none,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(800, 900);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
        child: Scaffold(
          body: SingleChildScrollView(
            child: Align(
              alignment: Alignment.topLeft,
              child: TickerMode(
                enabled: ticking,
                child: SizedBox(
                  width: width,
                  child: _Hero(
                    scene: scene,
                    effect: effect,
                    content: SizedBox(key: _content, height: contentHeight),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  ));
}

Rect _hero(WidgetTester tester) => tester.getRect(find.byType(_Hero));

/// The pass of the street under the hero's left edge: its number and the
/// whole panorama's rect.
(int, Rect) _lead(WidgetTester tester) {
  final hero = _hero(tester);
  for (var i = 0; i < 100; i++) {
    final pass = find.byKey(ValueKey('home-scene-panorama-$i'));
    if (pass.evaluate().isEmpty) continue;
    final rect = tester.getRect(pass);
    if (rect.left <= hero.left + .01 &&
        rect.left + _Hero.lap * hero.width > hero.left + .01) {
      return (i, rect);
    }
  }
  throw StateError('No pass of the street under the hero');
}

Rect _panorama(WidgetTester tester) => _lead(tester).$2;
Rect _rider(WidgetTester tester) =>
    tester.getRect(find.byKey(const ValueKey('home-scene-rider')));
String? _riderAsset(WidgetTester tester) {
  final image = tester
      .widget<Image>(find.byKey(const ValueKey('home-scene-rider')))
      .image;
  return image is AssetImage ? image.assetName : null;
}

Finder get _effect => find.byKey(const ValueKey('home-scene-effect'));

/// How far the camera has panned, in hero widths.
double _camera(WidgetTester tester) {
  final (pass, panorama) = _lead(tester);
  final hero = _hero(tester);
  return pass * _Hero.lap + (hero.left - panorama.left) / hero.width;
}

void main() {
  setUp(() => _Hero.autoplay = true);
  tearDown(() => _Hero.autoplay = false);

  test('Snow overlay preserves the panorama dimensions and RGBA format', () {
    final bytes = File(_Hero.snowOverlayAsset).readAsBytesSync();
    final data = ByteData.sublistView(bytes);
    expect(data.getUint32(16), 1881);
    expect(data.getUint32(20), 836);
    expect(bytes[25], 6, reason: 'PNG must retain RGBA transparency');
  });

  testWidgets('Settled snow follows the street through travel and reset',
      (tester) async {
    await _pump(tester, effect: SceneEffect.snow);
    final snow = find.byKey(const ValueKey('home-snow-awning-overlay'));
    expect(snow, findsOneWidget);
    expect(tester.widget<Image>(snow).image,
        const AssetImage(_Hero.snowOverlayAsset));
    final start = tester.getRect(snow);
    expect(start, _panorama(tester));
    await tester.pump(const Duration(seconds: 15));
    expect(tester.getRect(snow), _panorama(tester));
    expect(tester.getRect(snow).left, lessThan(start.left));
    // Into the next pass: its snow comes with it, the seam's too.
    await tester.pump(const Duration(seconds: 16));
    expect(find.byKey(const ValueKey('home-scene-seam-0')), findsOneWidget);
    expect(snow, findsNWidgets(3));
    // Past the seam: the next pass alone.
    await tester.pump(const Duration(seconds: 15));
    expect(snow, findsOneWidget);
    expect(tester.getRect(snow), _panorama(tester));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Settled snow stays with reduced motion and only on snowy street',
      (tester) async {
    final snow = find.byKey(const ValueKey('home-snow-awning-overlay'));
    await _pump(tester, effect: SceneEffect.snow, reduced: true);
    expect(snow, findsOneWidget);
    expect(_effect, findsNothing);
    final still = tester.getRect(snow);
    await tester.pump(const Duration(seconds: 8));
    expect(tester.getRect(snow), still);
    await _pump(tester, effect: SceneEffect.snow, scene: HomeScene.plain);
    expect(snow, findsNothing);
    for (final weather in [
      SceneEffect.none,
      SceneEffect.rain,
      SceneEffect.leaves
    ]) {
      await _pump(tester, effect: weather);
      expect(snow, findsNothing);
    }
    await _pump(tester, effect: SceneEffect.snow);
    expect(snow, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'The panorama: three widths wide, its own proportions, at the '
      'bottom; the hero at least 1.6 × its width', (tester) async {
    await _pump(tester);
    final hero = _hero(tester);
    final panorama = _panorama(tester);
    expect(hero.height, closeTo(390 * 1.6, .01));
    expect(panorama.width, closeTo(390 * 3, .01));
    expect(panorama.width / panorama.height, closeTo(1881 / 836, .001));
    expect(panorama.bottom, closeTo(hero.bottom, .01));
    expect(panorama.left, closeTo(hero.left, .01));
  });

  testWidgets('Content stays above the rooftops; long content grows it',
      (tester) async {
    await _pump(tester, contentHeight: 400);
    final hero = _hero(tester);
    final rooftops =
        hero.bottom - _Hero.panoramaHeight(390) * _Hero.buildingsShare;
    expect(hero.height, greaterThan(390 * 1.6));
    expect(tester.getRect(find.byKey(_content)).bottom, closeTo(rooftops, .01));
  });

  testWidgets(
      'Nudaeng near the middle, wheels on the road, one small '
      'shadow under each wheel', (tester) async {
    await _pump(tester);
    final hero = _hero(tester);
    final rider = _rider(tester);
    const unit =
        390 * _Hero.wheelbaseFactor / (_Hero.frontHubX - _Hero.rearHubX);
    final ground = hero.bottom - _Hero.panoramaHeight(390) * .08;
    expect(rider.width, closeTo(_Hero.riderCanvas.width * unit, .01));
    expect(rider.height, closeTo(_Hero.riderCanvas.height * unit, .01));
    // The middle between the wheels at 48 % of the width.
    expect(
        rider.left + unit * (_Hero.rearHubX + _Hero.frontHubX) / 2 - hero.left,
        closeTo(390 * _Hero.riderCentre, .01));
    expect(rider.top + _Hero.riderRoadY * unit, closeTo(ground, .01));
    for (final (index, hub) in [_Hero.rearHubX, _Hero.frontHubX].indexed) {
      final shadow =
          tester.getRect(find.byKey(ValueKey('home-scene-shadow-$index')));
      expect(shadow.center.dx, closeTo(rider.left + hub * unit, .01));
      expect(shadow.center.dy, closeTo(ground, .01));
      expect(shadow.height, lessThan(4));
    }
  });

  test('The kick cycle: 12 poses, glides held, about 1.9 s', () {
    expect(_Hero.riderFrames, hasLength(12));
    expect(_Hero.riderDurations, hasLength(12));
    final cycle =
        _Hero.riderDurations.fold(Duration.zero, (total, step) => total + step);
    expect(cycle, const Duration(milliseconds: 1900));
    expect(_Hero.riderFrameAt(0), 0);
    expect(_Hero.riderFrameAt(.359), 0);
    expect(_Hero.riderFrameAt(.36), 1);
    // Every pose comes up, in order, then it loops.
    var seconds = 0.0;
    for (var i = 0; i < 12; i++) {
      expect(_Hero.riderFrameAt(seconds + .001), i);
      seconds += _Hero.riderDurations[i].inMicroseconds / 1e6;
    }
    expect(_Hero.riderFrameAt(1.9 + .001), 0);
  });

  test('Every pose shares the canvas the anchors were measured on', () {
    for (final asset in _Hero.riderFrames) {
      // A PNG's size: big-endian width and height at bytes 16 and 20.
      final header = ByteData.sublistView(File(asset).readAsBytesSync(), 0, 24);
      expect(
          Size(
              header.getUint32(16).toDouble(), header.getUint32(20).toDouble()),
          _Hero.riderCanvas,
          reason: asset);
    }
  });

  test('Rain wardrobe has a complete transparent-frame canvas', () {
    expect(_Hero.rainRiderFrames, hasLength(_Hero.riderDurations.length));
    for (final asset in _Hero.rainRiderFrames) {
      final header = ByteData.sublistView(File(asset).readAsBytesSync(), 0, 26);
      expect(
          Size(
              header.getUint32(16).toDouble(), header.getUint32(20).toDouble()),
          _Hero.rainRiderCanvas,
          reason: asset);
      expect(header.getUint8(25), 6, reason: 'RGBA PNG: $asset');
    }
  });

  testWidgets(
      'Rain selects the coat, cool scenery and a wet road; all poses play',
      (tester) async {
    await _pump(tester, effect: SceneEffect.rain);
    await tester.pump();
    final hero = _hero(tester);
    final rider = _rider(tester);
    const unit =
        390 * _Hero.wheelbaseFactor / (_Hero.frontHubX - _Hero.rearHubX);
    expect(rider.top + _Hero.rainRiderRoadY * unit,
        closeTo(hero.bottom - _Hero.panoramaHeight(390) * .08, .01));
    expect(
        find.byKey(const ValueKey('home-rain-colour-grade')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-rain-wet-road')), findsOneWidget);
    expect(
        tester
            .widget<ColoredBox>(find.byKey(const ValueKey('home-scene-sky')))
            .color,
        _Hero.rainSky);
    final seen = <String>{};
    for (var step = 0; step < 40; step++) {
      await tester.pump(const Duration(milliseconds: 50));
      seen.add(_riderAsset(tester)!);
      expect(_rider(tester), rider);
    }
    expect(seen, _Hero.rainRiderFrames.toSet());
    expect(tester.takeException(), isNull);
  });

  testWidgets('Changing weather swaps outfit without restarting the journey',
      (tester) async {
    await _pump(tester);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 650));
    final before = _camera(tester);
    final pose = _Hero.riderFrames.indexOf(_riderAsset(tester)!);
    await _pump(tester, effect: SceneEffect.rain);
    expect(_riderAsset(tester), _Hero.rainRiderFrames[pose]);
    expect(_camera(tester), closeTo(before, 1e-6));
    await _pump(tester, effect: SceneEffect.snow);
    expect(_riderAsset(tester), _Hero.riderFrames[pose]);
    expect(find.byKey(const ValueKey('home-rain-wet-road')), findsNothing);
    expect(find.byKey(const ValueKey('home-rain-colour-grade')), findsNothing);
    expect(
        tester
            .widget<ColoredBox>(find.byKey(const ValueKey('home-scene-sky')))
            .color,
        _Hero.skyFor(SceneEffect.snow));
  });

  for (final effect in SceneEffect.values) {
    testWidgets('${effect.label}: its light on the scenery, never on the UI',
        (tester) async {
      await _pump(tester, effect: effect);
      final grade = find.byKey(ValueKey('home-${effect.name}-colour-grade'));
      final sky = tester
          .widget<ColoredBox>(find.byKey(const ValueKey('home-scene-sky')))
          .color;
      if (effect == SceneEffect.none) {
        expect(find.byType(ColorFiltered), findsNothing);
        expect(sky, _Hero.sky);
        return;
      }
      expect(grade, findsOneWidget);
      // The sky above continues the relit panorama's top edge.
      expect(sky, _Hero.skyFor(effect));
      expect(sky, isNot(_Hero.sky));
      expect(_Hero.roadFor(effect), isNot(_Hero.road));
      // Greeting, prompt and buttons keep their colours.
      expect(find.ancestor(of: find.byKey(_content), matching: grade),
          findsNothing);
      expect(
          find.ancestor(
              of: find.byKey(_content), matching: find.byType(ColorFiltered)),
          findsNothing);
    });
  }

  test('Each light keeps its character', () {
    // The yellow house's wall, in the middle section.
    const wall = Color(0xFFE2B85A);
    double warmth(Color c) => c.r - c.b;
    double light(Color c) => c.computeLuminance();
    Color under(SceneEffect effect, Color c) => _Hero.graded(c, effect);
    // Rain: dimmer.
    expect(light(under(SceneEffect.rain, wall)), lessThan(light(wall)));
    expect(light(_Hero.rainSky), lessThan(light(_Hero.sky)));
    // Snow: the yellows down, the sky silvery blue and lighter.
    expect(warmth(under(SceneEffect.snow, wall)), lessThan(warmth(wall)));
    final snowSky = _Hero.skyFor(SceneEffect.snow);
    expect(snowSky.b, greaterThanOrEqualTo(snowSky.g));
    expect(light(snowSky), greaterThan(light(_Hero.sky)));
    // Leaves: warmer everywhere.
    expect(warmth(under(SceneEffect.leaves, wall)), greaterThan(warmth(wall)));
    expect(warmth(_Hero.skyFor(SceneEffect.leaves)),
        greaterThan(warmth(_Hero.sky)));
  });

  test('Effects thin out over the prompt, full over the street', () {
    const rooftops = 400.0;
    expect(_Hero.streetShare(200, rooftops), 0);
    expect(_Hero.streetShare(rooftops - 30, rooftops), 0);
    expect(_Hero.streetShare(rooftops + 15, rooftops), closeTo(.5, 1e-9));
    expect(_Hero.streetShare(rooftops + 60, rooftops), 1);
    expect(_Hero.streetShare(800, rooftops), 1);
  });

  for (final scene in HomeScene.values) {
    testWidgets('Reduced-motion rain keeps its coat and wet surface in $scene',
        (tester) async {
      await _pump(tester,
          scene: scene, effect: SceneEffect.rain, reduced: true);
      expect(_riderAsset(tester), _Hero.rainRiderFrames.first);
      expect(find.byKey(const ValueKey('home-rain-wet-road')), findsOneWidget);
      expect(_effect, findsNothing);
      await tester.pump(const Duration(seconds: 5));
      expect(_riderAsset(tester), _Hero.rainRiderFrames.first);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('The poses play in place: the scooter and wheels never move',
      (tester) async {
    await _pump(tester);
    final rider = _rider(tester);
    await tester.pump();
    final seen = <String>{};
    for (var frame = 0; frame < 40; frame++) {
      await tester.pump(const Duration(milliseconds: 50));
      seen.add(_riderAsset(tester)!);
      expect(_rider(tester), rider);
    }
    // A full cycle in 2 s: every pose shown.
    expect(seen, _Hero.riderFrames.toSet());
  });

  testWidgets('It rides in the plain scene too', (tester) async {
    await _pump(tester, scene: HomeScene.plain);
    await tester.pump();
    final first = _riderAsset(tester);
    await tester.pump(const Duration(milliseconds: 500));
    expect(_riderAsset(tester), isNot(first));
  });

  testWidgets('One label for the scene', (tester) async {
    await _pump(tester);
    expect(find.bySemanticsLabel(_Hero.semanticLabel(HomeScene.street)),
        findsOneWidget);
  });

  test('The camera pans a hero width every 15 s and never turns back', () {
    expect(_Hero.cameraAt(0), 0);
    expect(_Hero.cameraAt(15), closeTo(1, 1e-9));
    expect(_Hero.cameraAt(90), closeTo(6, 1e-9));
    expect(_Hero.lap, closeTo(2.75, 1e-9));
  });

  testWidgets('Pans right to left through the sections, evenly',
      (tester) async {
    await _pump(tester);
    await tester.pump();
    expect(_camera(tester), closeTo(0, 1e-6));
    await tester.pump(const Duration(milliseconds: 400));
    // Half-way through the ramp: a quarter of the full-pace travel.
    expect(_camera(tester), closeTo(_covered(.4) / _widthTime, 1e-4));
    await tester.pump(const Duration(milliseconds: 14600));
    expect(_camera(tester), closeTo(_covered(15) / _widthTime, 1e-4));
  });

  testWidgets('Pass after pass: no jump, gap or flash at the seam',
      (tester) async {
    await _pump(tester);
    await tester.pump();
    var last = _camera(tester);
    var sawSeam = false;
    // Over two passes (about 83 s) in 100 ms frames.
    for (var frame = 0; frame < 850; frame++) {
      await tester.pump(const Duration(milliseconds: 100));
      final camera = _camera(tester);
      final step = camera - last;
      // Steady pace once ramped: never back, never a leap.
      expect(step, greaterThanOrEqualTo(0), reason: 'frame $frame');
      expect(step, lessThanOrEqualTo(.1 / _widthTime + 1e-6),
          reason: 'frame $frame');
      final hero = _hero(tester);
      // The passes on screen cover the hero, side by side.
      var covered = hero.left;
      for (var i = 0; i < 100; i++) {
        final pass = find.byKey(ValueKey('home-scene-pass-$i'));
        if (pass.evaluate().isEmpty) continue;
        final rect = tester.getRect(pass);
        expect(rect.left, lessThanOrEqualTo(covered + .01));
        covered = math.max(covered, rect.right);
        final seam = find.byKey(ValueKey('home-scene-seam-$i'));
        if (seam.evaluate().isNotEmpty) {
          sawSeam = true;
          // The end fades over the next pass's start.
          expect(tester.getRect(seam).left, closeTo(rect.right, .01));
          expect(
              find.byKey(ValueKey('home-scene-pass-${i + 1}')), findsOneWidget);
        }
      }
      expect(covered, greaterThanOrEqualTo(hero.right - .01));
      last = camera;
    }
    expect(sawSeam, isTrue);
    expect(_lead(tester).$1, greaterThanOrEqualTo(1));
  });

  for (final width in [280.0, 370.0, 430.0, 600.0]) {
    testWidgets('Fits $width wide', (tester) async {
      await _pump(tester, width: width);
      await tester.pump();
      await tester.pump(const Duration(seconds: 5));
      expect(_hero(tester).height, greaterThanOrEqualTo(width * 1.6));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Plain scene: sky and road, Nudaeng, no street', (tester) async {
    await _pump(tester, scene: HomeScene.plain);
    expect(find.byKey(const ValueKey('home-scene-panorama')), findsNothing);
    expect(find.byKey(const ValueKey('home-scene-rider')), findsOneWidget);
    expect(find.bySemanticsLabel(_Hero.semanticLabel(HomeScene.plain)),
        findsOneWidget);
  });

  for (final effect in [
    SceneEffect.leaves,
    SceneEffect.rain,
    SceneEffect.snow,
  ]) {
    for (final scene in HomeScene.values) {
      testWidgets('${effect.label} over the ${scene.label} scene',
          (tester) async {
        await _pump(tester, scene: scene, effect: effect);
        expect(_effect, findsOneWidget);
        expect(tester.getRect(_effect), _hero(tester));
        for (var t = 0; t < 10; t++) {
          await tester.pump(const Duration(milliseconds: 700));
        }
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('Reduced motion: no effect, the camera holds', (tester) async {
    await _pump(tester, reduced: true, effect: SceneEffect.snow);
    expect(_effect, findsNothing);
    expect(_riderAsset(tester), _Hero.riderFrames.first);
    await tester.pump(const Duration(seconds: 10));
    expect(_camera(tester), closeTo(0, 1e-6));
  });

  testWidgets('Off screen it pauses, and resumes from where it was',
      (tester) async {
    await _pump(tester);
    await tester.pump();
    await tester.pump(const Duration(seconds: 6));
    final before = _camera(tester);
    // Another tab or a screen above Home.
    await _pump(tester, ticking: false);
    await tester.pump(const Duration(seconds: 10));
    expect(_camera(tester), closeTo(before, 1e-6));
    await _pump(tester);
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(_camera(tester) - before, closeTo(_covered(2) / _widthTime, 1e-4));
  });

  testWidgets('In the background it pauses, and resumes from where it was',
      (tester) async {
    await _pump(tester);
    await tester.pump();
    await tester.pump(const Duration(seconds: 6));
    final before = _camera(tester);
    final pose = _riderAsset(tester);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 10));
    expect(_camera(tester), closeTo(before, 1e-6));
    expect(_riderAsset(tester), pose);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(_camera(tester) - before, closeTo(_covered(2) / _widthTime, 1e-4));
  });

  group('Profile settings reach Home', () {
    setUp(() {
      _Hero.autoplay = false;
      SharedPreferences.setMockInitialValues({});
    });

    Future<void> choose(
        WidgetTester tester, String setting, String option) async {
      final item = find.byKey(ValueKey('setting-item-$setting'));
      await tester.scrollUntilVisible(item, 150,
          scrollable: find
              .descendant(
                  of: find.byType(ProfileScreen),
                  matching: find.byType(Scrollable))
              .first);
      await tester.ensureVisible(item);
      await tester.pumpAndSettle();
      await tester.tap(item);
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(
          of: find.byType(SettingEditor), matching: find.text(option)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lưu'));
      await tester.pumpAndSettle();
    }

    testWidgets('Khung cảnh and Giao diện động', (tester) async {
      await tester.pumpWidget(const AiDiaryApp());
      await tester.pumpAndSettle();
      var hero = tester.widget<_Hero>(find.byType(_Hero));
      expect(hero.scene, HomeScene.street);
      expect(hero.effect, SceneEffect.none);

      await tester.tap(find.bySemanticsLabel('Ảnh đại diện hồ sơ'));
      await tester.pumpAndSettle();
      await choose(tester, 'scene', HomeScene.plain.label);
      expect(
          tester
              .widget<Text>(find.byKey(const ValueKey('setting-value-scene')))
              .data,
          HomeScene.plain.label);
      await choose(tester, 'dynamic theme', SceneEffect.rain.label);
      expect(
          tester
              .widget<Text>(
                  find.byKey(const ValueKey('setting-value-dynamic theme')))
              .data,
          SceneEffect.rain.label);
      await tester.tap(find.byTooltip('Đóng'));
      await tester.pumpAndSettle();

      hero = tester.widget<_Hero>(find.byType(_Hero));
      expect(hero.scene, HomeScene.plain);
      expect(hero.effect, SceneEffect.rain);
      final saved = await HomeSceneSettings.open();
      expect(saved.scene, HomeScene.plain);
      expect(saved.effect, SceneEffect.rain);
    });
  });
}
