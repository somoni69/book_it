import '../../domain/entities/review_entity.dart';

class ReviewModel {
  final String id;
  final String bookingId;
  final String masterId;
  final String clientId;
  final int rating;
  final String? comment;
  final DateTime createdAt;

  const ReviewModel({
    required this.id,
    required this.bookingId,
    required this.masterId,
    required this.clientId,
    required this.rating,
    this.comment,
    required this.createdAt,
  });

  ReviewModel copyWith({
    String? id,
    String? bookingId,
    String? masterId,
    String? clientId,
    int? rating,
    String? comment,
    DateTime? createdAt,
  }) {
    return ReviewModel(
      id: id ?? this.id,
      bookingId: bookingId ?? this.bookingId,
      masterId: masterId ?? this.masterId,
      clientId: clientId ?? this.clientId,
      rating: rating ?? this.rating,
      comment: comment ?? this.comment,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'booking_id': bookingId,
      'master_id': masterId,
      'client_id': clientId,
      'rating': rating,
      'comment': comment,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory ReviewModel.fromJson(Map<String, dynamic> json) {
    return ReviewModel(
      id: json['id'] as String,
      bookingId: json['booking_id'] as String,
      masterId: json['master_id'] as String,
      clientId: json['client_id'] as String,
      rating: json['rating'] as int,
      comment: json['comment'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  ReviewEntity toEntity({
    required String clientName,
    String? clientAvatar,
  }) {
    return ReviewEntity(
      id: id,
      bookingId: bookingId,
      masterId: masterId,
      clientId: clientId,
      clientName: clientName,
      clientAvatar: clientAvatar,
      rating: rating,
      comment: comment,
      createdAt: createdAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ReviewModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'ReviewModel(id: $id, rating: $rating)';
  }
}
