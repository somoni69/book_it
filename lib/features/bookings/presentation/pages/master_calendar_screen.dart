import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';

class MasterCalendarScreen extends StatefulWidget {
  const MasterCalendarScreen({super.key});

  @override
  State<MasterCalendarScreen> createState() => _MasterCalendarScreenState();
}

class _MasterCalendarScreenState extends State<MasterCalendarScreen> {
  final _supabase = Supabase.instance.client;
  
  DateTime _selectedDate = DateTime.now();
  List<Map<String, dynamic>> _bookings = [];
  bool _isLoading = true;

  // Генерируем даты для горизонтального календаря (14 дней назад, 30 вперед)
  late final List<DateTime> _dates;
  late final ScrollController _dateScrollController;

  // --- ЕДИНЫЙ СТИЛЬ ---
  final BorderRadius _borderRadius = BorderRadius.circular(16);
  final List<BoxShadow> _cardShadow = [
    BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 16, offset: const Offset(0, 4)),
  ];

  @override
  void initState() {
    super.initState();
    _dates = List.generate(45, (index) => DateTime.now().subtract(const Duration(days: 14)).add(Duration(days: index)));
    
    // Пытаемся отцентрировать сегодняшний день
    _dateScrollController = ScrollController(initialScrollOffset: 14 * 68.0); 
    
    _loadBookingsForDate(_selectedDate);
  }

  @override
  void dispose() {
    _dateScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadBookingsForDate(DateTime date) async {
    try {
      setState(() => _isLoading = true);
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      // Получаем начало и конец выбранного дня
      final startOfDay = DateTime(date.year, date.month, date.day).toIso8601String();
      final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59).toIso8601String();

      // Тянем записи из БД
      final data = await _supabase
          .from('bookings')
          .select('*, client:profiles!client_id(*), service:services(*)')
          .eq('master_id', userId)
          .gte('start_time', startOfDay)
          .lte('start_time', endOfDay)
          .order('start_time', ascending: true);

      if (mounted) {
        setState(() {
          _bookings = List<Map<String, dynamic>>.from(data);
          _selectedDate = date;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки: $e'), backgroundColor: Colors.red.shade600, behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  // Считаем статистику за день
  double get _dailyRevenue {
    return _bookings
        .where((b) => b['status'] != 'cancelled')
        .fold(0.0, (sum, b) => sum + ((b['service']?['price'] ?? 0) as num).toDouble());
  }

  int get _dailyCount => _bookings.where((b) => b['status'] != 'cancelled').length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(
          DateFormat('MMMM yyyy', 'ru_RU').format(_selectedDate).toUpperCase(),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.today_rounded, color: Colors.blue.shade600),
            tooltip: 'Сегодня',
            onPressed: () {
              final today = DateTime.now();
              _loadBookingsForDate(today);
              // Возвращаем скролл к сегодняшнему дню
              _dateScrollController.animateTo(14 * 68.0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildDateSelector(),
          _buildDailyStats(),
          Expanded(
            child: _isLoading 
                ? _buildSkeletonTimeline() 
                : _bookings.isEmpty 
                    ? _buildEmptyState() 
                    : _buildTimeline(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Добавление личного события или перерыва
        },
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
        elevation: 4,
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  Widget _buildDateSelector() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.only(bottom: 16, top: 8),
      decoration: BoxDecoration(
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: SizedBox(
        height: 85,
        child: ListView.separated(
          controller: _dateScrollController,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          itemCount: _dates.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (context, index) {
            final date = _dates[index];
            final isSelected = date.year == _selectedDate.year && date.month == _selectedDate.month && date.day == _selectedDate.day;
            final isToday = date.year == DateTime.now().year && date.month == DateTime.now().month && date.day == DateTime.now().day;

            return GestureDetector(
              onTap: () => _loadBookingsForDate(date),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 60,
                decoration: BoxDecoration(
                  color: isSelected ? Colors.blue.shade600 : (isToday ? Colors.blue.shade50 : Colors.white),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isSelected ? Colors.blue.shade600 : Colors.grey.shade200),
                  boxShadow: isSelected ? [BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))] : [],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      DateFormat('E', 'ru_RU').format(date).toUpperCase(),
                      style: TextStyle(
                        fontSize: 12, 
                        fontWeight: FontWeight.w600, 
                        color: isSelected ? Colors.white70 : (isToday ? Colors.blue.shade600 : Colors.grey.shade500)
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      date.day.toString(),
                      style: TextStyle(
                        fontSize: 20, 
                        fontWeight: FontWeight.bold, 
                        color: isSelected ? Colors.white : Colors.black87
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildDailyStats() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.people_alt_rounded, color: Colors.blue.shade500, size: 20),
                  const SizedBox(height: 8),
                  Text('Записей', style: TextStyle(fontSize: 12, color: Colors.blue.shade700, fontWeight: FontWeight.w600)),
                  Text('$_dailyCount', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue.shade900)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.account_balance_wallet_rounded, color: Colors.green.shade500, size: 20),
                  const SizedBox(height: 8),
                  Text('Доход', style: TextStyle(fontSize: 12, color: Colors.green.shade700, fontWeight: FontWeight.w600)),
                  Text('${_dailyRevenue.toStringAsFixed(0)} с.', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green.shade900)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeline() {
    return RefreshIndicator(
      color: Colors.blue.shade600,
      onRefresh: () => _loadBookingsForDate(_selectedDate),
      child: ListView.builder(
        padding: const EdgeInsets.all(20).copyWith(bottom: 100),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _bookings.length,
        itemBuilder: (context, index) {
          final booking = _bookings[index];
          final isLast = index == _bookings.length - 1;
          return _buildTimelineItem(booking, isLast);
        },
      ),
    );
  }

  Widget _buildTimelineItem(Map<String, dynamic> booking, bool isLast) {
    final client = booking['client'] ?? {};
    final service = booking['service'] ?? {};
    final startTime = DateTime.parse(booking['start_time']);
    final status = booking['status'] ?? 'pending';

    // Настройка цветов статуса
    Color statusColor;
    IconData statusIcon;
    switch (status) {
      case 'confirmed':
        statusColor = Colors.blue.shade500;
        statusIcon = Icons.thumb_up_rounded;
        break;
      case 'completed':
        statusColor = Colors.green.shade500;
        statusIcon = Icons.check_circle_rounded;
        break;
      case 'cancelled':
        statusColor = Colors.red.shade400;
        statusIcon = Icons.cancel_rounded;
        break;
      default: // pending
        statusColor = Colors.orange.shade500;
        statusIcon = Icons.schedule_rounded;
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Временная шкала (Время + Линия)
          SizedBox(
            width: 56,
            child: Column(
              children: [
                Text(
                  DateFormat('HH:mm').format(startTime),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: isLast 
                      ? const SizedBox() 
                      : Container(width: 2, color: Colors.grey.shade200),
                ),
              ],
            ),
          ),
          
          // Карточка клиента
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Container(
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
                      // Открыть шторку (BottomSheet) с деталями записи и кнопками смены статуса
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(service['name'] ?? 'Услуга', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              Icon(statusIcon, color: statusColor, size: 20),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: Colors.grey.shade100,
                                backgroundImage: client['avatar_url'] != null ? NetworkImage(client['avatar_url']) : null,
                                child: client['avatar_url'] == null ? Icon(Icons.person, color: Colors.grey.shade400, size: 20) : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(client['full_name'] ?? 'Неизвестный клиент', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87)),
                                    if (client['phone'] != null)
                                      Text(client['phone'], style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
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
            decoration: BoxDecoration(color: Colors.grey.shade50, shape: BoxShape.circle),
            child: Icon(Icons.free_cancellation_rounded, size: 56, color: Colors.grey.shade300),
          ),
          const SizedBox(height: 24),
          const Text('Свободный день', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 8),
          Text('На эту дату пока нет ни одной записи.\nОтличное время для отдыха!', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade500, fontSize: 15, height: 1.4)),
        ],
      ),
    );
  }

  Widget _buildSkeletonTimeline() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade200,
      highlightColor: Colors.grey.shade50,
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: 4,
        itemBuilder: (_, __) => Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(width: 40, height: 20, color: Colors.white),
              const SizedBox(width: 16),
              Expanded(
                child: Container(height: 100, decoration: BoxDecoration(color: Colors.white, borderRadius: _borderRadius)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}