import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/booking_entity.dart';
import '../../domain/entities/service_entity.dart';
import '../../domain/repositories/booking_repository.dart';
import '../datasources/booking_remote_datasource.dart';
import '../../data/models/working_hour_model.dart';

class BookingRepositoryImpl implements BookingRepository {
  final BookingRemoteDataSource remoteDataSource;

  BookingRepositoryImpl(this.remoteDataSource);

  Future<List<Map<String, dynamic>>> getMasters() async {
    final response = await remoteDataSource.supabase
        .from('profiles')
        .select('id, full_name, avatar_url')
        .eq('role', 'master'); // Ищем только мастеров
    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<Map<String, dynamic>>> getMastersByCategory(
    String categoryId,
  ) async {
    // 1. Сначала узнаем ID всех специальностей в этой категории
    final specialtiesResp = await remoteDataSource.supabase
        .from('specialties')
        .select('id')
        .eq('category_id', categoryId);

    final specialtyIds = (specialtiesResp as List).map((e) => e['id']).toList();

    if (specialtyIds.isEmpty) return [];

    // 2. Ищем мастеров с этими специальностями
    final response = await remoteDataSource.supabase
        .from('profiles')
        .select() // Подтянем название специальности
        .filter('specialty_id', 'in', specialtyIds) // Фильтр IN
        .eq('role', 'master');

    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<Map<String, dynamic>>> getCategories() async {
    final response = await remoteDataSource.supabase
        .from('categories')
        .select('id, name, icon')
        .order('name');
    return List<Map<String, dynamic>>.from(response);
  }

  @override
  Future<List<BookingEntity>> getBookingsForMaster(
    String masterId,
    DateTime date,
  ) async {
    try {
      final models = await remoteDataSource.getBookings(masterId, date);
      // Мапим модели в энтити
      return models.map((model) => model.toEntity()).toList();
    } catch (e) {
      // Тут в реальном проекте мы бы возвращали Failure(Left)
      print("Error fetching bookings: $e");
      rethrow;
    }
  }

  @override
  Future<BookingEntity> createBooking({
    required String masterId,
    required String
    serviceId, // <-- Обрати внимание, serviceId может быть null в Entity, но тут мы ожидаем String?
    required DateTime startTime,
    String? comment,
  }) async {
    // 1. Рассчитываем время окончания (пока хардкод 60 минут)
    final endTime = startTime.add(const Duration(minutes: 60));

    // 1. ПОЛУЧАЕМ РЕАЛЬНОГО ЮЗЕРА
    // Для этого нам нужен SupabaseClient. Мы можем передать его в конструктор или взять глобальный singleton.
    // Так как в remoteDataSource уже есть клиент, но он приватный... для скорости возьмем глобальный.
    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) {
      throw Exception("Вы не авторизованы!");
    }

    // 2. Хардкод ОРГАНИЗАЦИИ пока оставляем (выбор салона будет позже)
    // Используем тот же UUID, что и ранее
    const organizationId = 'd5d6cd49-d1d4-4372-971f-1d497bdb6c0e';

    final bookingData = {
      'master_id': masterId,
      'client_id': user.id, // <--- ТЕПЕРЬ ТУТ РЕАЛЬНЫЙ ID!
      'organization_id': organizationId,
      'service_id': null,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime.toIso8601String(),
      'status': 'confirmed',
      'comment': comment,
    };

    final model = await remoteDataSource.createBooking(bookingData);
    return model.toEntity();
  }

  @override
  Future<void> cancelBooking(String bookingId) async {
    try {
      await remoteDataSource.deleteBooking(bookingId);
    } catch (e) {
      print("Error cancelling booking: $e");
      rethrow;
    }
  }

  @override
  Future<void> updateBookingStatus(
    String bookingId,
    BookingStatus newStatus,
  ) async {
    final statusStr = newStatus.name;
    await remoteDataSource.updateBookingStatus(bookingId, statusStr);
  }

  @override
  Future<List<ServiceEntity>> getServices(String masterId) async {
    final response = await remoteDataSource.supabase
        .from('services')
        .select()
        .eq('master_id', masterId); // Фильтруем по мастеру

    return (response as List)
        .map((json) => ServiceEntity.fromJson(json))
        .toList();
  }

  @override
  Future<List<WorkingHour>> getSchedule(String masterId) async {
    final response = await remoteDataSource.supabase
        .from('working_hours')
        .select()
        .eq('master_id', masterId);

    return (response as List).map((e) => WorkingHour.fromJson(e)).toList();
  }
}
