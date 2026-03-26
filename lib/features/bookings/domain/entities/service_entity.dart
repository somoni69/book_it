class ServiceEntity {
  final String id;
  final String masterId;
  final String title;
  final int durationMin;
  final double price;
  // --- НОВЫЕ ПОЛЯ ---
  final String bookingType; // 'time_slot' или 'daily'
  final int capacity; // Количество мест (по умолчанию 1)

  const ServiceEntity({
    required this.id,
    required this.masterId,
    required this.title,
    required this.durationMin,
    required this.price,
    this.bookingType = 'time_slot',
    this.capacity = 1,
  });

  ServiceEntity copyWith({
    String? id,
    String? masterId,
    String? title,
    int? durationMin,
    double? price,
    String? bookingType,
    int? capacity,
  }) {
    return ServiceEntity(
      id: id ?? this.id,
      masterId: masterId ?? this.masterId,
      title: title ?? this.title,
      durationMin: durationMin ?? this.durationMin,
      price: price ?? this.price,
      bookingType: bookingType ?? this.bookingType,
      capacity: capacity ?? this.capacity,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'master_id': masterId,
      'title': title,
      'duration_min': durationMin,
      'price': price,
      'booking_type': bookingType,
      'capacity': capacity,
    };
  }

  factory ServiceEntity.fromJson(Map<String, dynamic> json) {
    return ServiceEntity(
      id: json['id'],
      masterId: json['master_id'],
      title: json['title'],
      durationMin: int.tryParse(json['duration_min'].toString()) ?? 0,
      price: double.tryParse(json['price'].toString()) ?? 0.0,
      bookingType: json['booking_type'] ?? 'time_slot',
      capacity: int.tryParse(json['capacity'].toString()) ?? 1,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ServiceEntity && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'ServiceEntity(id: $id, title: $title, price: $price)';
  }
}
