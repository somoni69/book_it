import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shimmer/shimmer.dart';
import '../../data/datasources/booking_remote_datasource.dart';
import '../../data/repositories/booking_repository_impl.dart';
import 'service_selection_page.dart';

class MastersListPage extends StatefulWidget {
  final String categoryId;
  final String categoryName;

  const MastersListPage({
    super.key,
    required this.categoryId,
    required this.categoryName,
  });

  @override
  State<MastersListPage> createState() => _MastersListPageState();
}

class _MastersListPageState extends State<MastersListPage> {
  // Идеально в будущем: final _repository = sl<BookingRepository>();
  final _repository = BookingRepositoryImpl(
    BookingRemoteDataSourceImpl(Supabase.instance.client),
  );
  late Future<List<Map<String, dynamic>>> _mastersFuture;

  // --- ЕДИНЫЕ СТИЛИ ---
  final BorderRadius _borderRadius = BorderRadius.circular(20);
  final List<BoxShadow> _cardShadow = const [
    BoxShadow(
      color: Color(0x0A000000),
      blurRadius: 20,
      offset: Offset(0, 8),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _mastersFuture = _fetchMasters();
  }

  Future<List<Map<String, dynamic>>> _fetchMasters() {
    return _repository.getMastersByCategory(widget.categoryId);
  }

  Future<void> _refresh() async {
    setState(() {
      _mastersFuture = _fetchMasters();
    });
    await _mastersFuture; 
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(
          widget.categoryName,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
        shadowColor: Colors.black.withOpacity(0.05),
      ),
      body: RefreshIndicator(
        color: Colors.blue.shade600,
        onRefresh: _refresh,
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _mastersFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _buildSkeletonList();
            }
            if (snapshot.hasError) {
              return _buildErrorState(snapshot.error.toString());
            }
            final masters = snapshot.data ?? [];
            if (masters.isEmpty) {
              return _buildEmptyState();
            }
            return _buildList(masters);
          },
        ),
      ),
    );
  }

  Widget _buildList(List<Map<String, dynamic>> masters) {
    return ListView.separated(
      padding: const EdgeInsets.all(16).copyWith(bottom: 40),
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      itemCount: masters.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        return _buildMasterCard(masters[index]);
      },
    );
  }

  Widget _buildMasterCard(Map<String, dynamic> master) {
    final masterId = master['id'];
    final fullName = master['full_name'] ?? 'Без имени';
    final avatarUrl = master['avatar_url'];
    final specialization = master['specialization'] ?? 'Специалист';
    final rating = (master['rating'] as num?)?.toDouble() ?? 5.0;
    final reviewsCount = master['reviews_count'] ?? 0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: _borderRadius,
        boxShadow: _cardShadow,
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: _borderRadius,
          onTap: () => _navigateToServices(masterId),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  children: [
                    // Безопасный Аватар
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.blue.shade50,
                        border: Border.all(color: Colors.grey.shade100, width: 2),
                      ),
                      child: ClipOval(
                        child: avatarUrl != null && avatarUrl.toString().isNotEmpty
                            ? Image.network(
                                avatarUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => _buildFallbackAvatar(fullName),
                              )
                            : _buildFallbackAvatar(fullName),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Информация
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            fullName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            specialization,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Рейтинг + отзывы
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.star_rounded, size: 16, color: Colors.amber.shade600),
                                    const SizedBox(width: 4),
                                    Text(
                                      rating.toStringAsFixed(1),
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.amber.shade900,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '$reviewsCount отзывов',
                                style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Кнопка записи
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () => _navigateToServices(masterId),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade600,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Посмотреть услуги', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFallbackAvatar(String fullName) {
    return Center(
      child: Text(
        fullName.isNotEmpty ? fullName[0].toUpperCase() : '?',
        style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.blue.shade700),
      ),
    );
  }

  void _navigateToServices(String masterId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ServiceSelectionPage(masterId: masterId),
      ),
    );
  }

  // --- Ниже методы _buildSkeletonList, _buildEmptyState, _buildErrorState без изменений ---
  // (Они у тебя написаны отлично)

  Widget _buildSkeletonList() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade200,
      highlightColor: Colors.grey.shade50,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: 4,
        separatorBuilder: (_, __) => const SizedBox(height: 16),
        itemBuilder: (_, __) => Container(
          height: 180,
          decoration: BoxDecoration(color: Colors.white, borderRadius: _borderRadius),
        ),
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
            decoration: BoxDecoration(color: Colors.blue.shade50, shape: BoxShape.circle),
            child: Icon(Icons.people_alt_outlined, size: 56, color: Colors.blue.shade300),
          ),
          const SizedBox(height: 24),
          const Text('Мастера не найдены', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 8),
          Text('В этой категории пока нет\nдоступных специалистов', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600, fontSize: 15, height: 1.4)),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline_rounded, size: 64, color: Colors.red.shade300),
          const SizedBox(height: 16),
          const Text('Произошла ошибка', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(error, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600)),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _refresh,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Повторить попытку'),
          ),
        ],
      ),
    );
  }
}