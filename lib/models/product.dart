import 'entity.dart';
import 'json_read.dart';

/// Товар. Связи: производитель — многие к одному, категории и материалы —
/// многие ко многим (хранятся списками идентификаторов).
class Product implements Entity {
  const Product({
    required this.id,
    required this.name,
    required this.sku,
    required this.manufacturerId,
    required this.categoryIds,
    required this.materialIds,
    required this.price,
    required this.stock,
    required this.widthCm,
    required this.depthCm,
    required this.heightCm,
    this.color = '',
    this.description = '',
    this.deletedAt,
  });

  @override
  final int id;
  final String name;
  final String sku;
  final int manufacturerId;
  final List<int> categoryIds;
  final List<int> materialIds;
  final int price;
  final int stock;
  final int widthCm;
  final int depthCm;
  final int heightCm;
  final String color;
  final String description;

  @override
  final DateTime? deletedAt;

  @override
  bool get isDeleted => deletedAt != null;

  bool get inStock => stock > 0;

  String get dimensions => '$widthCm × $depthCm × $heightCm см';

  /// Разбирает обе формы записи: локальную (`manufacturerId`,
  /// `categoryIds`) и ответ сервера (`manufacturer: {id, name}`,
  /// `categories: [{id, name}]`).
  factory Product.fromJson(Map<String, dynamic> json) => Product(
    id: JsonRead.integer(json['id']),
    name: JsonRead.text(json['name']),
    sku: JsonRead.text(json['sku']),
    manufacturerId: JsonRead.refId(json, 'manufacturerId', 'manufacturer'),
    categoryIds: JsonRead.ids(json['categoryIds'] ?? json['categories']),
    materialIds: JsonRead.ids(json['materialIds'] ?? json['materials']),
    price: JsonRead.integer(json['price']),
    stock: JsonRead.integer(json['stock']),
    widthCm: JsonRead.integer(json['widthCm']),
    depthCm: JsonRead.integer(json['depthCm']),
    heightCm: JsonRead.integer(json['heightCm']),
    color: JsonRead.text(json['color']),
    description: JsonRead.text(json['description']),
    deletedAt: JsonRead.date(json['deletedAt']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'sku': sku,
    'manufacturerId': manufacturerId,
    'categoryIds': categoryIds,
    'materialIds': materialIds,
    'price': price,
    'stock': stock,
    'widthCm': widthCm,
    'depthCm': depthCm,
    'heightCm': heightCm,
    'color': color,
    'description': description,
    'deletedAt': deletedAt?.toIso8601String(),
  };

  Product copyWith({
    int? id,
    String? name,
    String? sku,
    int? manufacturerId,
    List<int>? categoryIds,
    List<int>? materialIds,
    int? price,
    int? stock,
    int? widthCm,
    int? depthCm,
    int? heightCm,
    String? color,
    String? description,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      sku: sku ?? this.sku,
      manufacturerId: manufacturerId ?? this.manufacturerId,
      categoryIds: categoryIds ?? this.categoryIds,
      materialIds: materialIds ?? this.materialIds,
      price: price ?? this.price,
      stock: stock ?? this.stock,
      widthCm: widthCm ?? this.widthCm,
      depthCm: depthCm ?? this.depthCm,
      heightCm: heightCm ?? this.heightCm,
      color: color ?? this.color,
      description: description ?? this.description,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
    );
  }
}
