import '../models/product.dart';
import '../models/product_query.dart';
import 'crud_repository.dart';

abstract interface class ProductRepository
    implements CrudRepository<Product, ProductQuery> {
  /// Сколько товаров (включая логически удалённые) ссылается на запись.
  Future<int> countByManufacturer(int manufacturerId);
  Future<int> countByCategory(int categoryId);
  Future<int> countByMaterial(int materialId);
}
