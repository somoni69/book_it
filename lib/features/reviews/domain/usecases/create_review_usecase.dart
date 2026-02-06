import '../entities/review_entity.dart';
import '../repositories/review_repository.dart';

class CreateReviewUseCase {
  final ReviewRepository _repository;

  CreateReviewUseCase(this._repository);

  Future<ReviewEntity> call({
    required String bookingId,
    required String clientId,
    required String masterId,
    required int rating,
    required String comment,
  }) async {
    // Валидация рейтинга
    if (rating < 1 || rating > 5) {
      throw ArgumentError('Рейтинг должен быть от 1 до 5');
    }

    // Валидация комментария
    if (comment.trim().isEmpty) {
      throw ArgumentError('Комментарий не может быть пустым');
    }

    // Проверка что отзыв еще не оставлен
    final hasReview = await _repository.hasReviewForBooking(bookingId);
    if (hasReview) {
      throw Exception('Вы уже оставили отзыв на эту запись');
    }

    return await _repository.createReview(
      bookingId: bookingId,
      clientId: clientId,
      masterId: masterId,
      rating: rating,
      comment: comment,
    );
  }
}
