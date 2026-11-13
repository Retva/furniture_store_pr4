import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/validators.dart';
import '../models/product.dart';
import '../state/reference_data_notifier.dart';
import '../widgets/entity_form_page.dart';
import '../widgets/form_fields.dart';

/// Форма товара — одна и для создания, и для изменения. В ней все три вида
/// связей, доступные товару: производитель (многие к одному), категории и
/// материалы (многие ко многим). Выбор производителя сужает список
/// материалов до тех, с которыми он работает.
class ProductFormScreen extends StatelessWidget {
  const ProductFormScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final refs = context.watch<ReferenceDataNotifier>();

    Map<int, String> materialsOf(int? manufacturerId) {
      final allowed = refs.manufacturerOf(manufacturerId ?? -1)?.materialIds;
      if (allowed == null) return const {};
      return {
        for (final m in refs.activeMaterials)
          if (allowed.contains(m.id)) m.id: m.name,
      };
    }

    return EntityFormPage<Product>(
      basePath: '/products',
      newTitle: 'Новый товар',
      editTitle: 'Изменение товара',
      initialValues: (p) => {
        'name': p?.name ?? '',
        'sku': p?.sku ?? '',
        'manufacturerId': p?.manufacturerId,
        'categoryIds': p?.categoryIds ?? <int>[],
        'materialIds': p?.materialIds ?? <int>[],
        'price': p?.price.toString() ?? '',
        'stock': p?.stock.toString() ?? '0',
        'widthCm': p?.widthCm.toString() ?? '',
        'depthCm': p?.depthCm.toString() ?? '',
        'heightCm': p?.heightCm.toString() ?? '',
        'color': p?.color ?? '',
        'description': p?.description ?? '',
      },
      fields: (values) => [
        TextFieldSpec(
          name: 'name',
          label: 'Название',
          validator: V.combine([V.required(), V.length(min: 3, max: 100)]),
        ),
        TextFieldSpec(
          name: 'sku',
          label: 'Артикул',
          hint: 'Например, DV-1010',
          validator: V.combine([
            V.required(),
            V.pattern(
              RegExp(r'^[A-Za-z]{2}-\d{4}$'),
              'Формат: две латинские буквы, дефис, четыре цифры',
            ),
          ]),
        ),
        DropdownFieldSpec<int>(
          name: 'manufacturerId',
          label: 'Производитель',
          requiredMessage: 'Выберите производителя',
          options: {
            for (final m in refs.activeManufacturers) m.id: m.name,
            if (values['manufacturerId'] is int &&
                refs
                        .manufacturerOf(values['manufacturerId'] as int)
                        ?.isDeleted ==
                    true)
              values['manufacturerId'] as int:
                  '${refs.manufacturerName(values['manufacturerId'] as int)} (удалён)',
          },
          onSelected: (scope, id) {
            final allowed = materialsOf(id);
            final current =
                scope.values['materialIds'] as List<int>? ?? const <int>[];
            scope.set(
              'materialIds',
              current.where(allowed.containsKey).toList(),
            );
          },
        ),
        MultiSelectFieldSpec(
          name: 'categoryIds',
          label: 'Категории',
          minCount: 1,
          options: {for (final c in refs.activeCategories) c.id: c.name},
        ),
        MultiSelectFieldSpec(
          name: 'materialIds',
          label: 'Материалы (только те, с которыми работает производитель)',
          minCount: 1,
          emptyText: 'Сначала выберите производителя',
          options: materialsOf(values['manufacturerId'] as int?),
        ),
        RowSpec([
          TextFieldSpec(
            name: 'price',
            label: 'Цена, ₽',
            digitsOnly: true,
            validator: V.combine([V.required(), V.positive(max: 10000000)]),
          ),
          TextFieldSpec(
            name: 'stock',
            label: 'Остаток, шт.',
            digitsOnly: true,
            validator: V.combine([V.required(), V.nonNegative(max: 10000)]),
          ),
        ]),
        RowSpec([
          for (final (key, label) in [
            ('widthCm', 'Ширина, см'),
            ('depthCm', 'Глубина, см'),
            ('heightCm', 'Высота, см'),
          ])
            TextFieldSpec(
              name: key,
              label: label,
              digitsOnly: true,
              validator: V.combine([V.required(), V.integer(min: 1, max: 500)]),
            ),
        ]),
        TextFieldSpec(
          name: 'color',
          label: 'Цвет',
          validator: V.combine([V.required(), V.length(min: 2, max: 40)]),
        ),
        TextFieldSpec(
          name: 'description',
          label: 'Описание',
          maxLines: 3,
          validator: V.length(max: 500),
        ),
      ],
      build: (v, original) => Product(
        id: original?.id ?? 0,
        name: (v['name'] as String).trim(),
        sku: (v['sku'] as String).trim().toUpperCase(),
        manufacturerId: v['manufacturerId'] as int,
        categoryIds: List<int>.of(v['categoryIds'] as List<int>),
        materialIds: List<int>.of(v['materialIds'] as List<int>),
        price: int.parse(v['price'] as String),
        stock: int.parse(v['stock'] as String),
        widthCm: int.parse(v['widthCm'] as String),
        depthCm: int.parse(v['depthCm'] as String),
        heightCm: int.parse(v['heightCm'] as String),
        color: (v['color'] as String).trim(),
        description: (v['description'] as String).trim(),
      ),
    );
  }
}
