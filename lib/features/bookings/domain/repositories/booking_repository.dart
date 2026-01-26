import '../entities/booking_entity.dart';
import '../entities/service_entity.dart';
import '../../data/models/working_hour_model.dart';

abstract class BookingRepository {
  // Получить записи для конкретного мастера на дату (для построения календаря)
  Future<List<BookingEntity>> getBookingsForMaster(
    String masterId,
    DateTime date,
  );

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

  Future<List<WorkingHour>> getSchedule(String masterId);
}
