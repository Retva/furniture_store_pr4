class AppConfig {
  const AppConfig._();

  /// Адрес API. В коде нет ни одного другого упоминания адреса сервера.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8080/api',
  );

  static const String dataSource = String.fromEnvironment(
    'DATA_SOURCE',
    defaultValue: 'api',
  );

  static bool get useApi => dataSource != 'local';

  /// Служебная учётная запись, под которой приложение выполняет запросы
  /// на изменение данных. Экран входа появится в следующей работе.
  static const String apiUser = String.fromEnvironment(
    'API_USER',
    defaultValue: 'admin',
  );

  static const String apiPassword = String.fromEnvironment(
    'API_PASSWORD',
    defaultValue: 'admin123',
  );
}
