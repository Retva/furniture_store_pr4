import 'list_query.dart';

/// Все условия отбора списка товаров в одном неизменяемом объекте.
class ProductQuery extends ListQuery {
  const ProductQuery({
    super.search = '',
    this.categoryId,
    this.manufacturerId,
    this.priceFrom,
    this.priceTo,
    super.sortField = defaultSort,
    super.sortAscending = true,
    super.page = 1,
    super.size = defaultPageSize,
    super.includeDeleted = false,
  });

  /// Разбор параметров адреса. Ничего не бросает: неверные значения заменяются значениями по умолчанию.
  factory ProductQuery.fromParameters(Map<String, String> params) {
    final (sortField, sortAscending) = QueryParams.parseSort(
      params['sort'],
      allowed: sortFields,
      fallback: defaultSort,
    );
    return ProductQuery(
      search: params['search'] ?? '',
      categoryId: QueryParams.parseInt(params['categoryId']),
      manufacturerId: QueryParams.parseInt(params['manufacturerId']),
      priceFrom: QueryParams.parseInt(params['priceFrom']),
      priceTo: QueryParams.parseInt(params['priceTo']),
      sortField: sortField,
      sortAscending: sortAscending,
      page: QueryParams.parsePage(params['page']),
      size: QueryParams.parseSize(params['size']),
      includeDeleted: QueryParams.parseBool(params['deleted']),
    );
  }

  static const String defaultSort = 'name';

  /// Поля, по которым разрешена сортировка.
  static const Set<String> sortFields = {'name', 'sku', 'price', 'stock'};

  final int? categoryId;
  final int? manufacturerId;

  final int? priceFrom;
  final int? priceTo;

  @override
  String get path => '/products';

  @override
  bool get hasFilters =>
      search.trim().isNotEmpty ||
      categoryId != null ||
      manufacturerId != null ||
      priceFrom != null ||
      priceTo != null;

  ProductQuery copyWith({
    String? search,
    Object? categoryId = _unset,
    Object? manufacturerId = _unset,
    Object? priceFrom = _unset,
    Object? priceTo = _unset,
    String? sortField,
    bool? sortAscending,
    int? page,
    int? size,
    bool? includeDeleted,
  }) {
    return ProductQuery(
      search: search ?? this.search,
      categoryId: identical(categoryId, _unset)
          ? this.categoryId
          : categoryId as int?,
      manufacturerId: identical(manufacturerId, _unset)
          ? this.manufacturerId
          : manufacturerId as int?,
      priceFrom: identical(priceFrom, _unset)
          ? this.priceFrom
          : priceFrom as int?,
      priceTo: identical(priceTo, _unset) ? this.priceTo : priceTo as int?,
      sortField: sortField ?? this.sortField,
      sortAscending: sortAscending ?? this.sortAscending,
      page: page ?? 1,
      size: size ?? this.size,
      includeDeleted: includeDeleted ?? this.includeDeleted,
    );
  }

  /// Переход на другую страницу — единственное изменение, которое страницу не сбрасывает.
  @override
  ProductQuery withPage(int page) => copyWith(page: page);

  @override
  ProductQuery withSize(int size) => copyWith(size: size);

  @override
  ProductQuery withSortDirection(bool ascending) =>
      copyWith(sortAscending: ascending);

  @override
  ProductQuery withDeleted(bool includeDeleted) =>
      copyWith(includeDeleted: includeDeleted);

  @override
  ProductQuery withSearch(String search) => copyWith(search: search);

  @override
  ProductQuery withSort(String field) => copyWith(
    sortField: field,
    sortAscending: field == sortField ? !sortAscending : true,
  );

  @override
  ProductQuery cleared() => ProductQuery(
    sortField: sortField,
    sortAscending: sortAscending,
    size: size,
    includeDeleted: includeDeleted,
  );

  @override
  Map<String, String> toQueryParameters() {
    return {
      ...commonParameters(defaultSort: defaultSort),
      if (categoryId != null) 'categoryId': '$categoryId',
      if (manufacturerId != null) 'manufacturerId': '$manufacturerId',
      if (priceFrom != null) 'priceFrom': '$priceFrom',
      if (priceTo != null) 'priceTo': '$priceTo',
    };
  }

  @override
  bool operator ==(Object other) =>
      other is ProductQuery &&
      other.search == search &&
      other.categoryId == categoryId &&
      other.manufacturerId == manufacturerId &&
      other.priceFrom == priceFrom &&
      other.priceTo == priceTo &&
      other.sortField == sortField &&
      other.sortAscending == sortAscending &&
      other.page == page &&
      other.size == size &&
      other.includeDeleted == includeDeleted;

  @override
  int get hashCode => Object.hash(
    search,
    categoryId,
    manufacturerId,
    priceFrom,
    priceTo,
    sortField,
    sortAscending,
    page,
    size,
    includeDeleted,
  );

  @override
  String toString() => 'ProductQuery(${toQueryParameters()})';

  static const Object _unset = Object();
}
