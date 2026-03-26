import 'package:equatable/equatable.dart';

enum BookingStatus { pending, confirmed, cancelled, completed }

class BookingEntity extends Equatable {
  final String id;
  final String masterId;
  final String clientId;
  final String? serviceId;
  final DateTime startTime;
  final DateTime endTime;
  final BookingStatus status;
  final String? comment;
  final String clientName;
  final String masterName;
  final String serviceName;
  // --- НОВЫЕ ПОЛЯ ---
  final int quantity; // Сколько мест забронировано (по умолчанию 1)
  final String bookingType; // 'time_slot' или 'daily'
  final int? capacity; // Количество гостей (для daily)

  const BookingEntity({
    required this.id,
    required this.masterId,
    required this.clientId,
    this.serviceId,
    required this.startTime,
    required this.endTime,
    required this.status,
    this.comment,
    this.clientName = 'Аноним',
    this.masterName = 'Мастер',
    this.serviceName = 'Услуга',
    this.quantity = 1,
    this.bookingType = 'time_slot',
    this.capacity,
  });

  BookingEntity copyWith({
    String? id,
    String? masterId,
    String? clientId,
    String? serviceId,
    DateTime? startTime,
    DateTime? endTime,
    BookingStatus? status,
    String? comment,
    String? clientName,
    String? masterName,
    String? serviceName,
    int? quantity,
    String? bookingType,
    int? capacity,
  }) {
    return BookingEntity(
      id: id ?? this.id,
      masterId: masterId ?? this.masterId,
      clientId: clientId ?? this.clientId,
      serviceId: serviceId ?? this.serviceId,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      status: status ?? this.status,
      comment: comment ?? this.comment,
      clientName: clientName ?? this.clientName,
      masterName: masterName ?? this.masterName,
      serviceName: serviceName ?? this.serviceName,
      quantity: quantity ?? this.quantity,
      bookingType: bookingType ?? this.bookingType,
      capacity: capacity ?? this.capacity,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'master_id': masterId,
      'client_id': clientId,
      'service_id': serviceId,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime.toIso8601String(),
      'status': status.name,
      'comment': comment,
      'client_name': clientName,
      'master_name': masterName,
      'service_name': serviceName,
      'quantity': quantity,
      'booking_type': bookingType,
      'capacity': capacity,
    };
  }

  factory BookingEntity.fromJson(Map<String, dynamic> json) {
    // Поддержка вложенной структуры service
    final service = json['service'] as Map<String, dynamic>?;

    return BookingEntity(
      id: json['id'] as String,
      masterId: json['master_id'] as String,
      clientId: json['client_id'] as String,
      serviceId: json['service_id'] as String?,
      startTime: DateTime.parse(json['start_time'] as String),
      endTime: DateTime.parse(json['end_time'] as String),
      status: BookingStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => BookingStatus.pending,
      ),
      comment: json['comment'] as String?,
      clientName: json['client_name'] as String? ?? 'Аноним',
      masterName: json['master_name'] as String? ?? 'Мастер',
      serviceName: json['service_name'] as String? ??
          service?['name'] as String? ??
          'Услуга',
      quantity: json['quantity'] as int? ?? 1,
      bookingType: json['booking_type'] as String? ??
          service?['booking_type'] as String? ??
          'time_slot',
      capacity: json['capacity'] as int? ?? service?['capacity'] as int?,
    );
  }

  @override
  List<Object?> get props => [
        id,
        masterId,
        startTime,
        status,
        clientName,
        masterName,
        serviceName,
        bookingType,
        capacity,
      ];

  // Хелпер: закончилась ли запись?
  bool get isPast => DateTime.now().isAfter(endTime);

  @override
  String toString() {
    return 'BookingEntity(id: $id, clientName: $clientName, masterName: $masterName, serviceName: $serviceName, status: $status)';
  }
}
