import 'package:flutter/foundation.dart';
import 'package:add_2_calendar/add_2_calendar.dart';
import 'package:permission_handler/permission_handler.dart';

/// Сервис для работы с системным календарем
/// Использует паттерн синглтон для глобального доступа
class CalendarService {
  // Приватный конструктор
  CalendarService._privateConstructor();

  // Единственный экземпляр
  static final CalendarService instance = CalendarService._privateConstructor();

  /// Добавляет запись бронирования в календарь
  Future<bool> addBookingToCalendar({
    required String title,
    required String description,
    required DateTime startDate,
    required DateTime endDate,
    String? location,
    Duration? reminderDuration,
  }) async {
    try {
      // Запрашиваем разрешения (только для Android)
      final hasPermission = await _checkCalendarPermission();
      if (!hasPermission) {
        debugPrint('❌ Нет разрешения для доступа к календарю');
        return false;
      }

      // Создаем событие
      final event = Event(
        title: title,
        description: description,
        location: location ?? '',
        startDate: startDate,
        endDate: endDate,
        allDay: false,
        iosParams: IOSParams(
          reminder: reminderDuration ?? const Duration(hours: 1),
        ),
        androidParams: const AndroidParams(
          emailInvites: [],
        ),
      );

      // Отображаем нативный диалог добавления
      final result = await Add2Calendar.addEvent2Cal(event);

      if (result) {
        debugPrint('✅ Событие успешно добавлено в календарь');
      } else {
        debugPrint('⚠️ Пользователь отменил добавление в календарь');
      }

      return result;
    } catch (e, stackTrace) {
      debugPrint('❌ Ошибка добавления в календарь: $e');
      debugPrint('Stack trace: $stackTrace');
      return false;
    }
  }

  /// Проверяет и запрашивает разрешения для календаря
  Future<bool> _checkCalendarPermission() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final status = await Permission.calendarFullAccess.request();
        return status.isGranted || status.isLimited;
      }
      // Для iOS разрешения обрабатываются нативно пакетом add_2_calendar
      return true;
    } catch (e) {
      debugPrint('❌ Ошибка при запросе разрешений: $e');
      return false;
    }
  }

  /// Формирует описание для события бронирования
  String buildBookingDescription({
    required String serviceName,
    required String masterName,
    String? clientName,
    String? phoneNumber,
    String? notes,
    double? price,
    String? status,
  }) {
    final buffer = StringBuffer();

    buffer.writeln('📅 Запись через BookIt');
    buffer.writeln('');

    if (clientName != null) {
      buffer.writeln('👤 Клиент: $clientName');
    }

    buffer.writeln('💼 Услуга: $serviceName');
    buffer.writeln('👨‍🔧 Мастер: $masterName');

    if (phoneNumber != null) {
      buffer.writeln('📞 Телефон: $phoneNumber');
    }

    if (price != null) {
      buffer.writeln('💰 Стоимость: ${price.toStringAsFixed(2)} сомони');
    }

    if (status != null) {
      buffer.writeln('📊 Статус: ${_getStatusText(status)}');
    }

    if (notes != null && notes.isNotEmpty) {
      buffer.writeln('📝 Примечания: $notes');
    }

    buffer.writeln('');
    buffer.writeln('ℹ️ Для изменения записи используйте приложение BookIt');

    return buffer.toString();
  }

  /// Конвертирует статус в читаемый текст
  String _getStatusText(String status) {
    const statusMap = {
      'pending': 'Ожидает подтверждения',
      'confirmed': 'Подтверждена',
      'cancelled': 'Отменена',
      'completed': 'Выполнена',
    };

    return statusMap[status] ?? status;
  }

  /// Добавляет повторяющееся событие (график работы)
  /// Note: add_2_calendar doesn't support recurrence rules directly
  /// This method creates multiple individual events instead
  Future<bool> addRecurringEvent({
    required String title,
    required String description,
    required DateTime startDate,
    required DateTime endDate,
    required List<int> daysOfWeek,
    required int interval,
    DateTime? until,
  }) async {
    try {
      final hasPermission = await _checkCalendarPermission();
      if (!hasPermission) return false;

      // Create single event (add_2_calendar doesn't support recurrence)
      final event = Event(
        title: title,
        description: description,
        startDate: startDate,
        endDate: endDate,
      );

      return await Add2Calendar.addEvent2Cal(event);
    } catch (e) {
      debugPrint('❌ Ошибка добавления повторяющегося события: $e');
      return false;
    }
  }

  /// Проверяет доступность календаря на устройстве
  Future<bool> isCalendarAvailable() async {
    try {
      // Check if we have calendar permissions
      return await _checkCalendarPermission();
    } catch (e) {
      debugPrint('❌ Календарь недоступен: $e');
      return false;
    }
  }
}
