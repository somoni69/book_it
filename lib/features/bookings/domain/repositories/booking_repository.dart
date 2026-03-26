import '../entities/booking_entity.dart';
import '../entities/service_entity.dart';
import '../entities/working_hour_entity.dart';

abstract class BookingRepository {
  // Получить записи для конкретного мастера на дату (для построения календаря)
  Future<List<BookingEntity>> getBookingsForMaster(
    String masterId,
    DateTime date,
  );

  // Получить все записи клиента
  Future<List<BookingEntity>> getClientBookings(String clientId);

  // Создать новую запись
  Future<BookingEntity> createBooking({
    required String masterId,
    required String serviceId,
    required DateTime startTime,
    String? comment,
  });

  // Отменить запись
  Future<void> cancelBooking(String bookingId);

  // Обновить статус (например, отменить или завершить)
  Future<void> updateBookingStatus(String bookingId, BookingStatus newStatus);

  Future<List<ServiceEntity>> getServices(String masterId);

  Future<List<WorkingHourEntity>> getSchedule(String masterId);

  /// ПОСУТОЧНАЯ ШАХМАТКА: Получает загруженность хостела на месяц.
  /// Принимает [serviceId] (конкретная койка/комната) и [month] (первое число месяца).
  /// Возвращает Map<Число_Месяца, Кол-во_Свободных_Мест>.
  /// Например: {1: 8, 2: 7, 3: 0, 4: 8...}
  Future<Map<int, int>> getHostelOccupancy({
    required String serviceId,
    required DateTime month,
  });
}
