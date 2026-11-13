import 'entity.dart';
import 'json_read.dart';

/// Категория мебели. Многие ко многим с товарами.
class ProductCategory implements Entity {
  const ProductCategory({
    required this.id,
    required this.name,
    this.description = '',
    this.deletedAt,
  });

  @override
  final int id;
  final String name;
  final String description;

  @override
  final DateTime? deletedAt;

  @override
  bool get isDeleted => deletedAt != null;

  factory ProductCategory.fromJson(Map<String, dynamic> json) =>
      ProductCategory(
        id: JsonRead.integer(json['id']),
        name: JsonRead.text(json['name']),
        description: JsonRead.text(json['description']),
        deletedAt: JsonRead.date(json['deletedAt']),
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'deletedAt': deletedAt?.toIso8601String(),
  };

  ProductCategory copyWith({
    int? id,
    String? name,
    String? description,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
  }) {
    return ProductCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
    );
  }
}
