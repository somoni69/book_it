import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class ICalSyncService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Главная функция синхронизации
  /// Принимает [icalUrl] (ссылку от Airbnb) и [serviceId] (ID нашей комнаты/койки)
  Future<void> syncWithAirbnb(String icalUrl, String serviceId) async {
    try {
      // 1. Скачиваем файл .ics
      final response = await http.get(Uri.parse(icalUrl));
      if (response.statusCode != 200) {
        throw Exception('Не удалось скачать iCal файл. Проверьте ссылку.');
      }

      final iCalData = response.body;

      // 2. Парсим события
      final List<Map<String, DateTime>> blockedDates = _parseICalEvents(iCalData);

      if (blockedDates.isEmpty) {
        return; // Нет бронирований на Airbnb
      }

      final masterId = _supabase.auth.currentUser!.id;

      // 3. Подготавливаем батч-запрос для Supabase
      // Мы будем сохранять их как брони от клиента "Airbnb Sync"
      final List<Map<String, dynamic>> bookingsToInsert = blockedDates.map((dates) {
        return {
          'master_id': masterId,
          'service_id': serviceId,
          // Клиента в базе у нас нет, поэтому мы просто используем свой же ID мастера 
          // или создаем системного пользователя "Airbnb" (пока пишем ID мастера как владельца брони)
          'client_id': masterId, 
          'start_time': dates['start']!.toIso8601String(),
          'end_time': dates['end']!.toIso8601String(),
          'status': 'confirmed',
          'booking_type': 'daily',
          'capacity': 1, // Блокируем 1 место (если это хостел) или всё (если квартира)
          'comment': 'Бронь с Airbnb/Booking 🌍' // Метка, чтобы отличать их в UI
        };
      }).toList();

      // 4. Очищаем старые синхронизации (чтобы не было дублей)
      // Удаляем только те, что начинаются сегодня или позже и имеют нашу метку
      final now = DateTime.now().toUtc().toIso8601String();
      await _supabase
          .from('bookings')
          .delete()
          .eq('service_id', serviceId)
          .eq('comment', 'Бронь с Airbnb/Booking 🌍')
          .gte('start_time', now);

      // 5. Записываем свежие данные из Airbnb в нашу базу!
      // Фильтруем: добавляем только те события, которые еще не прошли
      final futureBookings = bookingsToInsert.where((b) {
         final endTime = DateTime.parse(b['end_time'] as String);
         return endTime.isAfter(DateTime.now());
      }).toList();

      if (futureBookings.isNotEmpty) {
        await _supabase.from('bookings').insert(futureBookings);
      }

    } catch (e) {
      throw Exception('Ошибка синхронизации iCal: $e');
    }
  }

  /// Вспомогательная функция, которая читает текстовый файл .ics
  /// и вытаскивает из него даты START и END.
  List<Map<String, DateTime>> _parseICalEvents(String iCalData) {
    final List<Map<String, DateTime>> events = [];
    
    // Разбиваем файл на строки
    final lines = iCalData.split('\n');
    
    DateTime? currentStart;
    DateTime? currentEnd;
    bool inEvent = false;

    for (var line in lines) {
      line = line.trim();
      
      if (line == 'BEGIN:VEVENT') {
        inEvent = true;
        currentStart = null;
        currentEnd = null;
      } else if (line == 'END:VEVENT' && inEvent) {
        if (currentStart != null && currentEnd != null) {
          events.add({
            'start': currentStart,
            'end': currentEnd,
          });
        }
        inEvent = false;
      } else if (inEvent) {
        // Парсим начало брони: DTSTART;VALUE=DATE:20260510
        if (line.startsWith('DTSTART')) {
          currentStart = _parseICalDate(line);
        }
        // Парсим конец брони: DTEND;VALUE=DATE:20260515
        else if (line.startsWith('DTEND')) {
          currentEnd = _parseICalDate(line);
        }
      }
    }

    return events;
  }

  /// Превращает строку "DTSTART;VALUE=DATE:20260510" в объект DateTime во Flutter
  DateTime? _parseICalDate(String line) {
    try {
      // Ищем где начинается дата (после двоеточия)
      final parts = line.split(':');
      if (parts.length > 1) {
        String dateStr = parts[1].trim();
        // В iCal формат обычно YYYYMMDD (например 20260510)
        if (dateStr.length >= 8) {
          int year = int.parse(dateStr.substring(0, 4));
          int month = int.parse(dateStr.substring(4, 6));
          int day = int.parse(dateStr.substring(6, 8));
          
          // Возвращаем дату (заезд обычно в 14:00)
          return DateTime.utc(year, month, day, 14, 0); 
        }
      }
    } catch (e) {
      return null;
    }
    return null;
  }
}