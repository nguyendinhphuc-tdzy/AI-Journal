import 'package:ai_diary/features/album/presentation/nudaeng_album_key.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _scene({
  bool success = false,
  bool reducedMotion = false,
  VoidCallback? onCompleted,
  String? label,
}) =>
    MediaQuery(
      data: MediaQueryData(disableAnimations: reducedMotion),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox.square(
            dimension: 240,
            child: NudaengAlbumKey(
              authSucceeded: success,
              onCompleted: onCompleted,
              semanticLabel: label,
            ),
          ),
        ),
      ),
    );

String _visibleAsset(WidgetTester tester) {
  final layer = tester
      .widgetList<Opacity>(find.byType(Opacity))
      .singleWhere((widget) => widget.opacity == 1 && widget.child is Image);
  return ((layer.child as Image).image as AssetImage).assetName;
}

void main() {
  testWidgets('Waiting stays still indefinitely without completion',
      (tester) async {
    var completions = 0;
    await tester.pumpWidget(_scene(onCompleted: () => completions++));
    await tester.pump(const Duration(seconds: 30));
    expect(_visibleAsset(tester), NudaengAlbumKey.frames.first);
    expect(completions, 0);
  });

  testWidgets('Success plays once for exactly one second, then holds',
      (tester) async {
    var completions = 0;
    void completed() => completions++;
    await tester.pumpWidget(_scene(onCompleted: completed));
    await tester.pumpWidget(_scene(success: true, onCompleted: completed));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 149));
    expect(_visibleAsset(tester), NudaengAlbumKey.frames[0]);
    await tester.pump(const Duration(milliseconds: 1));
    expect(_visibleAsset(tester), NudaengAlbumKey.frames[1]);
    await tester.pump(const Duration(milliseconds: 249));
    expect(_visibleAsset(tester), NudaengAlbumKey.frames[1]);
    await tester.pump(const Duration(milliseconds: 1));
    expect(_visibleAsset(tester), NudaengAlbumKey.frames[2]);
    await tester.pump(const Duration(milliseconds: 350));
    expect(_visibleAsset(tester), NudaengAlbumKey.frames[3]);
    await tester.pump(const Duration(milliseconds: 249));
    expect(completions, 0, reason: '999 ms must not complete');
    await tester.pump(const Duration(milliseconds: 1));
    expect(completions, 1);
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpWidget(_scene(
        success: true, onCompleted: completed, label: 'Đã cất chìa khóa'));
    await tester.pump(const Duration(seconds: 3));
    expect(_visibleAsset(tester), NudaengAlbumKey.frames.last);
    expect(completions, 1, reason: 'rebuild must not replay or notify again');
  });

  testWidgets('Already successful on mount plays once', (tester) async {
    var completions = 0;
    await tester
        .pumpWidget(_scene(success: true, onCompleted: () => completions++));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(_visibleAsset(tester), NudaengAlbumKey.frames.last);
    expect(completions, 1);
  });

  testWidgets('Reset cancels pending success and permits a new attempt',
      (tester) async {
    var completions = 0;
    void completed() => completions++;
    await tester.pumpWidget(_scene(success: true, onCompleted: completed));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpWidget(_scene(onCompleted: completed));
    await tester.pump(const Duration(seconds: 2));
    expect(_visibleAsset(tester), NudaengAlbumKey.frames.first);
    expect(completions, 0);
    await tester.pumpWidget(_scene(success: true, onCompleted: completed));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(completions, 1);
  });

  testWidgets('Reduced motion waits, then shows final pose without delay',
      (tester) async {
    var completions = 0;
    void completed() => completions++;
    await tester
        .pumpWidget(_scene(reducedMotion: true, onCompleted: completed));
    await tester.pump(const Duration(seconds: 5));
    expect(_visibleAsset(tester), NudaengAlbumKey.frames.first);
    expect(completions, 0);
    await tester.pumpWidget(
        _scene(success: true, reducedMotion: true, onCompleted: completed));
    expect(_visibleAsset(tester), NudaengAlbumKey.frames.last);
    expect(completions, 1);
    await tester.pumpWidget(
        _scene(success: true, reducedMotion: true, onCompleted: completed));
    expect(completions, 1);
  });

  testWidgets('Enabling reduced motion mid-run finishes only once',
      (tester) async {
    var completions = 0;
    void completed() => completions++;
    await tester.pumpWidget(_scene(success: true, onCompleted: completed));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpWidget(
        _scene(success: true, reducedMotion: true, onCompleted: completed));
    expect(_visibleAsset(tester), NudaengAlbumKey.frames.last);
    expect(completions, 1);
    await tester.pump(const Duration(seconds: 2));
    expect(completions, 1);
  });

  testWidgets('Leaving mid-run cancels completion', (tester) async {
    var completions = 0;
    await tester
        .pumpWidget(_scene(success: true, onCompleted: () => completions++));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
    expect(completions, 0);
    expect(tester.takeException(), isNull);
  });
}
