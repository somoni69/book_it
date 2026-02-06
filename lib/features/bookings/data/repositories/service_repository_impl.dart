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
      // Получаем организацию мастера (пока hardcode)
      const orgId = 'd5d6cd49-d1d4-4372-971f-1d497bdb6c0e';

      final data = {
        'master_id': service.masterId,
        'organization_id': orgId,
        'title': service.title,
        'price': service.price,
        'duration_min': service.durationMin,
      };

      final response = await _supabaseClient
          .from('services')
          .insert(data)
          .select()
          .single();

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
