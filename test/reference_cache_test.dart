import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furniture_store/api/api_client.dart';
import 'package:furniture_store/repositories/api/api_repositories.dart';
import 'package:furniture_store/state/reference_data_notifier.dart';

import 'api_repository_test.dart' show FakeAdapter, json, page;

void main() {
  late FakeAdapter adapter;
  late Dio dio;

  setUp(() {
    adapter = FakeAdapter((o) async => json(200, page([])));
    dio = buildDio(
      baseUrl: 'http://test/api',
      adapter: adapter,
      log: (_) {},
      retry: const RetryPolicy.none(),
    );
  });

  group('Кэш справочников', () {
    test('повторная загрузка не ходит на сервер, пока кэш свежий', () async {
      adapter.handler = (o) async => json(200, page([]));
      final categories = ApiCategoryRepository(dio);
      final manufacturers = ApiManufacturerRepository(dio);
      final materials = ApiMaterialRepository(dio);
      final refs = ReferenceDataNotifier(categories, manufacturers, materials);

      await refs.load();
      final afterFirst = adapter.requests.length;
      await refs.load();
      expect(adapter.requests.length, afterFirst);

      // Изменение категории помечает кэш устаревшим.
      categories.addChangeListener(refs.markStale);
      categories.notifyChanged();
      await refs.load();
      expect(adapter.requests.length > afterFirst, isTrue);
    });
  });
}
