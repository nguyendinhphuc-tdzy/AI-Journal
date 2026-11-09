import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Background music ("Nhạc nền" in the profile): a quiet loop, no lyrics.
enum MusicTrack {
  off('Tắt', null),
  rain('Mưa nhẹ', 'music_rain.m4a'),
  cafe('Quán cà phê', 'music_cafe.m4a'),
  piano('Piano nhẹ', 'music_piano.m4a');

  const MusicTrack(this.label, this.asset);
  final String label;

  /// Under `assets/sounds/`.
  final String? asset;
}

/// The pen heard while writing ("Tiếng bút"). Each has a few recorded
/// strokes, `<prefix>_1.wav` to `_<strokes>.wav`, played at random.
enum PenSound {
  off('Tắt', null),
  pencil('Bút chì', 'pen_pencil'),
  ballpoint('Bút bi', 'pen_ballpoint'),
  fountain('Bút mực', 'pen_fountain'),
  marker('Bút lông', 'pen_marker');

  const PenSound(this.label, this.prefix);
  final String label;
  final String? prefix;

  static const strokes = 4;
}

/// How loud, for the music and for the interface's sounds apart.
enum SoundLevel {
  off('Tắt', 0, 0),
  // The files are already quiet (music about -24 dBFS): these scale them.
  low('Nhỏ', .5, .5),
  medium('Vừa', .75, .75),
  high('Lớn', 1, 1);

  const SoundLevel(this.label, this.musicVolume, this.effectsVolume);
  final String label;
  final double musicVolume;
  final double effectsVolume;
}

/// The sound choices, on this device. Out of the box the music plays,
/// quietly, and the interface sounds are on, low.
class SoundSettings {
  SoundSettings._(this._prefs);

  static Future<SoundSettings> open() async =>
      SoundSettings._(await SharedPreferences.getInstance());

  /// Bumped after every saved change, so the sound follows at once.
  static final changes = ValueNotifier<int>(0);

  static const _musicKey = 'sound.music';
  static const _musicLevelKey = 'sound.musicLevel';
  static const _penKey = 'sound.pen';
  static const _effectsKey = 'sound.effects';

  final SharedPreferences _prefs;

  MusicTrack get music =>
      MusicTrack.values.asNameMap()[_prefs.getString(_musicKey)] ??
      MusicTrack.rain;

  SoundLevel get musicLevel => _level(_musicLevelKey) ?? SoundLevel.low;

  PenSound get pen =>
      PenSound.values.asNameMap()[_prefs.getString(_penKey)] ?? PenSound.pencil;

  SoundLevel get effects => _level(_effectsKey) ?? SoundLevel.low;

  SoundLevel? _level(String key) =>
      SoundLevel.values.asNameMap()[_prefs.getString(key)];

  Future<void> saveMusic(MusicTrack track) =>
      _save(_prefs.setString(_musicKey, track.name));

  Future<void> saveMusicLevel(SoundLevel level) =>
      _save(_prefs.setString(_musicLevelKey, level.name));

  Future<void> savePen(PenSound pen) =>
      _save(_prefs.setString(_penKey, pen.name));

  Future<void> saveEffects(SoundLevel level) =>
      _save(_prefs.setString(_effectsKey, level.name));

  Future<void> _save(Future<bool> result) async {
    if (!await result) throw StateError('Sound settings could not be saved');
    changes.value++;
  }
}
