import 'package:flutter/foundation.dart';
import 'package:add_2_calendar/add_2_calendar.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:book_it/features/bookings/domain/entities/booking_entity.dart';

class CalendarService {
  static final CalendarService _instance = CalendarService._internal();
  factory CalendarService() => _instance;
  CalendarService._internal();

  // Добавление записи в календарь
  Future<bool> addBookingToCalendar({
    required BookingEntity booking,
    required String serviceName,
    required String masterName,
    String? clientName,
  }) async {
    try {
      // Запрашиваем разрешения (для Android)
      if (await _requestCalendarPermission()) {
        final event = Event(
          title: 'Запись: $serviceName',
          description: _buildEventDescription(booking, masterName, clientName),
          location: 'BookIt - Онлайн запись',
          startDate: booking.startTime,
          endDate: booking.endTime,
          allDay: false,
          recurrence: null,
          androidParams: const AndroidParams(emailInvites: []),
        );

        final result = await Add2Calendar.addEvent2Cal(event);
        return result;
      }
      return false;
    } catch (e) {
      debugPrint('❌ Ошибка добавления в календарь: $e');
      return false;
    }
  }

  Future<bool> _requestCalendarPermission() async {
    try {
      // Для Android
      if (defaultTargetPlatform == TargetPlatform.android) {
        final status = await Permission.calendarFullAccess.request();
        return status.isGranted;
      }
      return true; // Для других платформ или если не Android
    } catch (e) {
      return false;
    }
  }

  String _buildEventDescription(
    BookingEntity booking,
    String masterName,
    String? clientName,
  ) {
    final buffer = StringBuffer();

    buffer.writeln('Запись создана через BookIt');
    buffer.writeln('');

    if (clientName != null) {
      buffer.writeln('👤 Клиент: $clientName');
    }

    buffer.writeln('👨‍🔧 Мастер: $masterName');
    // buffer.writeln('💰 Стоимость: ${booking.price} сомони'); // У BookingEntity нет price!
    buffer.writeln('📞 Для связи: используйте приложение BookIt');

    buffer.writeln('📊 Статус: ${_getStatusText(booking.status.name)}');

    return buffer.toString();
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'Ожидает подтверждения';
      case 'confirmed':
        return 'Подтверждена';
      case 'cancelled':
        return 'Отменена';
      case 'completed':
        return 'Выполнена';
      default:
        return status;
    }
  }

  // Удаление записи из календаря (по ID события)
  Future<void> removeBookingFromCalendar(String eventId) async {
    // TODO: Реализовать при необходимости
    debugPrint('Удаление события из календаря: $eventId');
  }

  // Синхронизация всех записей с календарем
  Future<void> syncAllBookingsWithCalendar(List<BookingEntity> bookings) async {
    for (final booking in bookings) {
      // Только подтвержденные и будущие записи
      if (booking.status == BookingStatus.confirmed &&
          booking.startTime.isAfter(DateTime.now())) {
        // TODO: Получить детали услуги и мастера
        // await addBookingToCalendar(...);
      }
    }
  }
}
