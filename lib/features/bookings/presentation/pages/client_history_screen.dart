import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shimmer/shimmer.dart';
import '../../data/datasources/booking_remote_datasource.dart';
import '../../data/repositories/booking_repository_impl.dart';
import '../../domain/entities/booking_entity.dart';
import '../../../reviews/data/repositories/review_repository_impl.dart';
import '../../../reviews/presentation/pages/review_screen.dart';

class ClientHistoryScreen extends StatefulWidget {
  const ClientHistoryScreen({super.key});

  @override
  State<ClientHistoryScreen> createState() => _ClientHistoryScreenState();
}

class _ClientHistoryScreenState extends State<ClientHistoryScreen> {
  late BookingRepositoryImpl _bookingRepo;
  late ReviewRepositoryImpl _reviewRepo;
  List<BookingEntity> _bookings = [];
  bool _isLoading = true;

  // --- Единый стиль ---
  final BorderRadius _borderRadius = BorderRadius.circular(20);
  final List<BoxShadow> _cardShadow = [
    BoxShadow(
      color: Colors.black.withOpacity(0.04),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];

  @override
  void initState() {
    super.initState();
    final supabase = Supabase.instance.client;
    final dataSource = BookingRemoteDataSourceImpl(supabase);
    _bookingRepo = BookingRepositoryImpl(dataSource);
    _reviewRepo = ReviewRepositoryImpl(supabase);
    _loadBookings();
  }

  Future<void> _loadBookings() async {
    try {
      setState(() => _isLoading = true);
      final currentUserId = Supabase.instance.client.auth.currentUser?.id;
      if (currentUserId == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final bookings = await _bookingRepo.getClientBookings(currentUserId);

      if (mounted) {
        setState(() {
          _bookings = bookings;
          _isLoading = false;
        });
        _checkForReview();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _checkForReview() async {
    final completedBookings = _bookings
        .where((b) => b.status == BookingStatus.completed && b.startTime.isBefore(DateTime.now()))
        .toList();

    if (completedBookings.isEmpty) return;

    try {
      final latestBooking = completedBookings.first;
      final hasReview = await _reviewRepo.hasReviewForBooking(latestBooking.id);

      if (!hasReview && mounted) {
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ReviewScreen(
                  bookingId: latestBooking.id,
                  masterId: latestBooking.masterId,
                  masterName: latestBooking.masterName,
                  serviceName: latestBooking.serviceName,
                ),
              ),
            ).then((reviewed) {
              if (reviewed == true) _loadBookings();
            });
          }
        });
      }
    } catch (e) {
      // Игнорируем ошибки проверки отзывов
    }
  }

  String _formatDate(DateTime date) {
    final months = ['янв', 'фев', 'мар', 'апр', 'мая', 'июн', 'июл', 'авг', 'сен', 'окт', 'ноя', 'дек'];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String _formatTime(DateTime time) => '${time.hour}:${time.minute.toString().padLeft(2, '0')}';

  Map<String, dynamic> _getStatusStyle(BookingStatus status) {
    switch (status) {
      case BookingStatus.pending:
        return {'text': 'Ожидает', 'color': Colors.orange.shade700, 'bg': Colors.orange.shade50};
      case BookingStatus.confirmed:
        return {'text': 'Подтверждена', 'color': Colors.green.shade700, 'bg': Colors.green.shade50};
      case BookingStatus.cancelled:
        return {'text': 'Отменена', 'color': Colors.red.shade700, 'bg': Colors.red.shade50};
      case BookingStatus.completed:
        return {'text': 'Завершена', 'color': Colors.blue.shade700, 'bg': Colors.blue.shade50};
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Мои записи', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
        shadowColor: Colors.black.withOpacity(0.05),
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
        padding: const EdgeInsets.all(20),
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
        padding: const EdgeInsets.all(20),
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 4,
        separatorBuilder: (_, __) => const SizedBox(height: 16),
        itemBuilder: (context, index) => Container(
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
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: Colors.blue.shade50, shape: BoxShape.circle),
            child: Icon(Icons.receipt_long_rounded, size: 64, color: Colors.blue.shade300),
          ),
          const SizedBox(height: 24),
          const Text('У вас пока нет записей', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 8),
          Text('Все ваши бронирования будут\nотображаться здесь', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Colors.grey.shade600, height: 1.4)),
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
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: _borderRadius,
        boxShadow: _cardShadow,
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Шапка карточки (Дата и статус)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.calendar_month_rounded, size: 18, color: Colors.grey.shade500),
                    const SizedBox(width: 8),
                    Text(
                      _formatDate(booking.startTime),
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
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
                _buildInfoRow(
                  Icons.access_time_rounded,
                  'Время',
                  '${_formatTime(booking.startTime)} – ${_formatTime(booking.endTime)}',
                  Colors.blue.shade600,
                  Colors.blue.shade50,
                ),
                const SizedBox(height: 16),
                _buildInfoRow(
                  Icons.person_outline_rounded,
                  'Мастер',
                  booking.masterName.isNotEmpty ? booking.masterName : 'Мастер',
                  Colors.orange.shade600,
                  Colors.orange.shade50,
                ),
                const SizedBox(height: 16),
                _buildInfoRow(
                  Icons.content_cut_rounded,
                  'Услуга',
                  booking.serviceName.isNotEmpty ? booking.serviceName : 'Услуга',
                  Colors.purple.shade500,
                  Colors.purple.shade50,
                ),
              ],
            ),
          ),

          // Кнопка отмены
          if (booking.status == BookingStatus.confirmed || booking.status == BookingStatus.pending) ...[
            Divider(height: 1, color: Colors.grey.shade100),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _cancelBooking(booking.id),
                borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(20), bottomRight: Radius.circular(20)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.cancel_outlined, size: 18, color: Colors.red.shade400),
                      const SizedBox(width: 8),
                      Text('Отменить запись', style: TextStyle(color: Colors.red.shade400, fontWeight: FontWeight.w600, fontSize: 14)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, Color iconColor, Color bgColor) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, size: 18, color: iconColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87), overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _cancelBooking(String bookingId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Отменить запись?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Вы уверены, что хотите отменить эту запись? Мастер получит уведомление об отмене.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Нет, оставить', style: TextStyle(color: Colors.grey.shade700)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade50,
              foregroundColor: Colors.red.shade600,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Да, отменить'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        setState(() => _isLoading = true);
        await _bookingRepo.updateBookingStatus(bookingId, BookingStatus.cancelled);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Запись успешно отменена'), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating),
          );
          _loadBookings();
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
          );
        }
      }
    }
  }
}