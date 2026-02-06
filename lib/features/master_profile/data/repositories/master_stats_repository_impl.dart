import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/master_stats_entity.dart';
import '../../domain/repositories/master_stats_repository.dart';

class MasterStatsRepositoryImpl implements MasterStatsRepository {
  final SupabaseClient _supabase;

  MasterStatsRepositoryImpl(this._supabase);

  @override
  Future<MasterStatsEntity> getMasterStats(String masterId) async {
    try {
      // 1. Получаем статистику по бронированиям
      final bookingsResponse = await _supabase
          .from('bookings')
          .select('status, price, service_id, client_id, start_time')
          .eq('master_id', masterId);

      final bookings = List<Map<String, dynamic>>.from(bookingsResponse);

      // 2. Получаем рейтинг
      final reviewsResponse = await _supabase
          .from('reviews')
          .select('rating')
          .eq('master_id', masterId);

      final reviews = List<Map<String, dynamic>>.from(reviewsResponse);

      // 3. Агрегируем данные
      final now = DateTime.now();
      final monthStart = DateTime(now.year, now.month, 1);

      int totalBookings = bookings.length;
      int completedBookings = 0;
      int pendingBookings = 0;
      int cancelledBookings = 0;
      double totalRevenue = 0;
      double monthlyRevenue = 0;
      final Set<String> uniqueClients = {};
      DateTime? lastBookingDate;
      final Map<String, int> bookingsByService = {};

      for (final booking in bookings) {
        final status = booking['status'] as String;
        final price = (booking['price'] as num?)?.toDouble() ?? 0;
        final serviceId = booking['service_id'] as String?;
        final clientId = booking['client_id'] as String?;
        final startTime = DateTime.parse(booking['start_time'] as String);

        // Статусы
        if (status == 'completed') completedBookings++;
        if (status == 'pending') pendingBookings++;
        if (status == 'cancelled') cancelledBookings++;

        // Доход
        totalRevenue += price;
        if (startTime.isAfter(monthStart)) {
          monthlyRevenue += price;
        }

        // Уникальные клиенты
        if (clientId != null) uniqueClients.add(clientId);

        // Последняя запись
        if (lastBookingDate == null || startTime.isAfter(lastBookingDate)) {
          lastBookingDate = startTime;
        }

        // По услугам
        if (serviceId != null) {
          bookingsByService[serviceId] =
              (bookingsByService[serviceId] ?? 0) + 1;
        }
      }

      // 4. Вычисляем средний рейтинг
      double averageRating = 0;
      if (reviews.isNotEmpty) {
        final totalRating = reviews
            .map((r) => (r['rating'] as num).toDouble())
            .reduce((a, b) => a + b);
        averageRating = totalRating / reviews.length;
      }

      return MasterStatsEntity(
        masterId: masterId,
        averageRating: double.parse(averageRating.toStringAsFixed(1)),
        totalBookings: totalBookings,
        completedBookings: completedBookings,
        pendingBookings: pendingBookings,
        cancelledBookings: cancelledBookings,
        totalRevenue: double.parse(totalRevenue.toStringAsFixed(2)),
        monthlyRevenue: double.parse(monthlyRevenue.toStringAsFixed(2)),
        uniqueClients: uniqueClients.length,
        lastBookingDate: lastBookingDate,
        bookingsByService: bookingsByService,
      );
    } catch (e) {
      throw Exception('Ошибка загрузки статистики: $e');
    }
  }
}
