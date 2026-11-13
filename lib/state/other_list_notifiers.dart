import '../models/basic_query.dart';
import '../models/customer.dart';
import '../models/furniture_material.dart';
import '../models/product_category.dart';
import '../repositories/category_repository.dart';
import '../repositories/customer_repository.dart';
import '../repositories/material_repository.dart';
import 'entity_list_notifier.dart';

class CategoryListNotifier
    extends EntityListNotifier<ProductCategory, BasicQuery> {
  CategoryListNotifier(CategoryRepository repository)
    : super(repository, const BasicQuery(spec: categoryQuerySpec));
}

class MaterialListNotifier
    extends EntityListNotifier<FurnitureMaterial, BasicQuery> {
  MaterialListNotifier(MaterialRepository repository)
    : super(repository, const BasicQuery(spec: materialQuerySpec));
}

class CustomerListNotifier extends EntityListNotifier<Customer, BasicQuery> {
  CustomerListNotifier(CustomerRepository repository)
    : super(repository, const BasicQuery(spec: customerQuerySpec));
}
