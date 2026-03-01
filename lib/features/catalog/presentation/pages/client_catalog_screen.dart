import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shimmer/shimmer.dart';
import '../../../bookings/presentation/pages/service_selection_page.dart'; // Твой экран бронирования или профиль мастера

class ClientCatalogScreen extends StatefulWidget {
  const ClientCatalogScreen({super.key});

  @override
  State<ClientCatalogScreen> createState() => _ClientCatalogScreenState();
}

class _ClientCatalogScreenState extends State<ClientCatalogScreen> {
  final _supabase = Supabase.instance.client;
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  List<Map<String, dynamic>> _masters = [];
  List<Map<String, dynamic>> _categories = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedCategoryId = 'all'; // 'all' - все категории

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
    _loadCategories();
    _loadMasters();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      setState(() {
        _searchQuery = query;
        _isLoading = true;
      });
      _loadMasters();
    });
  }

  void _onCategorySelected(String categoryId) {
    if (_selectedCategoryId == categoryId) return;
    setState(() {
      _selectedCategoryId = categoryId;
      _isLoading = true;
    });
    _loadMasters();
  }

  Future<void> _loadCategories() async {
    try {
      final data = await _supabase.from('categories').select().order('name');
      if (mounted) {
        setState(() {
          _categories = [
            {'id': 'all', 'name': 'Все'},
            ...List<Map<String, dynamic>>.from(data)
          ];
        });
      }
    } catch (e) {
      // Игнорируем или логируем
    }
  }

  Future<void> _loadMasters() async {
    try {
      var query = _supabase
          .from('profiles')
          .select(
              'id, full_name, avatar_url, specialization, rating, reviews_count, specialty_id')
          .eq('role', 'master');

      if (_searchQuery.isNotEmpty) {
        query = query.ilike('full_name', '%$_searchQuery%');
      }

      // ИСПРАВЛЕНИЕ ЗДЕСЬ 👇
      if (_selectedCategoryId != 'all') {
        // Шаг 1: Получаем все специальности для выбранной категории
        final specs = await _supabase
            .from('specialties')
            .select('id')
            .eq('category_id', _selectedCategoryId);

        final List<dynamic> specIds = specs.map((s) => s['id']).toList();

        // Если в категории нет специальностей, то и мастеров быть не может
        if (specIds.isEmpty) {
          if (mounted) {
            setState(() {
              _masters = [];
              _isLoading = false;
            });
          }
          return;
        }

        // Шаг 2: Ищем мастеров. Используем правильный синтаксис .inFilter()
        query = query.inFilter('specialty_id', specIds);
      }

      final data = await query;

      if (mounted) {
        setState(() {
          _masters = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Поиск специалистов',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(70),
          child: _buildSearchBar(),
        ),
      ),
      body: Column(
        children: [
          _buildCategoriesBar(),
          Expanded(
            child: _isLoading
                ? _buildSkeletonList()
                : _masters.isEmpty
                    ? _buildEmptyState()
                    : _buildMastersList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: TextField(
          controller: _searchController,
          onChanged: _onSearchChanged,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            hintText: 'Имя мастера или услуга...',
            hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 15),
            prefixIcon: Icon(Icons.search_rounded,
                color: Colors.grey.shade500, size: 22),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.close_rounded,
                        color: Colors.grey.shade500, size: 20),
                    onPressed: () {
                      _searchController.clear();
                      _onSearchChanged('');
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoriesBar() {
    if (_categories.isEmpty) return const SizedBox.shrink();

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.only(bottom: 12),
      child: SizedBox(
        height: 38,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          itemCount: _categories.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final category = _categories[index];
            final isSelected = _selectedCategoryId == category['id'];

            return GestureDetector(
              onTap: () => _onCategorySelected(category['id']),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected ? Colors.black87 : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? Colors.black87 : Colors.grey.shade300,
                  ),
                ),
                child: Text(
                  category['name'],
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.black87,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildMastersList() {
    return RefreshIndicator(
      color: Colors.blue.shade600,
      onRefresh: _loadMasters,
      child: ListView.separated(
        padding: const EdgeInsets.all(16).copyWith(bottom: 32),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _masters.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) => _buildMasterCard(_masters[index]),
      ),
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
          onTap: () {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => ServiceSelectionPage(masterId: masterId)));
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Аватар
                CircleAvatar(
                  radius: 32,
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
                const SizedBox(width: 16),

                // Инфо
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
                              fontSize: 14,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500)),
                      const SizedBox(height: 8),

                      // Рейтинг и отзывы
                      Row(
                        children: [
                          Icon(Icons.star_rounded,
                              size: 16, color: Colors.amber.shade500),
                          const SizedBox(width: 4),
                          Text(rating.toStringAsFixed(1),
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.amber.shade800)),
                          const SizedBox(width: 6),
                          Text('($reviewsCount)',
                              style: TextStyle(
                                  fontSize: 13, color: Colors.grey.shade500)),
                        ],
                      ),
                    ],
                  ),
                ),

                // Кнопка перехода
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('Запись',
                      style: TextStyle(
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.bold,
                          fontSize: 13)),
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
        itemCount: 6,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, __) => Container(
            height: 100,
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
                color: Colors.grey.shade100, shape: BoxShape.circle),
            child: Icon(Icons.search_off_rounded,
                size: 56, color: Colors.grey.shade400),
          ),
          const SizedBox(height: 24),
          const Text('Ничего не найдено',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87)),
          const SizedBox(height: 8),
          Text(
              'Попробуйте изменить параметры поиска\nили выбрать другую категорию',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.grey.shade500, fontSize: 14, height: 1.4)),
        ],
      ),
    );
  }
}
