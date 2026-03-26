import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/error/database_exception.dart';
import '../../../../core/services/google_calendar_api_service.dart'; // <-- ДОБАВИЛИ ИМПОРТ
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
        .eq('role', 'master');
    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<Map<String, dynamic>>> getMastersByCategory(
    String categoryId,
  ) async {
    final specialtiesResp = await remoteDataSource.supabase
        .from('specialties')
        .select('id')
        .eq('category_id', categoryId);

    final specialtyIds = (specialtiesResp as List).map((e) => e['id']).toList();

    if (specialtyIds.isEmpty) return [];

    final response = await remoteDataSource.supabase
        .from('profiles')
        .select()
        .filter('specialty_id', 'in', specialtyIds)
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
      return models.map((model) => model.toEntity()).toList();
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<List<BookingEntity>> getClientBookings(String clientId) async {
    try {
      final response =
          await remoteDataSource.supabase.from('bookings').select('''
            *,
            service_details:services(title, duration_min, price),
            master_profile:profiles!bookings_master_id_fkey(id, full_name, avatar_url)
          ''').eq('client_id', clientId).order('start_time', ascending: false);

      return (response as List).map((json) {
        final model = BookingModel.fromJson(json);
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
      final endTime = startTime.add(const Duration(minutes: 60));
      final user = Supabase.instance.client.auth.currentUser;

      if (user == null) {
        throw Exception("Вы не авторизованы!");
      }

      const organizationId = 'd5d6cd49-d1d4-4372-971f-1d497bdb6c0e';

      final bookingData = {
        'master_id': masterId,
        'client_id': user.id,
        'organization_id': organizationId,
        'service_id': serviceId,
        'start_time': startTime.toIso8601String(),
        'end_time': endTime.toIso8601String(),
        // ИДЕАЛЬНО: Здесь статус должен быть 'pending', чтобы мастер потом подтвердил её и она улетела в календарь.
        'status': 'confirmed',
        'comment': comment,
      };

      final model = await remoteDataSource.createBooking(bookingData);
      final createdBooking = model.toEntity();

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
      // 1. Проверяем, есть ли гугл-событие перед удалением
      final bookingResponse = await remoteDataSource.supabase
          .from('bookings')
          .select('google_event_id, master_id')
          .eq('id', bookingId)
          .maybeSingle();

      if (bookingResponse != null) {
        final googleEventId = bookingResponse['google_event_id'] as String?;
        final masterId = bookingResponse['master_id'] as String?;
        final currentUser = remoteDataSource.supabase.auth.currentUser;

        // Удаляем из календаря, если текущий юзер - это мастер этой записи
        if (googleEventId != null && currentUser?.id == masterId) {
          if (await GoogleCalendarApiService.isSignedIn()) {
            await GoogleCalendarApiService.deleteEvent(googleEventId);
          }
        }
      }

      // 2. Удаляем саму запись из БД
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

      // 1. Сначала вытаскиваем полные данные о записи (для календаря)
      final bookingResponse =
          await remoteDataSource.supabase.from('bookings').select('''
            *,
            client_profile:profiles!bookings_client_id_fkey(full_name),
            service_details:services!bookings_service_id_fkey(title)
          ''').eq('id', bookingId).single();

      final clientId = bookingResponse['client_id'] as String;
      final masterId = bookingResponse['master_id'] as String;
      final startTime = DateTime.parse(bookingResponse['start_time'] as String);
      final endTime = DateTime.parse(bookingResponse['end_time'] as String);
      final clientName =
          bookingResponse['client_profile']?['full_name'] ?? 'Клиент';
      final serviceName =
          bookingResponse['service_details']?['title'] ?? 'Услуга';
      final googleEventId = bookingResponse['google_event_id'] as String?;
      final comment = bookingResponse['comment'] as String? ?? 'Нет примечаний';

      // 2. Обновляем статус в БД
      await remoteDataSource.updateBookingStatus(bookingId, statusStr);

      // --- ИНТЕГРАЦИЯ С GOOGLE CALENDAR ---
      final currentUser = remoteDataSource.supabase.auth.currentUser;

      // Логика работает только если на устройстве сейчас авторизован мастер
      if (currentUser != null && currentUser.id == masterId) {
        final isGoogleConnected = await GoogleCalendarApiService.isSignedIn();

        if (isGoogleConnected) {
          if (newStatus == BookingStatus.confirmed && googleEventId == null) {
            // Мастер подтвердил -> Создаем событие
            final newEventId = await GoogleCalendarApiService.createEvent(
              summary: 'BookIt: $serviceName ($clientName)',
              description:
                  'Клиент: $clientName\nУслуга: $serviceName\nКомментарий: $comment',
              startTime: startTime,
              endTime: endTime,
            );

            if (newEventId != null) {
              await remoteDataSource.supabase
                  .from('bookings')
                  .update({'google_event_id': newEventId}).eq('id', bookingId);
            }
          } else if (newStatus == BookingStatus.cancelled &&
              googleEventId != null) {
            // Мастер отменил -> Удаляем событие
            await GoogleCalendarApiService.deleteEvent(googleEventId);

            await remoteDataSource.supabase
                .from('bookings')
                .update({'google_event_id': null}).eq('id', bookingId);
          }
        }
      }
      // ------------------------------------

      // 3. Уведомления клиенту
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
        .eq('master_id', masterId);

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

  @override
  Future<Map<int, int>> getHostelOccupancy({
    required String serviceId,
    required DateTime month,
  }) async {
    try {
      // 1. Сначала узнаем ПОЛНУЮ вместимость этой услуги
      final serviceData = await remoteDataSource.supabase
          .from('services')
          .select('capacity')
          .eq('id', serviceId)
          .single();

      // Если вместимость не указана, считаем, что это 1 место (может быть для VIP комнат)
      final int totalCapacity = serviceData['capacity'] ?? 1;

      // 2. Идем в Supabase и вызываем SQL-функцию (RPC), которая посчитает гостей на каждый день.
      final List<dynamic> response = await remoteDataSource.supabase.rpc(
        'count_daily_bookings',
        params: {
          'p_service_id': serviceId,
          'p_start_date': month.toIso8601String(),
          'p_end_date':
              DateTime(month.year, month.month + 1, 0).toIso8601String(),
        },
      );

      // 3. Dart-логика маппинга ответа в удобный формат
      final Map<int, int> occupancyMap = {};

      // Инициализируем карту: по умолчанию все дни полностью свободны
      final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
      for (int i = 1; i <= daysInMonth; i++) {
        occupancyMap[i] = totalCapacity;
      }

      // Обновляем карту на основе реальных броней из Supabase
      // RPC вернет список [{booking_date: '2024-05-15', booked_count: 3}, ...]
      for (var item in response) {
        final date = DateTime.parse(item['booking_date']);
        final int bookedCount = item['booked_count'] ?? 0;

        // Вычитаем занятые места из полной вместимости
        int available = totalCapacity - bookedCount;

        // Страховка: свободных мест не может быть меньше 0
        if (available < 0) available = 0;

        occupancyMap[date.day] = available;
      }

      return occupancyMap;
    } on PostgrestException catch (e) {
      throw DatabaseException(e.message);
    } catch (e) {
      throw DatabaseException('Ошибка загрузки шахматки: $e');
    }
  }
}
