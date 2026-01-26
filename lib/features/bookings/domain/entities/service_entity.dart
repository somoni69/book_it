class ServiceEntity {
  final String id;
  final String masterId;
  final String title;
  final int durationMin;
  final double price;

  ServiceEntity({
    required this.id,
    required this.masterId,
    required this.title,
    required this.durationMin,
    required this.price,
  });

  factory ServiceEntity.fromJson(Map<String, dynamic> json) {
    return ServiceEntity(
      id: json['id'],
      masterId: json['master_id'],
      title: json['title'],
      durationMin: json['duration_min'],
      price: (json['price'] as num).toDouble(),
    );
  }
}
