import 'package:flutter_test/flutter_test.dart';
import 'package:furniture_store/models/manufacturer_query.dart';
import 'package:furniture_store/models/product_query.dart';
import 'package:furniture_store/repositories/local_manufacturer_repository.dart';
import 'package:furniture_store/repositories/local_product_repository.dart';
import 'package:furniture_store/repositories/network_simulator.dart';
import 'package:furniture_store/repositories/repository_exception.dart';

void main() {
  late LocalProductRepository products;
  late LocalManufacturerRepository manufacturers;

  setUp(() {
    final network = NetworkSimulator.instant();
    products = LocalProductRepository(network: network);
    manufacturers = LocalManufacturerRepository(network: network);
  });

  group('Начальный набор', () {
    test('не меньше 20 товаров и 8 производителей', () async {
      final p = await products.find(const ProductQuery(size: 50));
      final m = await manufacturers.find(const ManufacturerQuery(size: 50));
      expect(p.total >= 20, isTrue);
      expect(m.total >= 8, isTrue);
    });

    test('удалённые записи по умолчанию не видны', () async {
      final active = await products.find(const ProductQuery(size: 50));
      final all = await products.find(
        const ProductQuery(size: 50, includeDeleted: true),
      );
      expect(all.total, active.total + 1);
    });
  });

  group('Поиск и фильтры', () {
    test('поиск по артикулу без учёта регистра', () async {
      final result = await products.find(const ProductQuery(search: 'dv-10'));
      expect(result.total, 6);
    });

    test('поиск по названию', () async {
      final result = await products.find(const ProductQuery(search: 'КРЕСЛО'));
      expect(result.total, 5);
    });

    test('фильтры складываются между собой и с поиском', () async {
      final result = await products.find(
        const ProductQuery(
          search: 'диван',
          categoryId: 1,
          priceFrom: 50000,
          priceTo: 120000,
        ),
      );
      final names = result.items.map((p) => p.name).toList();
      expect(names, [
        'Диван «Осло» прямой',
        'Диван-кровать «Верона»',
        'Угловой диван «Мальмё»',
      ]);
    });

    test('фильтр по производителю', () async {
      final result = await products.find(const ProductQuery(manufacturerId: 7));
      expect(result.items.every((p) => p.manufacturerId == 7), isTrue);
      expect(result.total, 4);
    });

    test('производителей ищем по названию и стране', () async {
      final byCountry = await manufacturers.find(
        const ManufacturerQuery(search: 'ита'),
      );
      expect(byCountry.items.map((m) => m.name).toList(), [
        'Casa Nobile',
        'Legno Vivo',
      ]);
      final byName = await manufacturers.find(
        const ManufacturerQuery(search: 'лес'),
      );
      expect(byName.items.single.name, 'Северный лес');
    });
  });

  group('Сортировка и страницы', () {
    test('по цене по убыванию', () async {
      final result = await products.find(
        const ProductQuery(sortField: 'price', sortAscending: false),
      );
      final prices = result.items.map((p) => p.price).toList();
      expect(prices.first, 245000);
      for (var i = 1; i < prices.length; i++) {
        expect(prices[i - 1] >= prices[i], isTrue);
      }
    });

    test('четвёртая страница по 10 — последняя', () async {
      final result = await products.find(const ProductQuery(page: 4));
      expect(result.total, 40);
      expect(result.totalPages, 4);
      expect(result.items.length, 10);
      expect(result.hasNext, isFalse);
      expect(result.firstIndex, 31);
      expect(result.lastIndex, 40);
    });

    test('страница за пределами — пустая, но total известен', () async {
      final result = await products.find(const ProductQuery(page: 9));
      expect(result.items.isEmpty, isTrue);
      expect(result.total, 40);
    });
  });

  group('Удаление', () {
    test('логическое удаление и восстановление', () async {
      await products.softDelete(1);
      var result = await products.find(const ProductQuery(search: 'DV-1001'));
      expect(result.total, 0);

      result = await products.find(
        const ProductQuery(search: 'DV-1001', includeDeleted: true),
      );
      expect(result.items.single.isDeleted, isTrue);

      await products.restore(1);
      result = await products.find(const ProductQuery(search: 'DV-1001'));
      expect(result.items.single.isDeleted, isFalse);
    });

    test('deleteMany считает только действительно удалённые', () async {
      final count = await products.deleteMany([1, 2, 41, 999]);
      expect(count, 2);
      final again = await products.deleteMany([1, 2]);
      expect(again, 0);
    });

    test('физическое удаление стирает запись', () async {
      await products.hardDelete(3);
      expect(await products.findById(3), isNull);
    });

    test('удаление несуществующей записи — понятная ошибка', () async {
      Object? error;
      try {
        await products.softDelete(999);
      } catch (e) {
        error = e;
      }
      expect(error is RepositoryException, isTrue);
    });
  });

  group('Условия отбора в адресе', () {
    test('запрос переводится в адрес и обратно без потерь', () {
      const query = ProductQuery(
        search: 'диван',
        categoryId: 1,
        manufacturerId: 6,
        priceFrom: 10000,
        priceTo: 90000,
        sortField: 'price',
        sortAscending: false,
        page: 3,
        size: 25,
        includeDeleted: true,
      );
      final params = query.toQueryParameters();
      expect(params['sort'], 'price,desc');
      expect(ProductQuery.fromParameters(params), query);
    });

    test('значения по умолчанию в адрес не пишутся', () {
      expect(const ProductQuery().toLocation(), '/products');
      expect(const ManufacturerQuery(country: 'Италия').toQueryParameters(), {
        'country': 'Италия',
      });
    });

    test('мусор в адресе заменяется значениями по умолчанию', () {
      final query = ProductQuery.fromParameters({
        'page': '-5',
        'size': '1000',
        'sort': 'hack,desc',
        'categoryId': 'abc',
      });
      expect(query.page, 1);
      expect(query.size, 10);
      expect(query.sortField, 'name');
      expect(query.sortAscending, isFalse);
      expect(query.categoryId, isNull);
    });

    test('смена условий возвращает на первую страницу', () {
      const query = ProductQuery(page: 7, categoryId: 2);
      expect(query.copyWith(search: 'стол').page, 1);
      expect(query.withPage(3).page, 3);
      expect(query.copyWith(categoryId: null).categoryId, isNull);
      expect(query.copyWith(search: 'x').categoryId, 2);
    });

    test('повторный щелчок по колонке меняет направление', () {
      const query = ProductQuery();
      final byPrice = query.withSort('price');
      expect(byPrice.sortAscending, isTrue);
      expect(byPrice.withSort('price').sortAscending, isFalse);
      expect(byPrice.withSort('stock').sortAscending, isTrue);
    });
  });
}
