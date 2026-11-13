import '../models/basic_query.dart';
import '../models/customer.dart';
import 'crud_repository.dart';

abstract interface class CustomerRepository
    implements CrudRepository<Customer, BasicQuery> {}
