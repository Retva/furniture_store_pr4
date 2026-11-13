import 'package:flutter/material.dart';

import '../models/list_query.dart';
import '../models/page_result.dart';

/// Переходы между страницами и выбор размера страницы:
/// «Всего: 40   10 ▾   |‹  ‹  2 / 4  ›  ›|».
class PaginationBar extends StatelessWidget {
  const PaginationBar({
    super.key,
    required this.result,
    required this.onPageChanged,
    required this.onSizeChanged,
  });

  final PageResult<Object?> result;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onSizeChanged;

  @override
  Widget build(BuildContext context) {
    final page = result.page;
    final last = result.totalPages;

    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      children: [
        Text('Всего: ${result.total}'),
        DropdownButton<int>(
          value: result.size,
          items: [
            for (final size in pageSizes)
              DropdownMenuItem(value: size, child: Text('$size')),
          ],
          onChanged: (value) {
            if (value != null && value != result.size) onSizeChanged(value);
          },
        ),
        IconButton(
          tooltip: 'Первая страница',
          icon: const Icon(Icons.first_page),
          onPressed: result.hasPrevious ? () => onPageChanged(1) : null,
        ),
        IconButton(
          tooltip: 'Предыдущая страница',
          icon: const Icon(Icons.chevron_left),
          onPressed: result.hasPrevious ? () => onPageChanged(page - 1) : null,
        ),
        Text('$page / $last'),
        IconButton(
          tooltip: 'Следующая страница',
          icon: const Icon(Icons.chevron_right),
          onPressed: result.hasNext ? () => onPageChanged(page + 1) : null,
        ),
        IconButton(
          tooltip: 'Последняя страница',
          icon: const Icon(Icons.last_page),
          onPressed: result.hasNext ? () => onPageChanged(last) : null,
        ),
      ],
    );
  }
}
