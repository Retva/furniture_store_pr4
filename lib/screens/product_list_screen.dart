import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/formatting.dart';
import '../models/product.dart';
import '../models/product_query.dart';
import '../state/product_list_notifier.dart';
import '../state/reference_data_notifier.dart';
import '../widgets/entity_list_page.dart';
import '../widgets/entity_table.dart';
import '../widgets/product_filters.dart';

class ProductListScreen extends StatelessWidget {
  const ProductListScreen({super.key, required this.query});

  final ProductQuery query;

  @override
  Widget build(BuildContext context) {
    final refs = context.watch<ReferenceDataNotifier>();
    return EntityListPage<Product, ProductQuery, ProductListNotifier>(
      query: query,
      basePath: '/products',
      createLabel: 'Добавить товар',
      emptyTitle: 'В каталоге пока нет товаров',
      nameOf: (p) => p.name,
      filters: (q, go, compact) => ProductFilters(
        query: q,
        categories: refs.activeCategories,
        manufacturers: refs.activeManufacturers,
        compact: compact,
        onChanged: go,
      ),
      columns: (open) => [
        TableColumnSpec(
          label: 'Артикул',
          sortField: 'sku',
          build: (p) => Text(p.sku),
        ),
        nameColumn(
          label: 'Название',
          sortField: 'name',
          text: (p) => p.name,
          onOpen: open,
        ),
        TableColumnSpec(
          label: 'Категории',
          build: (p) => Text(refs.categoryNames(p.categoryIds)),
        ),
        TableColumnSpec(
          label: 'Производитель',
          build: (p) => Text(refs.manufacturerName(p.manufacturerId)),
        ),
        TableColumnSpec(
          label: 'Цена',
          sortField: 'price',
          numeric: true,
          build: (p) => Text(formatPrice(p.price)),
        ),
        TableColumnSpec(
          label: 'Остаток',
          sortField: 'stock',
          numeric: true,
          build: (p) => Text(formatStock(p.stock)),
        ),
      ],
      cardSubtitle: (p) =>
          '${p.sku} · ${refs.categoryNames(p.categoryIds)} · ${refs.manufacturerName(p.manufacturerId)}',
      cardDetails: (p) =>
          Text('${formatPrice(p.price)} · ${formatStock(p.stock)}'),
    );
  }
}
