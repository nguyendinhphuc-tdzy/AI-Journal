/// What this build offers, so onboarding copy never promises more than the
/// app does. Flip a flag when the module ships (or is pulled).
abstract final class BuildFeatures {
  /// Home shows a writing prompt (local sample prompts until the
  /// daily-prompt API is connected).
  static const writingPrompts = true;

  /// Journal → "Go Deeper" → AI Reflection exists; it still shows a sample
  /// reflection until `POST /api/v1/ai/reflection` is wired.
  static const aiReflection = true;

  /// Album is still an empty screen; shown in OB05 by product decision
  /// (16/10/2026) ahead of the module.
  static const album = true;

  static const study = true;

  /// Explore / places is still an empty screen.
  static const places = false;
}
