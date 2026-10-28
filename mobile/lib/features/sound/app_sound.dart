import 'dart:async';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/widgets.dart';

import 'data/sound_settings.dart';

/// A moment the interface marks with a sound. Each has one or a few
/// recordings under `assets/sounds/`, picked at random so a repeated sound
/// does not repeat exactly. Sources and licences: `assets/sounds/CREDITS.md`.
enum SoundCue {
  /// Opening an entry written before; turning a page of an album.
  pageTurn(['page_turn_1.wav', 'page_turn_2.wav']),

  /// Opening the list of every entry.
  bookOpen(['book_open.wav']),

  /// Changing the paper; saving a quote.
  paper(['paper.wav']),

  /// An entry saved.
  penClick(['pen_click.wav']),

  /// Letters taken out while writing.
  erase(['erase_1.wav', 'erase_2.wav']);

  const SoundCue(this.assets);
  final List<String> assets;
}

/// Plays sound files; the app's is [AudioplayersBackend]. Tests use a
/// recording one ([AppSound.backend]).
abstract class SoundBackend {
  Future<void> effect(String asset, double volume);

  /// Loops [asset] at [volume], fading over from what was playing; null
  /// fades the music out.
  Future<void> music(String? asset, double volume);

  Future<void> pauseMusic();

  /// Loads [assets] ahead, so their first play is not late.
  Future<void> preload(Iterable<String> assets);
}

/// Silent: widget tests, where there is no audio plugin.
class SilentSoundBackend implements SoundBackend {
  const SilentSoundBackend();
  @override
  Future<void> effect(String asset, double volume) async {}
  @override
  Future<void> music(String? asset, double volume) async {}
  @override
  Future<void> pauseMusic() async {}
  @override
  Future<void> preload(Iterable<String> assets) async {}
}

/// Sound through `audioplayers`. Plays alongside other apps' audio (never
/// stopping the user's own music) and, on iOS, keeps quiet with the
/// silent switch: the ambient category, which mixes with others by itself
/// (the plugin refuses `mixWithOthers` on it).
class AudioplayersBackend implements SoundBackend {
  AudioplayersBackend() {
    unawaited(_guard(() => AudioPlayer.global.setAudioContext(AudioContext(
          iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
          android: const AudioContextAndroid(
            usageType: AndroidUsageType.media,
            contentType: AndroidContentType.sonification,
            audioFocus: AndroidAudioFocus.none,
          ),
        ))));
  }

  static const _fade = Duration(milliseconds: 1200);

  /// Players per short sound, used in turn: a quick stroke overlaps the
  /// last instead of cutting it.
  static const _voices = 2;

  /// Short sounds, loaded once and kept: on Android in low-latency mode
  /// (SoundPool, decoded ahead), so a stroke starts with the key press.
  final _rings = <String, Future<List<AudioPlayer>>>{};
  final _turn = <String, int>{};
  final _player = AudioPlayer();
  String? _playing;
  Timer? _fading;

  Future<List<AudioPlayer>> _ring(String asset) =>
      _rings[asset] ??= Future.wait([
        for (var i = 0; i < _voices; i++)
          () async {
            final player = AudioPlayer();
            await player.setPlayerMode(PlayerMode.lowLatency);
            await player.setReleaseMode(ReleaseMode.stop);
            await player.setSource(AssetSource('sounds/$asset'));
            return player;
          }(),
      ]);

  @override
  Future<void> preload(Iterable<String> assets) =>
      _guard(() async => Future.wait(assets.map(_ring)));

  @override
  Future<void> effect(String asset, double volume) => _guard(() async {
        final ring = await _ring(asset);
        final turn = _turn[asset] = ((_turn[asset] ?? -1) + 1) % ring.length;
        final player = ring[turn];
        // From the start, at this stroke's volume.
        await player.stop();
        await player.setVolume(volume);
        await player.resume();
      });

  @override
  Future<void> music(String? asset, double volume) => _guard(() async {
        if (asset == _playing && asset != null) {
          await _player.setVolume(volume);
          if (_player.state != PlayerState.playing) {
            await _player.resume();
          }
          return;
        }
        await _fadeTo(0);
        _playing = asset;
        if (asset == null) {
          await _player.stop();
          return;
        }
        await _player.setReleaseMode(ReleaseMode.loop);
        await _player.play(AssetSource('sounds/$asset'), volume: 0);
        await _fadeTo(volume);
      });

  @override
  Future<void> pauseMusic() => _guard(_player.pause);

  /// Ramps the music's volume to [target] over [_fade].
  Future<void> _fadeTo(double target) {
    _fading?.cancel();
    final from = _player.volume;
    if (from == target) return Future.value();
    const steps = 12;
    var step = 0;
    final done = Completer<void>();
    _fading = Timer.periodic(_fade ~/ steps, (timer) {
      step++;
      unawaited(_guard(
          () => _player.setVolume(from + (target - from) * step / steps)));
      if (step == steps) {
        timer.cancel();
        done.complete();
      }
    });
    return done.future;
  }

  /// A missing file or a device without audio never breaks the app.
  static Future<void> _guard(Future<void> Function() play) async {
    try {
      await play();
    } catch (error) {
      debugPrint('Sound skipped: $error');
    }
  }
}

/// The app's sound: the background music, kept to the settings and paused
/// while the app is away, and the interface's sounds.
class AppSound with WidgetsBindingObserver {
  AppSound._();

  static final instance = AppSound._();

  /// Where sound goes. Silent under widget tests (no audio plugin there);
  /// tests may set a recording backend.
  @visibleForTesting
  static SoundBackend? backend;

