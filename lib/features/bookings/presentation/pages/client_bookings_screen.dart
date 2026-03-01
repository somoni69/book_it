import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';

class ClientBookingsScreen extends StatefulWidget {
  const ClientBookingsScreen({super.key});

  @override
  State<ClientBookingsScreen> createState() => _ClientBookingsScreenState();
}

class _ClientBookingsScreenState extends State<ClientBookingsScreen>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  late TabController _tabController;

  List<Map<String, dynamic>> _bookings = [];
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
    _tabController = TabController(length: 3, vsync: this);
    _loadBookings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadBookings() async {
    try {
      setState(() => _isLoading = true);
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      // ИСПРАВЛЕНИЕ ЗДЕСЬ 👇
      // Мы явно указываем !bookings_master_id_fkey, чтобы БД поняла, кого именно искать
      final data = await _supabase
          .from('bookings')
          .select(
              '*, master:profiles!bookings_master_id_fkey(*), service:services(*)')
          .eq('client_id', userId)
          .order('start_time', ascending: false);

      if (mounted) {
        setState(() {
          _bookings = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Ошибка загрузки: $e'),
              backgroundColor: Colors.red.shade600,
              behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  List<Map<String, dynamic>> _getFilteredBookings(String status) {
    final now = DateTime.now();
    return _bookings.where((b) {
      final startTime = DateTime.parse(b['start_time']);
      final bStatus =
          b['status']; // 'pending', 'confirmed', 'completed', 'cancelled'

      if (status == 'upcoming') {
        return (bStatus == 'pending' || bStatus == 'confirmed') &&
            startTime.isAfter(now);
      } else if (status == 'past') {
        return bStatus == 'completed' ||
            (startTime.isBefore(now) && bStatus != 'cancelled');
      } else if (status == 'cancelled') {
        return bStatus == 'cancelled';
      }
      return false;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Мои записи',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0, // Убираем тень для слияния с TabBar
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(kTextTabBarHeight + 8),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2))
              ],
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: Colors.blue.shade700,
              unselectedLabelColor: Colors.grey.shade500,
              labelStyle:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              unselectedLabelStyle:
                  const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
              indicatorColor: Colors.blue.shade600,
              indicatorWeight: 3,
              indicatorSize: TabBarIndicatorSize.tab,
              tabs: const [
                Tab(text: 'Предстоящие'),
                Tab(text: 'Прошедшие'),
                Tab(text: 'Отмененные'),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? _buildSkeletonList()
          : TabBarView(
              controller: _tabController,
              children: [
                _buildBookingList(_getFilteredBookings('upcoming'), 'upcoming'),
                _buildBookingList(_getFilteredBookings('past'), 'past'),
                _buildBookingList(
                    _getFilteredBookings('cancelled'), 'cancelled'),
              ],
            ),
    );
  }

  Widget _buildBookingList(List<Map<String, dynamic>> bookings, String type) {
    if (bookings.isEmpty) {
      return _buildEmptyState(type);
    }

    return RefreshIndicator(
      color: Colors.blue.shade600,
      onRefresh: _loadBookings,
      child: ListView.separated(
        padding: const EdgeInsets.all(16).copyWith(bottom: 32),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: bookings.length,
        separatorBuilder: (_, __) => const SizedBox(height: 16),
        itemBuilder: (context, index) =>
            _buildBookingCard(bookings[index], type),
      ),
    );
  }

  Widget _buildBookingCard(Map<String, dynamic> booking, String type) {
    final master = booking['master'] ?? {};
    final service = booking['service'] ?? {};
    final startTime = DateTime.parse(booking['start_time']);

    final masterName = master['full_name'] ?? 'Мастер';
    final masterAvatar = master['avatar_url'];
    final serviceName = service['name'] ?? 'Услуга';
    final price = service['price'] ?? 0;

    return Container(
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: _borderRadius,
          boxShadow: _cardShadow,
          border: Border.all(color: Colors.grey.shade100)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Шапка карточки (Дата и Время)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16))),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.calendar_month_rounded,
                        size: 18, color: Colors.blue.shade600),
                    const SizedBox(width: 8),
                    Text(
                      DateFormat('d MMMM yyyy', 'ru_RU').format(startTime),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                  ],
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      color: Colors.blue.shade100.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(8)),
                  child: Text(
                    DateFormat('HH:mm').format(startTime),
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
                        fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.grey.shade100),

          // Тело карточки
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.blue.shade50,
                  backgroundImage:
                      masterAvatar != null ? NetworkImage(masterAvatar) : null,
                  child: masterAvatar == null
                      ? Text(masterName[0].toUpperCase(),
                          style: TextStyle(
                              color: Colors.blue.shade700,
                              fontWeight: FontWeight.bold))
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(serviceName,
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87)),
                      const SizedBox(height: 4),
                      Text('Мастер: $masterName',
                          style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500)),
                      const SizedBox(height: 8),
                      Text('$price с.',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade600)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Кнопки действий
          if (type == 'upcoming') ...[
            Divider(height: 1, color: Colors.grey.shade100),
            Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () {
                    // Логика отмены записи
                  },
                  style: TextButton.styleFrom(
                      foregroundColor: Colors.red.shade400,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10))),
                  child: const Text('Отменить запись',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          ] else if (type == 'past') ...[
            Divider(height: 1, color: Colors.grey.shade100),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        // Оставить отзыв
                      },
                      style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.amber.shade700,
                          side: BorderSide(color: Colors.amber.shade200),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10))),
                      child: const Text('Оценить'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        // Повторить запись
                      },
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade600,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10))),
                      child: const Text('Повторить'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

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
            decoration: BoxDecoration(
                color: Colors.white, borderRadius: _borderRadius)),
      ),
    );
  }

  Widget _buildEmptyState(String type) {
    IconData icon;
    String title;
    String subtitle;

    switch (type) {
      case 'upcoming':
        icon = Icons.event_available_rounded;
        title = 'Нет предстоящих записей';
        subtitle = 'Самое время запланировать\nновый визит к мастеру';
        break;
      case 'past':
        icon = Icons.history_rounded;
        title = 'История пуста';
        subtitle = 'Здесь будут отображаться\nваши прошедшие сеансы';
        break;
      default:
        icon = Icons.event_busy_rounded;
        title = 'Нет отмененных записей';
        subtitle = 'Отличная статистика!\nВы не пропустили ни одного визита';
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
                color: Colors.grey.shade100, shape: BoxShape.circle),
            child: Icon(icon, size: 56, color: Colors.grey.shade400),
          ),
          const SizedBox(height: 24),
          Text(title,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87)),
          const SizedBox(height: 8),
          Text(subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.grey.shade500, fontSize: 14, height: 1.4)),
        ],
      ),
    );
  }
}
