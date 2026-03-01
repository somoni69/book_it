import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shimmer/shimmer.dart';
import '../../../bookings/presentation/pages/masters_list_page.dart'; // Твой экран со списком мастеров конкретной категории

class CategoriesPage extends StatefulWidget {
  const CategoriesPage({super.key});

  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage> {
  final _supabase = Supabase.instance.client;
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _filteredCategories = [];
  bool _isLoading = true;

  // --- ЕДИНЫЙ СТИЛЬ ---
  final BorderRadius _borderRadius = BorderRadius.circular(20);
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
    _searchController.addListener(_filterCategories);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final data = await _supabase.from('categories').select().order('name');
      if (mounted) {
        setState(() {
          _categories = List<Map<String, dynamic>>.from(data);
          _filteredCategories = _categories;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _filterCategories() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredCategories = _categories.where((cat) {
        final name = cat['name'].toString().toLowerCase();
        return name.contains(query);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Услуги',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: _isLoading
                ? _buildSkeletonGrid()
                : _filteredCategories.isEmpty
                    ? _buildEmptyState()
                    : _buildGrid(),
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
        height: 52,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: TextField(
          controller: _searchController,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            hintText: 'Поиск услуг...',
            hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 16),
            prefixIcon: Icon(Icons.search_rounded,
                color: Colors.blue.shade600, size: 24),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.close_rounded,
                        color: Colors.grey.shade500, size: 20),
                    onPressed: () {
                      _searchController.clear();
                      FocusScope.of(context).unfocus();
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ),
    );
  }

  Widget _buildGrid() {
    return RefreshIndicator(
      color: Colors.blue.shade600,
      onRefresh: _loadCategories,
      child: GridView.builder(
        padding: const EdgeInsets.all(16).copyWith(bottom: 32),
        physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics()),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.95, // Пропорции карточки (почти квадрат)
        ),
        itemCount: _filteredCategories.length,
        itemBuilder: (context, index) {
          return _buildCategoryCard(_filteredCategories[index]);
        },
      ),
    );
  }

  Widget _buildCategoryCard(Map<String, dynamic> cat) {
    IconData icon;
    Color iconColor;
    Color bgColor;

    final name = cat['name'].toString().toLowerCase();

    // Распознаем популярные категории для красивых иконок и цветов
    if (name.contains("здоровье") || name.contains("мед")) {
      icon = Icons.medical_services_rounded;
      iconColor = Colors.teal.shade500;
      bgColor = Colors.teal.shade50;
    } else if (name.contains("красота") ||
        name.contains("бьюти") ||
        name.contains("маникюр")) {
      icon = Icons.face_retouching_natural_rounded;
      iconColor = Colors.purple.shade500;
      bgColor = Colors.purple.shade50;
    } else if (name.contains("спорт") || name.contains("фитнес")) {
      icon = Icons.fitness_center_rounded;
      iconColor = Colors.orange.shade500;
      bgColor = Colors.orange.shade50;
    } else if (name.contains("авто")) {
      icon = Icons.directions_car_rounded;
      iconColor = Colors.blueGrey.shade500;
      bgColor = Colors.blueGrey.shade50;
    } else {
      icon = Icons.work_outline_rounded;
      iconColor = Colors.blue.shade500;
      bgColor = Colors.blue.shade50;
    }

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
            // Раскомментировали переход! 🚀
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => MastersListPage(
                          categoryId: cat['id'],
                          categoryName: cat['name'],
                        )));
          },
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration:
                      BoxDecoration(color: bgColor, shape: BoxShape.circle),
                  child: Icon(icon, color: iconColor, size: 36),
                ),
                const Spacer(),
                Text(
                  cat['name'],
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.black87),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSkeletonGrid() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade200,
      highlightColor: Colors.grey.shade50,
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.95,
        ),
        itemCount: 6,
        itemBuilder: (_, __) => Container(
          decoration:
              BoxDecoration(color: Colors.white, borderRadius: _borderRadius),
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
            decoration: BoxDecoration(
                color: Colors.grey.shade100, shape: BoxShape.circle),
            child: Icon(Icons.search_off_rounded,
                size: 56, color: Colors.grey.shade400),
          ),
          const SizedBox(height: 24),
          const Text('Категория не найдена',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87)),
          const SizedBox(height: 8),
          Text('Попробуйте ввести другое название',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.grey.shade500, fontSize: 14, height: 1.4)),
        ],
      ),
    );
  }
}
