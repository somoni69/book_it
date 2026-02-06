import 'package:flutter/material.dart';

class ReviewEntity {
  final String id;
  final String bookingId;
  final String masterId;
  final String clientId;
  final String clientName;
  final String? clientAvatar;
  final int rating;
  final String? comment;
  final DateTime createdAt;

  const ReviewEntity({
    required this.id,
    required this.bookingId,
    required this.masterId,
    required this.clientId,
    required this.clientName,
    this.clientAvatar,
    required this.rating,
    this.comment,
    required this.createdAt,
  });

  ReviewEntity copyWith({
    String? id,
    String? bookingId,
    String? masterId,
    String? clientId,
    String? clientName,
    String? clientAvatar,
    int? rating,
    String? comment,
    DateTime? createdAt,
  }) {
    return ReviewEntity(
      id: id ?? this.id,
      bookingId: bookingId ?? this.bookingId,
      masterId: masterId ?? this.masterId,
      clientId: clientId ?? this.clientId,
      clientName: clientName ?? this.clientName,
      clientAvatar: clientAvatar ?? this.clientAvatar,
      rating: rating ?? this.rating,
      comment: comment ?? this.comment,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  List<Widget> get stars {
    return List.generate(
      5,
      (index) => Icon(
        index < rating ? Icons.star : Icons.star_border,
        size: 20,
        color: Colors.amber,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'booking_id': bookingId,
      'master_id': masterId,
      'client_id': clientId,
      'client_name': clientName,
      'client_avatar': clientAvatar,
      'rating': rating,
      'comment': comment,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory ReviewEntity.fromJson(Map<String, dynamic> json) {
    return ReviewEntity(
      id: json['id'] as String,
      bookingId: json['booking_id'] as String,
      masterId: json['master_id'] as String,
      clientId: json['client_id'] as String,
      clientName: json['client_name'] as String,
      clientAvatar: json['client_avatar'] as String?,
      rating: json['rating'] as int,
      comment: json['comment'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ReviewEntity && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'ReviewEntity(id: $id, clientName: $clientName, rating: $rating)';
  }
}
