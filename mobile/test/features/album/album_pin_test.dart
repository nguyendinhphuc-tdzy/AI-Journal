import 'package:ai_diary/core/theme/app_theme.dart';
import 'package:ai_diary/features/album/data/album_auth.dart';
import 'package:ai_diary/features/album/data/album_pins.dart';
import 'package:ai_diary/features/album/presentation/album_pin_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _type(WidgetTester tester, String pin) async {
  for (final digit in pin.split('')) {
    await tester.tap(find.bySemanticsLabel(digit));
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

/// A button that runs [action] with a context under the app's theme.
Future<void> _pump(
    WidgetTester tester, Future<void> Function(BuildContext) action) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.light,
    home: Builder(
      builder: (context) => Scaffold(
        body: TextButton(
            onPressed: () => action(context), child: const Text('go')),
      ),
    ),
  ));
  await tester.tap(find.text('go'));
  await tester.pumpAndSettle();
}

void main() {
  test('Only a salted hash is kept; it checks the right PIN only', () async {
    SharedPreferences.setMockInitialValues({});
    const pins = LocalAlbumPins();
    await pins.set('a1', '1234');
    final kept =
        (await SharedPreferences.getInstance()).getString('album.pin.a1')!;
    expect(kept, isNot(contains('1234')));
    expect(await pins.has('a1'), isTrue);
    expect(await pins.check('a1', '1234'), isTrue);
    expect(await pins.check('a1', '4321'), isFalse);
    expect(await pins.check('other', '1234'), isFalse);
    // The same PIN twice is kept differently (its own salt).
    await pins.set('a2', '1234');
    expect((await SharedPreferences.getInstance()).getString('album.pin.a2'),
        isNot(kept));
    await pins.set('a1', null);
    expect(await pins.has('a1'), isFalse);
  });

  testWidgets('Choosing: entered twice; a mismatch starts over',
      (tester) async {
    String? chosen;
    await _pump(
        tester,
        (context) async => chosen =
            await PinAlbumAuth(InMemoryAlbumPins()).choosePin(context));
    expect(find.text(AlbumPinPad.chooseTitle), findsOneWidget);
    await _type(tester, '1357');
    expect(find.text(AlbumPinPad.confirmTitle), findsOneWidget);
    await _type(tester, '1358');
    expect(find.text(AlbumPinPad.mismatch), findsOneWidget);
    expect(find.text(AlbumPinPad.chooseTitle), findsOneWidget);
    await _type(tester, '2468');
    await _type(tester, '2468');
    expect(find.byType(AlbumPinPad), findsNothing);
    expect(chosen, '2468');
  });

  testWidgets('Verifying: wrong says so; five wrong wait; right opens',
      (tester) async {
    final pins = InMemoryAlbumPins();
    await pins.set('a1', '2468');
    final auth = PinAlbumAuth(pins);
    AlbumAuthResult? result;
    await _pump(
        tester,
        (context) async =>
            result = await auth.verify(context, 'a1', reason: 'Để mở album.'));
    expect(find.text(AlbumPinPad.verifyTitle), findsOneWidget);
    await _type(tester, '1111');
    expect(find.text(AlbumPinPad.wrong), findsOneWidget);
    for (var i = 0; i < PinAlbumAuth.maxTries - 1; i++) {
      await _type(tester, '1111');
    }
    expect(find.text(AlbumPinPad.waitText(30)), findsOneWidget);
    // Keys do nothing while it waits.
    await _type(tester, '2468');
    expect(find.byType(AlbumPinPad), findsOneWidget);
    await tester.pump(PinAlbumAuth.wait);
    await tester.pumpAndSettle();
    expect(find.text(AlbumPinPad.waitText(30)), findsNothing);
    // The real wait is wall-clock time; tests do not wait it out.
    await tester.tap(find.text(AlbumPinPad.forgotLabel));
    await tester.pump();
    expect(find.text(AlbumPinPad.forgotHelp), findsOneWidget);
    expect(result, isNull);
  });

  testWidgets('Verifying: the right PIN closes with success', (tester) async {
    final pins = InMemoryAlbumPins();
    await pins.set('a1', '2468');
    AlbumAuthResult? result;
    await _pump(
        tester,
        (context) async => result = await PinAlbumAuth(pins)
            .verify(context, 'a1', reason: 'Để mở album.'));
    await _type(tester, '2468');
    expect(find.byType(AlbumPinPad), findsNothing);
    expect(result, AlbumAuthResult.success);
  });

  testWidgets('An album locked before PINs: the device once, then a new PIN',
      (tester) async {
    final pins = InMemoryAlbumPins();
    var deviceAsked = 0;
    AlbumAuthResult? result;
    await _pump(
        tester,
        (context) async => result = await PinAlbumAuth(pins, () async {
              deviceAsked++;
              return true;
            }).verify(context, 'old', reason: 'Để mở album.'));
    expect(deviceAsked, 1);
    expect(find.text(AlbumPinPad.chooseTitle), findsOneWidget);
    await _type(tester, '2468');
    await _type(tester, '2468');
    expect(result, AlbumAuthResult.success);
    expect(await pins.check('old', '2468'), isTrue);
  });
}
