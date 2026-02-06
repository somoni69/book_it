class ServiceEntity {
  final String id;
  final String masterId;
  final String title;
  final int durationMin;
  final double price;

  const ServiceEntity({
    required this.id,
    required this.masterId,
    required this.title,
    required this.durationMin,
    required this.price,
  });

  ServiceEntity copyWith({
    String? id,
    String? masterId,
    String? title,
    int? durationMin,
    double? price,
  }) {
    return ServiceEntity(
      id: id ?? this.id,
      masterId: masterId ?? this.masterId,
      title: title ?? this.title,
      durationMin: durationMin ?? this.durationMin,
      price: price ?? this.price,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'master_id': masterId,
      'title': title,
      'duration_min': durationMin,
      'price': price,
    };
  }

  factory ServiceEntity.fromJson(Map<String, dynamic> json) {
    return ServiceEntity(
      id: json['id'],
      masterId: json['master_id'],
      title: json['title'],
      durationMin: json['duration_min'],
      price: (json['price'] as num).toDouble(),
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
