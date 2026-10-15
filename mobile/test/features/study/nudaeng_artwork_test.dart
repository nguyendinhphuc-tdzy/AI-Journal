import 'dart:ui' as ui;

import 'package:ai_diary/features/study/presentation/nudaeng_artwork.dart';
import 'package:ai_diary/features/study/presentation/nudaeng_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Cutouts have alpha and retain original GIF frames and timing',
      () async {
    final paths = <String>{
      for (final artwork in NudaengArtwork.values) ...[
        artwork.idleAsset,
        if (artwork.animationAsset != null) artwork.animationAsset!,
      ],
    };
    expect(paths.length, 11);
    for (final path in paths) {
      // ND05 is newly generated, not a cutout of a supplied GIF.
      if (path.contains('ND05-check-notebook')) continue;
      expect(path, matches(r'^assets/(Deimage|NudaenggifDe)/'));
      final bytes = await rootBundle.load(path);
      final codec = await ui.instantiateImageCodec(
        bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
        targetWidth: 64,
      );
      final sourcePath = path.endsWith('.gif')
          ? path.replaceFirst('-transparent.gif', '.gif')
          : path.replaceFirst('-transparent.png', '.jpg');
      final sourceBytes = await rootBundle.load(sourcePath);
      final originalCodec = await ui.instantiateImageCodec(
        sourceBytes.buffer
            .asUint8List(sourceBytes.offsetInBytes, sourceBytes.lengthInBytes),
        targetWidth: 64,
      );
      expect(codec.frameCount, originalCodec.frameCount, reason: path);
      for (var index = 0; index < codec.frameCount; index++) {
        final frame = await codec.getNextFrame();
        final originalFrame = await originalCodec.getNextFrame();
        expect(frame.duration, originalFrame.duration,
            reason: '$path frame $index');
        final rgba =
            (await frame.image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
        var transparent = 0;
        var opaque = 0;
        for (var i = 3; i < rgba.lengthInBytes; i += 4) {
          if (rgba.getUint8(i) == 0) transparent++;
          if (rgba.getUint8(i) == 255) opaque++;
        }
        expect(transparent, greaterThan(0), reason: '$path frame $index');
        expect(opaque, greaterThan(0), reason: '$path frame $index');
        frame.image.dispose();
        originalFrame.image.dispose();
      }
      originalCodec.dispose();
      codec.dispose();
    }
  });

  test('New ND05 has 12 transparent frames lasting exactly 1.2 seconds',
      () async {
    const artwork = NudaengArtwork.challengeProgress;
    expect(artwork.maxDuration, const Duration(milliseconds: 1200));
    final bytes = await rootBundle.load(artwork.animationAsset!);
    final codec = await ui.instantiateImageCodec(bytes.buffer.asUint8List());
    expect(codec.frameCount, 12);
    expect(codec.repetitionCount, 0);
    var duration = Duration.zero;
    for (var i = 0; i < codec.frameCount; i++) {
      final frame = await codec.getNextFrame();
      duration += frame.duration;
      final data =
          (await frame.image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
      var transparent = 0;
      var opaque = 0;
      for (var j = 3; j < data.lengthInBytes; j += 4) {
        if (data.getUint8(j) == 0) transparent++;
        if (data.getUint8(j) == 255) opaque++;
      }
      expect(transparent, greaterThan(0));
      expect(opaque, greaterThan(0));
      frame.image.dispose();
    }
    codec.dispose();
    expect(duration, const Duration(milliseconds: 1200));
  });

  test('S06 first time rests on the tail wag; reopened shows the static image',
      () {
    const celebration = NudaengArtwork.challengeCelebration;
    expect(celebration.animationAsset, endsWith('-transparent.gif'));
    // Resting on the GIF itself means it never dissolves into another drawing.
    expect(celebration.idleAsset, celebration.animationAsset);
    expect(celebration.idleFidget, isTrue);
    const completion = NudaengArtwork.challengeCompletion;
    expect(completion.idleAsset, endsWith('challengs-transparent.png'));
    expect(completion.animationAsset, isNull);
  });

  testWidgets('Study banner shows static Study-transparent.png, never a GIF',
      (tester) async {
    expect(NudaengArtwork.study.idleAsset,
        'assets/Deimage/Study-transparent.png');
    expect(NudaengArtwork.study.animationAsset, isNull);
    for (final reduced in [false, true]) {
      await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduced),
          child: NudaengView(
              key: ValueKey(reduced),
              artwork: NudaengArtwork.study,
              width: 96,
              height: 112,
              label: 'Study'),
        ),
      ));
      // Asset decoding runs outside the fake test clock.
      for (var i = 0; i < 100; i++) {
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)));
        await tester.pump();
        if (tester.widget<RawImage>(find.byType(RawImage)).image != null) {
          break;
        }
      }
      final image = tester.widget<RawImage>(find.byType(RawImage)).image!;
      // Study.jpg is a landscape crop.
      expect(image.width, greaterThan(image.height));
      expect(tester.binding.transientCallbackCount, 0);
    }
    expect(tester.takeException(), isNull);
  });
}
