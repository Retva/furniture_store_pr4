import 'entity.dart';
import 'json_read.dart';

/// Производитель. Один ко многим с товарами. [materialIds] — материалы, с
/// которыми работает фабрика: по ним сужается выбор материалов в форме товара.
class Manufacturer implements Entity {
  const Manufacturer({
    required this.id,
    required this.name,
    required this.country,
    required this.city,
    required this.foundedYear,
    this.email = '',
    this.website = '',
    this.materialIds = const [],
    this.description = '',
    this.deletedAt,
  });

  @override
  final int id;
  final String name;
  final String country;
  final String city;
  final int foundedYear;
  final String email;
  final String website;
  final List<int> materialIds;
  final String description;

  @override
  final DateTime? deletedAt;

  @override
  bool get isDeleted => deletedAt != null;

  factory Manufacturer.fromJson(Map<String, dynamic> json) => Manufacturer(
    id: JsonRead.integer(json['id']),
    name: JsonRead.text(json['name']),
    country: JsonRead.text(json['country']),
    city: JsonRead.text(json['city']),
    foundedYear: JsonRead.integer(json['foundedYear']),
    email: JsonRead.text(json['email']),
    website: JsonRead.text(json['website']),
    materialIds: JsonRead.ids(json['materialIds'] ?? json['materials']),
    description: JsonRead.text(json['description']),
    deletedAt: JsonRead.date(json['deletedAt']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'country': country,
    'city': city,
    'foundedYear': foundedYear,
    'email': email,
    'website': website,
    'materialIds': materialIds,
    'description': description,
    'deletedAt': deletedAt?.toIso8601String(),
  };

  Manufacturer copyWith({
    int? id,
    String? name,
    String? country,
    String? city,
    int? foundedYear,
    String? email,
    String? website,
    List<int>? materialIds,
    String? description,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
  }) {
    return Manufacturer(
      id: id ?? this.id,
      name: name ?? this.name,
      country: country ?? this.country,
      city: city ?? this.city,
      foundedYear: foundedYear ?? this.foundedYear,
      email: email ?? this.email,
      website: website ?? this.website,
      materialIds: materialIds ?? this.materialIds,
      description: description ?? this.description,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
    );
  }
}
