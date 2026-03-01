import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shimmer/shimmer.dart';
import 'package:book_it/features/bookings/data/datasources/booking_remote_datasource.dart';
import 'package:book_it/features/bookings/data/repositories/booking_repository_impl.dart';
import 'package:book_it/features/bookings/domain/entities/booking_entity.dart';
import '../../../../core/utils/user_utils.dart';

class MasterTodayBookingsScreen extends StatefulWidget {
  const MasterTodayBookingsScreen({super.key});

  @override
  _MasterTodayBookingsScreenState createState() => _MasterTodayBookingsScreenState();
}

class _MasterTodayBookingsScreenState extends State<MasterTodayBookingsScreen> {
  late BookingRepositoryImpl _bookingRepo;
  List<BookingEntity> _bookings = [];
  bool _isLoading = true;

  // --- ЕДИНЫЙ СТИЛЬ ---
  final BorderRadius _borderRadius = BorderRadius.circular(16);
  final List<BoxShadow> _cardShadow = [
    BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 16, offset: const Offset(0, 4)),
  ];

  @override
  void initState() {
    super.initState();
    final supabase = Supabase.instance.client;
    final dataSource = BookingRemoteDataSourceImpl(supabase);
    _bookingRepo = BookingRepositoryImpl(dataSource);
    _loadBookings();
  }

  Future<void> _loadBookings() async {
    try {
      setState(() => _isLoading = true);
      final masterId = UserUtils.getCurrentUserIdOrThrow();
      final bookings = await _bookingRepo.getBookingsForMaster(masterId, DateTime.now());

      if (mounted) {
        setState(() {
          _bookings = bookings;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorSnackbar('Ошибка загрузки: ${e.toString()}');
      }
    }
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating));
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating));
  }

  Future<void> _updateBookingStatus(String bookingId, String status) async {
    try {
      final bookingStatus = BookingStatus.values.firstWhere((e) => e.name == status, orElse: () => BookingStatus.pending);
      await _bookingRepo.updateBookingStatus(bookingId, bookingStatus);
      _showSuccessSnackbar('Статус успешно обновлен');
      _loadBookings();
    } catch (e) {
      _showErrorSnackbar('Ошибка обновления статуса');
    }
  }

  String _formatTime(DateTime time) => '${time.hour}:${time.minute.toString().padLeft(2, '0')}';

  Map<String, dynamic> _getStatusStyle(BookingStatus status) {
    switch (status) {
      case BookingStatus.pending: return {'text': 'Ожидает', 'color': Colors.orange.shade600, 'bg': Colors.orange.shade50};
      case BookingStatus.confirmed: return {'text': 'Подтверждена', 'color': Colors.green.shade600, 'bg': Colors.green.shade50};
      case BookingStatus.cancelled: return {'text': 'Отменена', 'color': Colors.red.shade600, 'bg': Colors.red.shade50};
      case BookingStatus.completed: return {'text': 'Завершена', 'color': Colors.blue.shade600, 'bg': Colors.blue.shade50};
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Записи на сегодня', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
        shadowColor: Colors.black.withOpacity(0.05),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded, color: Colors.blue), onPressed: _loadBookings, tooltip: 'Обновить'),
        ],
      ),
      body: _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_isLoading) return _buildSkeletonList();
    if (_bookings.isEmpty) return _buildEmptyState();

    return RefreshIndicator(
      color: Colors.blue.shade600,
      onRefresh: _loadBookings,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _bookings.length,
        separatorBuilder: (_, __) => const SizedBox(height: 16),
        itemBuilder: (context, index) => _buildBookingCard(_bookings[index]),
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
        itemBuilder: (_, __) => Container(height: 160, decoration: BoxDecoration(color: Colors.white, borderRadius: _borderRadius)),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: Colors.blue.shade50, shape: BoxShape.circle),
            child: Icon(Icons.event_available_rounded, size: 64, color: Colors.blue.shade300),
          ),
          const SizedBox(height: 24),
          const Text('Нет записей на сегодня', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 8),
          Text('Отличный день для отдыха\nили новых клиентов', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600, fontSize: 14, height: 1.4)),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _loadBookings,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Обновить', style: TextStyle(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingCard(BookingEntity booking) {
    final statusStyle = _getStatusStyle(booking.status);

    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: _borderRadius, boxShadow: _cardShadow, border: Border.all(color: Colors.grey.shade100)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Шапка карточки
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(10)),
                      child: Icon(Icons.access_time_filled_rounded, size: 20, color: Colors.blue.shade600),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${_formatTime(booking.startTime)} - ${_formatTime(booking.endTime)}',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: statusStyle['bg'], borderRadius: BorderRadius.circular(8)),
                  child: Text(
                    statusStyle['text'],
                    style: TextStyle(color: statusStyle['color'], fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.grey.shade100),
          
          // Тело карточки
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildInfoRow(Icons.person_outline_rounded, 'Клиент', booking.clientName),
                const SizedBox(height: 12),
                _buildInfoRow(Icons.content_cut_rounded, 'Услуга', booking.serviceName.isNotEmpty ? booking.serviceName : 'Услуга не указана'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.timer_outlined, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text('${_calculateDuration(booking.startTime, booking.endTime)} мин', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(6)),
                      child: Text('100 с.', style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Кнопки действий (только для pending)
          if (booking.status == BookingStatus.pending) ...[
            Divider(height: 1, color: Colors.grey.shade100),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _updateBookingStatus(booking.id, 'cancelled'),
                      icon: Icon(Icons.close_rounded, size: 18, color: Colors.red.shade400),
                      label: Text('Отклонить', style: TextStyle(color: Colors.red.shade400)),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.red.shade200),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _updateBookingStatus(booking.id, 'confirmed'),
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: const Text('Принять'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
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

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade500),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              text: '$label: ',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
              children: [
                TextSpan(text: value, style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w500)),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  int _calculateDuration(DateTime start, DateTime end) => end.difference(start).inMinutes;
}