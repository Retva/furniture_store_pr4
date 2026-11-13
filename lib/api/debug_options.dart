/// Учебные переключатели, которые добавляют к каждому запросу служебные параметры мок-сервера.
class DebugOptions {
  /// `?__delay=1500` — сервер ответит через полторы секунды.
  bool slowResponses = false;

  /// `?__fail=500` — сервер ответит ошибкой 500.
  bool failResponses = false;

  static const int delayMs = 1500;
  static const int failStatus = 500;

  Map<String, Object> get queryParameters => {
    if (slowResponses) '__delay': delayMs,
    if (failResponses) '__fail': failStatus,
  };
}
