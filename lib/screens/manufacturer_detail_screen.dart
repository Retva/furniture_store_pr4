import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/manufacturer.dart';
import '../models/product_query.dart';
import '../state/manufacturer_list_notifier.dart';
import '../state/reference_data_notifier.dart';
import '../widgets/entity_detail_page.dart';

class ManufacturerDetailScreen extends StatelessWidget {
  const ManufacturerDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final refs = context.watch<ReferenceDataNotifier>();
    return EntityDetailPage<Manufacturer>(
      basePath: '/manufacturers',
      backLabel: 'К производителям',
      backLocation: (c) =>
          c.read<ManufacturerListNotifier>().query.toLocation(),
      title: (m) => m.name,
      subtitle: (m) => '${m.country}, ${m.city}',
      rows: (context, m) => [
        ('Страна', Text(m.country)),
        ('Город', Text(m.city)),
        ('Год основания', Text('${m.foundedYear}')),
        ('Почта', Text(m.email.isEmpty ? '—' : m.email)),
        ('Сайт', Text(m.website.isEmpty ? '—' : m.website)),
        ('Материалы', Text(refs.materialNames(m.materialIds))),
        ('Описание', Text(m.description.isEmpty ? '—' : m.description)),
      ],
      extraActions: (context, m) => [
        OutlinedButton.icon(
          onPressed: () =>
              context.go(ProductQuery(manufacturerId: m.id).toLocation()),
          icon: const Icon(Icons.chair_outlined),
          label: const Text('Товары производителя'),
        ),
      ],
    );
  }
}
