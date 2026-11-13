import 'entity.dart';
import 'json_read.dart';

/// Материал. Многие ко многим с товарами.
///
/// Назван FurnitureMaterial, а не Material: Material — виджет Flutter, и
/// одинаковые имена пришлось бы различать префиксами при каждом импорте.
class FurnitureMaterial implements Entity {
  const FurnitureMaterial({
    required this.id,
    required this.name,
    required this.kind,
    this.origin = '',
    this.deletedAt,
  });

  static const List<String> kinds = [
    'Дерево',
    'Плита',
    'Ткань',
    'Кожа',
    'Металл',
    'Стекло',
    'Пластик',
  ];

  @override
  final int id;
  final String name;
  final String kind;
  final String origin;

  @override
  final DateTime? deletedAt;

  @override
  bool get isDeleted => deletedAt != null;

  factory FurnitureMaterial.fromJson(Map<String, dynamic> json) =>
      FurnitureMaterial(
        id: JsonRead.integer(json['id']),
        name: JsonRead.text(json['name']),
        kind: JsonRead.text(json['kind'], kinds.first),
        origin: JsonRead.text(json['origin']),
        deletedAt: JsonRead.date(json['deletedAt']),
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'kind': kind,
    'origin': origin,
    'deletedAt': deletedAt?.toIso8601String(),
  };

  FurnitureMaterial copyWith({
    int? id,
    String? name,
    String? kind,
    String? origin,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
  }) {
    return FurnitureMaterial(
      id: id ?? this.id,
      name: name ?? this.name,
      kind: kind ?? this.kind,
      origin: origin ?? this.origin,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
    );
  }
}
