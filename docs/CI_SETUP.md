# CI setup — Flutter and FastAPI

GitHub Actions checks Pull Requests and pushes to the current default
`setup/initial-import` branch (also `main` if the team renames it).
The workflows can also be run manually from the **Actions** tab.

## Workflows

| Workflow | Working directory | Checks |
| --- | --- | --- |
| `Flutter CI` | `mobile/` | Flutter stable setup, `flutter pub get`, `flutter analyze --no-pub`, `flutter test --no-pub --reporter expanded`, `flutter build bundle --no-pub` |
| `Backend CI` | `backend/` | Python 3.12 dependencies, `python -m pytest -q`, `alembic upgrade head`, `alembic check` |

### Supabase safety

Backend CI runs only with a local SQLite connection defined in the workflow.
`backend/tests/test_api.py` overrides that with an isolated temporary SQLite
file. Neither workflow reads Supabase passwords, uses repository secrets or
runs migrations against the shared Supabase project.

### Flutter version

Flutter CI installs the **latest stable** Flutter toolchain through
`subosito/flutter-action@v2`. The repository's `mobile/pubspec.lock` currently
needs Dart 3.11 or newer. The toolchain version is printed in the job log.
Once the first green build is obtained, the team should pin a compatible
Flutter version for reproducible runs.

### Android APK is not yet validated

The tracked `mobile/android/` directory has Gradle configuration but
**does not contain `android/gradlew` or the Gradle wrapper JAR**. The initial
Flutter CI therefore builds a Flutter bundle, **not** an Android APK; it does
not validate Android Gradle compilation or an emulator runtime.

Before adding `flutter build apk --debug` to CI, restore/check in a complete,
compatible Android Gradle wrapper and validate the Android Gradle Plugin,
Gradle version and Java toolchain using a developer's working Flutter setup.
Do not regenerate the Android project in CI just to hide missing tracked files.

## For Phúc (repository maintainer)

1. Open a PR against `setup/initial-import`; look at the **Checks** tab.
2. Wait for **Flutter analyze / test / bundle** and
   **FastAPI tests / Alembic** to finish successfully.
3. A failing test means the change needs investigation; the workflows
   do not automatically approve or merge a PR.
4. After the workflows are confirmed, configure a branch ruleset requiring
   a PR, approval and these two status checks before merge.
5. Keep running the real Android emulator smoke test on developer machines
   until an Android APK build and emulator tests are configured in CI.

The workflows intentionally do not trigger on every feature-branch push
without a PR, which avoids extra CI usage. Pull Requests against the
default branch trigger both workflows.
