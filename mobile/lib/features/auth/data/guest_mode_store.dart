import 'package:shared_preferences/shared_preferences.dart';

/// Guest data only lives in this app sandbox. There is no anonymous Supabase
/// account, session, upload or cloud synchronization for this mode.
class GuestModeStore {
  GuestModeStore._(this._preferences);

  static Future<GuestModeStore> open() async =>
      GuestModeStore._(await SharedPreferences.getInstance());

  static const userId = 'local-guest';
  static const _activeKey = 'auth.local_guest.active';
  static const _guestDataPrefix = 'users.$userId.';

  final SharedPreferences _preferences;

  bool get isActive => _preferences.getBool(_activeKey) ?? false;

  Future<void> enter() async {
    if (!await _preferences.setBool(_activeKey, true)) {
      throw StateError('Could not start local guest mode');
    }
  }

  /// Used when a legitimate Supabase login supersedes an old guest flag.
  Future<void> deactivate() async {
    if (!await _preferences.remove(_activeKey)) {
      throw StateError('Could not clear local guest mode');
    }
  }

  /// Explicitly leaving guest mode discards its local journal, drafts and
  /// onboarding progress; no guest data is moved into a real account.
  Future<void> leaveAndDiscard() async {
    for (final key in _preferences.getKeys().toList()) {
      if ((key.startsWith(_guestDataPrefix) ||
          key.startsWith('account.$userId.onboarding.')) &&
          !await _preferences.remove(key)) {
        throw StateError('Could not remove local guest data');
      }
    }
    await deactivate();
  }
}
