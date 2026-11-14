class AppConfig {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://multitenant-service.onboarding.smilego.io/api',
  );

  static const String tenant = String.fromEnvironment(
    'TENANT',
    defaultValue: 'parcelaamericanas',
  );

  static const String origem = 'CAPANA';
}
