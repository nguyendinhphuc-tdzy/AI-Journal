import 'dart:math' as math;

import 'package:ai_diary/features/onboarding/presentation/nudaeng_chasing_cockroach.dart';
import 'package:ai_diary/features/onboarding/presentation/nudaeng_cockroach_idle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _idle({bool active = true, bool reducedMotion = false, int seed = 1}) =>
    MediaQuery(
      data: MediaQueryData(disableAnimations: reducedMotion),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(
            width: 306,
            height: 319,
            child:
                NudaengCockroachIdle(active: active, random: math.Random(seed)),
          ),
        ),
      ),
    );

Future<void> _pump(WidgetTester tester,
    {bool active = true, bool reducedMotion = false, int seed = 1}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(400, 400);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
      _idle(active: active, reducedMotion: reducedMotion, seed: seed));
}

/// Antenna frame currently painted.
int _antennae(WidgetTester tester) => tester
    .widgetList<Opacity>(find.descendant(
        of: find.byType(NudaengCockroachIdle), matching: find.byType(Opacity)))
    .where((layer) {
      final child = layer.child;
      if (child is! Image) return false;
      final image = child.image;
      return image is ResizeImage &&
          NudaengCockroachIdle.cockroachFrames
              .contains((image.imageProvider as AssetImage).assetName);
    })
    .toList()
    .indexWhere((layer) => layer.opacity == 1);

/// Opacity of the twitching sprite as it fades in over the run's cockroach.
double _reveal(WidgetTester tester) => tester
    .widget<FadeTransition>(find.descendant(
        of: find.byType(NudaengCockroachIdle),
        matching: find.byType(FadeTransition)))
    .opacity
    .value;

/// Opacity of the run's own cockroach, under the sprite.
double _runCockroach(WidgetTester tester) => tester
        .widgetList<Opacity>(find.descendant(
            of: find.byType(NudaengCockroachIdle),
            matching: find.byType(Opacity)))
        .firstWhere((layer) {
      final child = layer.child;
      return child is Image &&
          child.image ==
              const AssetImage(NudaengCockroachIdle.runCockroachFrame);
    }).opacity;

/// Antenna frames over [length], sampled each 20 ms, repeats collapsed.
Future<String> _watch(WidgetTester tester, Duration length) async {
  var last = _antennae(tester);
  final seen = StringBuffer('$last');
  for (var t = Duration.zero;
      t < length;
      t += const Duration(milliseconds: 20)) {
    await tester.pump(const Duration(milliseconds: 20));
    final now = _antennae(tester);
    if (now != last) seen.write(now);
    last = now;
  }
  return seen.toString();
}

void main() {
  testWidgets('Starts from the run\'s last frame, split in two',
      (tester) async {
    await _pump(tester);
    final runLayers = tester
        .widgetList<Image>(find.descendant(
            of: find.byType(NudaengCockroachIdle),
            matching: find.byType(Image)))
        .map((image) => image.image)
        .whereType<AssetImage>()
        .map((image) => image.assetName);
    expect(runLayers, [
      NudaengCockroachIdle.dogFrame,
      NudaengCockroachIdle.runCockroachFrame,
    ]);
    expect(_runCockroach(tester), 1);
    expect(_reveal(tester), 0, reason: 'sprite not shown yet');
    expect(NudaengCockroachIdle.space.aspectRatio,
        closeTo(NudaengChasingCockroach.aspectRatio, 1e-9));
  });

  testWidgets('Sprite fades in over an opaque cockroach, then takes over',
      (tester) async {
    await _pump(tester);
    await tester.pump(const Duration(milliseconds: 130));
    expect(_reveal(tester), inExclusiveRange(0, 1));
    expect(_runCockroach(tester), 1, reason: 'nothing dims while it fades');
    await tester.pump(const Duration(milliseconds: 200));
    expect(_reveal(tester), 1);
    expect(_runCockroach(tester), 0);
  });

  testWidgets('Settles first, then twitches left → centre → right → centre',
      (tester) async {
    await _pump(tester);
    expect(await _watch(tester, const Duration(milliseconds: 1150)), '0',
        reason: 'a breath before the first twitch');
    expect(await _watch(tester, const Duration(seconds: 2)), contains('1020'));
  });

  testWidgets('Twitches now and then, still in between', (tester) async {
    await _pump(tester, seed: 5);
    final frames = await _watch(tester, const Duration(seconds: 13));
    // Each twitch bends left exactly once: the first after 1.2–2 s, then
    // every 2–4 s plus 0.52 s.
    expect('1'.allMatches(frames).length, inInclusiveRange(3, 5));
  });

  testWidgets('Inactive: holds the run pose, no timers', (tester) async {
    await _pump(tester, active: false);
    expect(await _watch(tester, const Duration(seconds: 6)), '0');
    expect(_reveal(tester), 0);
    expect(_runCockroach(tester), 1);
  });

  testWidgets('Deactivated mid-twitch: back to the run pose', (tester) async {
    await _pump(tester);
    await _watch(tester, const Duration(seconds: 2));
    await tester.pumpWidget(_idle(active: false));
    await tester.pump();
    expect(_antennae(tester), 0);
    expect(_reveal(tester), 0);
    expect(_runCockroach(tester), 1);
    expect(await _watch(tester, const Duration(seconds: 5)), '0');
  });

  testWidgets('Reduced motion: sprite shown, antennae centred', (tester) async {
    await _pump(tester, reducedMotion: true);
    expect(_reveal(tester), 1);
    expect(await _watch(tester, const Duration(seconds: 10)), '0');
  });

  testWidgets('Cockroach sprite lands where the run leaves it', (tester) async {
    // Full source canvas: the body stays at exactly the run's coordinates.
    const rect = NudaengCockroachIdle.cockroachRect;
    expect(rect, Offset.zero & NudaengCockroachIdle.space);
    await _pump(tester);
    final placed = tester.widget<Positioned>(find.descendant(
        of: find.byType(NudaengCockroachIdle),
        matching: find.byType(Positioned)));
    expect(placed.left, 0);
    expect(placed.top, 0);
    expect(placed.width, 306);
    expect(placed.height, 319);
  });
}
