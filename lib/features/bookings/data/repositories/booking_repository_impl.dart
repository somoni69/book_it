import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/error/database_exception.dart';
import '../../domain/entities/booking_entity.dart';
import '../../domain/entities/service_entity.dart';
import '../../domain/entities/working_hour_entity.dart';
import '../../domain/repositories/booking_repository.dart';
import '../datasources/booking_remote_datasource.dart';
import '../models/booking_model.dart';
import '../models/working_hour_model.dart';

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
      rethrow;
    }
  }

  @override
  Future<List<BookingEntity>> getClientBookings(String clientId) async {
    try {
      final response = await remoteDataSource.supabase
          .from('bookings')
          .select('''
            *,
            services:service_id(title, duration_min, price),
            master:profiles!bookings_master_id_fkey(id, full_name, avatar_url)
          ''')
          .eq('client_id', clientId)
          .order('start_time', ascending: false);

      return (response as List).map((json) {
        // Создаем модель из JSON
        final model = BookingModel.fromJson(json);

        // Конвертируем в entity
        return model.toEntity();
      }).toList();
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<BookingEntity> createBooking({
    required String masterId,
    required String serviceId,
    required DateTime startTime,
    String? comment,
  }) async {
    try {
      // 1. Рассчитываем время окончания (пока хардкод 60 минут)
      final endTime = startTime.add(const Duration(minutes: 60));

      // 1. ПОЛУЧАЕМ РЕАЛЬНОГО ЮЗЕРА
      final user = Supabase.instance.client.auth.currentUser;

      if (user == null) {
        throw Exception("Вы не авторизованы!");
      }

      // 2. Хардкод ОРГАНИЗАЦИИ пока оставляем (выбор салона будет позже)
      const organizationId = 'd5d6cd49-d1d4-4372-971f-1d497bdb6c0e';

      final bookingData = {
        'master_id': masterId,
        'client_id': user.id,
        'organization_id': organizationId,
        'service_id': serviceId,
        'start_time': startTime.toIso8601String(),
        'end_time': endTime.toIso8601String(),
        'status': 'confirmed',
        'comment': comment,
      };

      final model = await remoteDataSource.createBooking(bookingData);
      final createdBooking = model.toEntity();

      // Отправляем push уведомление мастеру
      await _sendPushNotificationToMaster(
        masterId: masterId,
        title: '📅 Новая запись!',
        body: 'У вас новая запись на ${_formatTime(startTime)}',
        screen: 'booking_details',
        data: {'booking_id': createdBooking.id},
      );

      return createdBooking;
    } on PostgrestException catch (e) {
      throw DatabaseException(e.message);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> cancelBooking(String bookingId) async {
    try {
      await remoteDataSource.deleteBooking(bookingId);
    } catch (e) {
      debugPrint("Error cancelling booking: $e");
      rethrow;
    }
  }

  @override
  Future<void> updateBookingStatus(
    String bookingId,
    BookingStatus newStatus,
  ) async {
    try {
      final statusStr = newStatus.name;
      await remoteDataSource.updateBookingStatus(bookingId, statusStr);

      // Получаем детали брони для уведомления
      final bookingResponse = await remoteDataSource.supabase
          .from('bookings')
          .select('client_id, master_id, start_time')
          .eq('id', bookingId)
          .single();

      final clientId = bookingResponse['client_id'] as String;
      final startTime = DateTime.parse(bookingResponse['start_time'] as String);

      // Отправляем уведомление клиенту
      String title, body;

      switch (newStatus) {
        case BookingStatus.confirmed:
          title = '✅ Запись подтверждена';
          body = 'Мастер подтвердил вашу запись на ${_formatTime(startTime)}';
          break;
        case BookingStatus.cancelled:
          title = '❌ Запись отменена';
          body = 'Мастер отменил вашу запись на ${_formatTime(startTime)}';
          break;
        default:
          return;
      }

      await _sendPushNotificationToClient(
        clientId: clientId,
        title: title,
        body: body,
        screen: 'booking_details',
        data: {'booking_id': bookingId},
      );
    } on PostgrestException catch (e) {
      throw DatabaseException(e.message);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> _sendPushNotificationToMaster({
    required String masterId,
    required String title,
    required String body,
    String? screen,
    Map<String, dynamic>? data,
  }) async {
    try {
      await remoteDataSource.supabase.rpc(
        'send_push_notification',
        params: {
          'p_user_id': masterId,
          'p_title': title,
          'p_body': body,
          'p_screen': screen,
          'p_data': data ?? {},
        },
      );
    } catch (e) {
      debugPrint('❌ Ошибка отправки push мастеру: $e');
    }
  }

  Future<void> _sendPushNotificationToClient({
    required String clientId,
    required String title,
    required String body,
    String? screen,
    Map<String, dynamic>? data,
  }) async {
    try {
      await remoteDataSource.supabase.rpc(
        'send_push_notification',
        params: {
          'p_user_id': clientId,
          'p_title': title,
          'p_body': body,
          'p_screen': screen,
          'p_data': data ?? {},
        },
      );
    } catch (e) {
      debugPrint('❌ Ошибка отправки push клиенту: $e');
    }
  }

  String _formatTime(DateTime time) {
    return '${time.hour}:${time.minute.toString().padLeft(2, '0')}';
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
  Future<List<WorkingHourEntity>> getSchedule(String masterId) async {
    final response = await remoteDataSource.supabase
        .from('working_hours')
        .select()
        .eq('master_id', masterId)
        .eq('is_active', true)
        .order('day_of_week');

    return (response as List)
        .map((json) => WorkingHourModel.fromJson(json).toEntity())
        .toList();
  }
}
