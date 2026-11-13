import 'package:dio/dio.dart';

import '../api/api_exception.dart';
import '../models/order.dart';

/// Оформление заказов. Есть только у сервера: остатки и скидки считает он.
abstract interface class OrderRepository {
  /// Бросает [ConflictException] (409), если товара на складе меньше,
  /// чем заказано, и [ApiValidationException] (422) при неверных данных.
  Future<Order> place({
    required int customerId,
    required int productId,
    required int quantity,
  });

  Future<List<Order>> forProduct(int productId);

  Future<Order> cancel(int orderId);
}

class ApiOrderRepository implements OrderRepository {
  ApiOrderRepository(this.dio);

  final Dio dio;

  @override
  Future<Order> place({
    required int customerId,
    required int productId,
    required int quantity,
  }) => guard(() async {
    final response = await dio.post<Map<String, dynamic>>(
      '/orders',
      data: {
        'customerId': customerId,
        'productId': productId,
        'quantity': quantity,
      },
    );
    return Order.fromJson(response.data!);
  });

  @override
  Future<List<Order>> forProduct(int productId) => guard(() async {
    final response = await dio.get<Map<String, dynamic>>(
      '/orders',
      queryParameters: {'productId': productId, 'size': 100, 'sort': 'id,desc'},
    );
    return [
      for (final row in response.data!['items'] as List)
        Order.fromJson((row as Map).cast<String, dynamic>()),
    ];
  });

  @override
  Future<Order> cancel(int orderId) => guard(() async {
    final response = await dio.post<Map<String, dynamic>>(
      '/orders/$orderId/cancel',
    );
    return Order.fromJson(response.data!);
  });
}
