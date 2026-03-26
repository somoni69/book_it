import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/service_entity.dart';
import '../../domain/repositories/service_repository.dart';

class ServiceRepositoryImpl implements ServiceRepository {
  final SupabaseClient _supabaseClient;

  ServiceRepositoryImpl(this._supabaseClient);

  @override
  Future<List<ServiceEntity>> getServicesByMaster(String masterId) async {
    try {
      final response = await _supabaseClient
          .from('services')
          .select()
          .eq('master_id', masterId)
          .order('title');

      return (response as List)
          .map((json) => ServiceEntity.fromJson(json))
          .toList();
    } on PostgrestException catch (e) {
      throw Exception('Database error: ${e.message}');
    } catch (e) {
      throw Exception('Failed to load services: $e');
    }
  }

  @override
  Future<ServiceEntity> createService(ServiceEntity service) async {
    try {
      // Get the master's organization or use default
      String? orgId;

      // Try to get organization from the master's profile
      final profileResponse = await _supabaseClient
          .from('profiles')
          .select('organization_id')
          .eq('id', service.masterId)
          .maybeSingle();

      if (profileResponse != null &&
          profileResponse['organization_id'] != null) {
        orgId = profileResponse['organization_id'] as String;
      } else {
        // Fallback: try to get or create organization for this master
        final existingOrg = await _supabaseClient
            .from('organizations')
            .select('id')
            .eq('owner_id', service.masterId)
            .maybeSingle();

        if (existingOrg != null) {
          orgId = existingOrg['id'] as String;
        } else {
          // Create a new organization for this master
          final newOrg = await _supabaseClient
              .from('organizations')
              .insert({
                'name': 'Personal Business',
                'owner_id': service.masterId,
                'type': 'individual',
              })
              .select()
              .single();
          orgId = newOrg['id'] as String;
        }
      }

      final data = {
        'master_id': service.masterId,
        'organization_id': orgId,
        'title': service.title,
        'price': service.price,
        'duration_min': service.durationMin,
        'booking_type': service.bookingType,
        'capacity': service.capacity,
      };

      final response =
          await _supabaseClient.from('services').insert(data).select().single();

      return ServiceEntity.fromJson(response);
    } on PostgrestException catch (e) {
      throw Exception('Database error: ${e.message}');
    } catch (e) {
      throw Exception('Failed to create service: $e');
    }
  }

  @override
  Future<ServiceEntity> updateService(ServiceEntity service) async {
    try {
      final data = {
        'title': service.title,
        'price': service.price,
        'duration_min': service.durationMin,
        'booking_type': service.bookingType,
        'capacity': service.capacity,
      };

      final response = await _supabaseClient
          .from('services')
          .update(data)
          .eq('id', service.id)
          .select()
          .single();

      return ServiceEntity.fromJson(response);
    } on PostgrestException catch (e) {
      throw Exception('Database error: ${e.message}');
    } catch (e) {
      throw Exception('Failed to update service: $e');
    }
  }

  @override
  Future<void> deleteService(String serviceId) async {
    try {
      await _supabaseClient.from('services').delete().eq('id', serviceId);
    } on PostgrestException catch (e) {
      throw Exception('Database error: ${e.message}');
    } catch (e) {
      throw Exception('Failed to delete service: $e');
    }
  }
}
