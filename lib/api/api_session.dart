import 'package:dio/dio.dart';

/// Учётная запись, под которой приложение обращается к API, и полученный токен доступа.
class ApiSession {
  ApiSession({required this.username, required this.password});

  String username;
  String password;

  String? accessToken;

  /// Роль, которую сервер вернул при входе: admin, manager, viewer.
  String? role;

  Future<String>? _pending;

  /// Учётные записи мок-сервера — для переключателя ролей.
  static const Map<String, String> demoAccounts = {
    'admin': 'admin123',
    'manager': 'manager123',
    'viewer': 'viewer123',
  };

  void switchUser(String username) {
    this.username = username;
    password = demoAccounts[username] ?? password;
    accessToken = null;
    role = null;
  }

  /// Вход. Параллельные запросы ждут один и тот же вход, а не входят
  /// каждый сам по себе.
  Future<String> login(Dio dio) {
    return _pending ??= _login(dio).whenComplete(() => _pending = null);
  }

  Future<String> _login(Dio dio) async {
    final response = await dio.post<Map<String, dynamic>>(
      '/auth/login',
      data: {'username': username, 'password': password},
      options: Options(extra: {ApiSession.skipAuth: true}),
    );
    final data = response.data!;
    accessToken = data['accessToken'] as String;
    role = (data['user'] as Map?)?['role'] as String?;
    return accessToken!;
  }

  /// Пометка запроса, которому токен не нужен (сам вход).
  static const String skipAuth = 'skipAuth';
}
