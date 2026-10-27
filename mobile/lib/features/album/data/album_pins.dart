import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Each locked album's 4-digit PIN. Only a salted, stretched hash is kept,
/// never the PIN. The lock only gates opening the album in the app; it does
/// not encrypt the album, so this is not a vault.
abstract interface class AlbumPins {
  static const length = 4;

  Future<bool> has(String albumId);

  /// Whether [pin] is [albumId]'s. False when it has none.
  Future<bool> check(String albumId, String pin);

  /// Keeps [pin] for [albumId], replacing any; null forgets it.
  Future<void> set(String albumId, String? pin);
}

/// The hash kept for a PIN: "salt:hash", the hash repeated [rounds] times
/// so guessing every PIN takes a moment rather than an instant.
String albumPinHash(String pin, String salt, {int rounds = 4000}) {
  List<int> digest = utf8.encode('$salt:$pin');
  for (var i = 0; i < rounds; i++) {
    digest = sha256.convert(digest).bytes;
  }
  return '$salt:${base64Url.encode(digest)}';
}

String _salt() {
  final random = Random.secure();
  return base64Url.encode([for (var i = 0; i < 16; i++) random.nextInt(256)]);
}

bool _matches(String kept, String pin) {
  final salt = kept.split(':').first;
  final candidate = albumPinHash(pin, salt);
  // The same time whatever matches, so the time says nothing.
  if (candidate.length != kept.length) return false;
  var diff = 0;
  for (var i = 0; i < kept.length; i++) {
    diff |= kept.codeUnitAt(i) ^ candidate.codeUnitAt(i);
  }
  return diff == 0;
}

/// On this device, via shared_preferences.
class LocalAlbumPins implements AlbumPins {
  const LocalAlbumPins({this.userId});

  /// Signed-in accounts never read another account's PIN on this device.
  /// The null account preserves pre-auth demo compatibility.
  final String? userId;
  String _key(String albumId) => userId == null
      ? 'album.pin.$albumId'
      : 'album.pin.$userId.$albumId';

  @override
  Future<bool> has(String albumId) async =>
      (await SharedPreferences.getInstance()).containsKey(_key(albumId));

  @override
  Future<bool> check(String albumId, String pin) async {
    final kept =
        (await SharedPreferences.getInstance()).getString(_key(albumId));
    return kept != null && _matches(kept, pin);
  }

  @override
  Future<void> set(String albumId, String? pin) async {
    final prefs = await SharedPreferences.getInstance();
    final ok = pin == null
        ? await prefs.remove(_key(albumId))
        : await prefs.setString(_key(albumId), albumPinHash(pin, _salt()));
    if (!ok) throw StateError('Could not keep the album PIN');
  }
}

/// In memory only, for tests.
class InMemoryAlbumPins implements AlbumPins {
  final _kept = <String, String>{};

  @override
  Future<bool> has(String albumId) async => _kept.containsKey(albumId);

  @override
  Future<bool> check(String albumId, String pin) async {
    final kept = _kept[albumId];
    return kept != null && _matches(kept, pin);
  }

  @override
  Future<void> set(String albumId, String? pin) async {
    if (pin == null) {
      _kept.remove(albumId);
    } else {
      _kept[albumId] = albumPinHash(pin, _salt());
    }
  }
}
