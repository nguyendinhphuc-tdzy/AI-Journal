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

  /// Explore's old shared keys (no owner), which earlier builds used for
  /// guests: whatever is left there belongs to some past guest. Removed on
  /// entering and on leaving guest mode, so no guest sees another's pins.
  static const legacyKeys = ['explore.savedPlaces', 'explore.communityStops'];

  final SharedPreferences _preferences;

  bool get isActive => _preferences.getBool(_activeKey) ?? false;

  Future<void> enter() async {
    await _removeLegacy();
    if (!await _preferences.setBool(_activeKey, true)) {
      throw StateError('Could not start local guest mode');
    }
  }

  Future<void> _removeLegacy() async {
    for (final key in legacyKeys) {
      if (_preferences.containsKey(key) && !await _preferences.remove(key)) {
        throw StateError('Could not remove local guest data');
      }
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
          key.startsWith('account.$userId.onboarding.') ||
          // Saved quotes (and any analyses) kept for the guest.
          key.startsWith('account.$userId.journal.') ||
          key == 'study.progress.$userId' ||
          key.startsWith('album.pin.$userId.')) &&
          !await _preferences.remove(key)) {
        throw StateError('Could not remove local guest data');
      }
    }
    await _removeLegacy();
    await deactivate();
  }
}
