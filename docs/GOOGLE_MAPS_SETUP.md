# Google Maps setup

Explore uses `google_maps_flutter` with three sample locations near central Ho Chi Minh City. Search and the hamburger menu filter these local samples, not Google Places. The custom marker combines a static frame from `docsach.gif` with a pink heart pin; native bitmap markers do not animate GIFs. Album's Share dialog is still a mock preview and does not publish data.

## API keys

1. Create/select a Google Cloud project, attach billing, and enable **Maps SDK for Android** and/or **Maps SDK for iOS**.
2. In APIs & Services > Credentials, create separate API keys for Android and iOS.
3. Restrict the Android key to the app package (`com.example.ai_diary` currently) and signing certificate SHA-1; restrict its API access to Maps SDK for Android. Add both debug and release certificate fingerprints as appropriate. Run `android/gradlew.bat signingReport` from `mobile` to see signing fingerprints.
4. Restrict the iOS key to the actual bundle identifier and Maps SDK for iOS.

Official instructions: https://developers.google.com/maps/flutter-package/config
Key restrictions: https://developers.google.com/maps/api-security-best-practices
Plugin platform requirements: https://pub.dev/packages/google_maps_flutter

## Android (configured in this repository)

Append this line to **mobile/android/local.properties**, keeping its existing SDK paths:

```properties
MAPS_API_KEY=YOUR_ANDROID_API_KEY
```

This file is already gitignored. `android/app/build.gradle.kts` supplies the value to the `com.google.android.geo.API_KEY` manifest metadata. Internet permission is configured; location permission is not needed because Explore does not request the user's location. The installed plugin requires Android API 24+, which is set in Gradle.

Run from `mobile`:

```sh
flutter pub get
flutter run
```

Use an Android device or emulator with Google Play services. Fully rebuild after changing the key (hot reload is insufficient). A placeholder key allows compilation but cannot load authenticated Google map tiles. The key is packaged in the native app, so application/API restrictions are required; keeping it outside Git does not make it a backend secret.

## iOS (not scaffolded in this repository)

On macOS, create the iOS platform if required (`flutter create --platforms=ios .` from `mobile`, review generated changes). For the currently resolved plugin, use iOS 15+ and configure the deployment target/Podfile consistently. Follow the installed plugin's iOS setup if adopting a newer SDK implementation.

In `ios/Runner/AppDelegate.swift`:

```swift
import GoogleMaps
```

Inside `application(_:didFinishLaunchingWithOptions:)`, before returning/calling the superclass:

```swift
GMSServices.provideAPIKey("YOUR_IOS_API_KEY")
```

Keep the existing Flutter plugin registration code. For shared source, load the key from a locally configured Xcode build setting/Info.plist entry rather than committing the literal key. Build and validate on macOS/Xcode; this Windows workspace cannot run iOS builds.

## Verification

Widget tests substitute the native map view via `test/flutter_test_config.dart`. They cover Flutter UI, filtering, marker data and Album-to-Explore navigation; they do not verify map tile loading, billing or key authorization. Those checks require a configured key on a real device/emulator.
