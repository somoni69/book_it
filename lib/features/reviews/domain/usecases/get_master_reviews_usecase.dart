import '../entities/review_entity.dart';
import '../repositories/review_repository.dart';

class GetMasterReviewsUseCase {
  final ReviewRepository _repository;

  GetMasterReviewsUseCase(this._repository);

  Future<MasterReviewsResult> call(String masterId) async {
    final reviews = await _repository.getMasterReviews(masterId);
    final averageRating = await _repository.getMasterAverageRating(masterId);

    return MasterReviewsResult(
      reviews: reviews,
      averageRating: averageRating,
      totalReviews: reviews.length,
    );
  }
}

class MasterReviewsResult {
  final List<ReviewEntity> reviews;
  final double averageRating;
  final int totalReviews;

  MasterReviewsResult({
    required this.reviews,
    required this.averageRating,
    required this.totalReviews,
  });
}
