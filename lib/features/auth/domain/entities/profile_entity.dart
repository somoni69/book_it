enum UserRole { client, master, admin }

class Profile {
  final String id;
  final String email;
  final String fullName;
  final UserRole role;
  final String? avatarUrl;
  final String? specialtyId;
  final String? description;
  final String? instagramUrl;
  final int? experienceYears;
  final double? hourlyRate;
  final bool isAvailable;
  final List<String> portfolioPhotos;
  final double? rating;
  final int? completedBookings;
  final double? totalRevenue;
  final String? organizationId;

  const Profile({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    this.avatarUrl,
    this.specialtyId,
    this.description,
    this.instagramUrl,
    this.experienceYears,
    this.hourlyRate,
    this.isAvailable = true,
    this.portfolioPhotos = const [],
    this.rating,
    this.completedBookings,
    this.totalRevenue,
    this.organizationId,
  });

  Profile copyWith({
    String? id,
    String? email,
    String? fullName,
    UserRole? role,
    String? avatarUrl,
    String? specialtyId,
    String? description,
    String? instagramUrl,
    int? experienceYears,
    double? hourlyRate,
    bool? isAvailable,
    List<String>? portfolioPhotos,
    double? rating,
    int? completedBookings,
    double? totalRevenue,
    String? organizationId,
  }) {
    return Profile(
      id: id ?? this.id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      role: role ?? this.role,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      specialtyId: specialtyId ?? this.specialtyId,
      description: description ?? this.description,
      instagramUrl: instagramUrl ?? this.instagramUrl,
      experienceYears: experienceYears ?? this.experienceYears,
      hourlyRate: hourlyRate ?? this.hourlyRate,
      isAvailable: isAvailable ?? this.isAvailable,
      portfolioPhotos: portfolioPhotos ?? this.portfolioPhotos,
      rating: rating ?? this.rating,
      completedBookings: completedBookings ?? this.completedBookings,
      totalRevenue: totalRevenue ?? this.totalRevenue,
      organizationId: organizationId ?? this.organizationId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'full_name': fullName,
      'role': role.name,
      'avatar_url': avatarUrl,
      'specialty_id': specialtyId,
      'description': description,
      'instagram_url': instagramUrl,
      'experience_years': experienceYears,
      'hourly_rate': hourlyRate,
      'is_available': isAvailable,
      'portfolio_photos': portfolioPhotos,
      'rating': rating,
      'completed_bookings': completedBookings,
      'total_revenue': totalRevenue,
      'organization_id': organizationId,
    };
  }

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String,
      email: json['email'] as String,
      fullName: json['full_name'] as String,
      role: UserRole.values.firstWhere(
        (e) => e.name == json['role'],
        orElse: () => UserRole.client,
      ),
      avatarUrl: json['avatar_url'] as String?,
      specialtyId: json['specialty_id'] as String?,
      description: json['description'] as String?,
      instagramUrl: json['instagram_url'] as String?,
      experienceYears: json['experience_years'] as int?,
      hourlyRate: json['hourly_rate'] != null
          ? (json['hourly_rate'] as num).toDouble()
          : null,
      isAvailable: json['is_available'] as bool? ?? true,
      portfolioPhotos: json['portfolio_photos'] != null
          ? List<String>.from(json['portfolio_photos'] as List)
          : const [],
      rating:
          json['rating'] != null ? (json['rating'] as num).toDouble() : null,
      completedBookings: json['completed_bookings'] as int?,
      totalRevenue: json['total_revenue'] != null
          ? (json['total_revenue'] as num).toDouble()
          : null,
      organizationId: json['organization_id'] as String?,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Profile && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'Profile(id: $id, email: $email, fullName: $fullName, role: $role)';
  }
}
