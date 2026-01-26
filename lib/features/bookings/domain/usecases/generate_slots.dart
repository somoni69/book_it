import '../entities/booking_entity.dart';
import '../../data/models/working_hour_model.dart';
import '../entities/time_slot.dart';

class GenerateSlotsUseCase {
  List<TimeSlot> call({
    required List<BookingEntity> bookings,
    required List<WorkingHour> schedule, // <--- ПРИНИМАЕМ ГРАФИК
    required DateTime date,
    required int serviceDurationMin,
  }) {
    final List<TimeSlot> slots = [];

    // 1. Находим настройки для этого дня недели
    // DateTime.weekday: 1 = Пн, 7 = Вс.
    final daySettings = schedule.firstWhere(
      (h) => h.dayOfWeek == date.weekday,
      orElse: () => WorkingHour(
        id: '',
        dayOfWeek: 0,
        startTime: '09:00',
        endTime: '18:00',
        isDayOff: false,
      ), // Дефолт
    );

    // 2. Если выходной - возвращаем пустоту
    if (daySettings.isDayOff) {
      print(
        "🛑 Сегодня выходной (GenerateSlotsUseCase)!",
      ); // <--- Добавь принт сюда
      return [];
    }

    // 3. Парсим время начала и конца (строки "09:00" -> DateTime)
    final startParts = daySettings.startTime.split(':');
    final endParts = daySettings.endTime.split(':');

    final workStart = DateTime(
      date.year,
      date.month,
      date.day,
      int.parse(startParts[0]),
      int.parse(startParts[1]),
    );

    final workEnd = DateTime(
      date.year,
      date.month,
      date.day,
      int.parse(endParts[0]),
      int.parse(endParts[1]),
    );

    // 4. Генерируем слоты
    final step = Duration(minutes: serviceDurationMin);
    DateTime current = workStart;

    while (current.add(step).isBefore(workEnd) ||
        current.add(step).isAtSameMomentAs(workEnd)) {
      final slotEnd = current.add(step);

      // Проверка пересечений
      bool isOverlapping = bookings.any((booking) {
        if (booking.status == BookingStatus.cancelled) return false;
        return booking.startTime.isBefore(slotEnd) &&
            booking.endTime.isAfter(current);
      });

      // Проверка на прошедшее время (если сегодня)
      bool isPast = current.isBefore(DateTime.now());

      slots.add(
        TimeSlot(
          startTime: current,
          endTime: slotEnd,
          isAvailable: !isOverlapping && !isPast,
        ),
      );

      current = current.add(step);
    }

    return slots;
  }
}
