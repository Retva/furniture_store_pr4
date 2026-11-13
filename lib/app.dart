import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'api/api_client.dart';
import 'api/api_session.dart';
import 'api/debug_options.dart';
import 'core/config.dart';
import 'core/router.dart';
import 'core/scroll_behavior.dart';
import 'models/customer.dart';
import 'models/furniture_material.dart';
import 'models/manufacturer.dart';
import 'models/product.dart';
import 'models/product_category.dart';
import 'repositories/api/api_repositories.dart';
import 'repositories/category_repository.dart';
import 'repositories/customer_repository.dart';
import 'repositories/local_category_repository.dart';
import 'repositories/local_customer_repository.dart';
import 'repositories/local_manufacturer_repository.dart';
import 'repositories/local_material_repository.dart';
import 'repositories/local_product_repository.dart';
import 'repositories/local_storage.dart';
import 'repositories/manufacturer_repository.dart';
import 'repositories/material_repository.dart';
import 'repositories/network_simulator.dart';
import 'repositories/order_repository.dart';
import 'repositories/product_repository.dart';
import 'state/manufacturer_list_notifier.dart';
import 'state/debug_settings_notifier.dart';
import 'state/other_list_notifiers.dart';
import 'state/product_list_notifier.dart';
import 'state/reference_data_notifier.dart';
import 'state/unsaved_changes_guard.dart';

class FurnitureStoreApp extends StatefulWidget {
  const FurnitureStoreApp({
    super.key,
    required this.store,
    required this.report,
    this.network,
  });

  final KeyValueStore store;
  final StorageReport report;
  final NetworkSimulator? network;

  @override
  State<FurnitureStoreApp> createState() => _FurnitureStoreAppState();
}

class _FurnitureStoreAppState extends State<FurnitureStoreApp> {
  late final NetworkSimulator _network = widget.network ?? NetworkSimulator();
  final UnsavedChangesGuard _guard = UnsavedChangesGuard();
  late final GoRouter _router = createRouter(_guard);
  final GlobalKey<ScaffoldMessengerState> _messenger = GlobalKey();

  late final ProductRepository _products;
  late final ManufacturerRepository _manufacturers;
  late final CategoryRepository _categories;
  late final MaterialRepository _materials;
  late final CustomerRepository _customers;

  /// Заказы есть только при работе с сервером.
  OrderRepository? _orders;

  late final DebugSettingsNotifier _debug;
  late final ReferenceDataNotifier _refs;

  EntityStore<T> _storeFor<T>(
    String key,
    String title,
    T Function(Map<String, dynamic>) fromJson,
    Map<String, dynamic> Function(T) toJson,
  ) => EntityStore<T>(
    store: widget.store,
    key: key,
    title: title,
    fromJson: fromJson,
    toJson: toJson,
    report: widget.report,
  );

