import 'package:flutter/widgets.dart';

/// OB02 nickname rules. Any text the keyboard can enter is allowed: Vietnamese
/// marks, emoji and other Unicode stay as typed. Length counts user-perceived
/// characters (grapheme clusters), so a letter with its tone mark or one
/// emoji counts once and is never split.
abstract final class Nickname {
  static const maxLength = 30;

  /// Trimmed nickname, or null when empty: later copy then says "bạn".
  static String? normalize(String raw) {
    final value = raw.trim();
    return value.isEmpty ? null : value;
  }

  static int length(String raw) => raw.trim().characters.length;

  static bool isTooLong(String raw) => length(raw) > maxLength;
}
