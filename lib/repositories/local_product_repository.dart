import '../models/product.dart';
import '../models/product_query.dart';
import 'local_crud_repository.dart';
import 'product_repository.dart';
import 'seed_data.dart';

class LocalProductRepository extends LocalCrudRepository<Product, ProductQuery>
    implements ProductRepository {
  LocalProductRepository({List<Product>? seed, super.store, super.network})
    : super(seed ?? seedProducts);

  @override
  String get entityName => 'Товар';

  @override
  String nameOf(Product item) => item.name;

  @override
  bool matches(Product p, ProductQuery q) {
    final needle = q.search.trim().toLowerCase();
    if (needle.isNotEmpty &&
        !p.name.toLowerCase().contains(needle) &&
        !p.sku.toLowerCase().contains(needle)) {
      return false;
    }
    if (q.categoryId != null && !p.categoryIds.contains(q.categoryId)) {
      return false;
    }
    if (q.manufacturerId != null && p.manufacturerId != q.manufacturerId) {
      return false;
    }
    if (q.priceFrom != null && p.price < q.priceFrom!) return false;
    if (q.priceTo != null && p.price > q.priceTo!) return false;
    return true;
  }

  @override
  int compareBy(Product a, Product b, String field) => switch (field) {
    'sku' => compareText(a.sku, b.sku),
    'price' => a.price.compareTo(b.price),
    'stock' => a.stock.compareTo(b.stock),
    _ => compareText(a.name, b.name),
  };

  @override
  Product withDeletedAt(Product item, DateTime? deletedAt) => deletedAt == null
      ? item.copyWith(clearDeletedAt: true)
      : item.copyWith(deletedAt: deletedAt);

  @override
  Product withId(Product item, int id) => item.copyWith(id: id);

  @override
  Map<String, String> uniquenessErrors(Product item) => {
    if (isTaken(item, (p) => p.sku))
      'sku': 'Артикул ${item.sku} уже есть у другого товара',
  };

  int _count(bool Function(Product) test) => records.where(test).length;

  @override
  Future<int> countByManufacturer(int id) async =>
      _count((p) => p.manufacturerId == id);

  @override
  Future<int> countByCategory(int id) async =>
      _count((p) => p.categoryIds.contains(id));

  @override
  Future<int> countByMaterial(int id) async =>
      _count((p) => p.materialIds.contains(id));
}
