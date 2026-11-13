import '../models/manufacturer.dart';
import '../models/manufacturer_query.dart';
import 'local_crud_repository.dart';
import 'manufacturer_repository.dart';
import 'seed_data.dart';

class LocalManufacturerRepository
    extends LocalCrudRepository<Manufacturer, ManufacturerQuery>
    implements ManufacturerRepository {
  LocalManufacturerRepository({
    List<Manufacturer>? seed,
    super.store,
    super.network,
    super.usageCount,
  }) : super(seed ?? seedManufacturers);

  @override
  String get entityName => 'Производитель';

  @override
  String nameOf(Manufacturer item) => item.name;

  @override
  String usageMessage(int count) =>
      'на него ссылаются $count ${countWord(count, 'товар', 'товара', 'товаров')}';

  @override
  bool matches(Manufacturer m, ManufacturerQuery q) {
    final needle = q.search.trim().toLowerCase();
    if (needle.isNotEmpty &&
        !m.name.toLowerCase().contains(needle) &&
        !m.country.toLowerCase().contains(needle)) {
      return false;
    }
    if (q.country != null && m.country != q.country) return false;
    return true;
  }

  @override
  int compareBy(Manufacturer a, Manufacturer b, String field) =>
      switch (field) {
        'country' => compareText(a.country, b.country),
        'foundedYear' => a.foundedYear.compareTo(b.foundedYear),
        _ => compareText(a.name, b.name),
      };

  @override
  Manufacturer withDeletedAt(Manufacturer item, DateTime? deletedAt) =>
      deletedAt == null
      ? item.copyWith(clearDeletedAt: true)
      : item.copyWith(deletedAt: deletedAt);

  @override
  Manufacturer withId(Manufacturer item, int id) => item.copyWith(id: id);

  @override
  Map<String, String> uniquenessErrors(Manufacturer item) => {
    if (isTaken(item, (m) => m.name))
      'name': 'Производитель с таким названием уже есть',
  };

  @override
  Future<List<String>> countries() async {
    await network.roundTrip();
    final set = {
      for (final m in records)
        if (!m.isDeleted) m.country,
    };
    return set.toList()..sort(compareText);
  }
}
