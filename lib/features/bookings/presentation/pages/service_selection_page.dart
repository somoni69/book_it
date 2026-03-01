import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shimmer/shimmer.dart';
import '../../data/repositories/service_repository_impl.dart';
import '../../domain/entities/service_entity.dart';
import 'booking_page.dart'; // Экран выбора времени (РАСКОММЕНТИРОВАНО!)

class ServiceSelectionPage extends StatefulWidget {
  final String masterId;

  const ServiceSelectionPage({
    super.key,
    required this.masterId,
  });

  @override
  State<ServiceSelectionPage> createState() => _ServiceSelectionPageState();
}

class _ServiceSelectionPageState extends State<ServiceSelectionPage> {
  final _supabase = Supabase.instance.client;
  final _serviceRepository = ServiceRepositoryImpl(Supabase.instance.client);

  late Future<(Map<String, dynamic>?, List<ServiceEntity>)> _futureData;
  Map<String, dynamic>? _selectedService;
  Map<String, dynamic>? _masterData;

  // --- ЕДИНЫЕ СТИЛИ ---
  final BorderRadius _borderRadius = BorderRadius.circular(16);
  final List<BoxShadow> _cardShadow = [
    BoxShadow(
        color: Colors.black.withOpacity(0.03),
        blurRadius: 12,
        offset: const Offset(0, 4)),
  ];

  @override
  void initState() {
    super.initState();
    _futureData = _loadData();
  }

  Future<(Map<String, dynamic>?, List<ServiceEntity>)> _loadData() async {
    // Параллельная загрузка профиля мастера и его услуг
    final profileFuture =
        _supabase.from('profiles').select().eq('id', widget.masterId).single();
    final servicesFuture =
        _serviceRepository.getServicesByMaster(widget.masterId);

    final results = await Future.wait<dynamic>([profileFuture, servicesFuture]);
    return (
      results[0] as Map<String, dynamic>?,
      results[1] as List<ServiceEntity>
    );
  }

  Future<void> _refresh() {
    setState(() {
      _futureData = _loadData();
    });
    return _futureData; // для RefreshIndicator
  }

  String _formatDuration(int minutes) {
    if (minutes < 60) return '$minutes мин';
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    return mins == 0 ? '$hours ч' : '$hours ч $mins мин';
  }

