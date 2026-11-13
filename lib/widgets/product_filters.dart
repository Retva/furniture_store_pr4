import 'package:flutter/material.dart';

import '../models/manufacturer.dart';
import '../models/product_category.dart';
import '../models/product_query.dart';
import 'debounced_text_field.dart';
import 'sort_control.dart';

/// Поиск и фильтры каталога.
///
/// Своего состояния у панели нет: она показывает [query], пришедший из
/// адреса, а любое изменение отдаёт наружу новым запросом через
/// [onChanged]. Экран превращает его в новый адрес.
class ProductFilters extends StatelessWidget {
  const ProductFilters({
    super.key,
    required this.query,
    required this.categories,
    required this.manufacturers,
    required this.onChanged,
    required this.compact,
  });

  final ProductQuery query;
  final List<ProductCategory> categories;

  /// Действующие производители для выпадающего списка.
  final List<Manufacturer> manufacturers;
  final ValueChanged<ProductQuery> onChanged;

  /// Узкое окно: поля во всю ширину и выбор сортировки вместо заголовков.
  final bool compact;

  static const Map<String, String> sortLabels = {
    'name': 'Название',
    'sku': 'Артикул',
    'price': 'Цена',
    'stock': 'Остаток',
  };

  @override
  Widget build(BuildContext context) {
    final rangeInvalid =
        query.priceFrom != null &&
        query.priceTo != null &&
        query.priceFrom! > query.priceTo!;

    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 12.0;
        final full = constraints.maxWidth;
        // На узком окне поля встают во всю ширину, цены — по две в ряд.
        double width(double desired) => compact ? full : desired;
        final priceWidth = compact ? (full - gap) / 2 : 120.0;

        // Wrap, а не Row: элементы, которые не помещаются, переносятся на
        // следующую строку, а не вылезают за край с жёлто-чёрной полосой.
        // Expanded внутри Wrap не работает, поэтому ширины заданы явно.
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: width(240),
              child: DebouncedTextField(
                value: query.search,
                label: 'Поиск: товар или артикул',
                onChanged: (text) => onChanged(query.copyWith(search: text)),
              ),
            ),
            SizedBox(
              width: width(180),
              child: _Dropdown(
                label: 'Категория',
                anyLabel: 'Все категории',
                value: query.categoryId,
                options: {for (final c in categories) c.id: c.name},
                onChanged: (id) => onChanged(query.copyWith(categoryId: id)),
              ),
            ),
            SizedBox(
              width: width(200),
              child: _Dropdown(
                label: 'Производитель',
                anyLabel: 'Все производители',
                value: query.manufacturerId,
                options: {for (final m in manufacturers) m.id: m.name},
                onChanged: (id) =>
                    onChanged(query.copyWith(manufacturerId: id)),
              ),
            ),
            SizedBox(
              width: priceWidth,
              child: DebouncedTextField(
                value: query.priceFrom?.toString() ?? '',
                label: 'Цена от',
                digitsOnly: true,
                onChanged: (text) =>
                    onChanged(query.copyWith(priceFrom: int.tryParse(text))),
              ),
            ),
            SizedBox(
              width: priceWidth,
              child: DebouncedTextField(
                value: query.priceTo?.toString() ?? '',
                label: 'Цена до',
                digitsOnly: true,
                errorText: rangeInvalid ? 'Меньше, чем «от»' : null,
                onChanged: (text) =>
                    onChanged(query.copyWith(priceTo: int.tryParse(text))),
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

/// Выпадающий список «любое значение или одно из справочника».
///
/// Вынесен отдельно, потому что у него две тонкости, которые легко забыть.
class _Dropdown extends StatelessWidget {
  const _Dropdown({
    required this.label,
    required this.anyLabel,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final String anyLabel;
  final int? value;
  final Map<int, String> options;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    // Первая тонкость: значение из адреса может отсутствовать в списке —
    // справочник ещё грузится или производителя удалили. DropdownButton в
    // таком случае падает с ошибкой, поэтому добавляем пункт-заглушку.
    final items = {
      ...options,
      if (value != null && !options.containsKey(value)) value!: '№ $value',
    };

    return DropdownButtonFormField<int?>(
      // Вторая тонкость: поле формы запоминает начальное значение и потом
      // его не перечитывает. После «назад» в браузере значение в адресе
      // другое, а поле показывало бы старое. Ключ по значению заставляет
      // создать поле заново.
      key: ValueKey('$label-$value'),
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: [
        DropdownMenuItem<int?>(value: null, child: Text(anyLabel)),
        for (final entry in items.entries)
          DropdownMenuItem<int?>(
            value: entry.key,
            child: Text(entry.value, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: (id) {
        if (id != value) onChanged(id);
      },
    );
  }
}
