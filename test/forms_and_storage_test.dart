import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:furniture_store/core/validators.dart';
import 'package:furniture_store/models/basic_query.dart';
import 'package:furniture_store/models/customer.dart';
import 'package:furniture_store/models/product.dart';
import 'package:furniture_store/models/product_query.dart';
import 'package:furniture_store/repositories/local_customer_repository.dart';
import 'package:furniture_store/repositories/local_manufacturer_repository.dart';
import 'package:furniture_store/repositories/local_material_repository.dart';
import 'package:furniture_store/repositories/local_product_repository.dart';
import 'package:furniture_store/repositories/local_storage.dart';
import 'package:furniture_store/repositories/network_simulator.dart';
import 'package:furniture_store/repositories/repository_exception.dart';

EntityStore<Product> productStore(KeyValueStore store, StorageReport report) =>
    EntityStore<Product>(
      store: store,
      key: StorageKeys.products,
      title: 'Товары',
      fromJson: Product.fromJson,
      toJson: (p) => p.toJson(),
      report: report,
    );

Future<Object?> errorOf(Future<Object?> Function() action) async {
  try {
    await action();
  } catch (e) {
    return e;
  }
  return null;
}

void main() {
  final network = NetworkSimulator.instant();

  group('Валидаторы', () {
    test('обязательность и длина', () {
      expect(V.required()('  '), 'Заполните поле');
      expect(V.required()('стол'), isNull);
      expect(V.length(min: 3)('ab'), 'Не короче 3 символов');
      expect(V.length(max: 3)('abcd'), 'Не длиннее 3 символов');
    });

    test('числа: диапазон и положительность', () {
      expect(V.integer(min: 1, max: 30)('31'), 'Не больше 30');
      expect(V.integer()('12a'), 'Введите целое число');
      expect(V.positive()('0'), 'Должно быть больше нуля');
      expect(V.nonNegative()('0'), isNull);
    });

    test('почта и телефон', () {
      expect(V.email()('anna@mail.ru'), isNull);
      expect(V.email()('anna@mail'), 'Некорректный адрес почты');
      expect(V.phone()('+7 (912) 345-67-01'), isNull);
      expect(V.phone()('12345'), 'В номере должно быть 10–15 цифр');
    });

    test('дата: формат, несуществующий день, будущее', () {
      expect(V.pastDate()('01.10.2025'), isNull);
      expect(V.pastDate()('2025-10-01'), 'Дата в формате ДД.ММ.ГГГГ');
      expect(V.pastDate()('31.02.2025'), 'Дата в формате ДД.ММ.ГГГГ');
      expect(V.pastDate()('01.01.2999'), 'Дата не может быть в будущем');
    });

    test('combine возвращает первую сработавшую проверку', () {
      final v = V.combine([V.required(), V.length(min: 5)]);
      expect(v(''), 'Заполните поле');
      expect(v('abc'), 'Не короче 5 символов');
      expect(V.optional(V.email())(''), isNull);
    });
  });

  group('Разбор JSON', () {
    test('пустой объект не роняет разбор', () {
      final p = Product.fromJson({});
      expect(p.id, 0);
      expect(p.name, '');
      expect(p.categoryIds.isEmpty, isTrue);
      expect(p.deletedAt, isNull);
    });

    test('значения другого типа заменяются значениями по умолчанию', () {
      final p = Product.fromJson({
        'id': '7',
        'price': null,
        'categoryIds': [1, 'x', null, 3],
        'deletedAt': 'не дата',
      });
      expect(p.id, 7);
      expect(p.price, 0);
      expect(p.categoryIds, [1, 3]);
      expect(p.deletedAt, isNull);
    });

    test('покупатель с картой переживает toJson и fromJson', () {
      final c = Customer(
        id: 1,
        fullName: 'Иванова Анна',
        email: 'a@b.ru',
        card: DiscountCard(
          number: '12345678',
          discountPercent: 7,
          issuedAt: DateTime(2025, 3, 1),
        ),
      );
      final back = Customer.fromJson(
        jsonDecode(jsonEncode(c.toJson())) as Map<String, dynamic>,
      );
      expect(back.card!.number, '12345678');
      expect(back.card!.discountPercent, 7);
      expect(Customer.fromJson({'card': null}).hasCard, isFalse);
    });
  });

  group('Сохранение между перезагрузками', () {
    test('созданная запись видна новому экземпляру хранилища', () async {
      final store = MemoryKeyValueStore();
      final report = StorageReport();
      final first = LocalProductRepository(
        store: productStore(store, report),
        network: network,
      );
      final created = await first.create(
        first.records.first.copyWith(name: 'Новый диван', sku: 'DV-9999'),
      );

      final second = LocalProductRepository(
        store: productStore(store, report),
        network: network,
      );
      final found = await second.findById(created.id);
      expect(found!.name, 'Новый диван');
    });

    test('испорченные данные заменяются начальным набором', () {
      final store = MemoryKeyValueStore({StorageKeys.products: '{не json'});
      final report = StorageReport();
      final repo = LocalProductRepository(
        store: productStore(store, report),
        network: network,
      );
      expect(repo.records.length, 41);
      expect(report.messages.length, 1);
    });

    test('данные версии 1 переводятся на версию 2', () async {
      final store = MemoryKeyValueStore({
        StorageKeys.productsV1: jsonEncode([
          {
            'id': 1,
            'name': 'Стул',
            'sku': 'SL-0001',
            'categoryId': 4,
            'material': 'Бук',
          },
        ]),
      });
      final report = StorageReport();
      await StorageMigrator(store, report).run();

      expect(store.getString(StorageKeys.productsV1), isNull);
      expect(store.getString(StorageKeys.versionKey), '2');
      final repo = LocalProductRepository(
        store: productStore(store, report),
        network: network,
      );
      expect(repo.records.single.categoryIds, [4]);
      expect(repo.records.single.description.contains('Бук'), isTrue);
      expect(report.messages.length, 1);
    });
  });

  group('Уникальность и связи', () {
    test('повтор артикула — ошибка в поле sku', () async {
      final repo = LocalProductRepository(network: network);
      final error = await errorOf(
        () => repo.create(repo.records[1].copyWith(sku: 'dv-1001')),
      );
      expect(error is ValidationException, isTrue);
      expect((error as ValidationException).errors.containsKey('sku'), isTrue);
    });

    test('повтор почты покупателя — ошибка в поле email', () async {
      final repo = LocalCustomerRepository(network: network);
      final error = await errorOf(
        () => repo.create(
          const Customer(
            id: 0,
            fullName: 'Тест Тестов',
            email: 'ANNA.IVANOVA@mail.example',
          ),
        ),
      );
      expect(
        (error as ValidationException).errors.containsKey('email'),
        isTrue,
      );
    });

    test('производителя с товарами удалить нельзя, число указано', () async {
      final products = LocalProductRepository(network: network);
      final manufacturers = LocalManufacturerRepository(
        network: network,
        usageCount: products.countByManufacturer,
      );
      final error = await errorOf(() => manufacturers.softDelete(6));
      expect(error is RepositoryException, isTrue);
      expect('$error'.contains('3 товара'), isTrue);
      expect((await manufacturers.findById(6))!.isDeleted, isFalse);
    });

    test('материал без товаров удаляется', () async {
      final products = LocalProductRepository(network: network);
      final materials = LocalMaterialRepository(
        network: network,
        usageCount: products.countByMaterial,
      );
      final error = await errorOf(() => materials.hardDelete(23));
      expect(error, isNull);
    });

    test('фильтр по категории учитывает несколько категорий товара', () async {
      final repo = LocalProductRepository(network: network);
      final beds = await repo.find(const ProductQuery(categoryId: 6, size: 50));
      expect(beds.items.any((p) => p.name.contains('Диван-кровать')), isTrue);
    });

    test('фильтр покупателей по наличию карты', () async {
      final repo = LocalCustomerRepository(network: network);
      final withCard = await repo.find(
        const BasicQuery(spec: customerQuerySpec, filter: 'yes'),
      );
      expect(withCard.items.every((c) => c.hasCard), isTrue);
      expect(withCard.total, 7);
    });
  });
}
