import '../models/basic_query.dart';
import '../models/product_category.dart';
import 'category_repository.dart';
import 'local_crud_repository.dart';
import 'seed_data.dart';

class LocalCategoryRepository
    extends LocalCrudRepository<ProductCategory, BasicQuery>
    implements CategoryRepository {
  LocalCategoryRepository({
    List<ProductCategory>? seed,
    super.store,
    super.network,
    super.usageCount,
  }) : super(seed ?? seedCategories);

  @override
  String get entityName => 'Категория';

  @override
  String nameOf(ProductCategory item) => item.name;

  @override
  String usageMessage(int count) =>
      'в ней $count ${countWord(count, 'товар', 'товара', 'товаров')}';

  @override
  bool matches(ProductCategory c, BasicQuery q) {
    final needle = q.search.trim().toLowerCase();
    return needle.isEmpty ||
        c.name.toLowerCase().contains(needle) ||
        c.description.toLowerCase().contains(needle);
  }

  @override
  int compareBy(ProductCategory a, ProductCategory b, String field) =>
      compareText(a.name, b.name);

  @override
  ProductCategory withDeletedAt(ProductCategory item, DateTime? deletedAt) =>
      deletedAt == null
      ? item.copyWith(clearDeletedAt: true)
      : item.copyWith(deletedAt: deletedAt);

  @override
  ProductCategory withId(ProductCategory item, int id) => item.copyWith(id: id);

  @override
  Map<String, String> uniquenessErrors(ProductCategory item) => {
    if (isTaken(item, (c) => c.name)) 'name': 'Такая категория уже есть',
  };
}
