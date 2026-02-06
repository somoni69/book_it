import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/review_entity.dart';
import '../../domain/repositories/review_repository.dart';
import '../models/review_model.dart';

class ReviewRepositoryImpl implements ReviewRepository {
  final SupabaseClient _supabase;

  ReviewRepositoryImpl(this._supabase);

  @override
  Future<ReviewEntity> createReview({
    required String bookingId,
    required String clientId,
    required String masterId,
    required int rating,
    required String comment,
  }) async {
    try {
      final response = await _supabase
          .from('reviews')
          .insert({
            'booking_id': bookingId,
            'client_id': clientId,
            'master_id': masterId,
            'rating': rating,
            'comment': comment,
            'created_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      // Получаем имя клиента для отзыва
      final clientResponse = await _supabase
          .from('profiles')
          .select('full_name, avatar_url')
          .eq('id', clientId)
          .single();

      final model = ReviewModel.fromJson(response);
      return model.toEntity(
        clientName: clientResponse['full_name'] as String,
        clientAvatar: clientResponse['avatar_url'] as String?,
      );
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<List<ReviewEntity>> getMasterReviews(String masterId) async {
    try {
      final response = await _supabase.from('reviews').select('''
            *,
            client:profiles!reviews_client_id_fkey(id, full_name, avatar_url)
          ''').eq('master_id', masterId).order('created_at', ascending: false);

      return (response as List).map((json) {
        final clientName = json['client']?['full_name'] as String? ?? 'Клиент';
        final clientAvatar = json['client']?['avatar_url'] as String?;

        final model = ReviewModel.fromJson(json);
        return model.toEntity(
          clientName: clientName,
          clientAvatar: clientAvatar,
        );
      }).toList();
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<double> getMasterAverageRating(String masterId) async {
    try {
      final response = await _supabase
          .from('reviews')
          .select('rating')
          .eq('master_id', masterId);

      if (response.isEmpty) return 0.0;

      final ratings = (response as List)
          .map((r) => (r['rating'] as num).toDouble())
          .toList();

      final average = ratings.reduce((a, b) => a + b) / ratings.length;
      return double.parse(average.toStringAsFixed(1)); // Округление до 1 знака
    } catch (e) {
      return 0.0;
    }
  }

  @override
  Future<bool> hasReviewForBooking(String bookingId) async {
    try {
      final response = await _supabase
          .from('reviews')
          .select('id')
          .eq('booking_id', bookingId)
          .limit(1);

      return response.isNotEmpty;
    } catch (e) {
      return false;
    }
  }
}
