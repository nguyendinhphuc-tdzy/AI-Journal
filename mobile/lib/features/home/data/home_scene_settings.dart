import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The scene at the top of Home's reflection card ("Khung cảnh" in the
/// profile). Add a scene here and in `HomeSceneHero` to offer it.
enum HomeScene {
  street('Phố Việt Nam'),
  plain('Mint trơn');

  const HomeScene(this.label);
  final String label;
}

/// What falls over the scene ("Giao diện động" in the profile). Only inside
/// the scene; off with reduced motion.
enum SceneEffect {
  none('Tắt'),
  leaves('Lá rơi'),
  rain('Mưa'),
  snow('Tuyết');

  const SceneEffect(this.label);
  final String label;
}

/// The two choices, on this device.
class HomeSceneSettings {
  HomeSceneSettings._(this._prefs);

  static Future<HomeSceneSettings> open() async =>
      HomeSceneSettings._(await SharedPreferences.getInstance());

  /// Bumped after every saved change, so Home updates at once.
  static final changes = ValueNotifier<int>(0);

  static const _sceneKey = 'home.scene';
  static const _effectKey = 'home.effect';

  final SharedPreferences _prefs;

  HomeScene get scene =>
      HomeScene.values.asNameMap()[_prefs.getString(_sceneKey)] ??
      HomeScene.street;

  SceneEffect get effect =>
      SceneEffect.values.asNameMap()[_prefs.getString(_effectKey)] ??
      SceneEffect.none;

  Future<void> saveScene(HomeScene scene) =>
      _save(_prefs.setString(_sceneKey, scene.name));

  Future<void> saveEffect(SceneEffect effect) =>
      _save(_prefs.setString(_effectKey, effect.name));

  Future<void> _save(Future<bool> result) async {
    if (!await result) throw StateError('Scene settings could not be saved');
    changes.value++;
  }
}
