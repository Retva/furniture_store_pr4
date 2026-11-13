import 'list_query.dart';

/// Настройки списка, у которого из фильтров — поиск и один выпадающий
/// список: категории, материалы, покупатели.
class QuerySpec {
  const QuerySpec({
    required this.path,
    required this.sortFields,
    this.defaultSort = 'name',
    this.filterKey,
  });

  final String path;
  final Set<String> sortFields;
  final String defaultSort;

  /// Имя параметра адреса для дополнительного фильтра: `kind`, `card`.
  final String? filterKey;
}

const categoryQuerySpec = QuerySpec(path: '/categories', sortFields: {'name'});

const materialQuerySpec = QuerySpec(
  path: '/materials',
  sortFields: {'name', 'kind', 'origin'},
  filterKey: 'kind',
);

const customerQuerySpec = QuerySpec(
  path: '/customers',
  sortFields: {'fullName', 'email', 'discount'},
  defaultSort: 'fullName',
  filterKey: 'card',
);

/// Условия отбора для категорий, материалов и покупателей. Поведение то же,
/// что у [ListQuery]: всё переводится в адрес и обратно.
class BasicQuery extends ListQuery {
  const BasicQuery({
    required this.spec,
    super.search = '',
    this.filter,
    String? sortField,
    super.sortAscending = true,
    super.page = 1,
    super.size = defaultPageSize,
    super.includeDeleted = false,
  }) : super(sortField: sortField ?? '');

  factory BasicQuery.fromParameters(
    QuerySpec spec,
    Map<String, String> params,
  ) {
    final (sortField, sortAscending) = QueryParams.parseSort(
      params['sort'],
      allowed: spec.sortFields,
      fallback: spec.defaultSort,
    );
    final key = spec.filterKey;
    final filter = key == null ? null : params[key]?.trim();
    return BasicQuery(
      spec: spec,
      search: params['search'] ?? '',
      filter: filter == null || filter.isEmpty ? null : filter,
      sortField: sortField,
      sortAscending: sortAscending,
      page: QueryParams.parsePage(params['page']),
      size: QueryParams.parseSize(params['size']),
      includeDeleted: QueryParams.parseBool(params['deleted']),
    );
  }

  final QuerySpec spec;
  final String? filter;

  /// Поле сортировки с учётом значения по умолчанию: в const-конструкторе
  /// его нельзя взять из [spec], поэтому пустая строка означает «по умолчанию».
  @override
  String get sortField =>
      super.sortField.isEmpty ? spec.defaultSort : super.sortField;

  @override
  String get path => spec.path;

  @override
  bool get hasFilters => search.trim().isNotEmpty || filter != null;

  BasicQuery copyWith({
    String? search,
    Object? filter = _unset,
    String? sortField,
    bool? sortAscending,
    int? page,
    int? size,
    bool? includeDeleted,
  }) {
    return BasicQuery(
      spec: spec,
      search: search ?? this.search,
      filter: identical(filter, _unset) ? this.filter : filter as String?,
      sortField: sortField ?? this.sortField,
      sortAscending: sortAscending ?? this.sortAscending,
      page: page ?? 1,
      size: size ?? this.size,
      includeDeleted: includeDeleted ?? this.includeDeleted,
    );
  }

  @override
  BasicQuery withPage(int page) => copyWith(page: page);

  @override
  BasicQuery withSize(int size) => copyWith(size: size);

  @override
  BasicQuery withSort(String field) => copyWith(
    sortField: field,
    sortAscending: field == sortField ? !sortAscending : true,
  );

  @override
  BasicQuery withSortDirection(bool ascending) =>
      copyWith(sortAscending: ascending);

  @override
  BasicQuery withDeleted(bool includeDeleted) =>
      copyWith(includeDeleted: includeDeleted);

  @override
  BasicQuery withSearch(String search) => copyWith(search: search);

  BasicQuery withFilter(String? filter) => copyWith(filter: filter);

  @override
  BasicQuery cleared() => BasicQuery(
    spec: spec,
    sortField: sortField,
    sortAscending: sortAscending,
    size: size,
    includeDeleted: includeDeleted,
  );

  @override
  Map<String, String> toQueryParameters() {
    final key = spec.filterKey;
    return {
      ...commonParameters(defaultSort: spec.defaultSort),
      if (key != null && filter != null) key: filter!,
    };
  }

  @override
  bool operator ==(Object other) =>
      other is BasicQuery &&
      other.spec.path == spec.path &&
      other.search == search &&
      other.filter == filter &&
      other.sortField == sortField &&
      other.sortAscending == sortAscending &&
      other.page == page &&
      other.size == size &&
      other.includeDeleted == includeDeleted;

  @override
  int get hashCode => Object.hash(
    spec.path,
    search,
    filter,
    sortField,
    sortAscending,
    page,
    size,
    includeDeleted,
  );

  static const Object _unset = Object();
}
