import '../models/basic_query.dart';
import '../models/product_category.dart';
import 'crud_repository.dart';

abstract interface class CategoryRepository
    implements CrudRepository<ProductCategory, BasicQuery> {}
