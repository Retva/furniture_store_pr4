import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/validators.dart';
import '../models/basic_query.dart';
import '../models/furniture_material.dart';
import '../state/other_list_notifiers.dart';
import '../widgets/basic_filters.dart';
import '../widgets/entity_detail_page.dart';
import '../widgets/entity_form_page.dart';
import '../widgets/entity_list_page.dart';
import '../widgets/entity_table.dart';
import '../widgets/form_fields.dart';

class MaterialListScreen extends StatelessWidget {
  const MaterialListScreen({super.key, required this.query});

  final BasicQuery query;

  @override
  Widget build(BuildContext context) {
    return EntityListPage<FurnitureMaterial, BasicQuery, MaterialListNotifier>(
      query: query,
      basePath: '/materials',
      createLabel: 'Добавить материал',
      emptyTitle: 'Материалов пока нет',
      nameOf: (m) => m.name,
      filters: (q, go, compact) => BasicFilters(
        query: q,
        searchLabel: 'Поиск: название или страна',
        filterLabel: 'Тип',
        filterOptions: {for (final k in FurnitureMaterial.kinds) k: k},
        sortLabels: const {
          'name': 'Название',
          'kind': 'Тип',
          'origin': 'Страна',
        },
        compact: compact,
        onChanged: go,
      ),
      columns: (open) => [
        nameColumn(
          label: 'Название',
          sortField: 'name',
          text: (m) => m.name,
          onOpen: open,
        ),
        TableColumnSpec(
          label: 'Тип',
          sortField: 'kind',
          build: (m) => Text(m.kind),
        ),
        TableColumnSpec(
          label: 'Страна',
          sortField: 'origin',
          build: (m) => Text(m.origin),
        ),
      ],
      cardSubtitle: (m) => '${m.kind} · ${m.origin}',
    );
  }
}

class MaterialDetailScreen extends StatelessWidget {
  const MaterialDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return EntityDetailPage<FurnitureMaterial>(
      basePath: '/materials',
      backLabel: 'К материалам',
      backLocation: (c) => c.read<MaterialListNotifier>().query.toLocation(),
      title: (m) => m.name,
      rows: (context, m) => [
        ('Тип', Text(m.kind)),
        ('Страна происхождения', Text(m.origin.isEmpty ? '—' : m.origin)),
      ],
    );
  }
}

class MaterialFormScreen extends StatelessWidget {
  const MaterialFormScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return EntityFormPage<FurnitureMaterial>(
      basePath: '/materials',
      newTitle: 'Новый материал',
      editTitle: 'Изменение материала',
      initialValues: (m) => {
        'name': m?.name ?? '',
        'kind': m?.kind,
        'origin': m?.origin ?? '',
      },
      fields: (values) => [
        TextFieldSpec(
          name: 'name',
          label: 'Название',
          validator: V.combine([V.required(), V.length(min: 2, max: 40)]),
        ),
        DropdownFieldSpec<String>(
          name: 'kind',
          label: 'Тип материала',
          requiredMessage: 'Выберите тип',
          options: {for (final k in FurnitureMaterial.kinds) k: k},
        ),
        TextFieldSpec(
          name: 'origin',
          label: 'Страна происхождения',
          validator: V.combine([V.required(), V.length(min: 2, max: 60)]),
        ),
      ],
      build: (v, original) => FurnitureMaterial(
        id: original?.id ?? 0,
        name: (v['name'] as String).trim(),
        kind: v['kind'] as String,
        origin: (v['origin'] as String).trim(),
      ),
    );
  }
}
