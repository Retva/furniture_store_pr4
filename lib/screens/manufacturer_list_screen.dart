import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/manufacturer.dart';
import '../models/manufacturer_query.dart';
import '../state/manufacturer_list_notifier.dart';
import '../state/reference_data_notifier.dart';
import '../widgets/entity_list_page.dart';
import '../widgets/entity_table.dart';
import '../widgets/manufacturer_filters.dart';

class ManufacturerListScreen extends StatelessWidget {
  const ManufacturerListScreen({super.key, required this.query});

  final ManufacturerQuery query;

  @override
  Widget build(BuildContext context) {
    final refs = context.watch<ReferenceDataNotifier>();
    return EntityListPage<
      Manufacturer,
      ManufacturerQuery,
      ManufacturerListNotifier
    >(
      query: query,
      basePath: '/manufacturers',
      createLabel: 'Добавить производителя',
      emptyTitle: 'Производителей пока нет',
      nameOf: (m) => m.name,
      filters: (q, go, compact) => ManufacturerFilters(
        query: q,
        countries: refs.countries,
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
          label: 'Страна',
          sortField: 'country',
          build: (m) => Text(m.country),
        ),
        TableColumnSpec(label: 'Город', build: (m) => Text(m.city)),
        TableColumnSpec(
          label: 'Основан',
          sortField: 'foundedYear',
          numeric: true,
          build: (m) => Text('${m.foundedYear}'),
        ),
        TableColumnSpec(
          label: 'Почта',
          build: (m) => Text(m.email.isEmpty ? '—' : m.email),
        ),
      ],
      cardSubtitle: (m) => '${m.country}, ${m.city}',
      cardDetails: (m) => Text('Основан в ${m.foundedYear} году'),
    );
  }
}
