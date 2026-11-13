import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'repositories/local_storage.dart';
import 'repositories/prefs_key_value_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();
  final prefs = await SharedPreferences.getInstance();
  final store = PrefsKeyValueStore(prefs);
  final report = StorageReport();
  await StorageMigrator(store, report).run();
  runApp(FurnitureStoreApp(store: store, report: report));
}
