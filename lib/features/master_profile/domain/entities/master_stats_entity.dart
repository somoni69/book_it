class MasterStatsEntity {
  final String masterId;
  final double averageRating;
  final int totalBookings;
  final int completedBookings;
  final int pendingBookings;
  final int cancelledBookings;
  final double totalRevenue;
  final double monthlyRevenue;
  final int uniqueClients;
  final DateTime? lastBookingDate;
  final Map<String, int> bookingsByService;

  const MasterStatsEntity({
    required this.masterId,
    required this.averageRating,
    required this.totalBookings,
    required this.completedBookings,
    required this.pendingBookings,
    required this.cancelledBookings,
    required this.totalRevenue,
    required this.monthlyRevenue,
    required this.uniqueClients,
    required this.lastBookingDate,
    required this.bookingsByService,
  });

  MasterStatsEntity copyWith({
    String? masterId,
    double? averageRating,
    int? totalBookings,
    int? completedBookings,
    int? pendingBookings,
    int? cancelledBookings,
    double? totalRevenue,
    double? monthlyRevenue,
    int? uniqueClients,
    DateTime? lastBookingDate,
    Map<String, int>? bookingsByService,
  }) {
    return MasterStatsEntity(
      masterId: masterId ?? this.masterId,
      averageRating: averageRating ?? this.averageRating,
      totalBookings: totalBookings ?? this.totalBookings,
      completedBookings: completedBookings ?? this.completedBookings,
      pendingBookings: pendingBookings ?? this.pendingBookings,
      cancelledBookings: cancelledBookings ?? this.cancelledBookings,
      totalRevenue: totalRevenue ?? this.totalRevenue,
      monthlyRevenue: monthlyRevenue ?? this.monthlyRevenue,
      uniqueClients: uniqueClients ?? this.uniqueClients,
      lastBookingDate: lastBookingDate ?? this.lastBookingDate,
      bookingsByService: bookingsByService ?? this.bookingsByService,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'master_id': masterId,
      'average_rating': averageRating,
      'total_bookings': totalBookings,
      'completed_bookings': completedBookings,
      'pending_bookings': pendingBookings,
      'cancelled_bookings': cancelledBookings,
      'total_revenue': totalRevenue,
      'monthly_revenue': monthlyRevenue,
      'unique_clients': uniqueClients,
      'last_booking_date': lastBookingDate?.toIso8601String(),
      'bookings_by_service': bookingsByService,
    };
  }

  factory MasterStatsEntity.fromJson(Map<String, dynamic> json) {
    return MasterStatsEntity(
      masterId: json['master_id'] as String,
      averageRating: (json['average_rating'] as num).toDouble(),
      totalBookings: json['total_bookings'] as int,
      completedBookings: json['completed_bookings'] as int,
      pendingBookings: json['pending_bookings'] as int,
      cancelledBookings: json['cancelled_bookings'] as int,
      totalRevenue: (json['total_revenue'] as num).toDouble(),
      monthlyRevenue: (json['monthly_revenue'] as num).toDouble(),
      uniqueClients: json['unique_clients'] as int,
      lastBookingDate: json['last_booking_date'] != null
          ? DateTime.parse(json['last_booking_date'] as String)
          : null,
      bookingsByService:
          Map<String, int>.from(json['bookings_by_service'] as Map),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MasterStatsEntity && other.masterId == masterId;
  }

  @override
  int get hashCode => masterId.hashCode;

  @override
  String toString() {
    return 'MasterStatsEntity(masterId: $masterId, averageRating: $averageRating, totalBookings: $totalBookings)';
  }
}
