/// Размеры страницы, между которыми переключается пользователь.
const List<int> pageSizes = [10, 25, 50];

const int defaultPageSize = 10;

/// Общая часть условий отбора любого списка: поиск, сортировка, страница, показ удалённых.
/// Конкретные запросы — [ProductQuery] и [ManufacturerQuery] — добавляют свои фильтры. Обобщённым виджетам (полоса страниц, заголовок таблицы) хватает этой общей части.
abstract class ListQuery {
  const ListQuery({
    required this.search,
    required this.sortField,
    required this.sortAscending,
    required this.page,
    required this.size,
    required this.includeDeleted,
  });

  final String search;
  final String sortField;
  final bool sortAscending;

  final int page;
  final int size;
  final bool includeDeleted;

  bool get hasFilters;

  ListQuery withPage(int page);

  ListQuery withSize(int size);

  ListQuery withSort(String field);

  ListQuery withSortDirection(bool ascending);

  ListQuery withDeleted(bool includeDeleted);

  ListQuery withSearch(String search);

  ListQuery cleared();

  Map<String, String> toQueryParameters();

  String get path;

  String toLocation() {
    final params = toQueryParameters();
    return Uri(
      path: path,
      queryParameters: params.isEmpty ? null : params,
    ).toString();
  }

  /// Параметры запроса к API. В отличие от адреса страницы, здесь всегда
  /// передаются страница, размер и сортировка — сервер не обязан знать,
  /// какие значения клиент считает значениями по умолчанию. Фильтры
  /// называются так же, как в адресной строке.
  Map<String, String> toApiParameters() {
    final filters = {...toQueryParameters()}
      ..remove('deleted')
      ..remove('sort')
      ..remove('page')
      ..remove('size');
    return {
      ...filters,
      'sort': '$sortField,${sortAscending ? 'asc' : 'desc'}',
      'page': '$page',
      'size': '$size',
      if (includeDeleted) 'includeDeleted': 'true',
    };
  }

  Map<String, String> commonParameters({required String defaultSort}) {
    return {
      if (search.trim().isNotEmpty) 'search': search.trim(),
      if (sortField != defaultSort || !sortAscending)
        'sort': '$sortField,${sortAscending ? 'asc' : 'desc'}',
      if (page != 1) 'page': '$page',
      if (size != defaultPageSize) 'size': '$size',
      if (includeDeleted) 'deleted': 'true',
    };
  }
}

class QueryParams {
  const QueryParams._();

  static int? parseInt(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    return int.tryParse(raw.trim());
  }

  static int parsePage(String? raw) {
    final value = parseInt(raw);
    return value == null || value < 1 ? 1 : value;
  }

  static int parseSize(String? raw) {
    final value = parseInt(raw);
    return pageSizes.contains(value) ? value! : defaultPageSize;
  }

  static bool parseBool(String? raw) => raw == 'true' || raw == '1';

  static (String, bool) parseSort(
    String? raw, {
    required Set<String> allowed,
    required String fallback,
  }) {
    if (raw == null || raw.isEmpty) return (fallback, true);
    final parts = raw.split(',');
    final field = allowed.contains(parts.first) ? parts.first : fallback;
    final ascending = parts.length < 2 || parts[1].toLowerCase() != 'desc';
    return (field, ascending);
  }
}
