import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/validators.dart';
import '../models/basic_query.dart';
import '../models/product_category.dart';
import '../models/product_query.dart';
import '../state/other_list_notifiers.dart';
import '../widgets/basic_filters.dart';
import '../widgets/entity_detail_page.dart';
import '../widgets/entity_form_page.dart';
import '../widgets/entity_list_page.dart';
import '../widgets/entity_table.dart';
import '../widgets/form_fields.dart';

class CategoryListScreen extends StatelessWidget {
  const CategoryListScreen({super.key, required this.query});

  final BasicQuery query;

  @override
  Widget build(BuildContext context) {
    return EntityListPage<ProductCategory, BasicQuery, CategoryListNotifier>(
      query: query,
      basePath: '/categories',
      createLabel: 'Добавить категорию',
      emptyTitle: 'Категорий пока нет',
      nameOf: (c) => c.name,
      filters: (q, go, compact) => BasicFilters(
        query: q,
        searchLabel: 'Поиск: название или описание',
        sortLabels: const {'name': 'Название'},
        compact: compact,
        onChanged: go,
      ),
      columns: (open) => [
        nameColumn(
          label: 'Название',
          sortField: 'name',
          text: (c) => c.name,
          onOpen: open,
        ),
        TableColumnSpec(label: 'Описание', build: (c) => Text(c.description)),
      ],
      cardSubtitle: (c) => c.description,
    );
  }
}

class CategoryDetailScreen extends StatelessWidget {
  const CategoryDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return EntityDetailPage<ProductCategory>(
      basePath: '/categories',
      backLabel: 'К категориям',
      backLocation: (c) => c.read<CategoryListNotifier>().query.toLocation(),
      title: (c) => c.name,
      rows: (context, c) => [
        ('Описание', Text(c.description.isEmpty ? '—' : c.description)),
      ],
      extraActions: (context, c) => [
        OutlinedButton.icon(
          onPressed: () =>
              context.go(ProductQuery(categoryId: c.id).toLocation()),
          icon: const Icon(Icons.chair_outlined),
          label: const Text('Товары категории'),
        ),
      ],
    );
  }
}

class CategoryFormScreen extends StatelessWidget {
  const CategoryFormScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return EntityFormPage<ProductCategory>(
      basePath: '/categories',
      newTitle: 'Новая категория',
      editTitle: 'Изменение категории',
      initialValues: (c) => {
        'name': c?.name ?? '',
        'description': c?.description ?? '',
      },
      fields: (values) => [
        TextFieldSpec(
          name: 'name',
          label: 'Название',
          validator: V.combine([V.required(), V.length(min: 2, max: 40)]),
        ),
        TextFieldSpec(
          name: 'description',
          label: 'Описание',
          maxLines: 3,
          validator: V.length(max: 200),
        ),
      ],
      build: (v, original) => ProductCategory(
        id: original?.id ?? 0,
        name: (v['name'] as String).trim(),
        description: (v['description'] as String).trim(),
      ),
    );
  }
}
