import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';

class MasterAnalyticsScreen extends StatefulWidget {
  const MasterAnalyticsScreen({super.key});

  @override
  State<MasterAnalyticsScreen> createState() => _MasterAnalyticsScreenState();
}

class _MasterAnalyticsScreenState extends State<MasterAnalyticsScreen> {
  final _supabase = Supabase.instance.client;
  
  bool _isLoading = true;
  String _selectedPeriod = 'week'; // 'week' или 'month'
  
  double _totalRevenue = 0;
  int _totalBookings = 0;
  double _avgCheck = 0;
  
  // Данные для графика: дата -> сумма
  Map<String, double> _chartData = {};
  double _maxChartValue = 0;

  // Топ услуг
  List<Map<String, dynamic>> _topServices = [];

  // --- ЕДИНЫЙ СТИЛЬ ---
  final BorderRadius _borderRadius = BorderRadius.circular(16);
  final List<BoxShadow> _cardShadow = [
    BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 16, offset: const Offset(0, 4)),
  ];

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    try {
      setState(() => _isLoading = true);
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final now = DateTime.now();
      final startDate = _selectedPeriod == 'week' 
          ? now.subtract(const Duration(days: 6)) 
          : now.subtract(const Duration(days: 29));

      // Тянем только завершенные записи за период
      final data = await _supabase
          .from('bookings')
          .select('*, service:services(name, price)')
          .eq('master_id', userId)
          .eq('status', 'completed')
          .gte('start_time', startDate.toIso8601String())
          .order('start_time', ascending: true);

      _processData(List<Map<String, dynamic>>.from(data), startDate, now);
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _processData(List<Map<String, dynamic>> bookings, DateTime start, DateTime end) {
    _totalRevenue = 0;
    _totalBookings = bookings.length;
    _chartData = {};
    _maxChartValue = 0;
    
    Map<String, Map<String, dynamic>> servicesStats = {};

    // 1. Инициализируем пустые дни для графика, чтобы не было дырок
    int daysCount = _selectedPeriod == 'week' ? 7 : 30;
    for (int i = 0; i < daysCount; i++) {
      final d = start.add(Duration(days: i));
      final dateKey = DateFormat('yyyy-MM-dd').format(d);
      _chartData[dateKey] = 0.0;
    }

    // 2. Считаем данные
    for (var b in bookings) {
      final dateKey = DateFormat('yyyy-MM-dd').format(DateTime.parse(b['start_time']));
      final serviceName = b['service']?['name'] ?? 'Неизвестная услуга';
      final price = (b['service']?['price'] as num?)?.toDouble() ?? 0.0;

      // Общая выручка
      _totalRevenue += price;

      // График
      if (_chartData.containsKey(dateKey)) {
        _chartData[dateKey] = _chartData[dateKey]! + price;
        if (_chartData[dateKey]! > _maxChartValue) {
          _maxChartValue = _chartData[dateKey]!;
        }
      }

      // Топ услуг
      if (!servicesStats.containsKey(serviceName)) {
        servicesStats[serviceName] = {'count': 0, 'revenue': 0.0};
      }
      servicesStats[serviceName]!['count']++;
      servicesStats[serviceName]!['revenue'] += price;
    }

    _avgCheck = _totalBookings > 0 ? _totalRevenue / _totalBookings : 0;

    // Сортируем топ услуг по выручке
    _topServices = servicesStats.entries.map((e) => {
      'name': e.key,
      'count': e.value['count'],
      'revenue': e.value['revenue'],
    }).toList();
    _topServices.sort((a, b) => (b['revenue'] as double).compareTo(a['revenue'] as double));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Аналитика', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),
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
              onRefresh: _loadAnalytics,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16).copyWith(bottom: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPeriodSelector(),
                    const SizedBox(height: 24),
                    _buildSummaryCards(),
                    const SizedBox(height: 24),
                    _buildChartCard(),
                    const SizedBox(height: 24),
                    _buildTopServicesSection(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildPeriodSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Expanded(child: _buildPeriodButton('week', 'За неделю')),
          Expanded(child: _buildPeriodButton('month', 'За месяц')),
        ],
      ),
    );
  }

  Widget _buildPeriodButton(String value, String label) {
    final isSelected = _selectedPeriod == value;
    return GestureDetector(
      onTap: () {
        if (!isSelected) {
          setState(() => _selectedPeriod = value);
          _loadAnalytics();
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))] : [],
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.w500, color: isSelected ? Colors.black87 : Colors.grey.shade600, fontSize: 14),
        ),
      ),
    );
  }

  Widget _buildSummaryCards() {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [Colors.blue.shade600, Colors.blue.shade400], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: _borderRadius,
              boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 6))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Общий доход', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13, fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                Text('${_totalRevenue.toStringAsFixed(0)} с.', style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 1,
          child: Column(
            children: [
              _buildSmallStatsCard('Записи', _totalBookings.toString(), Icons.task_alt_rounded, Colors.green),
              const SizedBox(height: 12),
              _buildSmallStatsCard('Ср. чек', '${_avgCheck.toStringAsFixed(0)} с.', Icons.receipt_long_rounded, Colors.orange),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSmallStatsCard(String title, String value, IconData icon, MaterialColor color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: _cardShadow, border: Border.all(color: Colors.grey.shade100)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color.shade500),
              const SizedBox(width: 6),
              Text(title, style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
            ],
          ),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
        ],
      ),
    );
  }

  Widget _buildChartCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: _borderRadius, boxShadow: _cardShadow, border: Border.all(color: Colors.grey.shade100)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Динамика доходов', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 24),
          if (_maxChartValue == 0)
            const SizedBox(
              height: 150,
              child: Center(child: Text('Нет данных за этот период', style: TextStyle(color: Colors.grey))),
            )
          else
            SizedBox(
              height: 150,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: _chartData.entries.map((e) {
                  final date = DateTime.parse(e.key);
                  // Для месяца показываем каждый 3й или 5й день, для недели - каждый
                  final showLabel = _selectedPeriod == 'week' || date.day % 5 == 0;
                  final heightFactor = e.value / _maxChartValue;
                  
                  return Flexible(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (e.value > 0 && _selectedPeriod == 'week')
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(e.value >= 1000 ? '${(e.value / 1000).toStringAsFixed(1)}k' : e.value.toStringAsFixed(0), style: TextStyle(fontSize: 9, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
                          ),
                        Expanded(
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 2),
                              width: _selectedPeriod == 'week' ? 24 : 8,
                              height: 150 * heightFactor,
                              decoration: BoxDecoration(
                                color: heightFactor > 0.8 ? Colors.blue.shade600 : Colors.blue.shade300,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          showLabel ? DateFormat('dd.MM').format(date) : '',
                          style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTopServicesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 16),
          child: Text('Топ услуг по доходу', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
        ),
        if (_topServices.isEmpty)
          const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('Пока нет завершенных услуг', style: TextStyle(color: Colors.grey))))
        else
          Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: _borderRadius, boxShadow: _cardShadow, border: Border.all(color: Colors.grey.shade100)),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _topServices.length > 5 ? 5 : _topServices.length, // Показываем топ-5
              separatorBuilder: (_, __) => Divider(height: 1, indent: 16, color: Colors.grey.shade100),
              itemBuilder: (context, index) {
                final service = _topServices[index];
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: index == 0 ? Colors.amber.shade100 : Colors.grey.shade100, shape: BoxShape.circle),
                        child: Text('${index + 1}', style: TextStyle(fontWeight: FontWeight.bold, color: index == 0 ? Colors.amber.shade800 : Colors.grey.shade600, fontSize: 13)),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(service['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87)),
                            const SizedBox(height: 4),
                            Text('${service['count']} оказано', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                          ],
                        ),
                      ),
                      Text('${(service['revenue'] as double).toStringAsFixed(0)} с.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.green.shade700)),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildSkeleton() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade200,
      highlightColor: Colors.grey.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(height: 40, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12))),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(flex: 2, child: Container(height: 140, decoration: BoxDecoration(color: Colors.white, borderRadius: _borderRadius))),
                const SizedBox(width: 12),
                Expanded(flex: 1, child: Container(height: 140, decoration: BoxDecoration(color: Colors.white, borderRadius: _borderRadius))),
              ],
            ),
            const SizedBox(height: 24),
            Container(height: 200, decoration: BoxDecoration(color: Colors.white, borderRadius: _borderRadius)),
          ],
        ),
      ),
    );
  }
}