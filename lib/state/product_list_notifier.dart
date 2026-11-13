import '../models/product.dart';
import '../models/product_query.dart';
import '../repositories/product_repository.dart';
import 'entity_list_notifier.dart';

/// Состояние списка товаров.
class ProductListNotifier extends EntityListNotifier<Product, ProductQuery> {
  ProductListNotifier(ProductRepository repository)
    : super(repository, const ProductQuery());
}
