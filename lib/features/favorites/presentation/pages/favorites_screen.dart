import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shimmer/shimmer.dart';
import '../../../bookings/presentation/pages/service_selection_page.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _favorites = [];
  bool _isLoading = true;

  // --- ЕДИНЫЙ СТИЛЬ ---
  final BorderRadius _borderRadius = BorderRadius.circular(16);
  final List<BoxShadow> _cardShadow = [
    BoxShadow(
        color: Colors.black.withOpacity(0.04),
        blurRadius: 16,
        offset: const Offset(0, 4)),
  ];

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    try {
      setState(() => _isLoading = true);
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      // Получаем избранных мастеров (предполагаемая структура)
      final data = await _supabase
          .from('favorites')
          .select('id, master:profiles(*)')
          .eq('client_id', userId);

      if (mounted) {
        setState(() {
          _favorites = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _removeFavorite(String favoriteId, int index) async {
    try {
      // Оптимистичное удаление из UI
      final removedItem = _favorites[index];
      setState(() => _favorites.removeAt(index));

      await _supabase.from('favorites').delete().eq('id', favoriteId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: const Text('Удалено из избранного'),
              backgroundColor: Colors.grey.shade800,
              behavior: SnackBarBehavior.floating),
        );
      }
    } catch (e) {
      // В случае ошибки возвращаем обратно
      _loadFavorites();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Избранное',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
        shadowColor: Colors.black.withOpacity(0.05),
      ),
      body: _isLoading
          ? _buildSkeletonList()
          : _favorites.isEmpty
              ? _buildEmptyState()
              : _buildList(),
    );
  }

  Widget _buildList() {
    return RefreshIndicator(
      color: Colors.red.shade400,
      onRefresh: _loadFavorites,
      child: ListView.separated(
        padding: const EdgeInsets.all(16).copyWith(bottom: 32),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _favorites.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) =>
            _buildMasterCard(_favorites[index], index),
      ),
    );
  }

  Widget _buildMasterCard(Map<String, dynamic> favorite, int index) {
    final master = favorite['master'] ?? {};
    final masterId = master['id'];
    final fullName = master['full_name'] ?? 'Без имени';
    final avatarUrl = master['avatar_url'];
    final specialization = master['specialization'] ?? 'Мастер';
    final rating = (master['rating'] as num?)?.toDouble() ?? 5.0;

    return Container(
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: _borderRadius,
          boxShadow: _cardShadow,
          border: Border.all(color: Colors.grey.shade100)),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => ServiceSelectionPage(masterId: masterId)));
          },
          borderRadius: _borderRadius,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Аватар
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border:
                          Border.all(color: Colors.grey.shade100, width: 2)),
                  child: CircleAvatar(
                    backgroundColor: Colors.blue.shade50,
                    backgroundImage:
                        avatarUrl != null ? NetworkImage(avatarUrl) : null,
                    child: avatarUrl == null
                        ? Text(fullName[0].toUpperCase(),
                            style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade700))
                        : null,
                  ),
                ),
                const SizedBox(width: 16),

                // Информация
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(fullName,
                          style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87)),
                      const SizedBox(height: 4),
                      Text(specialization,
                          style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.star_rounded,
                              size: 16, color: Colors.amber.shade400),
                          const SizedBox(width: 4),
                          Text(rating.toStringAsFixed(1),
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.amber.shade900)),
                        ],
                      ),
                    ],
                  ),
                ),

                // Кнопка лайка (Удалить)
                IconButton(
                  icon: Icon(Icons.favorite_rounded,
                      color: Colors.red.shade400, size: 28),
                  onPressed: () => _removeFavorite(favorite['id'], index),
                  splashRadius: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSkeletonList() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade200,
      highlightColor: Colors.grey.shade50,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: 5,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, __) => Container(
            height: 96,
            decoration: BoxDecoration(
                color: Colors.white, borderRadius: _borderRadius)),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
                color: Colors.red.shade50, shape: BoxShape.circle),
            child: Icon(Icons.favorite_border_rounded,
                size: 56, color: Colors.red.shade300),
          ),
          const SizedBox(height: 24),
          const Text('Список пуст',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87)),
          const SizedBox(height: 8),
          Text('Добавляйте мастеров в избранное,\nчтобы не потерять их',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.grey.shade500, fontSize: 15, height: 1.4)),
        ],
      ),
    );
  }
}
