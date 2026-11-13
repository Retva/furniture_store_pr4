import '../models/manufacturer.dart';
import '../models/manufacturer_query.dart';
import '../repositories/manufacturer_repository.dart';
import 'entity_list_notifier.dart';

/// Состояние списка производителей.
class ManufacturerListNotifier
    extends EntityListNotifier<Manufacturer, ManufacturerQuery> {
  ManufacturerListNotifier(ManufacturerRepository repository)
    : super(repository, const ManufacturerQuery());
}
