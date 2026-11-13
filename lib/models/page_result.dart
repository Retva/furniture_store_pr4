/// Одна страница списка и сведения о том, сколько всего записей.
class PageResult<T> {
  const PageResult({
    required this.items,
    required this.page,
    required this.size,
    required this.total,
  });

  /// Пустая страница — начальное значение.
  PageResult.empty({this.size = 10}) : items = <T>[], page = 1, total = 0;

  final List<T> items;

  final int page;
  final int size;

  final int total;

  int get totalPages => total == 0 ? 1 : (total / size).ceil();
  bool get hasPrevious => page > 1;
  bool get hasNext => page < totalPages;
  bool get isEmpty => items.isEmpty;

  int get firstIndex => total == 0 ? 0 : (page - 1) * size + 1;
  int get lastIndex => firstIndex == 0 ? 0 : firstIndex + items.length - 1;
}
