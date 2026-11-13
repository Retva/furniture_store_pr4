import 'package:dio/dio.dart';

import '../../api/api_client.dart';
import '../../api/api_exception.dart';
import '../../models/entity.dart';
import '../../models/list_query.dart';
import '../../models/page_result.dart';
import '../crud_repository.dart';

/// Общая часть всех репозиториев, работающих через REST API.
/// Каждая сущность отличается только адресом ресурса и тем, как запись переводится в JSON и обратно. Всё остальное — страницы, фильтры,
/// удаление, восстановление, перевод ошибок — одинаково и написано здесь.
class ApiCrudRepository<T extends Entity, Q extends ListQuery>
    implements CrudRepository<T, Q> {
  ApiCrudRepository(
    this.dio, {
    required this.resource,
    required this.fromJson,
    required this.toJson,
  });

  final Dio dio;

  /// Имя коллекции в адресе: `products` → `/api/products`.
  final String resource;
  final T Function(Map<String, dynamic>) fromJson;
  final Map<String, dynamic> Function(T) toJson;

  final LatestRequest _listRequest = LatestRequest();
  final List<void Function()> _changeListeners = [];

  /// Подписка на изменения данных. Через неё кэш справочников узнаёт, что
  /// категория или производитель изменились и их надо перечитать.
  void addChangeListener(void Function() listener) =>
      _changeListeners.add(listener);

  void notifyChanged() {
    for (final listener in _changeListeners) {
      listener();
    }
  }

  String get _path => '/$resource';

  /// Представление записи для отправки: без `id` и `deletedAt` — их
  /// назначает сервер. Связи уходят идентификаторами (`manufacturerId`,
  /// `categoryIds`), а возвращаются развёрнутыми объектами.
  Map<String, dynamic> toInput(T item) => toJson(item)
    ..remove('id')
    ..remove('deletedAt');

  PageResult<T> parsePage(Map<String, dynamic> data) => PageResult<T>(
    items: [
      for (final row in data['items'] as List)
        fromJson((row as Map).cast<String, dynamic>()),
    ],
    page: data['page'] as int,
    size: data['size'] as int,
    total: data['total'] as int,
  );

  /// Страница списка. Поиск, фильтры, сортировка и разбиение на страницы
  /// выполняются на сервере. Новый вызов отменяет предыдущий, если тот
  /// ещё не завершился.
  @override
  Future<PageResult<T>> find(Q query) => guard(() async {
    final response = await dio.get<Map<String, dynamic>>(
      _path,
      queryParameters: query.toApiParameters(),
      cancelToken: _listRequest.next(),
    );
    return parsePage(response.data!);
  });

  /// Все записи — для выпадающих списков. Сервер отдаёт не больше 100
  /// записей за раз, поэтому страницы запрашиваются по очереди.
  @override
  Future<List<T>> findAll({bool includeDeleted = true}) => guard(() async {
    final all = <T>[];
    var page = 1;
    while (true) {
      final response = await dio.get<Map<String, dynamic>>(
        _path,
        queryParameters: {
          'page': page,
          'size': 100,
          'sort': 'id,asc',
          if (includeDeleted) 'includeDeleted': true,
        },
      );
      final result = parsePage(response.data!);
      all.addAll(result.items);
      if (!result.hasNext) return List.unmodifiable(all);
      page++;
    }
  });

  /// Запись по номеру; `null`, если её нет (ответ 404).
  @override
  Future<T?> findById(int id) async {
    try {
      return await guard(() async {
        final response = await dio.get<Map<String, dynamic>>(
          '$_path/$id',
          queryParameters: {'includeDeleted': true},
        );
        return fromJson(response.data!);
      });
    } on NotFoundException {
      return null;
    }
  }

  @override
  Future<T> create(T item) => guard(() async {
    final response = await dio.post<Map<String, dynamic>>(
      _path,
      data: toInput(item),
    );
    notifyChanged();
    return fromJson(response.data!);
  });

  @override
  Future<T> update(T item) => guard(() async {
    final response = await dio.put<Map<String, dynamic>>(
      '$_path/${item.id}',
      data: toInput(item),
    );
    notifyChanged();
    return fromJson(response.data!);
  });

  @override
  Future<void> softDelete(int id) => guard(() async {
    await dio.delete<void>('$_path/$id');
    notifyChanged();
  });

  @override
  Future<void> hardDelete(int id) => guard(() async {
    await dio.delete<void>('$_path/$id', queryParameters: {'hard': true});
    notifyChanged();
  });

  @override
  Future<void> restore(int id) => guard(() async {
    await dio.post<Map<String, dynamic>>('$_path/$id/restore');
    notifyChanged();
  });

  @override
  Future<int> deleteMany(List<int> ids) => guard(() async {
    final response = await dio.post<Map<String, dynamic>>(
      '$_path/bulk-delete',
      data: {'ids': ids},
    );
    notifyChanged();
    return response.data!['deleted'] as int;
  });

  /// Сколько записей подходит под фильтр — без загрузки самих записей.
  Future<int> count(Map<String, Object> filter) => guard(() async {
    final response = await dio.get<Map<String, dynamic>>(
      _path,
      queryParameters: {...filter, 'size': 1, 'includeDeleted': true},
    );
    return response.data!['total'] as int;
  });
}
