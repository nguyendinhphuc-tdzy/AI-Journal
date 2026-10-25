import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local writing preferences, separate from onboarding progress and journals.
class WritingPreferences {
  WritingPreferences._(this._prefs);

  static Future<WritingPreferences> open() async =>
      WritingPreferences._(await SharedPreferences.getInstance());

  final SharedPreferences _prefs;
  bool get paper => _prefs.getBool('writing.paper') ?? true;
  bool get haptic => _prefs.getBool('writing.haptic') ?? false;
  double get textSize {
    final size = _prefs.getDouble('writing.textSize');
    return sizes.contains(size) ? size! : 16;
  }

  static const sizes = [14.0, 16.0, 20.0, 24.0];

  Future<void> _check(Future<bool> result) async {
    if (!await result) throw StateError('Preferences could not be saved');
  }

  Future<void> savePaper(bool value) =>
      _check(_prefs.setBool('writing.paper', value));
  Future<void> saveHaptic(bool value) =>
      _check(_prefs.setBool('writing.haptic', value));
  Future<void> saveTextSize(double value) {
    if (!sizes.contains(value)) throw ArgumentError.value(value);
    return _check(_prefs.setDouble('writing.textSize', value));
  }

  Future<void> feedback() async {
    if (!haptic) return;
    try {
      await HapticFeedback.selectionClick();
    } on PlatformException {
      // Unsupported devices must still allow writing and changing settings.
    } on MissingPluginException {
      // No native haptic implementation on this platform.
    }
  }
}
