import 'package:firebase_core/firebase_core.dart';

/// The Android app's public Firebase configuration, the same values as
/// `android/app/google-services.json` (not secrets: no service account or
/// private key). Kept here so the app needs no Google Services Gradle
/// plugin. Regenerate both together if the Firebase app changes.
abstract final class AppFirebaseOptions {
  static const android = FirebaseOptions(
    apiKey: 'AIzaSyDXyXfr7le8EAWMm-Aainp37bEIm4yKTGM',
    appId: '1:181460796085:android:028352368791b3cb6bb4fc',
    messagingSenderId: '181460796085',
    projectId: 'ai-journal-dev-a084b',
    storageBucket: 'ai-journal-dev-a084b.firebasestorage.app',
  );
}
