# Mobile assets — integration notes

- `assets/images/`: Home and Journal backgrounds plus Nudaeng GIFs from Trâm.
- `assets/Deimage/` and `assets/NudaenggifDe/`: Study artwork and GIFs from Vy.
- `assets/icons/` and `assets/mascot/`: reserved/shared graphic folders.
- `assets/fonts/Nunito.ttf` and `assets/fonts/BeVietnamPro-*.ttf`: fonts from Study PR #2.

The source of truth for registered assets and fonts is `mobile/pubspec.yaml`.
The Flutter font family identifiers are `Nunito` and `BeVietnamPro`.
After changing asset registrations, run `flutter pub get` and restart the app.
