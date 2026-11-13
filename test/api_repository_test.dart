import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furniture_store/api/api_client.dart';
import 'package:furniture_store/api/api_exception.dart';
import 'package:furniture_store/api/api_session.dart';
import 'package:furniture_store/api/debug_options.dart';
import 'package:furniture_store/models/basic_query.dart';
import 'package:furniture_store/models/product.dart';
import 'package:furniture_store/models/product_query.dart';
import 'package:furniture_store/repositories/api/api_repositories.dart';
import 'package:furniture_store/repositories/order_repository.dart';
import 'package:furniture_store/repositories/repository_exception.dart';

/// Поддельный транспорт Dio: вместо сети вызывает [handler] и запоминает
/// все запросы. Так репозитории проверяются целиком — с перехватчиками,
/// повторами и переводом ошибок, — но без сервера.
class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.handler);

  Future<ResponseBody> Function(RequestOptions options) handler;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (cancelFuture != null) {
      // Отмена прерывает «сетевой» запрос так же, как настоящий адаптер.
      return Future.any([
        handler(options),
        cancelFuture.then<ResponseBody>(
          (_) => throw DioException.requestCancelled(
            requestOptions: options,
            reason: 'cancelled',
          ),
        ),
      ]);
    }
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody json(int status, Object? body) => ResponseBody.fromString(
  body == null ? '' : jsonEncode(body),
  status,
  headers: {
    Headers.contentTypeHeader: ['application/json; charset=utf-8'],
  },
);

/// Запрос, на который «сервер» не ответил: выключен или недоступен.
Never offline(RequestOptions options) => throw DioException.connectionError(
  requestOptions: options,
  reason: 'Connection refused',
);

Future<Object?> errorOf(Future<Object?> Function() action) async {
  try {
    await action();
  } catch (e) {
    return e;
  }
  return null;
}

/// Товар так, как его присылает сервер: связи развёрнуты в объекты.
Map<String, dynamic> productJson(int id, {String sku = 'DV-1001'}) => {
  'id': id,
  'name': 'Диван «Осло»',
  'sku': sku,
  'manufacturer': {'id': 2, 'name': 'Северный лес'},
  'categories': [
    {'id': 1, 'name': 'Диваны'},
  ],
  'materials': [
    {'id': 4, 'name': 'Массив бука'},
    {'id': 9, 'name': 'Велюр'},
  ],
  'price': 54990,
  'stock': 3,
  'widthCm': 210,
  'depthCm': 95,
  'heightCm': 85,
  'color': 'серый',
  'description': '',
  'deletedAt': null,
};

Map<String, dynamic> page(List<Object> items, {int total = 1, int size = 10}) =>
    {'items': items, 'page': 1, 'size': size, 'total': total, 'totalPages': 1};

const sofa = Product(
  id: 0,
  name: 'Диван «Осло»',
  sku: 'DV-1001',
  manufacturerId: 2,
  categoryIds: [1],
  materialIds: [4, 9],
  price: 54990,
  stock: 3,
  widthCm: 210,
  depthCm: 95,
  heightCm: 85,
  color: 'серый',
);

