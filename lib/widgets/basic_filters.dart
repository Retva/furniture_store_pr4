import 'package:flutter/material.dart';

import '../models/basic_query.dart';
import 'debounced_text_field.dart';
import 'sort_control.dart';

/// Поиск, один выпадающий фильтр и показ удалённых — для категорий,
/// материалов и покупателей.
class BasicFilters extends StatelessWidget {
  const BasicFilters({
    super.key,
    required this.query,
    required this.searchLabel,
    required this.onChanged,
    required this.compact,
    required this.sortLabels,
    this.filterLabel,
    this.filterOptions = const {},
  });

  final BasicQuery query;
  final String searchLabel;
  final ValueChanged<BasicQuery> onChanged;
  final bool compact;
  final Map<String, String> sortLabels;
  final String? filterLabel;

  /// Значение фильтра → подпись.
  final Map<String, String> filterOptions;

  @override
  Widget build(BuildContext context) {
    final selected = query.filter;
    return LayoutBuilder(
      builder: (context, constraints) {
        double width(double desired) =>
            compact ? constraints.maxWidth : desired;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: width(280),
              child: DebouncedTextField(
                value: query.search,
                label: searchLabel,
                onChanged: (text) => onChanged(query.withSearch(text)),
              ),
            ),
            if (filterLabel != null)
              SizedBox(
                width: width(200),
                child: DropdownButtonFormField<String?>(
                  key: ValueKey('${query.path}-filter-$selected'),
                  initialValue: filterOptions.containsKey(selected)
                      ? selected
                      : null,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: filterLabel,
                    border: const OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Все'),
                    ),
                    for (final entry in filterOptions.entries)
                      DropdownMenuItem<String?>(
                        value: entry.key,
                        child: Text(entry.value),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != selected) onChanged(query.withFilter(value));
                  },
                ),
              ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Switch(
                  value: query.includeDeleted,
                  onChanged: (value) => onChanged(query.withDeleted(value)),
                ),
                const SizedBox(width: 6),
                const Text('Удалённые'),
              ],
            ),
            TextButton(
              onPressed: query.hasFilters
                  ? () => onChanged(query.cleared())
                  : null,
              child: const Text('Сбросить'),
            ),
            if (compact)
              SortControl(
                fields: sortLabels,
                field: query.sortField,
                ascending: query.sortAscending,
                onFieldChanged: (field) => onChanged(
                  query.copyWith(sortField: field, sortAscending: true),
                ),
                onDirectionToggled: () =>
                    onChanged(query.withSortDirection(!query.sortAscending)),
              ),
          ],
        );
      },
    );
  }
}
