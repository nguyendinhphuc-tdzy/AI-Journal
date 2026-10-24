import 'package:ai_diary/features/album/data/album_unlocks.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final unlocks = AlbumUnlocks.instance;

  setUp(() {
    unlocks.didChangeAppLifecycleState(AppLifecycleState.resumed);
    unlocks.lockAll();
  });

  test('a system PIN prompt pausing the app does not lock anything', () async {
    unlocks.unlock('a');
    final revision = unlocks.revision;
    final result = await unlocks.duringSystemPrompt(() async {
      // Android shows the PIN prompt as its own activity.
      unlocks.didChangeAppLifecycleState(AppLifecycleState.inactive);
      unlocks.didChangeAppLifecycleState(AppLifecycleState.hidden);
      unlocks.didChangeAppLifecycleState(AppLifecycleState.paused);
      Future<void>.delayed(const Duration(milliseconds: 10), () {
        unlocks.didChangeAppLifecycleState(AppLifecycleState.inactive);
        unlocks.didChangeAppLifecycleState(AppLifecycleState.resumed);
      });
      return 'ok';
    });
    expect(result, 'ok');
    expect(unlocks.foreground, isTrue, reason: 'waits until back in front');
    expect(unlocks.revision, revision);
    expect(unlocks.isUnlocked('a'), isTrue);
  });

  test('leaving the app outside a prompt still locks everything', () {
    unlocks.unlock('a');
    unlocks.didChangeAppLifecycleState(AppLifecycleState.paused);
    expect(unlocks.isUnlocked('a'), isFalse);
  });

  test('the app being closed during a prompt locks everything', () async {
    unlocks.unlock('a');
    await unlocks.duringSystemPrompt(() async {
      unlocks.didChangeAppLifecycleState(AppLifecycleState.detached);
      unlocks.didChangeAppLifecycleState(AppLifecycleState.resumed);
    });
    expect(unlocks.isUnlocked('a'), isFalse);
  });

  test('never back in front: gives up after the settle time', () async {
    final watch = Stopwatch()..start();
    await unlocks.duringSystemPrompt(() async {
      unlocks.didChangeAppLifecycleState(AppLifecycleState.paused);
    }, settle: const Duration(milliseconds: 50));
    expect(watch.elapsedMilliseconds, lessThan(1000));
    expect(unlocks.foreground, isFalse);
  });
}
