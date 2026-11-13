import '../models/basic_query.dart';
import '../models/customer.dart';
import 'customer_repository.dart';
import 'local_crud_repository.dart';
import 'seed_data.dart';

class LocalCustomerRepository extends LocalCrudRepository<Customer, BasicQuery>
    implements CustomerRepository {
  LocalCustomerRepository({List<Customer>? seed, super.store, super.network})
    : super(seed ?? seedCustomers);

  @override
  String get entityName => 'Покупатель';

  @override
  String nameOf(Customer item) => item.fullName;

  @override
  bool matches(Customer c, BasicQuery q) {
    final needle = q.search.trim().toLowerCase();
    if (needle.isNotEmpty &&
        !c.fullName.toLowerCase().contains(needle) &&
        !c.email.toLowerCase().contains(needle) &&
        !c.phone.contains(needle)) {
      return false;
    }
    if (q.filter == 'yes' && !c.hasCard) return false;
    if (q.filter == 'no' && c.hasCard) return false;
    return true;
  }

  @override
  int compareBy(Customer a, Customer b, String field) => switch (field) {
    'email' => compareText(a.email, b.email),
    'discount' => (a.card?.discountPercent ?? -1).compareTo(
      b.card?.discountPercent ?? -1,
    ),
    _ => compareText(a.fullName, b.fullName),
  };

  @override
  Customer withDeletedAt(Customer item, DateTime? deletedAt) =>
      deletedAt == null
      ? item.copyWith(clearDeletedAt: true)
      : item.copyWith(deletedAt: deletedAt);

  @override
  Customer withId(Customer item, int id) => item.copyWith(id: id);

  @override
  Map<String, String> uniquenessErrors(Customer item) => {
    if (isTaken(item, (c) => c.email))
      'email': 'Покупатель с такой почтой уже есть',
    if (item.card != null && isTaken(item, (c) => c.card?.number ?? ''))
      'cardNumber': 'Карта с таким номером уже выдана',
  };
}
