import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shimmer/shimmer.dart';
import '../../data/repositories/service_repository_impl.dart';
import '../../domain/entities/service_entity.dart';
import 'booking_page.dart';
import 'daily_booking_screen.dart';
import '../../../chat/presentation/pages/chat_screen.dart';

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
    return _futureData;
  }

  String _formatDuration(int minutes) {
    if (minutes < 60) return '$minutes мин';
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    return mins == 0 ? '$hours ч' : '$hours ч $mins мин';
  }

  // ==========================================
  // НОВОЕ: Всплывающее окно для создания отзыва
  // ==========================================
  void _showReviewBottomSheet() {
    int selectedStars = 5;
    final commentController = TextEditingController();
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(builder: (context, setModalState) {
        return Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              top: 24,
              left: 24,
              right: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Оцените специалиста',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),

              // Звездочки
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return IconButton(
                    iconSize: 40,
                    icon: Icon(
                      index < selectedStars
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      color: Colors.amber.shade500,
                    ),
                    onPressed: () =>
                        setModalState(() => selectedStars = index + 1),
                  );
                }),
              ),
              const SizedBox(height: 16),

              // Комментарий
              TextField(
                controller: commentController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Что вам понравилось?',
                  hintStyle: TextStyle(color: Colors.grey.shade400),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: Colors.grey.shade200)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: Colors.grey.shade200)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: Colors.blue.shade400)),
                ),
              ),
              const SizedBox(height: 24),

              // Кнопка отправки
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          setModalState(() => isSubmitting = true);
                          try {
                            final clientId = _supabase.auth.currentUser!.id;

                            // 1. Просто отправляем отзыв. Всё остальное база сделает сама!
                            await _supabase.from('reviews').insert({
                              'master_id': widget.masterId,
                              'client_id': clientId,
                              'rating': selectedStars,
                              'comment': commentController.text.trim(),
                            });

                            // 2. Ждем долю секунды, чтобы триггер в базе успел сработать
                            await Future.delayed(
                                const Duration(milliseconds: 300));

                            if (mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('Спасибо за отзыв!'),
                                      backgroundColor: Colors.green));
                              _refresh(); // Обновляем экран с новыми цифрами
                            }
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text('Ошибка: $e'),
                                backgroundColor: Colors.red));
                          } finally {
                            setModalState(() => isSubmitting = false);
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: isSubmitting
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Text('Отправить',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              )
            ],
          ),
        );
      }),
    );
  }

  void _proceedToBooking() {
    if (_selectedService == null) return;

    final originalServiceEntity = _futureData.then((data) {
      final services = data.$2;
      return services.firstWhere((s) => s.id == _selectedService!['id']);
    });

    originalServiceEntity.then((serviceEntity) {
      if (serviceEntity.bookingType == 'daily') {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DailyBookingScreenWrapper(
              service: serviceEntity,
              masterId: widget.masterId,
            ),
          ),
        );
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BookingPageWrapper(
              masterName: _masterData?['full_name'] ?? 'Мастер',
              service: serviceEntity,
            ),
          ),
        );
      }
    });
  }

  Future<void> _startChatWithMaster() async {
    if (_masterData == null) return;

    final supabase = Supabase.instance.client;
    final currentUser = supabase.auth.currentUser!;
    final masterId = _masterData!['id'];

    try {
      // 1. Ищем, есть ли уже чат между мной и этим мастером
      final response = await supabase
          .from('chats')
          .select()
          .or('and(user1_id.eq.${currentUser.id},user2_id.eq.$masterId),and(user1_id.eq.$masterId,user2_id.eq.${currentUser.id})')
          .maybeSingle();

      String chatId;

      if (response != null) {
        // Чат уже есть! Берем его ID
        chatId = response['id'];
      } else {
        // 2. Чата нет. Создаем новый!
        final myProfile = await supabase
            .from('profiles')
            .select()
            .eq('id', currentUser.id)
            .single();

        final newChat = await supabase
            .from('chats')
            .insert({
              'user1_id': currentUser.id,
              'user1_name': myProfile['full_name'],
              'user1_avatar': myProfile['avatar_url'],
              'user2_id': masterId,
              'user2_name': _masterData!['full_name'],
              'user2_avatar': _masterData!['avatar_url'],
            })
            .select()
            .single();

        chatId = newChat['id'];
      }

      // 3. Открываем ChatScreen
      if (mounted) {
        Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChatScreen(
                chatId: chatId,
                partnerId: masterId,
                partnerName: _masterData!['full_name'] ?? 'Специалист',
                partnerAvatar: _masterData!['avatar_url'],
              ),
            ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Ошибка создания чата: $e')));
      }
    }
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
            _masterData = master;

            return _buildContent(master, services);
          },
        ),
      ),
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
        if (services.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _buildEmptyState(),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16)
                .copyWith(bottom: 100),
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

    // Получаем рейтинг (безопасно конвертируем в double)
    final rating = (master['rating'] as num?)?.toDouble() ?? 5.0;
    final reviewsCount = master['reviews_count'] ?? 0;

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
        crossAxisAlignment: CrossAxisAlignment.start,
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
                  ? Image.network(avatarUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (c, e, s) => _buildFallbackAvatar(fullName))
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
                const SizedBox(height: 8),

                // ==========================================
                // НОВОЕ: Кликабельный рейтинг!
                // ==========================================
                GestureDetector(
                  onTap: _showReviewBottomSheet,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.star_rounded,
                            size: 16, color: Colors.amber.shade600),
                        const SizedBox(width: 4),
                        Text(
                          rating.toStringAsFixed(1),
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.amber.shade800,
                              fontSize: 13),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '($reviewsCount отзывов) • Оценить',
                          style: TextStyle(
                              color: Colors.amber.shade700,
                              fontSize: 12,
                              fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // ==========================================
          // НОВОЕ: Кнопка ЧАТА справа от профиля!
          // ==========================================
          Container(
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon:
                  Icon(Icons.chat_bubble_rounded, color: Colors.blue.shade600),
              onPressed: _startChatWithMaster,
              tooltip: 'Написать специалисту',
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
    final isDaily = service.bookingType == 'daily';

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedService = {
            'id': service.id,
            'name': service.title,
            'price': service.price,
            'duration_min': service.durationMin,
            'booking_type': service.bookingType,
          };
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDaily ? Colors.indigo.shade50 : Colors.blue.shade50)
              : Colors.white,
          borderRadius: _borderRadius,
          border: Border.all(
            color: isSelected
                ? (isDaily ? Colors.indigo.shade400 : Colors.blue.shade400)
                : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected ? [] : _cardShadow,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected
                      ? (isDaily
                          ? Colors.indigo.shade600
                          : Colors.blue.shade600)
                      : Colors.transparent,
                  border: Border.all(
                    color: isSelected
                        ? (isDaily
                            ? Colors.indigo.shade600
                            : Colors.blue.shade600)
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
                        Icon(
                            isDaily
                                ? Icons.nights_stay_rounded
                                : Icons.schedule_rounded,
                            size: 14,
                            color: isDaily
                                ? Colors.indigo.shade400
                                : Colors.grey.shade500),
                        const SizedBox(width: 4),
                        Text(
                            isDaily
                                ? 'Посуточно'
                                : _formatDuration(service.durationMin),
                            style: TextStyle(
                                fontSize: 13,
                                color: isDaily
                                    ? Colors.indigo.shade600
                                    : Colors.grey.shade600,
                                fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ],
                ),
              ),
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
    final price = double.tryParse(_selectedService!['price'].toString()) ?? 0.0;
    final isDaily = _selectedService!['booking_type'] == 'daily';

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
                        if (isDaily)
                          Text('за 1 ночь',
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey.shade500)),
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
                          backgroundColor: isDaily
                              ? Colors.indigo.shade600
                              : Colors.blue.shade600,
                          foregroundColor: Colors.white,
                          elevation: 4,
                          shadowColor: (isDaily ? Colors.indigo : Colors.blue)
                              .withOpacity(0.4),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(isDaily ? 'Выбрать даты' : 'Выбрать время',
                                style: const TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.bold)),
                            const SizedBox(width: 8),
                            Icon(
                                isDaily
                                    ? Icons.date_range_rounded
                                    : Icons.arrow_forward_rounded,
                                size: 20),
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
