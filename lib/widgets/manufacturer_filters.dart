import 'package:flutter/material.dart';

import '../models/manufacturer_query.dart';
import 'debounced_text_field.dart';
import 'sort_control.dart';

/// Поиск и фильтр по стране для списка производителей.
class ManufacturerFilters extends StatelessWidget {
  const ManufacturerFilters({
    super.key,
    required this.query,
    required this.countries,
    required this.onChanged,
    required this.compact,
  });

  final ManufacturerQuery query;
  final List<String> countries;
  final ValueChanged<ManufacturerQuery> onChanged;
  final bool compact;

  static const Map<String, String> sortLabels = {
    'name': 'Название',
    'country': 'Страна',
    'foundedYear': 'Год основания',
  };

  @override
  Widget build(BuildContext context) {
    final selected = query.country;
    // Страна из адреса может не совпасть ни с одной из списка — тогда
    // добавляем её, иначе выпадающий список упадёт.
    final options = [
      ...countries,
      if (selected != null && !countries.contains(selected)) selected,
    ];

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
              width: width(320),
              child: DebouncedTextField(
                value: query.search,
                label: 'Поиск: название или страна',
                onChanged: (text) => onChanged(query.copyWith(search: text)),
              ),
            ),
            SizedBox(
              width: width(220),
              child: DropdownButtonFormField<String?>(
                key: ValueKey('country-$selected'),
                initialValue: selected,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Страна',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Все страны'),
                  ),
                  for (final country in options)
                    DropdownMenuItem<String?>(
                      value: country,
                      child: Text(country),
                    ),
                ],
                onChanged: (value) {
                  if (value != selected) {
                    onChanged(query.copyWith(country: value));
                  }
                },
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Switch(
                  value: query.includeDeleted,
                  onChanged: (value) =>
                      onChanged(query.copyWith(includeDeleted: value)),
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
                onDirectionToggled: () => onChanged(
                  query.copyWith(sortAscending: !query.sortAscending),
                ),
              ),
          ],
        );
      },
    );
  }
}
