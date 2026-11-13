import '../models/basic_query.dart';
import '../models/furniture_material.dart';
import 'local_crud_repository.dart';
import 'material_repository.dart';
import 'seed_data.dart';

class LocalMaterialRepository
    extends LocalCrudRepository<FurnitureMaterial, BasicQuery>
    implements MaterialRepository {
  LocalMaterialRepository({
    List<FurnitureMaterial>? seed,
    super.store,
    super.network,
    super.usageCount,
  }) : super(seed ?? seedMaterials);

  @override
  String get entityName => 'Материал';

  @override
  String nameOf(FurnitureMaterial item) => item.name;

  @override
  String usageMessage(int count) =>
      'он используется в $count ${countWord(count, 'товаре', 'товарах', 'товарах')}';

  @override
  bool matches(FurnitureMaterial m, BasicQuery q) {
    final needle = q.search.trim().toLowerCase();
    if (needle.isNotEmpty &&
        !m.name.toLowerCase().contains(needle) &&
        !m.origin.toLowerCase().contains(needle)) {
      return false;
    }
    if (q.filter != null && m.kind != q.filter) return false;
    return true;
  }

  @override
  int compareBy(FurnitureMaterial a, FurnitureMaterial b, String field) =>
      switch (field) {
        'kind' => compareText(a.kind, b.kind),
        'origin' => compareText(a.origin, b.origin),
        _ => compareText(a.name, b.name),
      };

  @override
  FurnitureMaterial withDeletedAt(
    FurnitureMaterial item,
    DateTime? deletedAt,
  ) => deletedAt == null
      ? item.copyWith(clearDeletedAt: true)
      : item.copyWith(deletedAt: deletedAt);

  @override
  FurnitureMaterial withId(FurnitureMaterial item, int id) =>
      item.copyWith(id: id);

  @override
  Map<String, String> uniquenessErrors(FurnitureMaterial item) => {
    if (isTaken(item, (m) => m.name)) 'name': 'Такой материал уже есть',
  };
}
