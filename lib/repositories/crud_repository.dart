import '../models/entity.dart';
import '../models/page_result.dart';

/// Операции над записями, не зависящие от того, где записи лежат.
abstract interface class CrudRepository<T extends Entity, Q> {
  Future<PageResult<T>> find(Q query);

  /// Все записи без страниц — для выпадающих списков и подписей.
  Future<List<T>> findAll({bool includeDeleted = true});

  Future<T?> findById(int id);

  /// Бросает [ValidationException], если нарушена уникальность.
  Future<T> create(T item);

  Future<T> update(T item);

  Future<void> softDelete(int id);

  Future<void> hardDelete(int id);

  Future<void> restore(int id);

  Future<int> deleteMany(List<int> ids);
}
