import 'package:flutter/widgets.dart';

/// Outcome of asking for an album's PIN.
enum AlbumAuthResult {
  success,

  /// Closed without entering the PIN.
  canceled,

  /// Could not be checked (e.g. the PIN store could not be read).
  failed,
}

/// Locked albums open with a 4-digit PIN of their own, chosen when the lock
/// is turned on (A02, A03) and asked for to open the album (A04) or to turn
/// the lock off. Not the device's screen lock. The lock only gates opening
/// an album in the app; it does not encrypt anything.
///
/// The app's is `PinAlbumAuth` (the PIN pad sheet over [AlbumPins]); tests
/// pass their own.
abstract interface class AlbumAuth {
  /// Asks for a new PIN, entered twice. Null when the user gave up.
  Future<String?> choosePin(BuildContext context);

  /// Asks for [albumId]'s PIN; [reason] says what it opens.
  Future<AlbumAuthResult> verify(BuildContext context, String albumId,
      {required String reason});

  /// Keeps [pin] as [albumId]'s, replacing any; null forgets it.
  Future<void> setPin(String albumId, String? pin);
}
