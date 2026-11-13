import '../models/basic_query.dart';
import '../models/furniture_material.dart';
import 'crud_repository.dart';

abstract interface class MaterialRepository
    implements CrudRepository<FurnitureMaterial, BasicQuery> {}
