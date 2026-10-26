class AppConfig {
  AppConfig._();

  // Android emulator -> host machine. For an Android phone, use
  // --dart-define=API_BASE_URL=http://<LAN_IP>:8000/api/v1 on a trusted LAN.
  // HTTPS is required for real deployments and real diary content.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000/api/v1',
  );
}
