// lib/features/bookings/presentation/pages/booking_details_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:book_it/features/bookings/domain/entities/booking_entity.dart';
import '../bloc/booking_bloc.dart';
import '../bloc/booking_event.dart';
import '../bloc/booking_state.dart';

class BookingDetailsScreen extends StatefulWidget {
  final String bookingId;
  const BookingDetailsScreen({super.key, required this.bookingId});

  @override
  State<BookingDetailsScreen> createState() => _BookingDetailsScreenState();
}

class _BookingDetailsScreenState extends State<BookingDetailsScreen> {
  @override
  void initState() {
    super.initState();
    // Здесь можно загрузить данные о записи по ID
    // context.read<BookingBloc>().add(LoadBookingDetails(widget.bookingId));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Детали записи'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: BlocBuilder<BookingBloc, BookingState>(
        builder: (context, state) {
          if (state is BookingLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          // Заглушка - позже заменишь на реальные данные из state
          final booking = BookingEntity(
            id: widget.bookingId,
            masterId: '',
            clientId: '',
            startTime: DateTime.now(),
            endTime: DateTime.now().add(const Duration(hours: 1)),
            status: BookingStatus.confirmed,
            clientName: 'Клиент',
            masterName: 'Мастер',
          );

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.person),
                          title: const Text('Клиент'),
                          subtitle: Text(booking.clientName),
                        ),
                        ListTile(
                          leading: const Icon(Icons.access_time),
                          title: const Text('Время'),
                          subtitle: Text(
                              '${booking.startTime.hour}:${booking.startTime.minute.toString().padLeft(2, '0')} - ${booking.endTime.hour}:${booking.endTime.minute.toString().padLeft(2, '0')}'),
                        ),
                        ListTile(
                          leading: const Icon(Icons.calendar_today),
                          title: const Text('Дата'),
                          subtitle: Text(
                              '${booking.startTime.day}.${booking.startTime.month}.${booking.startTime.year}'),
                        ),
                        ListTile(
                          leading: const Icon(Icons.info),
                          title: const Text('Статус'),
                          subtitle: Chip(
                            label: Text(
                              booking.status.name.toUpperCase(),
                              style: const TextStyle(color: Colors.white),
                            ),
                            backgroundColor: booking.status ==
                                    BookingStatus.confirmed
                                ? Colors.green
                                : Colors.orange,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                if (booking.status == BookingStatus.pending ||
                    booking.status == BookingStatus.confirmed)
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.check_circle),
                          label: const Text('Подтвердить'),
                          onPressed: () {},
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.cancel),
                          label: const Text('Отменить'),
                          onPressed: () {},
                        ),
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
}