import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/formatting.dart';
import '../models/product.dart';
import '../models/product_query.dart';
import '../repositories/customer_repository.dart';
import '../repositories/order_repository.dart';
import '../state/entity_detail_notifier.dart';
import '../state/product_list_notifier.dart';
import '../state/reference_data_notifier.dart';
import '../widgets/entity_detail_page.dart';
import '../widgets/dialogs.dart';
import '../widgets/info_table.dart';
import '../widgets/order_dialog.dart';

class ProductDetailScreen extends StatelessWidget {
  const ProductDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final refs = context.watch<ReferenceDataNotifier>();
    final orders = context.read<OrderRepository?>();
    return EntityDetailPage<Product>(
      basePath: '/products',
      backLabel: 'К каталогу',
      backLocation: (c) => c.read<ProductListNotifier>().query.toLocation(),
      title: (p) => p.name,
      subtitle: (p) => 'Артикул ${p.sku}',
      // Заказы оформляет сервер; в режиме localStorage кнопки нет.
      extraActions: orders == null
          ? null
          : (context, p) => [
              if (!p.isDeleted)
                OutlinedButton.icon(
                  onPressed: () => _order(context, p, orders),
                  icon: const Icon(Icons.shopping_cart_outlined),
                  label: const Text('Оформить заказ'),
                ),
            ],
      rows: (context, p) {
        final manufacturer = refs.manufacturerOf(p.manufacturerId);
        return [
          ('Цена', Text(formatPrice(p.price))),
          (
            'Наличие',
            Text(
              p.inStock ? 'В наличии: ${formatStock(p.stock)}' : 'Под заказ',
            ),
          ),
          (
            'Производитель',
            manufacturer == null
                ? const Text('—')
                : InfoLink(
                    text: '${manufacturer.name} (${manufacturer.country})',
                    onTap: () =>
                        context.go('/manufacturers/${manufacturer.id}'),
                  ),
          ),
          (
            'Категории',
            Wrap(
              spacing: 12,
              children: [
                for (final id in p.categoryIds)
                  InfoLink(
                    text: refs.categoryName(id),
                    onTap: () =>
                        context.go(ProductQuery(categoryId: id).toLocation()),
                  ),
              ],
            ),
          ),
          ('Материалы', Text(refs.materialNames(p.materialIds))),
          ('Габариты (Ш × Г × В)', Text(p.dimensions)),
          ('Цвет', Text(p.color.isEmpty ? '—' : p.color)),
          ('Описание', Text(p.description.isEmpty ? '—' : p.description)),
        ];
      },
    );
  }

  Future<void> _order(
    BuildContext context,
    Product product,
    OrderRepository orders,
  ) async {
    final detail = context.read<EntityDetailNotifier<Product>>();
    final order = await showOrderDialog(
      context,
      product: product,
      orders: orders,
      customers: context.read<CustomerRepository>(),
    );
    if (order == null || !context.mounted) return;
    showMessage(
      context,
      'Заказ № ${order.id} оформлен: ${order.quantity} шт. на '
      '${formatPrice(order.total)}',
    );
    // Сервер списал товар со склада — перечитываем остаток.
    await detail.load(quiet: true);
  }
}
