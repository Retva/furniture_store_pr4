import 'json_read.dart';

/// Заказ покупателя на товар. Создаётся на сервере: он проверяет остаток,
/// списывает товар со склада и считает сумму со скидкой по карте.
class Order {
  const Order({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.total,
    required this.createdAt,
    this.cancelledAt,
  });

  final int id;
  final int customerId;
  final String customerName;
  final int productId;
  final String productName;
  final int quantity;
  final int total;
  final DateTime createdAt;
  final DateTime? cancelledAt;

  bool get isCancelled => cancelledAt != null;

  factory Order.fromJson(Map<String, dynamic> json) {
    final customer = JsonRead.map(json['customer']) ?? const {};
    final product = JsonRead.map(json['product']) ?? const {};
    return Order(
      id: JsonRead.integer(json['id']),
      customerId: JsonRead.refId(json, 'customerId', 'customer'),
      customerName: JsonRead.text(customer['fullName']),
      productId: JsonRead.refId(json, 'productId', 'product'),
      productName: JsonRead.text(product['name']),
      quantity: JsonRead.integer(json['quantity']),
      total: JsonRead.integer(json['total']),
      createdAt: JsonRead.date(json['createdAt']) ?? DateTime.now(),
      cancelledAt: JsonRead.date(json['cancelledAt']),
    );
  }
}
