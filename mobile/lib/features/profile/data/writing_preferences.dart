import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The paper a journal entry is written on.
enum JournalPaper {
  plain('Giấy trơn', null),
  ruled('Giấy kẻ', 'assets/images/journal-paper-ruled.jpg'),
  doPaper('Giấy dó', 'assets/images/journal-paper-do.jpg'),
  aged('Giấy cũ', 'assets/images/journal-paper-aged.jpg');

  const JournalPaper(this.label, this.asset);

  final String label;

  /// The sheet's texture; none for plain paper. The ruled sheet has no
  /// printed lines: the editor draws them on the text's line height
  /// (`tool/build_journal_papers.py`).
  final String? asset;
}

/// Local writing preferences, separate from onboarding progress and journals.
class WritingPreferences {
  WritingPreferences._(this._prefs);

  static Future<WritingPreferences> open() async =>
      WritingPreferences._(await SharedPreferences.getInstance());

  final SharedPreferences _prefs;

  /// The chosen paper. Before there was a choice, paper was on or off:
  /// off reads as plain, on as Giấy dó (which replaced the old texture).
  JournalPaper get paper =>
      JournalPaper.values.asNameMap()[_prefs.getString('writing.paperStyle')] ??
      (_prefs.getBool('writing.paper') == false
          ? JournalPaper.plain
          : JournalPaper.doPaper);
  bool get haptic => _prefs.getBool('writing.haptic') ?? false;
  double get textSize {
    final size = _prefs.getDouble('writing.textSize');
    return sizes.contains(size) ? size! : 16;
  }

  static const sizes = [14.0, 16.0, 20.0, 24.0];

  Future<void> _check(Future<bool> result) async {
    if (!await result) throw StateError('Preferences could not be saved');
  }

  Future<void> savePaper(JournalPaper value) =>
      _check(_prefs.setString('writing.paperStyle', value.name));
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
