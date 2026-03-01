import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:book_it/features/bookings/domain/entities/booking_entity.dart';
import '../bloc/booking_bloc.dart';
import '../bloc/booking_state.dart';

class BookingDetailsScreen extends StatefulWidget {
  final String bookingId;
  const BookingDetailsScreen({super.key, required this.bookingId});

  @override
  State<BookingDetailsScreen> createState() => _BookingDetailsScreenState();
}

class _BookingDetailsScreenState extends State<BookingDetailsScreen> {
  // --- Единый стиль ---
  final BorderRadius _borderRadius = BorderRadius.circular(16);
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
    // context.read<BookingBloc>().add(LoadBookingDetails(widget.bookingId));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Детали записи', style: TextStyle(fontWeight: FontWeight.w600)),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
        shadowColor: Colors.black.withOpacity(0.05),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: BlocBuilder<BookingBloc, BookingState>(
        builder: (context, state) {
          if (state is BookingLoading) {
            return const Center(child: CircularProgressIndicator(color: Colors.blue));
          }

          // Заглушка
          final booking = BookingEntity(
            id: widget.bookingId,
            masterId: '',
            clientId: '',
            startTime: DateTime.now(),
            endTime: DateTime.now().add(const Duration(hours: 1)),
            status: BookingStatus.confirmed,
            clientName: 'Алексей Иванов',
            masterName: 'Мастер',
          );

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: _borderRadius,
                    boxShadow: _cardShadow,
                  ),
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('ID Записи', style: TextStyle(color: Colors.grey, fontSize: 13)),
                          Text('#${booking.id.length > 8 ? booking.id.substring(0, 8) : booking.id}', 
                               style: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.bold, fontSize: 13)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(height: 1),
                      const SizedBox(height: 16),
                      
                      _buildDetailRow(Icons.person_outline, 'Клиент', booking.clientName),
                      const SizedBox(height: 20),
                      _buildDetailRow(
                        Icons.access_time_rounded, 
                        'Время', 
                        '${DateFormat('HH:mm').format(booking.startTime)} - ${DateFormat('HH:mm').format(booking.endTime)}'
                      ),
                      const SizedBox(height: 20),
                      _buildDetailRow(
                        Icons.calendar_today_rounded, 
                        'Дата', 
                        DateFormat('d MMMM yyyy', 'ru_RU').format(booking.startTime)
                      ),
                      const SizedBox(height: 20),
                      
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(10)),
                            child: Icon(Icons.info_outline, size: 20, color: Colors.blue.shade700),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Статус', style: TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w500)),
                                const SizedBox(height: 4),
                                _buildStatusBadge(booking.status),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 32),
                
                if (booking.status == BookingStatus.pending || booking.status == BookingStatus.confirmed)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ElevatedButton.icon(
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('Подтвердить запись', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade600,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () {},
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.cancel_outlined),
                        label: const Text('Отменить', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red.shade500,
                          side: BorderSide(color: Colors.red.shade200),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () {},
                      ),
                    ],
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, size: 20, color: Colors.blue.shade700),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w500)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(BookingStatus status) {
    Color bgColor;
    Color textColor;
    String text;

    switch (status) {
      case BookingStatus.confirmed:
        bgColor = Colors.green.shade50;
        textColor = Colors.green.shade700;
        text = 'Подтверждена';
        break;
      case BookingStatus.pending:
        bgColor = Colors.orange.shade50;
        textColor = Colors.orange.shade700;
        text = 'Ожидает';
        break;
      case BookingStatus.cancelled:
        bgColor = Colors.red.shade50;
        textColor = Colors.red.shade700;
        text = 'Отменена';
        break;
      case BookingStatus.completed:
        bgColor = Colors.blue.shade50;
        textColor = Colors.blue.shade700;
        text = 'Завершена';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(8)),
      child: Text(text, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 13)),
    );
  }
}