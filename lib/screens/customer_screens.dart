import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/formatting.dart';
import '../core/validators.dart';
import '../models/basic_query.dart';
import '../models/customer.dart';
import '../state/other_list_notifiers.dart';
import '../widgets/basic_filters.dart';
import '../widgets/entity_detail_page.dart';
import '../widgets/entity_form_page.dart';
import '../widgets/entity_list_page.dart';
import '../widgets/entity_table.dart';
import '../widgets/form_fields.dart';

String _cardText(Customer c) => c.card == null
    ? 'нет'
    : '№ ${c.card!.number}, скидка ${c.card!.discountPercent}%';

class CustomerListScreen extends StatelessWidget {
  const CustomerListScreen({super.key, required this.query});

  final BasicQuery query;

  @override
  Widget build(BuildContext context) {
    return EntityListPage<Customer, BasicQuery, CustomerListNotifier>(
      query: query,
      basePath: '/customers',
      createLabel: 'Добавить покупателя',
      emptyTitle: 'Покупателей пока нет',
      nameOf: (c) => c.fullName,
      filters: (q, go, compact) => BasicFilters(
        query: q,
        searchLabel: 'Поиск: ФИО, почта или телефон',
        filterLabel: 'Дисконтная карта',
        filterOptions: const {'yes': 'Есть карта', 'no': 'Нет карты'},
        sortLabels: const {
          'fullName': 'ФИО',
          'email': 'Почта',
          'discount': 'Скидка',
        },
        compact: compact,
        onChanged: go,
      ),
      columns: (open) => [
        nameColumn(
          label: 'ФИО',
          sortField: 'fullName',
          text: (c) => c.fullName,
          onOpen: open,
        ),
        TableColumnSpec(
          label: 'Почта',
          sortField: 'email',
          build: (c) => Text(c.email),
        ),
        TableColumnSpec(label: 'Телефон', build: (c) => Text(c.phone)),
        TableColumnSpec(
          label: 'Карта',
          sortField: 'discount',
          build: (c) => Text(_cardText(c)),
        ),
      ],
      cardSubtitle: (c) => '${c.email} · ${c.phone}',
      cardDetails: (c) => Text('Карта: ${_cardText(c)}'),
    );
  }
}

class CustomerDetailScreen extends StatelessWidget {
  const CustomerDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return EntityDetailPage<Customer>(
      basePath: '/customers',
      backLabel: 'К покупателям',
      backLocation: (c) => c.read<CustomerListNotifier>().query.toLocation(),
      title: (c) => c.fullName,
      subtitle: (c) => c.email,
      rows: (context, c) => [
        ('Почта', Text(c.email)),
        ('Телефон', Text(c.phone.isEmpty ? '—' : c.phone)),
        (
          'Дисконтная карта',
          Text(c.card == null ? 'не выдана' : '№ ${c.card!.number}'),
        ),
        if (c.card != null) ...[
          ('Скидка', Text('${c.card!.discountPercent}%')),
          ('Дата выдачи', Text(formatDate(c.card!.issuedAt))),
        ],
      ],
    );
  }
}

/// Форма покупателя. Дисконтная карта (связь один к одному) — вложенная
/// группа полей прямо в форме, отдельного экрана у карты нет.
class CustomerFormScreen extends StatelessWidget {
  const CustomerFormScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return EntityFormPage<Customer>(
      basePath: '/customers',
      newTitle: 'Новый покупатель',
      editTitle: 'Изменение покупателя',
      initialValues: (c) => {
        'fullName': c?.fullName ?? '',
        'email': c?.email ?? '',
        'phone': c?.phone ?? '',
        'hasCard': c?.card != null,
        'cardNumber': c?.card?.number ?? '',
        'discountPercent': c?.card?.discountPercent.toString() ?? '5',
        'issuedAt': formatDate(c?.card?.issuedAt ?? DateTime.now()),
      },
      fields: (values) => [
        TextFieldSpec(
          name: 'fullName',
          label: 'ФИО',
          validator: V.combine([
            V.required(),
            V.length(min: 5, max: 100),
            V.pattern(
              RegExp(r'^[А-Яа-яЁёA-Za-z\- ]+$'),
              'Только буквы, пробелы и дефис',
            ),
          ]),
        ),
        RowSpec([
          TextFieldSpec(
            name: 'email',
            label: 'Почта',
            keyboardType: TextInputType.emailAddress,
            validator: V.combine([V.required(), V.email(), V.length(max: 100)]),
          ),
          TextFieldSpec(
            name: 'phone',
            label: 'Телефон',
            hint: '+7 (900) 123-45-67',
            keyboardType: TextInputType.phone,
            validator: V.combine([V.required(), V.phone()]),
          ),
        ]),
        const SwitchFieldSpec(
          name: 'hasCard',
          label: 'Выдать дисконтную карту',
        ),
        if (values['hasCard'] == true)
          SectionSpec(
            title: 'Дисконтная карта',
            children: [
              RowSpec([
                TextFieldSpec(
                  name: 'cardNumber',
                  label: 'Номер карты',
                  digitsOnly: true,
                  validator: V.combine([
                    V.required(),
                    V.pattern(RegExp(r'^\d{8}$'), 'Ровно 8 цифр'),
                  ]),
                ),
                TextFieldSpec(
                  name: 'discountPercent',
                  label: 'Скидка, %',
                  digitsOnly: true,
                  validator: V.combine([
                    V.required(),
                    V.integer(min: 1, max: 30),
                  ]),
                ),
                TextFieldSpec(
                  name: 'issuedAt',
                  label: 'Дата выдачи',
                  hint: 'ДД.ММ.ГГГГ',
                  validator: V.combine([V.required(), V.pastDate()]),
                ),
              ]),
            ],
          ),
      ],
      build: (v, original) => Customer(
        id: original?.id ?? 0,
        fullName: (v['fullName'] as String).trim(),
        email: (v['email'] as String).trim().toLowerCase(),
        phone: (v['phone'] as String).trim(),
        card: v['hasCard'] == true
            ? DiscountCard(
                number: (v['cardNumber'] as String).trim(),
                discountPercent: int.parse(v['discountPercent'] as String),
                issuedAt: V.parseDate(v['issuedAt'] as String)!,
              )
            : null,
      ),
    );
  }
}
