import 'package:dio/dio.dart';

import '../repositories/repository_exception.dart';

/// Ошибки обращения к серверу.
sealed class ApiException extends RepositoryException {
  const ApiException(super.message, {this.statusCode});

  /// Код ответа сервера; `null`, если ответа не было.
  final int? statusCode;
}

/// Ответа нет: сервер выключен, неверный адрес, CORS, истёк тайм-аут.
class NetworkException extends ApiException {
  const NetworkException([
    super.message =
        'Сервер недоступен. Проверьте подключение и повторите попытку.',
  ]);
}

/// 401 — не выполнен вход либо срок действия токена истёк.
class UnauthorizedException extends ApiException {
  const UnauthorizedException([super.message = 'Требуется вход в систему.'])
    : super(statusCode: 401);
}

/// 403 — роль пользователя не позволяет выполнить операцию.
class ForbiddenException extends ApiException {
  const ForbiddenException([
    super.message = 'Недостаточно прав для этого действия.',
  ]) : super(statusCode: 403);
}

/// 404 — записи нет.
class NotFoundException extends ApiException {
  const NotFoundException([super.message = 'Запись не найдена.'])
    : super(statusCode: 404);
}

/// 409 — операция противоречит состоянию данных: удалить производителя,
/// у которого есть товары; заказать больше, чем есть на складе.
class ConflictException extends ApiException {
  const ConflictException([super.message = 'Операция невозможна.'])
    : super(statusCode: 409);
}

/// 422 — данные не прошли проверку сервера. Ошибки привязаны к полям и
/// показываются под ними. Реализует [ValidationException], поэтому формы
/// из ПР3 обрабатывают её тем же кодом, что и ошибки уникальности.
class ApiValidationException extends ApiException
    implements ValidationException {
  const ApiValidationException(
    this.errors, [
    super.message = 'Проверьте правильность заполнения полей.',
  ]) : super(statusCode: 422);

  @override
  final Map<String, String> errors;
}

/// 5xx и прочие ответы, которых клиент не ожидает.
class ServerException extends ApiException {
  const ServerException(super.message, {super.statusCode});
}

/// Запрос отменён клиентом: пользователь ушёл со страницы или запустил
/// новый поиск раньше, чем пришёл ответ на старый. Сообщение не показывается.
class CancelledException extends ApiException {
  const CancelledException() : super('Запрос отменён.');
}

/// Переводит ошибку Dio в одно из исключений [ApiException].
ApiException mapDioError(DioException error) {
  final inner = error.error;
  if (inner is ApiException) return inner;

  switch (error.type) {
    case DioExceptionType.cancel:
      return const CancelledException();
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
      return const NetworkException(
        'Сервер слишком долго не отвечает. Повторите попытку позже.',
      );
    case DioExceptionType.badResponse:
      final response = error.response;
      if (response == null) return const NetworkException();
      return mapHttpError(response.statusCode ?? 0, response.data);
    default:
      // connectionError, unknown и прочее: ответа от сервера нет. На web
      // сюда же попадает запрет CORS — браузер не показывает ответ коду.
      return const NetworkException();
  }
}

/// Переводит ответ с кодом ошибки в исключение. Текст берётся из поля
/// `message` ответа, а если сервер его не прислал — подставляется свой.
ApiException mapHttpError(int status, Object? data) {
  final body = data is Map ? data : const {};
  final message = body['message'] is String ? body['message'] as String : null;

  return switch (status) {
    401 => UnauthorizedException(message ?? 'Требуется вход в систему.'),
    403 => ForbiddenException(
      message ?? 'Недостаточно прав для этого действия.',
    ),
    404 => NotFoundException(message ?? 'Запись не найдена.'),
    409 => ConflictException(message ?? 'Операция невозможна.'),
    422 => ApiValidationException({
      if (body['errors'] is Map)
        for (final entry in (body['errors'] as Map).entries)
          '${entry.key}': '${entry.value}',
    }, message ?? 'Проверьте правильность заполнения полей.'),
    >= 500 => ServerException(
      'Ошибка на сервере ($status). Повторите попытку позже.',
      statusCode: status,
    ),
    _ => ServerException(
      message ?? 'Неожиданный ответ сервера ($status).',
      statusCode: status,
    ),
  };
}

/// Выполняет запрос и превращает любые ошибки Dio в [ApiException].
/// Репозитории оборачивают в него каждый вызов, поэтому наружу Dio не
/// протекает: экраны и состояния про него не знают.
Future<T> guard<T>(Future<T> Function() request) async {
  try {
    return await request();
  } on DioException catch (e) {
    throw mapDioError(e);
  } on FormatException {
    throw const ServerException('Сервер прислал данные в неожиданном формате.');
  } on TypeError {
    throw const ServerException('Сервер прислал данные в неожиданном формате.');
  }
}
