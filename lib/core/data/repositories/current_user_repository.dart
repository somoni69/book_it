import 'package:supabase_flutter/supabase_flutter.dart';
import '../../error/database_exception.dart';
import '../../../features/auth/domain/entities/profile_entity.dart';

class CurrentUserRepository {
  final SupabaseClient _supabaseClient;

  CurrentUserRepository(this._supabaseClient);

  Future<Profile> getCurrentUser() async {
    try {
      final user = _supabaseClient.auth.currentUser;
      if (user == null) {
        throw DatabaseException('User not authorized');
      }

      final response = await _supabaseClient
          .from('profiles')
          .select()
          .eq('id', user.id)
          .single();

      return _profileFromJson(response);
    } catch (e) {
      throw DatabaseException('Failed to load profile: $e');
    }
  }

  Profile _profileFromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String,
      email: json['email'] as String,
      fullName: json['full_name'] as String,
      role: json['role'] == 'master' ? UserRole.master : UserRole.client,
      avatarUrl: json['avatar_url'] as String?,
      specialtyId: json['specialty_id'] as String?,
      organizationId: json['organization_id'] as String?,
      description: json['description'] as String?,
      instagramUrl: json['instagram_url'] as String?,
      experienceYears: json['experience_years'] as int?,
      hourlyRate: (json['hourly_rate'] as num?)?.toDouble(),
      isAvailable: json['is_available'] as bool? ?? true,
    );
  }

  Future<String?> getCurrentUserOrganizationId() async {
    final user = await getCurrentUser();
    return user.organizationId;
  }

  Future<bool> isCurrentUserMaster() async {
    final user = await getCurrentUser();
    return user.role == UserRole.master;
  }

  Future<List<Profile>> getMastersInMyOrganization() async {
    try {
      final user = await getCurrentUser();

      if (user.organizationId == null) {
        return [];
      }

      final response = await _supabaseClient
          .from('profiles')
          .select()
          .eq('organization_id', user.organizationId!)
          .eq('role', 'master')
          .eq('is_available', true);

      return (response as List).map((json) => _profileFromJson(json)).toList();
    } catch (e) {
      throw DatabaseException('Failed to load masters: $e');
    }
  }

  Future<String> getCurrentUserId() async {
    final user = _supabaseClient.auth.currentUser;
    if (user == null) {
      throw DatabaseException('User not authorized');
    }
    return user.id;
  }
}
