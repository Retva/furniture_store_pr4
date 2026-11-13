import '../models/manufacturer.dart';
import '../models/manufacturer_query.dart';
import 'crud_repository.dart';

abstract interface class ManufacturerRepository
    implements CrudRepository<Manufacturer, ManufacturerQuery> {
  Future<List<String>> countries();
}
