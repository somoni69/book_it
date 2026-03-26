import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Импорты слоев
import '../../data/datasources/booking_remote_datasource.dart';
import '../../data/repositories/booking_repository_impl.dart';
import '../../data/repositories/service_repository_impl.dart';
import '../bloc/booking_bloc.dart';
import '../bloc/booking_event.dart';
import '../bloc/booking_state.dart';
import '../../domain/entities/service_entity.dart';
import '../../domain/entities/time_slot.dart'; // ДОБАВЛЕН ИМПОРТ!

// Обёртка для создания BLoC
class BookingPageWrapper extends StatelessWidget {
  final ServiceEntity service;
  final String masterName;

  const BookingPageWrapper({
    super.key,
    required this.service,
    required this.masterName,
  });

  @override
  Widget build(BuildContext context) {
    final supabase = Supabase.instance.client;
    final dataSource = BookingRemoteDataSourceImpl(supabase);
    final repository = BookingRepositoryImpl(dataSource);
    final serviceRepository = ServiceRepositoryImpl(supabase);

    return BlocProvider(
      create: (context) => BookingBloc(
        repository: repository,
        serviceRepository: serviceRepository,
        masterId: service.masterId,
      )..add(
          LoadBookingsForDate(
            DateTime.now(),
            service.durationMin,
            service.id,
          ),
        ),
      child: BookingPage(
        service: service,
        masterName: masterName,
      ),
    );
  }
}

class BookingPage extends StatefulWidget {
  final ServiceEntity service;
  final String masterName;

  const BookingPage({
    super.key,
    required this.service,
    required this.masterName,
  });

  @override
  State<BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends State<BookingPage> {
  late final List<DateTime> _dates;
  DateTime _selectedDate = DateTime.now();
  String? _selectedTime;

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
    _dates =
        List.generate(30, (index) => DateTime.now().add(Duration(days: index)));
    _selectedDate = _dates.first;
  }

