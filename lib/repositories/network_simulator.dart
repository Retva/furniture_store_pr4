import 'repository_exception.dart';

/// Имитация сети для репозиториев в памяти.
///
/// Задержка нужна, чтобы был виден индикатор загрузки: без неё данные приходят мгновенно и состояние «загружается» не увидеть.
class NetworkSimulator {
  NetworkSimulator({this.latency = const Duration(milliseconds: 250)});

  /// Для тестов: без задержек и без сбоев.
  NetworkSimulator.instant() : latency = Duration.zero;

  Duration latency;

  /// Пока флаг поднят, каждый запрос заканчивается ошибкой.
  bool failRequests = false;

  Future<void> roundTrip() async {
    if (latency > Duration.zero) {
      await Future<void>.delayed(latency);
    }
    if (failRequests) {
      throw const RepositoryException(
        'Сервер не отвечает. Проверьте подключение и повторите попытку.',
      );
    }
  }
}
