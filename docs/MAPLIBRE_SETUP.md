# MapLibre + OpenFreeMap setup — Flutter / AI-Journal

**Status:** Phase A implemented in PR #13 with `maplibre_gl 0.27.1`; live backend integration remains deferred. **Flutter Explore/Map owner:** Trâm. **Backend owner:** Phúc.

## What does and does not require a key

- **Map rendering:** `maplibre_gl` with `https://tiles.openfreemap.org/styles/liberty` — no Google Maps API key, Google billing, or Google Android SHA-1 required.
- **Map look:** Explore and the place picker use the app's own styles (`features/explore/presentation/map_style.dart`: one light style in the app palette at any hour; the night style was dropped as hard to read) on OpenFreeMap's `planet` tiles and fonts, instead of the `liberty`/`dark` style URLs.
- **Manual marker/drop pin:** MapLibre built-in map gestures and annotations; no location permission for a manually selected point.
- **Address/POI search:** MapLibre alone does not provide it. MVP proposes Geoapify from **FastAPI backend** (`/api/v1/geo/search`), with Geoapify key in untracked `backend/.env`. Test with mock results until B09.
- **Saved markers/notes:** call FastAPI endpoints only after B09/B10; Supabase PostgreSQL remains backend-only. Auth via Supabase Auth SDK is a separate B03 task.

## Repository/toolchain verification first

Default/base is `setup/initial-import`. The approved existing branch for this task is `feat/explore-map-share`, updating PR #13. Only Phúc reviews and merges PRs; do not create another branch or PR.

Run in Windows PowerShell from repository root:

```powershell
git branch --show-current
git status
flutter doctor -v
flutter --version
java -version
flutter devices
```

As of the reviewed base: `mobile/android/app/build.gradle.kts` has Android namespace/package `com.example.ai_diary` and Java/Kotlin target 17; `settings.gradle.kts` uses Android Gradle Plugin 9.1.0, Kotlin 2.4.0; Gradle distribution is 9.3.1. Verify installed Flutter, actual **Gradle JDK** and compatibility with the chosen package. `maplibre_gl` 0.27.x documents Flutter >= 3.29 and JDK 21 to build Android; JDK running Gradle can differ from Android Java target. Do not randomly upgrade plugin/toolchain versions if an Android build fails.

## Install on approved branch only

```powershell
cd mobile
flutter pub add maplibre_gl
flutter pub get
flutter analyze
flutter test
flutter devices
flutter run
```

Retain both `mobile/pubspec.yaml` and `mobile/pubspec.lock` changes when committing an approved task.

## Minimal Explore render example

Use in `mobile/lib/features/explore/presentation/explore_screen.dart` for an initial non-persisted render:

```dart
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

class ExploreScreen extends StatelessWidget {
  const ExploreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: MapLibreMap(
        styleString: 'https://tiles.openfreemap.org/styles/liberty',
        initialCameraPosition: const CameraPosition(
          target: LatLng(10.8231, 106.6297),
          zoom: 12,
        ),
      ),
    );
  }
}
```

Use the installed package's supported constructor/API if the version differs. Add `onMapLongClick` + annotations using the currently installed package API to drop a local pin. Only persist after real API contract B09/B10 exists.

## Android and network considerations

- The existing **debug** manifest declares `android.permission.INTERNET`. Verify a release manifest includes the permission if release builds need network access.
- Do not add Google Maps SDK metadata or Android API keys; remove any obsolete key integration for this task only if explicitly approved.
- Do not request foreground/background GPS permissions for basic pan/zoom/drop pin.
- Preserve map-data provider attribution and follow OpenFreeMap usage and third-party provider terms; service availability/limits may change.
- Verify emulator map rendering, panning, zoom, pin selection, tab switches, offline/failure behavior and that no unrelated screen regressed. Inspect known baseline Study asset test failures separately.

## PR hygiene

No branch creation, push, merge, or release from this setup guide alone. Before an approved push, compare changed files, inspect `git diff`, run tests and ensure the head branch has only intended changes. Phúc is the only merger.

Official references:
- https://pub.dev/packages/maplibre_gl
- https://maplibre.org/maplibre-native/docs/book/flutter/
- https://openfreemap.org/

## Phase A implementation (PR #13)

- Existing branch: `feat/explore-map-share`. No Google Maps SDK/key integration remains. The old Google Maps setup document has been removed. An old key in ignored local.properties is unused; this task does not read or modify local secrets.
- Explore uses the Liberty OpenFreeMap style, native pan/zoom, tap/long-press temporary pins, Nudaeng PNG annotations and dismissible place details. Pins are temporary, not persisted.
- `ExplorePlacesRepository` is the replacement boundary for a future authenticated FastAPI adapter. The current implementation searches three fixed demo places with a 350 ms debounce; selecting a result moves the camera. Category filters operate only on demo data. No user data or backend requests are involved.
- Album Share still opens its existing mock dialog. It does not publish or save anything.
- A 20-second initial style/marker timeout offers Retry map without deleting a temporary pin. There is no offline tile package, and this plugin exposes no per-tile error callback in the widget API; a failed tile request after style load may still leave gaps until connectivity returns/retry.
- Native map attribution remains enabled and visible at the bottom right.
- Installed environment: Flutter 3.47.2 / Dart 3.13.2, AGP 9.1.0, Gradle 9.3.1, Android Studio JDK 25. App Java target remains 17; MapLibre compiles its plugin at Java 21. No toolchain upgrade was made.
- Phase B is not implemented: production JWT/Auth, server persistence, notes/links, provider search and its 429/503 handling. Backend source being merged does not imply Supabase migrations are deployed. Do not run migrations as part of this Flutter work.
- Widget tests replace only the native platform view. They cannot prove tile loading or native gestures; validate those on Android as well.
- Android uses `MapLibreMap.useHybridComposition = true` (TextureView in this package) so Flutter overlays and tab clipping compose with the native map.

### Validation on 2026-10-18

- `flutter pub get` and `flutter analyze`: passed.
- Focused Explore and Journal tests: 8 passed. Full `flutter test`: 267 passed, 11 failed; the same pre-existing Study artwork/motion/screen asset failures reproduced on the baseline. No Study tests or implementation were changed to hide failures.
- `flutter build apk --debug --no-pub` and `flutter run -d emulator-5554 --no-pub --no-resident`: passed on Android 17/API 37. Native checks confirmed map tiles, panning, Nudaeng markers, temporary pin selection, Home/Study/Album/Explore navigation and Album Share dialog.
- Offline recovery, pinch zoom and iOS rendering were not manually verified. Initial map loading has a timeout/retry UI, not guaranteed offline map support.
- Backend, onboarding, Study, Streak and main.dart match the integrated base commit `975380c`. Journal conflict resolution preserves entry IDs and saves follow-up text only after Finish entry confirmation.
