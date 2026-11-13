import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/validators.dart';
import '../models/manufacturer.dart';
import '../state/reference_data_notifier.dart';
import '../widgets/entity_form_page.dart';
import '../widgets/form_fields.dart';

class ManufacturerFormScreen extends StatelessWidget {
  const ManufacturerFormScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final refs = context.watch<ReferenceDataNotifier>();
    final year = DateTime.now().year;

    return EntityFormPage<Manufacturer>(
      basePath: '/manufacturers',
      newTitle: 'Новый производитель',
      editTitle: 'Изменение производителя',
      initialValues: (m) => {
        'name': m?.name ?? '',
        'country': m?.country ?? '',
        'city': m?.city ?? '',
        'foundedYear': m?.foundedYear.toString() ?? '',
        'email': m?.email ?? '',
        'website': m?.website ?? '',
        'materialIds': m?.materialIds ?? <int>[],
        'description': m?.description ?? '',
      },
      fields: (values) => [
        TextFieldSpec(
          name: 'name',
          label: 'Название',
          validator: V.combine([V.required(), V.length(min: 2, max: 80)]),
        ),
        RowSpec([
          TextFieldSpec(
            name: 'country',
            label: 'Страна',
            validator: V.combine([V.required(), V.length(min: 2, max: 60)]),
          ),
          TextFieldSpec(
            name: 'city',
            label: 'Город',
            validator: V.combine([V.required(), V.length(min: 2, max: 60)]),
          ),
        ]),
        RowSpec([
          TextFieldSpec(
            name: 'foundedYear',
            label: 'Год основания',
            digitsOnly: true,
            validator: V.combine([
              V.required(),
              V.integer(min: 1800, max: year),
            ]),
          ),
          TextFieldSpec(
            name: 'email',
            label: 'Почта',
            keyboardType: TextInputType.emailAddress,
            validator: V.combine([V.required(), V.email(), V.length(max: 100)]),
          ),
        ]),
        TextFieldSpec(
          name: 'website',
          label: 'Сайт',
          hint: 'example.ru',
          validator: V.optional(
            V.combine([
              V.pattern(
                RegExp(r'^[\w.-]+\.[a-zA-Z]{2,}(/.*)?$'),
                'Адрес сайта вида example.ru',
              ),
              V.length(max: 100),
            ]),
          ),
        ),
        MultiSelectFieldSpec(
          name: 'materialIds',
          label: 'Материалы, с которыми работает производитель',
          minCount: 1,
          options: {for (final m in refs.activeMaterials) m.id: m.name},
        ),
        TextFieldSpec(
          name: 'description',
          label: 'Описание',
          maxLines: 3,
          validator: V.length(max: 500),
        ),
      ],
      build: (v, original) => Manufacturer(
        id: original?.id ?? 0,
        name: (v['name'] as String).trim(),
        country: (v['country'] as String).trim(),
        city: (v['city'] as String).trim(),
        foundedYear: int.parse(v['foundedYear'] as String),
        email: (v['email'] as String).trim(),
        website: (v['website'] as String).trim(),
        materialIds: List<int>.of(v['materialIds'] as List<int>),
        description: (v['description'] as String).trim(),
      ),
    );
  }
}
