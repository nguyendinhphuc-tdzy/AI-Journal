import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'firebase_options.dart';

/// The device's push service (Firebase Cloud Messaging on Android). Tests
/// use their own.
abstract interface class PushPlatform {
  /// Ready to use; false where push is not available (no Firebase here).
  Future<bool> start();

  /// Asks to show notifications (the system prompt on Android 13+, once).
  Future<bool> requestPermission();

  /// This installation's push token; null when there is none.
  Future<String?> token();
  Stream<String> get tokenRefresh;

  /// The data of the notification that opened the app from closed.
  Future<Map<String, Object?>?> openedAtLaunch();

  /// The data of a notification tapped while the app was in the background.
  Stream<Map<String, Object?>> get opened;

  /// The data of a notification that arrived while the app was open (the
  /// system shows nothing then).
  Stream<Map<String, Object?>> get foreground;
}

class FirebasePushPlatform implements PushPlatform {
  const FirebasePushPlatform();

  FirebaseMessaging get _messaging => FirebaseMessaging.instance;

  @override
  Future<bool> start() async {
    if (!Platform.isAndroid) return false;
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(options: AppFirebaseOptions.android);
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> requestPermission() async {
    final settings = await _messaging.requestPermission();
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  // The registration token (not the newer installation id from register()):
  // the backend sends with FCM HTTP v1 `message.token`, which takes it.
  @override
  // ignore: deprecated_member_use
  Future<String?> token() => _messaging.getToken();

  @override
  // ignore: deprecated_member_use
  Stream<String> get tokenRefresh => _messaging.onTokenRefresh;

  @override
  Future<Map<String, Object?>?> openedAtLaunch() async =>
      (await _messaging.getInitialMessage())?.data;

  @override
  Stream<Map<String, Object?>> get opened =>
      FirebaseMessaging.onMessageOpenedApp.map((m) => m.data);

  @override
  Stream<Map<String, Object?>> get foreground =>
      FirebaseMessaging.onMessage.map((m) => m.data);
}