  void _proceedToBooking() {
    if (_selectedService == null) return;

    // Находим оригинальный ServiceEntity из списка
    final originalServiceEntity = _futureData.then((data) {
      final services = data.$2;
      return services.firstWhere((s) => s.id == _selectedService!['id']);
    });

    originalServiceEntity.then((serviceEntity) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BookingPageWrapper(
            masterName: _masterData?['full_name'] ?? 'Мастер',
            service: serviceEntity,
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Выбор услуги',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
        shadowColor: Colors.black.withOpacity(0.05),
      ),
      body: RefreshIndicator(
        color: Colors.blue.shade600,
        onRefresh: _refresh,
        child: FutureBuilder<(Map<String, dynamic>?, List<ServiceEntity>)>(
          future: _futureData,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _buildSkeleton();
            }
            if (snapshot.hasError) {
              return _buildErrorState(snapshot.error.toString());
            }
            final master = snapshot.data!.$1;
            final services = snapshot.data!.$2;
            _masterData = master; // сохраняем для нижней панели

            return _buildContent(master, services);
          },
        ),
      ),
      // Плавающая панель снизу (появляется при выборе услуги)
      bottomNavigationBar: _selectedService != null ? _buildBottomBar() : null,
    );
  }

  Widget _buildContent(
      Map<String, dynamic>? master, List<ServiceEntity> services) {
    return CustomScrollView(
      physics:
          const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      slivers: [
        if (master != null)
          SliverToBoxAdapter(
            child: _buildMasterHeader(master),
          ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          sliver: SliverToBoxAdapter(
            child: Text(
              'Услуги специалиста',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800),
            ),
          ),
        ),

        // Показываем пустой стейт прямо в скролле, чтобы шапка мастера оставалась видна
        if (services.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _buildEmptyState(),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16)
                .copyWith(bottom: 100), // отступ под BottomBar
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildServiceCard(services[index]),
                ),
                childCount: services.length,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMasterHeader(Map<String, dynamic> master) {
    final fullName = master['full_name'] ?? 'Мастер';
    final avatarUrl = master['avatar_url'];
    final specialization = master['specialization'] ?? 'Специалист';

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: _borderRadius,
        boxShadow: _cardShadow,
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.blue.shade50,
              border: Border.all(color: Colors.blue.shade100, width: 2),
            ),
            child: ClipOval(
              child: avatarUrl != null && avatarUrl.toString().isNotEmpty
                  ? Image.network(
                      avatarUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          _buildFallbackAvatar(fullName),
                    )
                  : _buildFallbackAvatar(fullName),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Вы записываетесь к:',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 4),
                Text(fullName,
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87)),
                const SizedBox(height: 2),
                Text(specialization,
                    style: TextStyle(
                        fontSize: 14,
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFallbackAvatar(String fullName) {
    return Center(
      child: Text(
        fullName.isNotEmpty ? fullName[0].toUpperCase() : '?',
        style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.blue.shade700),
      ),
    );
  }

  Widget _buildServiceCard(ServiceEntity service) {
    final isSelected = _selectedService?['id'] == service.id;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedService = {
            'id': service.id,
            'name': service.title,
            'price': service.price,
            'duration_min':
                service.durationMin, // ИСПРАВЛЕНО: нужно для BookingPage
          };
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.shade50 : Colors.white,
          borderRadius: _borderRadius,
          border: Border.all(
            color: isSelected ? Colors.blue.shade400 : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected ? [] : _cardShadow,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Кастомный радио-индикатор
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? Colors.blue.shade600 : Colors.transparent,
                  border: Border.all(
                    color: isSelected
                        ? Colors.blue.shade600
                        : Colors.grey.shade300,
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? const Icon(Icons.check_rounded,
                        size: 16, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 16),

              // Информация об услуге
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(service.title,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.schedule_rounded,
                            size: 14, color: Colors.grey.shade500),
                        const SizedBox(width: 4),
                        Text(_formatDuration(service.durationMin),
                            style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ],
                ),
              ),

              // Цена
              Text('${service.price.toStringAsFixed(0)} с.',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade700)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    final price = (_selectedService!['price'] as num).toDouble();

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 50 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: Container(
              padding: const EdgeInsets.all(20)
                  .copyWith(bottom: MediaQuery.of(context).padding.bottom + 20),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 20,
                      offset: const Offset(0, -5))
                ],
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Итого:',
                            style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey,
                                fontWeight: FontWeight.w500)),
                        Text('${price.toStringAsFixed(0)} с.',
                            style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87)),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _proceedToBooking,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade600,
                          foregroundColor: Colors.white,
                          elevation: 4,
                          shadowColor: Colors.blue.withOpacity(0.4),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('Выбрать время',
                                style: TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.bold)),
                            SizedBox(width: 8),
                            Icon(Icons.arrow_forward_rounded, size: 20),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
                color: Colors.grey.shade100, shape: BoxShape.circle),
            child: Icon(Icons.content_cut_rounded,
                size: 48, color: Colors.grey.shade400),
          ),
          const SizedBox(height: 24),
          const Text('Услуги не найдены',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Мастер пока не добавил ни одной услуги в свой прайс-лист.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade500, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline_rounded,
              size: 64, color: Colors.red.shade300),
          const SizedBox(height: 16),
          const Text('Произошла ошибка',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(error,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600)),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _refresh,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Повторить попытку'),
          ),
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
          Container(
              height: 100,
              decoration: BoxDecoration(
                  color: Colors.white, borderRadius: _borderRadius)),
          const SizedBox(height: 24),
          Container(
              height: 24,
              width: 150,
              color: Colors.white,
              margin: const EdgeInsets.only(right: 200, bottom: 16)),
          Container(
              height: 80,
              decoration: BoxDecoration(
                  color: Colors.white, borderRadius: _borderRadius),
              margin: const EdgeInsets.only(bottom: 12)),
          Container(
              height: 80,
              decoration: BoxDecoration(
                  color: Colors.white, borderRadius: _borderRadius),
              margin: const EdgeInsets.only(bottom: 12)),
          Container(
              height: 80,
              decoration: BoxDecoration(
                  color: Colors.white, borderRadius: _borderRadius)),
        ],
      ),
    );
  }
}
