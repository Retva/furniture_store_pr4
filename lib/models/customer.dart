import 'entity.dart';
import 'json_read.dart';

/// Дисконтная карта. Своего списка и экрана у неё нет: она часть покупателя
/// (связь один к одному) и редактируется в его форме.
class DiscountCard {
  const DiscountCard({
    required this.number,
    required this.discountPercent,
    required this.issuedAt,
  });

  final String number;
  final int discountPercent;
  final DateTime issuedAt;

  static DiscountCard? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final number = JsonRead.text(json['number']);
    if (number.isEmpty) return null;
    return DiscountCard(
      number: number,
      discountPercent: JsonRead.integer(json['discountPercent']),
      issuedAt: JsonRead.date(json['issuedAt']) ?? DateTime(2000),
    );
  }

  Map<String, dynamic> toJson() => {
    'number': number,
    'discountPercent': discountPercent,
    'issuedAt': issuedAt.toIso8601String(),
  };
}

/// Покупатель магазина. Один к одному с дисконтной картой.
class Customer implements Entity {
  const Customer({
    required this.id,
    required this.fullName,
    required this.email,
    this.phone = '',
    this.card,
    this.deletedAt,
  });

  @override
  final int id;
  final String fullName;
  final String email;
  final String phone;
  final DiscountCard? card;

  @override
  final DateTime? deletedAt;

  @override
  bool get isDeleted => deletedAt != null;

  bool get hasCard => card != null;

  factory Customer.fromJson(Map<String, dynamic> json) => Customer(
    id: JsonRead.integer(json['id']),
    fullName: JsonRead.text(json['fullName']),
    email: JsonRead.text(json['email']),
    phone: JsonRead.text(json['phone']),
    card: DiscountCard.fromJson(JsonRead.map(json['card'])),
    deletedAt: JsonRead.date(json['deletedAt']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'fullName': fullName,
    'email': email,
    'phone': phone,
    'card': card?.toJson(),
    'deletedAt': deletedAt?.toIso8601String(),
  };

  Customer copyWith({
    int? id,
    String? fullName,
    String? email,
    String? phone,
    DiscountCard? card,
    bool clearCard = false,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
  }) {
    return Customer(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      card: clearCard ? null : (card ?? this.card),
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
    );
  }
}
