import 'dart:convert';

/// Хранилище строк по ключу. В приложении за ним стоит shared_preferences
/// (на web — localStorage браузера), в тестах — словарь в памяти.
abstract interface class KeyValueStore {
  String? getString(String key);
  Future<void> setString(String key, String value);
  Future<void> remove(String key);
}

class MemoryKeyValueStore implements KeyValueStore {
  MemoryKeyValueStore([Map<String, String>? initial]) : data = {...?initial};

  final Map<String, String> data;

  @override
  String? getString(String key) => data[key];

  @override
  Future<void> setString(String key, String value) async => data[key] = value;

  @override
  Future<void> remove(String key) async => data.remove(key);
}

/// Сообщения о том, что произошло с сохранёнными данными при запуске:
/// миграция со старого формата или сброс испорченных данных.
class StorageReport {
  final List<String> messages = [];

  void add(String message) => messages.add(message);
}

/// Список записей одной сущности под одним ключом в виде JSON.
class EntityStore<T> {
  EntityStore({
    required this.store,
    required this.key,
    required this.fromJson,
    required this.toJson,
    required this.report,
    required this.title,
  });

  final KeyValueStore store;
  final String key;
  final T Function(Map<String, dynamic>) fromJson;
  final Map<String, dynamic> Function(T) toJson;
  final StorageReport report;

  /// Название набора для сообщений: «товары», «покупатели».
  final String title;

  /// Сохранённые записи или начальный набор, если сохранённых нет или они
  /// не разбираются. Испорченные данные не роняют приложение.
  List<T> loadOr(List<T> seed) {
    final raw = store.getString(key);
    if (raw == null) {
      save(seed);
      return [...seed];
    }
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    } catch (_) {
      report.add(
        'Сохранённые данные «$title» повреждены — восстановлен начальный набор.',
      );
      save(seed);
      return [...seed];
    }
  }

  Future<void> save(List<T> items) =>
      store.setString(key, jsonEncode(items.map(toJson).toList()));
}

/// Ключи текущей версии формата. Суффикс версии меняется вместе с составом
/// полей, и старые данные не попадают в разбор нового формата.
class StorageKeys {
  const StorageKeys._();

  static const int version = 2;
  static const String versionKey = 'schema_version';
  static const String products = 'products_v2';
  static const String manufacturers = 'manufacturers_v2';
  static const String categories = 'categories_v2';
  static const String materials = 'materials_v2';
  static const String customers = 'customers_v2';

  static const String productsV1 = 'products_v1';
  static const String manufacturersV1 = 'manufacturers_v1';
}

/// Перевод данных со старой версии формата на текущую.
///
/// Версия 1 — формат ПР2: у товара одна категория `categoryId` и материал
/// строкой `material`, у производителя нет почты и материалов. В версии 2
/// категории и материалы стали списками. Старые записи переводятся в новый
/// формат, а не выбрасываются; ключ v1 после этого удаляется.
class StorageMigrator {
  StorageMigrator(this.store, this.report);

  final KeyValueStore store;
  final StorageReport report;

  Future<void> run() async {
    final stored = int.tryParse(store.getString(StorageKeys.versionKey) ?? '');
    if (stored == StorageKeys.version) return;

    var migrated = 0;
    final oldProducts = store.getString(StorageKeys.productsV1);
    if (oldProducts != null) {
      migrated += await _migrateList(
        oldProducts,
        StorageKeys.products,
        _productV1toV2,
      );
      await store.remove(StorageKeys.productsV1);
    }
    final oldManufacturers = store.getString(StorageKeys.manufacturersV1);
    if (oldManufacturers != null) {
      migrated += await _migrateList(
        oldManufacturers,
        StorageKeys.manufacturers,
        (m) => {
          ...m,
          'email': m['email'] ?? '',
          'materialIds': m['materialIds'] ?? [],
        },
      );
      await store.remove(StorageKeys.manufacturersV1);
    }

    if (migrated > 0) {
      report.add(
        'Сохранённые данные переведены на формат версии ${StorageKeys.version}: '
        'обновлено записей — $migrated.',
      );
    } else if (stored != null && stored > StorageKeys.version) {
      report.add(
        'Данные сохранены более новой версией приложения и будут '
        'перезаписаны.',
      );
    }
    await store.setString(StorageKeys.versionKey, '${StorageKeys.version}');
  }

  Future<int> _migrateList(
    String raw,
    String targetKey,
    Map<String, dynamic> Function(Map<String, dynamic>) convert,
  ) async {
    try {
      final list = (jsonDecode(raw) as List)
          .map((e) => convert((e as Map).cast<String, dynamic>()))
          .toList();
      await store.setString(targetKey, jsonEncode(list));
      return list.length;
    } catch (_) {
      report.add('Старые данные не удалось разобрать — они пропущены.');
      return 0;
    }
  }

  static Map<String, dynamic> _productV1toV2(Map<String, dynamic> old) {
    final categoryId = old['categoryId'];
    return {
        ...old,
        'categoryIds':
            old['categoryIds'] ?? [if (categoryId is int) categoryId],
        'materialIds': old['materialIds'] ?? <int>[],
        'description': [
          if (old['description'] is String) old['description'],
          if (old['material'] is String &&
              (old['material'] as String).isNotEmpty)
            'Материал (из старой версии): ${old['material']}',
        ].join(' '),
      }
      ..remove('categoryId')
      ..remove('material');
  }
}
