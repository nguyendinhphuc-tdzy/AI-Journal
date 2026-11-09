import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/network/api_client.dart';

/// Tells the server which push token reaches this installation for the
/// signed-in account (`POST /devices`), and stops it before signing out
/// (`DELETE /devices`). The token itself is never logged or shown.
class DeviceRegistration {
  DeviceRegistration(this.api, {this.platform = 'android'});

  final ApiClient api;
  final String platform;

  static const _key = 'push.installationId';

  /// One id per installation, made once and kept: the server moves a
  /// rotated token of the same installation instead of adding another.
  Future<String> installationId() async {
    final prefs = await SharedPreferences.getInstance();
    final kept = prefs.getString(_key);
    if (kept != null && kept.length >= 8) return kept;
    final random = Random.secure();
    final id = List.generate(
        16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
    await prefs.setString(_key, id);
    return id;
  }

  Future<void> register(String token) async => api.postJson(
      '/devices',
      {
        'token': token,
        'installation_id': await installationId(),
        'platform': platform,
      },
      requireAuth: true);

  Future<void> unregister(String token) =>
      api.deleteJson('/devices', {'token': token}, requireAuth: true);
}
