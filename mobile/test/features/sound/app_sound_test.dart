import 'dart:io';

import 'package:ai_diary/core/theme/app_theme.dart';
import 'package:ai_diary/features/journal/data/journal_entry.dart';
import 'package:ai_diary/features/journal/presentation/write_journal_screen.dart';
import 'package:ai_diary/features/profile/profile_screen.dart';
import 'package:ai_diary/features/profile/widgets/setting_editor.dart';
import 'package:ai_diary/features/sound/app_sound.dart';
import 'package:ai_diary/features/sound/data/sound_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// What the app asked to play, in order.
class _Recorder implements SoundBackend {
  final effects = <(String, double)>[];
  final tracks = <(String?, double)>[];
  var pauses = 0;

  @override
  Future<void> effect(String asset, double volume) async =>
      effects.add((asset, volume));
  @override
  Future<void> music(String? asset, double volume) async =>
      tracks.add((asset, volume));
  @override
  Future<void> pauseMusic() async => pauses++;
  @override
  Future<void> preload(Iterable<String> assets) async {}
}

void main() {
  late _Recorder sound;
  var now = DateTime(2026, 10, 27, 9);

  /// Later than [AppSound.strokeGap], so the next stroke is heard.
  void later() => now = now.add(const Duration(milliseconds: 200));

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    sound = _Recorder();
    AppSound.backend = sound;
    // Well past the last stroke of the test before.
    now = now.add(const Duration(seconds: 1));
    AppSound.clock = () => now;
    await AppSound.instance.start();
    await AppSound.instance.refresh();
    AppSound.instance.followTyping();
  });
  tearDown(() {
    AppSound.backend = null;
    AppSound.clock = DateTime.now;
  });

  test('Every sound the app plays is in assets/sounds, with its credit', () {
    final files = [
      for (final cue in SoundCue.values) ...cue.assets,
      for (final track in MusicTrack.values)
        if (track.asset != null) track.asset!,
      for (final pen in PenSound.values)
        if (pen.prefix != null)
          for (var i = 1; i <= PenSound.strokes; i++) '${pen.prefix}_$i.wav',
    ];
    final credits = File('assets/sounds/CREDITS.md').readAsStringSync();
    for (final file in files) {
      expect(File('assets/sounds/$file').existsSync(), isTrue, reason: file);
      // Listed under its own name or its group's ("pen_pencil_1–4").
      final group = file.replaceFirst(RegExp(r'_\d\.(m4a|wav)$'), '_1');
      expect(credits.contains(file) || credits.contains(group), isTrue,
          reason: '$file has no credit');
    }
  });

  test('Out of the box: rain music, quietly; pencil; interface sounds low',
      () async {
    expect(sound.tracks.last, ('music_rain.m4a', SoundLevel.low.musicVolume));
    final settings = await SoundSettings.open();
    expect(settings.pen, PenSound.pencil);
    expect(settings.effects, SoundLevel.low);
  });

  test('Writing: the pen as letters come, the eraser as they go', () {
    AppSound.instance.typed('', 'H');
    later();
    AppSound.instance.typed('H', '');
    expect(sound.effects, hasLength(2));
    expect(sound.effects[0].$1, matches(RegExp(r'^pen_pencil_[1-4]\.wav$')));
    expect(
        sound.effects[0].$2,
        inInclusiveRange(
            .8 * SoundLevel.low.effectsVolume, SoundLevel.low.effectsVolume));
    expect(sound.effects[1].$1, matches(RegExp(r'^erase_[12]\.wav$')));
  });

  test('Fast typing is a run of strokes, not a rattle', () {
    for (var i = 0; i < 10; i++) {
      AppSound.instance.typed('a' * i, 'a' * (i + 1));
      now = now.add(const Duration(milliseconds: 20));
    }
    // 200 ms of typing, a stroke at most every 70 ms.
    expect(sound.effects.length, inInclusiveRange(2, 3));
  });

  test('The chosen pen is heard; off is silent', () async {
    final settings = await SoundSettings.open();
    await settings.savePen(PenSound.fountain);
    await AppSound.instance.refresh();
    AppSound.instance.typed('', 'a');
    expect(sound.effects.single.$1, startsWith('pen_fountain_'));

    await settings.saveEffects(SoundLevel.off);
    await AppSound.instance.refresh();
    later();
    AppSound.instance.typed('a', 'ab');
    AppSound.instance.play(SoundCue.pageTurn);
    expect(sound.effects, hasLength(1));
  });

  test('Music follows the settings and pauses while the app is away', () async {
    final settings = await SoundSettings.open();
    await settings.saveMusic(MusicTrack.piano);
    await settings.saveMusicLevel(SoundLevel.high);
    await pumpEventQueue();
    expect(sound.tracks.last, ('music_piano.m4a', SoundLevel.high.musicVolume));

    AppSound.instance.didChangeAppLifecycleState(AppLifecycleState.paused);
    expect(sound.pauses, 1);
    AppSound.instance.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await pumpEventQueue();
    expect(sound.tracks.last.$1, 'music_piano.m4a');

    await settings.saveMusic(MusicTrack.off);
    await pumpEventQueue();
    expect(sound.tracks.last.$1, isNull);
  });

  testWidgets('The editor: the pen while writing, a page turned on reopening',
      (tester) async {
    await tester.pumpWidget(
        MaterialApp(theme: AppTheme.light, home: const WriteJournalScreen()));
    await tester.enterText(find.byType(TextField), 'Một ngày');
    expect(sound.effects.single.$1, startsWith('pen_pencil_'));

    // Closed; then an old entry opened anew.
    await tester.pumpWidget(const SizedBox());
    // Closed; then an old entry opened anew.
    await tester.pumpWidget(const SizedBox());
    sound.effects.clear();
    final entry = JournalEntry(
      id: 'e1',
      createdAt: DateTime(2026, 10, 20),
      updatedAt: DateTime(2026, 10, 20),
      bodyVersion: 1,
      content: const JournalContent(body: 'Hôm qua'),
    );
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light, home: WriteJournalScreen(entry: entry)));
    expect(sound.effects.single.$1, startsWith('page_turn_'));
    // The text it opens with is not "written".
    expect(sound.effects, hasLength(1));
  });

  testWidgets('Any text field writes with the chosen pen', (tester) async {
    await SoundSettings.open().then((s) => s.savePen(PenSound.marker));
    await AppSound.instance.refresh();
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
            body: Column(children: [
      TextField(key: ValueKey('a')),
      TextField(key: ValueKey('b'), readOnly: true),
    ]))));
    await tester.enterText(find.byKey(const ValueKey('a')), 'Vy');
    expect(sound.effects.single.$1, startsWith('pen_marker_'));
    later();
    await tester.enterText(find.byKey(const ValueKey('a')), 'V');
    expect(sound.effects.last.$1, startsWith('erase_'));
    // Moving focus to a field that cannot be typed in is silent.
    later();
    sound.effects.clear();
    await tester.tap(find.byKey(const ValueKey('b')));
    await tester.pump();
    expect(sound.effects, isEmpty);
  });

  testWidgets('Profile: hear a pen or a music before keeping it',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(412, 915);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
        MaterialApp(theme: AppTheme.light, home: const ProfileScreen()));
    await tester.pumpAndSettle();
    Future<void> open(String item) async {
      final row = find.byKey(ValueKey('setting-item-$item'));
      await tester.scrollUntilVisible(row, 150,
          scrollable: find
              .descendant(
                  of: find.byType(ProfileScreen),
                  matching: find.byType(Scrollable))
              .first);
      await tester.pumpAndSettle();
      await tester.ensureVisible(row);
      await tester.pumpAndSettle();
      await tester.tap(row);
      await tester.pumpAndSettle();
    }

    Finder choice(String label) => find.descendant(
        of: find.byType(SettingEditor), matching: find.text(label));

    expect(
        tester
            .widget<Text>(
                find.byKey(const ValueKey('setting-value-background music')))
            .data,
        MusicTrack.rain.label);

    await open('pen sound');
    await tester.tap(choice(PenSound.marker.label));
    await tester.pump();
    expect(sound.effects.last.$1, startsWith('pen_marker_'));
    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();
    expect((await SoundSettings.open()).pen, PenSound.marker);

    await open('background music');
    await tester.tap(choice(MusicTrack.cafe.label));
    await tester.pump();
    expect(sound.tracks.last.$1, 'music_cafe.m4a');
    // Cancelled: the saved music comes back.
    await tester.tap(find.text('Hủy'));
    await tester.pumpAndSettle();
    expect(sound.tracks.last.$1, 'music_rain.m4a');
    expect((await SoundSettings.open()).music, MusicTrack.rain);
    expect(tester.takeException(), isNull);
  });
}
