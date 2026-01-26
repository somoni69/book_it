import '../entities/booking_entity.dart';
import '../repositories/booking_repository.dart';

class CreateBookingUseCase {
  final BookingRepository repository;

  CreateBookingUseCase(this.repository);

  Future<BookingEntity> call({
    required String masterId,
    required String serviceId,
    required DateTime startTime,
    String? comment,
  }) async {
    // 1. Бизнес-правило: Нельзя записаться в прошлое
    if (startTime.isBefore(DateTime.now())) {
      throw Exception("Нельзя записаться на прошедшее время!");
    }

    // 2. Бизнес-правило: Нельзя записываться на ночь (например, с 22:00 до 08:00)
    // if (startTime.hour < 8 || startTime.hour > 22) ...

    return await repository.createBooking(
      masterId: masterId,
      serviceId: serviceId,
      startTime: startTime,
      comment: comment,
    );
  }
}
