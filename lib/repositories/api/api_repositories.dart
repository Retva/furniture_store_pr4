import '../../models/basic_query.dart';
import '../../models/customer.dart';
import '../../models/furniture_material.dart';
import '../../models/manufacturer.dart';
import '../../models/manufacturer_query.dart';
import '../../models/product.dart';
import '../../models/product_category.dart';
import '../../models/product_query.dart';
import '../category_repository.dart';
import '../customer_repository.dart';
import '../manufacturer_repository.dart';
import '../material_repository.dart';
import '../product_repository.dart';
import 'api_crud_repository.dart';

/// Репозитории пяти сущностей. Каждый — это адрес ресурса и функции
/// перевода в JSON; общая логика в [ApiCrudRepository].

class ApiProductRepository extends ApiCrudRepository<Product, ProductQuery>
    implements ProductRepository {
  ApiProductRepository(super.dio)
    : super(
        resource: 'products',
        fromJson: Product.fromJson,
        toJson: (p) => p.toJson(),
      );

  @override
  Future<int> countByManufacturer(int manufacturerId) =>
      count({'manufacturerId': manufacturerId});

  @override
  Future<int> countByCategory(int categoryId) =>
      count({'categoryId': categoryId});

  @override
  Future<int> countByMaterial(int materialId) =>
      count({'materialId': materialId});
}

class ApiManufacturerRepository
    extends ApiCrudRepository<Manufacturer, ManufacturerQuery>
    implements ManufacturerRepository {
  ApiManufacturerRepository(super.dio)
    : super(
        resource: 'manufacturers',
        fromJson: Manufacturer.fromJson,
        toJson: (m) => m.toJson(),
      );

  /// Отдельного адреса для стран нет: список собирается из производителей.
  @override
  Future<List<String>> countries() async {
    final all = await findAll(includeDeleted: false);
    return ({for (final m in all) m.country}.toList()..sort());
  }
}

class ApiCategoryRepository
    extends ApiCrudRepository<ProductCategory, BasicQuery>
    implements CategoryRepository {
  ApiCategoryRepository(super.dio)
    : super(
        resource: 'categories',
        fromJson: ProductCategory.fromJson,
        toJson: (c) => c.toJson(),
      );
}

class ApiMaterialRepository
    extends ApiCrudRepository<FurnitureMaterial, BasicQuery>
    implements MaterialRepository {
  ApiMaterialRepository(super.dio)
    : super(
        resource: 'materials',
        fromJson: FurnitureMaterial.fromJson,
        toJson: (m) => m.toJson(),
      );
}

class ApiCustomerRepository extends ApiCrudRepository<Customer, BasicQuery>
    implements CustomerRepository {
  ApiCustomerRepository(super.dio)
    : super(
        resource: 'customers',
        fromJson: Customer.fromJson,
        toJson: (c) => c.toJson(),
      );
}
