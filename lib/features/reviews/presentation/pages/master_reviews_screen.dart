import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
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

  // --- ЕДИНЫЙ СТИЛЬ ---
  final BorderRadius _borderRadius = BorderRadius.circular(16);
  final List<BoxShadow> _cardShadow = [
    BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 16, offset: const Offset(0, 4)),
  ];

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
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatDate(DateTime date) => DateFormat('dd MMM yyyy', 'ru_RU').format(date);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Отзывы клиентов', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
        shadowColor: Colors.black.withOpacity(0.05),
      ),
      body: _isLoading
          ? _buildSkeleton()
          : RefreshIndicator(
              color: Colors.blue.shade600,
              onRefresh: _loadReviews,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: _reviews.isEmpty ? const SizedBox.shrink() : _buildStatsDashboard(),
                  ),
                  _reviews.isEmpty
                      ? SliverFillRemaining(child: _buildEmptyState())
                      : SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 16).copyWith(bottom: 32),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) => _buildReviewCard(_reviews[index]),
                              childCount: _reviews.length,
                            ),
                          ),
                        ),
                ],
              ),
            ),
    );
  }

  Widget _buildStatsDashboard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: _borderRadius, boxShadow: _cardShadow, border: Border.all(color: Colors.grey.shade100)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Левая часть: Оценка
          Column(
            children: [
              Text(_averageRating.toStringAsFixed(1), style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.black87, height: 1.1)),
              const SizedBox(height: 4),
              _buildRatingStars(_averageRating, size: 16),
              const SizedBox(height: 8),
              Text('${_reviews.length} ${_getReviewsWord(_reviews.length)}', style: TextStyle(fontSize: 13, color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
            ],
          ),
          const SizedBox(width: 24),
          Container(width: 1, height: 100, color: Colors.grey.shade200),
          const SizedBox(width: 24),
          // Правая часть: Распределение
          Expanded(child: _buildRatingDistribution()),
        ],
      ),
    );
  }

  Widget _buildRatingDistribution() {
    final distribution = <int, int>{for (var i = 1; i <= 5; i++) i: 0};
    for (var r in _reviews) {
      distribution[r.rating] = (distribution[r.rating] ?? 0) + 1;
    }

    return Column(
      children: List.generate(5, (index) {
        final star = 5 - index;
        final count = distribution[star] ?? 0;
        final percentage = _reviews.isEmpty ? 0.0 : count / _reviews.length;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            children: [
              Text('$star', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
              const SizedBox(width: 4),
              Icon(Icons.star_rounded, size: 12, color: Colors.amber.shade400),
              const SizedBox(width: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: percentage,
                    minHeight: 6,
                    backgroundColor: Colors.grey.shade100,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.amber.shade400),
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildReviewCard(ReviewEntity review) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: _borderRadius, boxShadow: _cardShadow, border: Border.all(color: Colors.grey.shade100)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: Colors.blue.shade50,
                backgroundImage: review.clientAvatar != null ? NetworkImage(review.clientAvatar!) : null,
                child: review.clientAvatar == null
                    ? Text(review.clientName.isNotEmpty ? review.clientName[0].toUpperCase() : '?', style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.bold, fontSize: 18))
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(review.clientName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
                    const SizedBox(height: 4),
                    Text(_formatDate(review.createdAt), style: TextStyle(fontSize: 13, color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(8)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${review.rating}', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber.shade900, fontSize: 14)),
                    const SizedBox(width: 4),
                    Icon(Icons.star_rounded, size: 14, color: Colors.amber.shade600),
                  ],
                ),
              ),
            ],
          ),
          if (review.comment != null && review.comment!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(review.comment!, style: TextStyle(fontSize: 15, color: Colors.grey.shade800, height: 1.4)),
          ],
        ],
      ),
    );
  }

  Widget _buildRatingStars(double rating, {double size = 20}) {
    final fullStars = rating.floor();
    final hasHalfStar = rating - fullStars >= 0.5;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        if (index < fullStars) return Icon(Icons.star_rounded, size: size, color: Colors.amber.shade400);
        if (index == fullStars && hasHalfStar) return Icon(Icons.star_half_rounded, size: size, color: Colors.amber.shade400);
        return Icon(Icons.star_rounded, size: size, color: Colors.grey.shade200);
      }),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(color: Colors.blue.shade50, shape: BoxShape.circle),
            child: Icon(Icons.rate_review_rounded, size: 56, color: Colors.blue.shade300),
          ),
          const SizedBox(height: 24),
          const Text('Пока нет отзывов', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 8),
          Text('Отзывы появятся здесь, когда\nклиенты оценят вашу работу', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600, fontSize: 15, height: 1.4)),
        ],
      ),
    );
  }

  Widget _buildSkeleton() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade200,
      highlightColor: Colors.grey.shade50,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(height: 160, decoration: BoxDecoration(color: Colors.white, borderRadius: _borderRadius)),
          const SizedBox(height: 24),
          ...List.generate(3, (_) => Container(height: 120, margin: const EdgeInsets.only(bottom: 12), decoration: BoxDecoration(color: Colors.white, borderRadius: _borderRadius))),
        ],
      ),
    );
  }

  String _getReviewsWord(int count) {
    if (count % 10 == 1 && count % 100 != 11) return 'отзыв';
    if (count % 10 >= 2 && count % 10 <= 4 && (count % 100 < 10 || count % 100 >= 20)) return 'отзыва';
    return 'отзывов';
  }
}