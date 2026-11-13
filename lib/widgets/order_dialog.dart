import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api/api_exception.dart';
import '../core/formatting.dart';
import '../core/validators.dart';
import '../models/customer.dart';
import '../models/order.dart';
import '../models/product.dart';
import '../repositories/customer_repository.dart';
import '../repositories/order_repository.dart';
import '../repositories/repository_exception.dart';

/// Диалог оформления заказа на товар. Возвращает созданный заказ или
/// `null`, если диалог закрыли.
///
/// Остаток проверяет сервер. Если товара не хватает, он отвечает 409, и
/// текст ответа показывается прямо в диалоге — данные формы сохраняются,
/// можно уменьшить количество и отправить ещё раз.
Future<Order?> showOrderDialog(
  BuildContext context, {
  required Product product,
  required OrderRepository orders,
  required CustomerRepository customers,
}) => showDialog<Order>(
  context: context,
  builder: (_) =>
      _OrderDialog(product: product, orders: orders, customers: customers),
);

class _OrderDialog extends StatefulWidget {
  const _OrderDialog({
    required this.product,
    required this.orders,
    required this.customers,
  });

  final Product product;
  final OrderRepository orders;
  final CustomerRepository customers;

  @override
  State<_OrderDialog> createState() => _OrderDialogState();
}

class _OrderDialogState extends State<_OrderDialog> {
  final _formKey = GlobalKey<FormState>();
  final _quantity = TextEditingController(text: '1');

  late Future<List<Customer>> _customers = _loadCustomers();
  int? _customerId;
  bool _sending = false;
  String? _conflict;
  Map<String, String> _fieldErrors = {};

  Future<List<Customer>> _loadCustomers() async {
    final all = await widget.customers.findAll(includeDeleted: false);
    return [...all]..sort((a, b) => a.fullName.compareTo(b.fullName));
  }

  @override
  void dispose() {
    _quantity.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _conflict = null;
      _fieldErrors = {};
    });
    if (!_formKey.currentState!.validate()) return;

    setState(() => _sending = true);
    try {
      final order = await widget.orders.place(
        customerId: _customerId!,
        productId: widget.product.id,
        quantity: int.parse(_quantity.text),
      );
      if (mounted) Navigator.of(context).pop(order);
    } on ConflictException catch (e) {
      setState(() => _conflict = e.message);
    } on ValidationException catch (e) {
      setState(() => _fieldErrors = e.errors);
      _formKey.currentState!.validate();
    } on RepositoryException catch (e) {
      setState(() => _conflict = e.message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final scheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: const Text('Оформить заказ'),
      content: SizedBox(
        width: 420,
        child: FutureBuilder<List<Customer>>(
          future: _customers,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const SizedBox(
                height: 120,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError) {
              final error = snapshot.error;
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    error is RepositoryException
                        ? error.message
                        : 'Не удалось загрузить покупателей',
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () =>
                        setState(() => _customers = _loadCustomers()),
                    child: const Text('Повторить'),
                  ),
                ],
              );
            }
            final customers = snapshot.data!;
            return Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(p.name, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    '${formatPrice(p.price)} · на складе: ${formatStock(p.stock)}',
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    initialValue: _customerId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Покупатель',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final c in customers)
                        DropdownMenuItem(
                          value: c.id,
                          child: Text(
                            c.hasCard
                                ? '${c.fullName} (скидка ${c.card!.discountPercent} %)'
                                : c.fullName,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    validator: (v) => v == null
                        ? 'Выберите покупателя'
                        : _fieldErrors['customerId'],
                    onChanged: (v) => setState(() => _customerId = v),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _quantity,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Количество, шт.',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        V.combine([V.required(), V.integer(min: 1, max: 100)])(
                          v,
                        ) ??
                        _fieldErrors['quantity'],
                  ),
                  if (_conflict != null) ...[
                    const SizedBox(height: 16),
                    Text(_conflict!, style: TextStyle(color: scheme.error)),
                  ],
                ],
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: _sending ? null : () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: _sending ? null : _submit,
          child: _sending
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Оформить'),
        ),
      ],
    );
  }
}
