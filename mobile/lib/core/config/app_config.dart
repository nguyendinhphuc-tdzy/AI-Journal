class AppConfig {
  AppConfig._();

  // Android Emulator localhost proxy by default. For physical Android
  // override with --dart-define=API_BASE_URL=https://YOUR_HOST/api/v1.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000/api/v1',
  );

  static const bool authEnabled = bool.fromEnvironment('AUTH_ENABLED');
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabasePublishableKey =
      String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

  static bool get supabaseConfigured =>
      supabaseUrl.trim().isNotEmpty && supabasePublishableKey.trim().isNotEmpty;

  static const bool phoneOtpEnabled =
      bool.fromEnvironment('PHONE_OTP_ENABLED');
  static const bool googleOAuthEnabled =
      bool.fromEnvironment('GOOGLE_OAUTH_ENABLED');
  static const bool facebookOAuthEnabled =
      bool.fromEnvironment('FACEBOOK_OAUTH_ENABLED');
  // Cloud journal requires backend migration 20261026_08 and an authenticated
  // Supabase session. Never enabled by default for existing device journals.
  static const bool journalCloudEnabled =
      bool.fromEnvironment('JOURNAL_CLOUD_ENABLED');
  static const String oauthRedirectUrl = 'aijournal://auth-callback/';
}
