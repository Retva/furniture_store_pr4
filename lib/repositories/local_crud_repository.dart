import '../models/entity.dart';
import '../models/list_query.dart';
import '../models/page_result.dart';
import 'crud_repository.dart';
import 'local_storage.dart';
import 'network_simulator.dart';
import 'repository_exception.dart';

/// Сколько записей других сущностей ссылается на запись [id].
typedef UsageCounter = Future<int> Function(int id);

/// Общая часть локальных хранилищ: страницы, сортировка, удаление,
/// восстановление, сохранение в localStorage после каждого изменения и
/// запрет удалять запись, на которую ссылаются другие.
abstract class LocalCrudRepository<T extends Entity, Q extends ListQuery>
    implements CrudRepository<T, Q> {
  LocalCrudRepository(
    List<T> seed, {
    EntityStore<T>? store,
    NetworkSimulator? network,
    this.usageCount,
  }) : _store = store,
       records = store == null ? [...seed] : store.loadOr(seed),
       network = network ?? NetworkSimulator() {
    _nextId = records.fold<int>(0, (max, x) => x.id > max ? x.id : max) + 1;
  }

  final List<T> records;
  final NetworkSimulator network;
  final EntityStore<T>? _store;

  /// Подсчёт ссылок на запись. Если задан и вернул больше нуля, удалить
  /// запись нельзя ни логически, ни физически.
  UsageCounter? usageCount;

  late int _nextId;

  String get entityName;

  String nameOf(T item);

  /// «на него ссылаются 5 товаров».
  String usageMessage(int count) => 'на запись ссылаются другие записи: $count';

  bool matches(T item, Q query);

  int compareBy(T a, T b, String field);

  T withDeletedAt(T item, DateTime? deletedAt);

  T withId(T item, int id);

  /// Проверка уникальности. Ошибки возвращаются по именам полей.
  Map<String, String> uniquenessErrors(T item) => const {};

  Future<void> _persist() async => _store?.save(records);

  @override
  Future<PageResult<T>> find(Q query) async {
    await network.roundTrip();

    final rows = records
        .where((item) => query.includeDeleted || !item.isDeleted)
        .where((item) => matches(item, query))
        .toList();

    rows.sort((a, b) {
      var result = compareBy(a, b, query.sortField);
      if (result == 0) result = a.id.compareTo(b.id);
      return query.sortAscending ? result : -result;
    });

    final total = rows.length;
    final from = (query.page - 1) * query.size;
    final to = (from + query.size) > total ? total : (from + query.size);
    final items = from >= total ? <T>[] : rows.sublist(from, to);

    return PageResult<T>(
      items: List.unmodifiable(items),
      page: query.page,
      size: query.size,
      total: total,
    );
  }

  @override
  Future<List<T>> findAll({bool includeDeleted = true}) async {
    await network.roundTrip();
    return List.unmodifiable(
      records.where((item) => includeDeleted || !item.isDeleted),
    );
  }

  @override
  Future<T?> findById(int id) async {
    await network.roundTrip();
    return records.where((item) => item.id == id).firstOrNull;
  }

  @override
  Future<T> create(T item) async {
    await network.roundTrip();
    final created = withId(item, _nextId);
    _checkUnique(created);
    _nextId++;
    records.add(created);
    await _persist();
    return created;
  }

  @override
  Future<T> update(T item) async {
    await network.roundTrip();
    final i = _indexOf(item.id);
    _checkUnique(item);
    records[i] = item;
    await _persist();
    return item;
  }

  @override
  Future<void> softDelete(int id) async {
    await network.roundTrip();
    final i = _indexOf(id);
    await _ensureUnused(records[i]);
    records[i] = withDeletedAt(records[i], DateTime.now());
    await _persist();
  }

  @override
  Future<void> hardDelete(int id) async {
    await network.roundTrip();
    await _ensureUnused(records[_indexOf(id)]);
    records.removeWhere((item) => item.id == id);
    await _persist();
  }

  @override
  Future<void> restore(int id) async {
    await network.roundTrip();
    final i = _indexOf(id);
    records[i] = withDeletedAt(records[i], null);
    await _persist();
  }

  @override
  Future<int> deleteMany(List<int> ids) async {
    await network.roundTrip();
    final targets = [
      for (final id in ids)
        ...records.where((item) => item.id == id && !item.isDeleted),
    ];

    final blocked = <String>[];
    for (final item in targets) {
      final count = await usageCount?.call(item.id) ?? 0;
      if (count > 0) blocked.add('«${nameOf(item)}» — ${usageMessage(count)}');
    }
    if (blocked.isNotEmpty) {
      throw RepositoryException(
        'Ничего не удалено, есть связанные записи: ${blocked.join('; ')}.',
      );
    }

    final now = DateTime.now();
    for (final item in targets) {
      final i = records.indexWhere((x) => x.id == item.id && !x.isDeleted);
      if (i != -1) records[i] = withDeletedAt(records[i], now);
    }
    await _persist();
    return targets.length;
  }

  Future<void> _ensureUnused(T item) async {
    final count = await usageCount?.call(item.id) ?? 0;
    if (count > 0) {
      throw RepositoryException(
        'Нельзя удалить «${nameOf(item)}»: ${usageMessage(count)}.',
      );
    }
  }

  void _checkUnique(T item) {
    final errors = uniquenessErrors(item);
    if (errors.isNotEmpty) throw ValidationException(errors);
  }

  int _indexOf(int id) {
    final i = records.indexWhere((item) => item.id == id);
    if (i == -1) {
      throw RepositoryException('$entityName с номером $id не найден.');
    }
    return i;
  }

  /// Есть ли у другой записи такое же значение поля (без учёта регистра).
  bool isTaken(T item, String Function(T) field) {
    final value = field(item).trim().toLowerCase();
    if (value.isEmpty) return false;
    return records.any(
      (other) =>
          other.id != item.id && field(other).trim().toLowerCase() == value,
    );
  }
}

int compareText(String a, String b) =>
    a.toLowerCase().compareTo(b.toLowerCase());

String countWord(int n, String one, String few, String many) {
  final mod10 = n % 10;
  final mod100 = n % 100;
  if (mod10 == 1 && mod100 != 11) return one;
  if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) return few;
  return many;
}
