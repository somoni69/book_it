import '../entities/review_entity.dart';

abstract class ReviewRepository {
  /// Создать отзыв
  Future<ReviewEntity> createReview({
    required String bookingId,
    required String clientId,
    required String masterId,
    required int rating,
    required String comment,
  });

  /// Получить все отзывы мастера
  Future<List<ReviewEntity>> getMasterReviews(String masterId);

  /// Получить средний рейтинг мастера
  Future<double> getMasterAverageRating(String masterId);

  /// Проверить, оставил ли клиент отзыв на запись
  Future<bool> hasReviewForBooking(String bookingId);
}