void main() {
  late FakeAdapter adapter;
  late ApiSession session;
  late DebugOptions debug;
  late Dio dio;
  late ApiProductRepository products;

  setUp(() {
    adapter = FakeAdapter((o) async => json(200, page([])));
    session = ApiSession(username: 'manager', password: 'manager123');
    debug = DebugOptions();
    dio = buildDio(
      baseUrl: 'http://test/api',
      session: session,
      debug: debug,
      adapter: adapter,
      log: (_) {},
      // Паузы между повторами в тестах не нужны.
      retry: const RetryPolicy(maxRetries: 3, baseDelay: Duration.zero),
    );
    products = ApiProductRepository(dio);
  });

  group('Чтение', () {
    test('поиск, фильтр, сортировка и страница уходят на сервер', () async {
      adapter.handler = (o) async =>
          json(200, page([productJson(7)], total: 31));

      final result = await products.find(
        const ProductQuery(
          search: 'диван',
          categoryId: 1,
          sortField: 'price',
          sortAscending: false,
          page: 2,
          size: 25,
        ),
      );

      final sent = adapter.requests.single;
      expect(sent.method, 'GET');
      expect(sent.uri.path, '/api/products');
      expect(sent.uri.queryParameters, {
        'search': 'диван',
        'categoryId': '1',
        'sort': 'price,desc',
        'page': '2',
        'size': '25',
      });
      expect(result.total, 31);
      expect(result.items.single.id, 7);
    });

    test('развёрнутые связи из ответа превращаются в идентификаторы', () async {
      adapter.handler = (o) async => json(200, productJson(7));

      final product = await products.findById(7);

      expect(product!.manufacturerId, 2);
      expect(product.categoryIds, [1]);
      expect(product.materialIds, [4, 9]);
    });

    test('404 при чтении записи — это null, а не ошибка', () async {
      adapter.handler = (o) async => json(404, {'message': 'Объект не найден'});

      expect(await products.findById(999), isNull);
    });

    test('новый поиск отменяет незавершённый предыдущий', () async {
      // Первый запрос «висит» секунду, второй отвечает сразу.
      adapter.handler = (o) async {
        final search = o.queryParameters['search'];
        if (search == null) {
          await Future<void>.delayed(const Duration(seconds: 1));
        }
        return json(200, page([productJson(search == null ? 1 : 2)]));
      };

      final first = errorOf(() => products.find(const ProductQuery()));
      final second = await products.find(const ProductQuery(search: 'шкаф'));

      expect(await first, isA<CancelledException>());
      expect(second.items.single.id, 2);
    });

    test('служебные параметры __delay и __fail добавляются из меню', () async {
      debug
        ..slowResponses = true
        ..failResponses = true;
      adapter.handler = (o) async => json(200, page([]));

      await products.find(const ProductQuery());

      expect(adapter.requests.first.uri.queryParameters['__delay'], '1500');
      expect(adapter.requests.first.uri.queryParameters['__fail'], '500');
    });
  });

  group('Запись', () {
    test(
      'на сервер уходят идентификаторы связей, без id и deletedAt',
      () async {
        adapter.handler = (o) async => o.path == '/auth/login'
            ? json(200, {
                'accessToken': 'token-1',
                'user': {'role': 'manager'},
              })
            : json(201, productJson(42));

        final created = await products.create(sofa);

        final post = adapter.requests.last;
        final body = post.data as Map<String, dynamic>;
        expect(post.method, 'POST');
        expect(body['manufacturerId'], 2);
        expect(body['categoryIds'], [1]);
        expect(body.containsKey('id'), isFalse);
        expect(body.containsKey('deletedAt'), isFalse);
        expect(post.headers['Authorization'], 'Bearer token-1');
        expect(created.id, 42);
      },
    );

    test('422 — ошибки привязаны к полям формы', () async {
      session.accessToken = 'token-1';
      adapter.handler = (o) async => json(422, {
        'message': 'Ошибка валидации',
        'errors': {'sku': 'Артикул DV-1001 уже есть у другого товара'},
      });

      final error = await errorOf(() => products.create(sofa));

      expect(error, isA<ApiValidationException>());
      // Формы из ПР3 ловят ValidationException — подходит и серверная.
      expect(error, isA<ValidationException>());
      expect(
        (error as ValidationException).errors['sku'],
        'Артикул DV-1001 уже есть у другого товара',
      );
    });

    test('409 — текст сервера доходит до пользователя', () async {
      session.accessToken = 'token-1';
      final manufacturers = ApiManufacturerRepository(dio);
      adapter.handler = (o) async => json(409, {
        'message':
            'Нельзя удалить «Северный лес»: на него ссылаются 5 товаров.',
      });

      final error = await errorOf(() => manufacturers.softDelete(2));

      expect(error, isA<ConflictException>());
      expect(
        (error as RepositoryException).message,
        'Нельзя удалить «Северный лес»: на него ссылаются 5 товаров.',
      );
    });

    test('409 при заказе больше, чем есть на складе', () async {
      session.accessToken = 'token-1';
      final orders = ApiOrderRepository(dio);
      adapter.handler = (o) async => json(409, {
        'message': 'На складе только 3 шт. товара «Диван «Осло»»',
      });

      final error = await errorOf(
        () => orders.place(customerId: 1, productId: 7, quantity: 5),
      );

      expect(error, isA<ConflictException>());
      expect(adapter.requests.single.path, '/orders');
    });

    test(
      'истёкший токен: вход выполняется заново и запрос повторяется',
      () async {
        session.accessToken = 'old';
        var logins = 0;
        adapter.handler = (o) async {
          if (o.path == '/auth/login') {
            logins++;
            return json(200, {
              'accessToken': 'fresh',
              'user': {'role': 'manager'},
            });
          }
          return o.headers['Authorization'] == 'Bearer fresh'
              ? json(204, null)
              : json(401, {'message': 'Требуется аутентификация'});
        };

        await products.softDelete(7);

        expect(logins, 1);
        expect(adapter.requests.length, 3); // DELETE → вход → DELETE
      },
    );

    test('403 — недостаточно прав', () async {
      session.accessToken = 'viewer-token';
      adapter.handler = (o) async =>
          json(403, {'message': 'Операция доступна начиная с роли «manager»'});

      final error = await errorOf(() => products.softDelete(7));

      expect(error, isA<ForbiddenException>());
    });
  });

  group('Сбои и повторы', () {
    test(
      'сервер выключен — NetworkException после трёх повторов GET',
      () async {
        adapter.handler = offline;

        final error = await errorOf(() => products.find(const ProductQuery()));

        expect(error, isA<NetworkException>());
        expect(adapter.requests.length, 4); // первая попытка + 3 повтора
      },
    );

    test('POST при сбое сети не повторяется', () async {
      session.accessToken = 'token-1';
      adapter.handler = offline;

      final error = await errorOf(() => products.create(sofa));

      expect(error, isA<NetworkException>());
      expect(adapter.requests.length, 1);
    });

    test('500 повторяется, и если сервер ожил — данные приходят', () async {
      var call = 0;
      adapter.handler = (o) async => ++call < 3
          ? json(500, {'message': 'Ошибка'})
          : json(200, page([productJson(1)]));

      final result = await products.find(const ProductQuery());

      expect(result.items.length, 1);
      expect(adapter.requests.length, 3);
    });

    test('400 и 404 не повторяются', () async {
      adapter.handler = (o) async => json(404, {'message': 'Ресурс не найден'});

      final error = await errorOf(
        () => ApiCategoryRepository(
          dio,
        ).find(const BasicQuery(spec: categoryQuerySpec)),
      );

      expect(error, isA<NotFoundException>());
      expect(adapter.requests.length, 1);
    });

    test('коды ответа переводятся в свои исключения', () {
      expect(mapHttpError(401, null), isA<UnauthorizedException>());
      expect(mapHttpError(403, null), isA<ForbiddenException>());
      expect(mapHttpError(404, null), isA<NotFoundException>());
      expect(mapHttpError(409, null), isA<ConflictException>());
      expect(mapHttpError(422, null), isA<ApiValidationException>());
      expect(mapHttpError(503, null), isA<ServerException>());
    });
  });
}
