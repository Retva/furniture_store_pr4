/// Ошибка хранилища с текстом, который можно показать человеку.
class RepositoryException implements Exception {
  const RepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Ошибки проверки, привязанные к полям: `{'sku': 'Артикул уже занят'}`.
/// Форма показывает их под соответствующими полями, а не общим сообщением.
class ValidationException extends RepositoryException {
  const ValidationException(this.errors)
    : super('Проверьте правильность заполнения полей.');

  final Map<String, String> errors;
}
