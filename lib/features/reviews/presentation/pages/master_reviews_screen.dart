import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../data/repositories/review_repository_impl.dart';
import '../../domain/entities/review_entity.dart';

class MasterReviewsScreen extends StatefulWidget {
  final String masterId;

  const MasterReviewsScreen({super.key, required this.masterId});

  @override
  State<MasterReviewsScreen> createState() => _MasterReviewsScreenState();
}

class _MasterReviewsScreenState extends State<MasterReviewsScreen> {
  late final ReviewRepositoryImpl _reviewRepo;
  List<ReviewEntity> _reviews = [];
  double _averageRating = 0.0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _reviewRepo = ReviewRepositoryImpl(Supabase.instance.client);
    _loadReviews();
  }

  Future<void> _loadReviews() async {
    try {
      setState(() => _isLoading = true);

      final results = await Future.wait([
        _reviewRepo.getMasterReviews(widget.masterId),
        _reviewRepo.getMasterAverageRating(widget.masterId),
      ]);

      if (mounted) {
        setState(() {
          _reviews = results[0] as List<ReviewEntity>;
          _averageRating = results[1] as double;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildRatingStars(double rating) {
    final fullStars = rating.floor();
    final hasHalfStar = rating - fullStars >= 0.5;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Полные звезды
        for (int i = 0; i < fullStars; i++)
          const Icon(Icons.star, size: 20, color: Colors.amber),

        // Половина звезды
        if (hasHalfStar)
          const Icon(Icons.star_half, size: 20, color: Colors.amber),

        // Пустые звезды
        for (int i = 0; i < 5 - fullStars - (hasHalfStar ? 1 : 0); i++)
          const Icon(Icons.star_border, size: 20, color: Colors.grey),

        const SizedBox(width: 8),
        Text(
          rating.toStringAsFixed(1),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return DateFormat('dd.MM.yyyy').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Отзывы клиентов',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadReviews,
            tooltip: 'Обновить',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Статистика
                _buildStatsCard(),

                // Список отзывов
                Expanded(
                  child: _reviews.isEmpty
                      ? _buildEmptyState()
                      : _buildReviewsList(),
                ),
              ],
            ),
    );
  }

  Widget _buildStatsCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Средний рейтинг
          _buildRatingStars(_averageRating),

          const SizedBox(height: 12),

          // Количество отзывов
          Text(
            '${_reviews.length} ${_getReviewsWord(_reviews.length)}',
            style: const TextStyle(fontSize: 16, color: Colors.grey),
          ),

          const SizedBox(height: 16),

          // Распределение по звездам
          if (_reviews.isNotEmpty) _buildRatingDistribution(),
        ],
      ),
    );
  }

  Widget _buildRatingDistribution() {
    final distribution = <int, int>{};
    for (int i = 1; i <= 5; i++) {
      distribution[i] = _reviews.where((r) => r.rating == i).length;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Распределение оценок:',
          style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
        ),
        const SizedBox(height: 8),
        for (int star = 5; star >= 1; star--)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                SizedBox(
                  width: 40,
                  child: Text('$star ★', style: const TextStyle(fontSize: 14)),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _reviews.isEmpty
                            ? 0
                            : (distribution[star] ?? 0) / _reviews.length,
                        backgroundColor: Colors.grey[200],
                        color: Colors.amber,
                        minHeight: 8,
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: 30,
                  child: Text(
                    '${distribution[star] ?? 0}',
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.reviews_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text(
            'Пока нет отзывов',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Ваши клиенты смогут оставить отзыв\nпосле завершенной записи',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewsList() {
    return RefreshIndicator(
      onRefresh: _loadReviews,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _reviews.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          return _buildReviewCard(_reviews[index]);
        },
      ),
    );
  }

  Widget _buildReviewCard(ReviewEntity review) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Заголовок
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Аватар клиента
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.grey[200],
                  backgroundImage: review.clientAvatar != null
                      ? NetworkImage(review.clientAvatar!)
                      : null,
                  child: review.clientAvatar == null
                      ? const Icon(Icons.person, size: 20, color: Colors.grey)
                      : null,
                ),

                const SizedBox(width: 12),

                // Имя и дата
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        review.clientName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatDate(review.createdAt),
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),

                // Звезды
                Row(
                  children: List.generate(
                    5,
                    (index) => Icon(
                      index < review.rating ? Icons.star : Icons.star_border,
                      size: 16,
                      color: Colors.amber,
                    ),
                  ),
                ),
              ],
            ),

            // Комментарий
            if (review.comment?.isNotEmpty ?? false) ...[
              const SizedBox(height: 12),
              Text(review.comment!, style: const TextStyle(fontSize: 15)),
            ],
          ],
        ),
      ),
    );
  }

  String _getReviewsWord(int count) {
    if (count % 10 == 1 && count % 100 != 11) return 'отзыв';
    if (count % 10 >= 2 &&
        count % 10 <= 4 &&
        (count % 100 < 10 || count % 100 >= 20)) {
      return 'отзыва';
    }
    return 'отзывов';
  }
}