  @override
  void initState() {
    super.initState();
    if (AppConfig.useApi) {
      _initApi();
    } else {
      _initLocal();
    }

    // Сообщения о миграции или сбросе данных показываются один раз после
    // первого кадра, когда уже есть куда их вывести.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final message in widget.report.messages) {
        _messenger.currentState?.showSnackBar(
          SnackBar(
            content: Text(message),
            duration: const Duration(seconds: 8),
          ),
        );
      }
      widget.report.messages.clear();
    });
  }

  /// Данные с сервера. Один экземпляр Dio на всё приложение; репозитории
  /// получают его готовым и ничего не знают о настройках.
  void _initApi() {
    final session = ApiSession(
      username: AppConfig.apiUser,
      password: AppConfig.apiPassword,
    );
    final options = DebugOptions();
    final dio = buildDio(
      baseUrl: AppConfig.apiBaseUrl,
      session: session,
      debug: options,
      log: debugPrint,
    );

    final categories = ApiCategoryRepository(dio);
    final manufacturers = ApiManufacturerRepository(dio);
    final materials = ApiMaterialRepository(dio);
    _products = ApiProductRepository(dio);
    _manufacturers = manufacturers;
    _categories = categories;
    _materials = materials;
    _customers = ApiCustomerRepository(dio);
    _orders = ApiOrderRepository(dio);

    _debug = DebugSettingsNotifier(options: options, session: session);
    _refs = ReferenceDataNotifier(categories, manufacturers, materials);

    // Изменили категорию, материал или производителя — кэш справочников
    // устарел и будет перечитан при следующем обращении.
    categories.addChangeListener(_refs.markStale);
    manufacturers.addChangeListener(_refs.markStale);
    materials.addChangeListener(_refs.markStale);
  }

  /// Данные в localStorage, как в ПР3: `--dart-define=DATA_SOURCE=local`.
  void _initLocal() {
    final products = LocalProductRepository(
      network: _network,
      store: _storeFor<Product>(
        StorageKeys.products,
        'Товары',
        Product.fromJson,
        (p) => p.toJson(),
      ),
    );
    // Удалить производителя, категорию или материал нельзя, пока на них
    // ссылаются товары: репозиторий спрашивает число ссылок у товаров.
    _manufacturers = LocalManufacturerRepository(
      network: _network,
      usageCount: products.countByManufacturer,
      store: _storeFor<Manufacturer>(
        StorageKeys.manufacturers,
        'Производители',
        Manufacturer.fromJson,
        (m) => m.toJson(),
      ),
    );
    _categories = LocalCategoryRepository(
      network: _network,
      usageCount: products.countByCategory,
      store: _storeFor<ProductCategory>(
        StorageKeys.categories,
        'Категории',
        ProductCategory.fromJson,
        (c) => c.toJson(),
      ),
    );
    _materials = LocalMaterialRepository(
      network: _network,
      usageCount: products.countByMaterial,
      store: _storeFor<FurnitureMaterial>(
        StorageKeys.materials,
        'Материалы',
        FurnitureMaterial.fromJson,
        (m) => m.toJson(),
      ),
    );
    _customers = LocalCustomerRepository(
      network: _network,
      store: _storeFor<Customer>(
        StorageKeys.customers,
        'Покупатели',
        Customer.fromJson,
        (c) => c.toJson(),
      ),
    );
    _products = products;

    _debug = DebugSettingsNotifier(simulator: _network);
    // Локальные данные читаются мгновенно, кэш не нужен.
    _refs = ReferenceDataNotifier(
      _categories,
      _manufacturers,
      _materials,
      maxAge: Duration.zero,
    );
  }

  @override
  void dispose() {
    _refs.dispose();
    _debug.dispose();
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ProductRepository>.value(value: _products),
        Provider<ManufacturerRepository>.value(value: _manufacturers),
        Provider<CategoryRepository>.value(value: _categories),
        Provider<MaterialRepository>.value(value: _materials),
        Provider<CustomerRepository>.value(value: _customers),
        Provider<OrderRepository?>.value(value: _orders),
        Provider<UnsavedChangesGuard>.value(value: _guard),
        ChangeNotifierProvider(create: (_) => ProductListNotifier(_products)),
        ChangeNotifierProvider(
          create: (_) => ManufacturerListNotifier(_manufacturers),
        ),
        ChangeNotifierProvider(
          create: (_) => CategoryListNotifier(_categories),
        ),
        ChangeNotifierProvider(create: (_) => MaterialListNotifier(_materials)),
        ChangeNotifierProvider(create: (_) => CustomerListNotifier(_customers)),
        ChangeNotifierProvider.value(value: _refs..load()),
        ChangeNotifierProvider.value(value: _debug),
      ],
      child: MaterialApp.router(
        title: 'МебельДом',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(useMaterial3: true),
        routerConfig: _router,
        scaffoldMessengerKey: _messenger,
        scrollBehavior: const AppScrollBehavior(),
        locale: const Locale('ru'),
        supportedLocales: const [Locale('ru')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
      ),
    );
  }
}
