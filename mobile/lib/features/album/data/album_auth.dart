import 'package:local_auth/local_auth.dart';

import 'album_unlocks.dart';

/// Outcome of asking the device to confirm it is the owner.
enum AlbumAuthResult {
  success,
  canceled,
  failed,

  /// No screen lock, fingerprint or face set up on the device.
  notSetUp,

  /// The device or platform cannot authenticate at all.
  notSupported,
}

/// Device authentication for locked albums. The lock only gates opening an
/// album in the app; it does not encrypt anything.
abstract interface class AlbumAuth {
  /// Whether this device can authenticate the user at all. False whenever it
  /// cannot be determined: a lock that cannot be opened must not be offered.
  Future<bool> isSupported();

  Future<AlbumAuthResult> authenticate(String reason);
}

/// Fingerprint, face or the screen lock (PIN, pattern, password), through the
/// operating system's own prompt.
class DeviceAlbumAuth implements AlbumAuth {
  DeviceAlbumAuth([LocalAuthentication? auth])
      : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  @override
  Future<bool> isSupported() async {
    try {
      return await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<AlbumAuthResult> authenticate(String reason) async {
    try {
      // The prompt pauses the app; that is not leaving it.
      final ok = await AlbumUnlocks.instance.duringSystemPrompt(() =>
          _auth.authenticate(
              localizedReason: reason, persistAcrossBackgrounding: true));
      return ok ? AlbumAuthResult.success : AlbumAuthResult.failed;
    } on LocalAuthException catch (error) {
      return switch (error.code) {
        LocalAuthExceptionCode.userCanceled ||
        LocalAuthExceptionCode.systemCanceled ||
        LocalAuthExceptionCode.timeout =>
          AlbumAuthResult.canceled,
        LocalAuthExceptionCode.noCredentialsSet ||
        LocalAuthExceptionCode.noBiometricsEnrolled =>
          AlbumAuthResult.notSetUp,
        LocalAuthExceptionCode.noBiometricHardware ||
        LocalAuthExceptionCode.uiUnavailable =>
          AlbumAuthResult.notSupported,
        _ => AlbumAuthResult.failed,
      };
    } catch (_) {
      return AlbumAuthResult.notSupported;
    }
  }
}
