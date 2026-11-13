import 'package:flutter/foundation.dart';

import '../models/furniture_material.dart';
import '../models/manufacturer.dart';
import '../models/product_category.dart';
import '../repositories/category_repository.dart';
import '../repositories/manufacturer_repository.dart';
import '../repositories/material_repository.dart';

enum ReferenceStatus { loading, ready, failed }

/// Справочники для подписей и выпадающих списков. Заполняются из
/// репозиториев, а не константами в коде, поэтому новая категория или
/// новый производитель сразу появляются в формах.
///
/// Справочники кэшируются: каждая форма просит их загрузить, но запрос к
/// серверу уходит, только если данных ещё нет, они старше [maxAge] или
/// помечены устаревшими после изменения категории, материала или
/// производителя ([markStale]).
class ReferenceDataNotifier extends ChangeNotifier {
  ReferenceDataNotifier(
    this._categories,
    this._manufacturers,
    this._materials, {
    this.maxAge = const Duration(minutes: 5),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final Duration maxAge;
  final DateTime Function() _clock;
  DateTime? _loadedAt;
  bool _stale = false;
  Future<void>? _pending;

  final CategoryRepository _categories;
  final ManufacturerRepository _manufacturers;
  final MaterialRepository _materials;

  ReferenceStatus _status = ReferenceStatus.loading;
  List<ProductCategory> _categoryList = const [];
  List<Manufacturer> _manufacturerList = const [];
  List<FurnitureMaterial> _materialList = const [];
  List<String> _countries = const [];
  bool _disposed = false;

  ReferenceStatus get status => _status;

  List<ProductCategory> get categories => _categoryList;
  List<Manufacturer> get manufacturers => _manufacturerList;
  List<FurnitureMaterial> get materials => _materialList;
  List<String> get countries => _countries;

  List<ProductCategory> get activeCategories =>
      _categoryList.where((c) => !c.isDeleted).toList();
  List<Manufacturer> get activeManufacturers =>
      _manufacturerList.where((m) => !m.isDeleted).toList();
  List<FurnitureMaterial> get activeMaterials =>
      _materialList.where((m) => !m.isDeleted).toList();

  /// Данные загружены и ещё годны — повторный запрос не нужен.
  bool get isFresh =>
      _status == ReferenceStatus.ready &&
      !_stale &&
      _loadedAt != null &&
      _clock().difference(_loadedAt!) < maxAge;

  /// Справочник изменился: при следующем [load] данные будут перечитаны.
  void markStale() => _stale = true;

  /// Загружает справочники, если кэш пуст или устарел. Одновременные
  /// вызовы ждут одну и ту же загрузку.
  Future<void> load({bool force = false}) {
    if (!force && isFresh) return Future.value();
    return _pending ??= _load().whenComplete(() => _pending = null);
  }

  Future<void> _load() async {
    if (_categoryList.isEmpty) {
      _status = ReferenceStatus.loading;
      if (!_disposed) notifyListeners();
    }
    try {
      final results = await Future.wait<Object>([
        _categories.findAll(),
        _manufacturers.findAll(),
        _materials.findAll(),
        _manufacturers.countries(),
      ]);
      _categoryList = _sorted(
        results[0] as List<ProductCategory>,
        (c) => c.name,
      );
      _manufacturerList = _sorted(
        results[1] as List<Manufacturer>,
        (m) => m.name,
      );
      _materialList = _sorted(
        results[2] as List<FurnitureMaterial>,
        (m) => m.name,
      );
      _countries = results[3] as List<String>;
      _status = ReferenceStatus.ready;
      _loadedAt = _clock();
      _stale = false;
    } catch (_) {
      // Если что-то уже было загружено, оставляем его: подписи в таблицах
      // лучше показать по старым данным, чем заменить прочерками.
      _status = _categoryList.isEmpty
          ? ReferenceStatus.failed
          : ReferenceStatus.ready;
    }
    if (!_disposed) notifyListeners();
  }

  static List<T> _sorted<T>(List<T> list, String Function(T) key) =>
      [...list]
        ..sort((a, b) => key(a).toLowerCase().compareTo(key(b).toLowerCase()));

  ProductCategory? categoryOf(int id) =>
      _categoryList.where((c) => c.id == id).firstOrNull;

  Manufacturer? manufacturerOf(int id) =>
      _manufacturerList.where((m) => m.id == id).firstOrNull;

  FurnitureMaterial? materialOf(int id) =>
      _materialList.where((m) => m.id == id).firstOrNull;

  String categoryName(int id) => categoryOf(id)?.name ?? '—';

  String manufacturerName(int id) => manufacturerOf(id)?.name ?? '—';

  String materialName(int id) => materialOf(id)?.name ?? '—';

  String categoryNames(List<int> ids) =>
      ids.isEmpty ? '—' : ids.map(categoryName).join(', ');

  String materialNames(List<int> ids) =>
      ids.isEmpty ? '—' : ids.map(materialName).join(', ');

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
