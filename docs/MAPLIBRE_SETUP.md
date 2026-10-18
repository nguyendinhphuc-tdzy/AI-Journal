# MapLibre + OpenFreeMap setup — Flutter / AI-Journal

**Status:** installation guide; **not installed by B01**. **Flutter Explore/Map owner:** Trâm. **Backend owner:** Phúc.

## What does and does not require a key

- **Map rendering:** `maplibre_gl` with `https://tiles.openfreemap.org/styles/liberty` — no Google Maps API key, Google billing, or Google Android SHA-1 required.
- **Manual marker/drop pin:** MapLibre built-in map gestures and annotations; no location permission for a manually selected point.
- **Address/POI search:** MapLibre alone does not provide it. MVP proposes Geoapify from **FastAPI backend** (`/api/v1/geo/search`), with Geoapify key in untracked `backend/.env`. Test with mock results until B09.
- **Saved markers/notes:** call FastAPI endpoints only after B09/B10; Supabase PostgreSQL remains backend-only. Auth via Supabase Auth SDK is a separate B03 task.

## Repository/toolchain verification first

Default/base is `setup/initial-import`. Trâm's currently known existing feature branch is `feat/journal-inline-follow-up`, whose PR #6 may still be open. **Do not** mix unrelated MapLibre changes into active PR #6 without Phúc's approval. Only Phúc merges PRs. Never create extra branches without assignment, reset working changes, or force-push.

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