  SoundBackend get _backend =>
      backend ??= WidgetsBinding.instance is WidgetsFlutterBinding
          ? AudioplayersBackend()
          : const SilentSoundBackend();

  /// Pen strokes and erasing come at most this often, however fast the
  /// typing: a run of letters reads as writing, not as a rattle.
  static const strokeGap = Duration(milliseconds: 70);

  /// The time, for [strokeGap]; tests set their own.
  @visibleForTesting
  static DateTime Function() clock = DateTime.now;

  final _random = math.Random();
  SoundSettings? _settings;
  var _started = false;
  var _foreground = true;
  DateTime _lastStroke = DateTime.fromMillisecondsSinceEpoch(0);

  /// The field being typed in (the one holding focus) and its text as last
  /// heard.
  TextEditingController? _field;
  String _fieldText = '';
  FocusManager? _focus;

  /// Starts the music by the settings, and follows them and the app's
  /// lifecycle from then on; every text field in the app writes with the
  /// chosen pen. Once per run.
  Future<void> start() async {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    followTyping();
    SoundSettings.changes.addListener(refresh);
    final state = WidgetsBinding.instance.lifecycleState;
    _foreground = state == null || state == AppLifecycleState.resumed;
    await refresh();
  }

  /// Reads the settings again and puts the music back to them (e.g. after
  /// a preview).
  Future<void> refresh() async {
    try {
      _settings = await SoundSettings.open();
    } catch (_) {
      return;
    }
    await _syncMusic();
    await _preload();
  }

  /// The interface's sounds and the chosen pen's strokes, loaded ahead.
  Future<void> _preload() async {
    final settings = _settings;
    if (settings == null || settings.effects == SoundLevel.off) return;
    await _backend.preload([
      for (final cue in SoundCue.values) ...cue.assets,
      ..._strokes(settings.pen),
    ]);
  }

  /// The recorded strokes of [pen].
  static List<String> _strokes(PenSound pen) => [
        if (pen.prefix != null)
          for (var i = 1; i <= PenSound.strokes; i++) '${pen.prefix}_$i.wav',
      ];

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final foreground = state == AppLifecycleState.resumed;
    if (foreground == _foreground) return;
    _foreground = foreground;
    foreground ? unawaited(_syncMusic()) : unawaited(_backend.pauseMusic());
  }

  Future<void> _syncMusic() async {
    final settings = _settings;
    if (settings == null || !_foreground) return;
    await _backend.music(settings.music.asset, settings.musicLevel.musicVolume);
  }

  /// [cue], at the interface's volume; nothing when it is off.
  void play(SoundCue cue) {
    final level = _settings?.effects ?? SoundLevel.off;
    if (level == SoundLevel.off) return;
    final asset = cue.assets[_random.nextInt(cue.assets.length)];
    unawaited(_backend.effect(asset, level.effectsVolume));
  }

  /// Follows [FocusManager.instance] for [_followFocus]. Once is enough in
  /// the app; tests call it again, as their binding swaps the manager.
  @visibleForTesting
  void followTyping() {
    final focus = FocusManager.instance;
    if (identical(focus, _focus)) return;
    _focus?.removeListener(_followFocus);
    _focus = focus..addListener(_followFocus);
  }

  /// Listens to whichever text field has focus, anywhere in the app, so no
  /// screen has to wire its own: typing there is [typed]. Moving the cursor
  /// or selecting is silent; so is the text a field opens with.
  void _followFocus() {
    final context = FocusManager.instance.primaryFocus?.context;
    final editable = context?.findAncestorStateOfType<EditableTextState>();
    final field = editable == null || editable.widget.readOnly
        ? null
        : editable.widget.controller;
    if (identical(field, _field)) return;
    // Removing is allowed on a controller already disposed with its screen.
    _field?.removeListener(_fieldChanged);
    _field = field?..addListener(_fieldChanged);
    _fieldText = field?.text ?? '';
  }

  void _fieldChanged() {
    final text = _field?.text ?? '';
    if (text == _fieldText) return;
    typed(_fieldText, text);
    _fieldText = text;
  }

  /// Text in a writing field went from [before] to [after]: a stroke of the
  /// chosen pen as letters come, the eraser as they go.
  void typed(String before, String after) {
    final settings = _settings;
    if (settings == null || settings.effects == SoundLevel.off) return;
    if (before == after) return;
    final now = clock();
    if (now.difference(_lastStroke) < strokeGap) return;
    _lastStroke = now;
    if (after.length < before.length) {
      play(SoundCue.erase);
    } else {
      _stroke(settings.pen, settings.effects.effectsVolume);
    }
  }

  /// One stroke of [pen], to hear it before choosing it.
  void previewPen(PenSound pen) =>
      _stroke(pen, (_settings?.effects ?? SoundLevel.low).effectsVolume);

  /// [track] now, to hear it before choosing it; [refresh] puts the saved
  /// one back.
  Future<void> previewMusic(MusicTrack track) => _backend.music(
      track.asset, (_settings?.musicLevel ?? SoundLevel.low).musicVolume);

  void _stroke(PenSound pen, double volume) {
    final prefix = pen.prefix;
    if (prefix == null || volume == 0) return;
    final strokes = _strokes(pen);
    // A little louder or softer each time, as a hand writes.
    final jitter = .8 + _random.nextDouble() * .2;
    unawaited(_backend.effect(
        strokes[_random.nextInt(strokes.length)], volume * jitter));
  }
}