  void _onDateSelected(DateTime date) {
    if (!isSameDay(_selectedDate, date)) {
      setState(() {
        _selectedDate = date;
        _selectedTime = null; // Сбрасываем выбранное время
      });
      context.read<BookingBloc>().add(
            LoadBookingsForDate(
              date,
              widget.service.durationMin,
              widget.service.id,
            ),
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<BookingBloc, BookingState>(
      listener: (context, state) {
        if (state is BookingLoaded) {
          // Если слоты загрузились для новой даты, убеждаемся что нижняя панель скрыта
          if (state.selectedSlot == null && _selectedTime != null) {
            setState(() => _selectedTime = null);
          }

          if (state.submissionStatus == BookingSubmissionStatus.success) {
            _showSuccessDialog();
          } else if (state.submissionStatus ==
              BookingSubmissionStatus.failure) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("❌ Ошибка при записи"),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(
          title: const Text('Дата и время',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),
          centerTitle: true,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 1,
          shadowColor: Colors.black.withOpacity(0.05),
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildServiceSummary(),
            _buildDateSelector(),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 24, 20, 16),
              child: Text('Свободное время',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87)),
            ),
            Expanded(
              child: BlocBuilder<BookingBloc, BookingState>(
                builder: (context, state) {
                  if (state is BookingLoading) {
                    return _buildSkeletonSlots();
                  } else if (state is BookingError) {
                    return _buildErrorState(state.message);
                  } else if (state is BookingLoaded) {
                    if (state.slots.isEmpty) {
                      return _buildEmptySlots();
                    }
                    return _buildTimeSlots(state.slots, state.selectedSlot);
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
          ],
        ),
        bottomNavigationBar: _selectedTime != null ? _buildBottomBar() : null,
      ),
    );
  }

  Widget _buildServiceSummary() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.content_cut_rounded,
                color: Colors.blue.shade700, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.service.title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.black87)),
                const SizedBox(height: 4),
                Text(widget.masterName,
                    style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          Text('${widget.service.price.toStringAsFixed(0)} с.',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.green.shade700)),
        ],
      ),
    );
  }

  Widget _buildDateSelector() {
    return Container(
      padding: const EdgeInsets.only(bottom: 16, top: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: SizedBox(
        height: 85,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          itemCount: _dates.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (context, index) {
            final date = _dates[index];
            final isSelected = date.year == _selectedDate.year &&
                date.month == _selectedDate.month &&
                date.day == _selectedDate.day;
            final isToday = date.year == DateTime.now().year &&
                date.month == DateTime.now().month &&
                date.day == DateTime.now().day;

            return GestureDetector(
              onTap: () => _onDateSelected(date),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 64,
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.blue.shade600
                      : (isToday ? Colors.blue.shade50 : Colors.white),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: isSelected
                          ? Colors.blue.shade600
                          : Colors.grey.shade200),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                              color: Colors.blue.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4))
                        ]
                      : [],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      DateFormat('E', 'ru_RU').format(date).toUpperCase(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? Colors.white70
                            : (isToday
                                ? Colors.blue.shade700
                                : Colors.grey.shade500),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      date.day.toString(),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : Colors.black87,
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

  Widget _buildTimeSlots(List<TimeSlot> slots, TimeSlot? selectedSlot) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20).copyWith(bottom: 40),
      child: Wrap(
        spacing: 12,
        runSpacing: 16,
        children: slots.map((slot) {
          final timeStr = _formatTime(slot.startTime);
          // НАДЕЖНАЯ ПРОВЕРКА ПО ВРЕМЕНИ, А НЕ ПО ССЫЛКЕ НА ОБЪЕКТ
          final isSelected = selectedSlot?.startTime == slot.startTime;

          return GestureDetector(
            onTap: slot.isAvailable
                ? () {
                    setState(() => _selectedTime = timeStr);
                    context.read<BookingBloc>().add(SelectTimeSlot(slot));
                  }
                : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: (MediaQuery.of(context).size.width - 40 - 24) / 3,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: slot.isAvailable
                    ? (isSelected ? Colors.black87 : Colors.white)
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? Colors.black87
                      : (slot.isAvailable
                          ? Colors.grey.shade300
                          : Colors.transparent),
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 4))
                      ]
                    : [],
              ),
              alignment: Alignment.center,
              child: Text(
                timeStr,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  color: slot.isAvailable
                      ? (isSelected ? Colors.white : Colors.black87)
                      : Colors.grey.shade400,
                  decoration:
                      !slot.isAvailable ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBottomBar() {
    return BlocBuilder<BookingBloc, BookingState>(
      builder: (context, state) {
        bool isSubmitting = false;
        if (state is BookingLoaded) {
          isSubmitting =
              state.submissionStatus == BookingSubmissionStatus.submitting;
        }

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
                  padding: const EdgeInsets.all(20).copyWith(
                      bottom: MediaQuery.of(context).padding.bottom + 20),
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
                  child: SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.event_available_rounded,
                                color: Colors.blue.shade600, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              '${DateFormat('d MMMM', 'ru_RU').format(_selectedDate)} в $_selectedTime',
                              style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: isSubmitting
                                ? null
                                : () => context
                                    .read<BookingBloc>()
                                    .add(ConfirmBooking(widget.service.id)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade600,
                              foregroundColor: Colors.white,
                              elevation: 4,
                              shadowColor: Colors.blue.withOpacity(0.4),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                            ),
                            child: isSubmitting
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2))
                                : const Text('Подтвердить запись',
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                    color: Colors.green.shade50, shape: BoxShape.circle),
                child: Icon(Icons.check_circle_rounded,
                    color: Colors.green.shade500, size: 48),
              ),
              const SizedBox(height: 24),
              const Text('Вы успешно записаны!',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87),
                  textAlign: TextAlign.center),
              const SizedBox(height: 12),
              Text(
                'Ждем вас ${DateFormat('d MMMM', 'ru_RU').format(_selectedDate)} в $_selectedTime\nу мастера ${widget.masterName}.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 15, color: Colors.grey.shade600, height: 1.4),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Отлично',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptySlots() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_busy_rounded, size: 56, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          const Text('Нет свободного времени',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('На эту дату все занято.\nВыберите другой день.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade500, height: 1.4)),
        ],
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline_rounded,
              size: 56, color: Colors.red.shade300),
          const SizedBox(height: 16),
          const Text('Ошибка загрузки',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(message,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600)),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              context.read<BookingBloc>().add(
                    LoadBookingsForDate(
                      _selectedDate,
                      widget.service.durationMin,
                      widget.service.id,
                    ),
                  );
            },
            child: const Text('Повторить'),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonSlots() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade200,
      highlightColor: Colors.grey.shade50,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Wrap(
          spacing: 12,
          runSpacing: 16,
          children: List.generate(
              9,
              (index) => Container(
                    width: (MediaQuery.of(context).size.width - 40 - 24) / 3,
                    height: 50,
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12)),
                  )),
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    return "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
  }

  bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
