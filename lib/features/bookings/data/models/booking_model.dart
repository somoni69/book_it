import '../../domain/entities/booking_entity.dart';

class BookingModel {
  final String id;
  final String clientId;
  final String masterId;
  final String serviceId;
  final DateTime startTime;
  final DateTime endTime;
  final String status;
  final double price;
  final String currency;
  final DateTime? createdAt;
  final String? comment;
  final double? rating;
  final Map<String, dynamic>? clientProfile;
  final Map<String, dynamic>? masterProfile;
  final Map<String, dynamic>? serviceDetails;
  final String? organizationId;

  const BookingModel({
    required this.id,
    required this.clientId,
    required this.masterId,
    required this.serviceId,
    required this.startTime,
    required this.endTime,
    required this.status,
    required this.price,
    required this.currency,
    this.createdAt,
    this.comment,
    this.rating,
    this.clientProfile,
    this.masterProfile,
    this.serviceDetails,
    this.organizationId,
  });

  BookingModel copyWith({
    String? id,
    String? clientId,
    String? masterId,
    String? serviceId,
    DateTime? startTime,
    DateTime? endTime,
    String? status,
    double? price,
    String? currency,
    DateTime? createdAt,
    String? comment,
    double? rating,
    Map<String, dynamic>? clientProfile,
    Map<String, dynamic>? masterProfile,
    Map<String, dynamic>? serviceDetails,
    String? organizationId,
  }) {
    return BookingModel(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      masterId: masterId ?? this.masterId,
      serviceId: serviceId ?? this.serviceId,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      status: status ?? this.status,
      price: price ?? this.price,
      currency: currency ?? this.currency,
      createdAt: createdAt ?? this.createdAt,
      comment: comment ?? this.comment,
      rating: rating ?? this.rating,
      clientProfile: clientProfile ?? this.clientProfile,
      masterProfile: masterProfile ?? this.masterProfile,
      serviceDetails: serviceDetails ?? this.serviceDetails,
      organizationId: organizationId ?? this.organizationId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'client_id': clientId,
      'master_id': masterId,
      'service_id': serviceId,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime.toIso8601String(),
      'status': status,
      'price': price,
      'currency': currency,
      'created_at': createdAt?.toIso8601String(),
      'comment': comment,
      'rating': rating,
      'client_profile': clientProfile,
      'master_profile': masterProfile,
      'service_details': serviceDetails,
      'organization_id': organizationId,
    };
  }

  factory BookingModel.fromJson(Map<String, dynamic> json) {
    return BookingModel(
      id: json['id'] as String,
      clientId: json['client_id'] as String,
      masterId: json['master_id'] as String,
      serviceId: json['service_id'] as String,
      startTime: DateTime.parse(json['start_time'] as String),
      endTime: DateTime.parse(json['end_time'] as String),
      status: json['status'] as String,
      price: (json['price'] as num).toDouble(),
      currency: json['currency'] as String,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      comment: json['comment'] as String?,
      rating:
          json['rating'] != null ? (json['rating'] as num).toDouble() : null,
      clientProfile: json['client_profile'] as Map<String, dynamic>?,
      masterProfile: json['master_profile'] as Map<String, dynamic>?,
      serviceDetails: json['service_details'] as Map<String, dynamic>?,
      organizationId: json['organization_id'] as String?,
    );
  }

  BookingEntity toEntity() {
    BookingStatus bookingStatus;
    switch (status.toLowerCase()) {
      case 'pending':
        bookingStatus = BookingStatus.pending;
        break;
      case 'confirmed':
        bookingStatus = BookingStatus.confirmed;
        break;
      case 'cancelled':
        bookingStatus = BookingStatus.cancelled;
        break;
      case 'completed':
        bookingStatus = BookingStatus.completed;
        break;
      default:
        bookingStatus = BookingStatus.pending;
    }

    return BookingEntity(
      id: id,
      masterId: masterId,
      clientId: clientId,
      serviceId: serviceId,
      startTime: startTime,
      endTime: endTime,
      status: bookingStatus,
      comment: comment,
      clientName: clientProfile?['full_name'] as String? ?? 'Аноним',
      masterName: masterProfile?['full_name'] as String? ?? 'Мастер',
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BookingModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'BookingModel(id: $id, status: $status)';
  }
}
