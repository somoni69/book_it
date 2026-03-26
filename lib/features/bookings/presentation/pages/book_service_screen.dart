import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shimmer/shimmer.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/services/calendar_service.dart';
import '../../../../core/utils/user_utils.dart';
import '../../domain/entities/booking_entity.dart';

class BookServiceScreen extends StatefulWidget {
  final String masterId;
  final String serviceId;
  final String serviceName;

  const BookServiceScreen({
    super.key,
    required this.masterId,
    required this.serviceId,
    required this.serviceName,
  });

  @override
  _BookServiceScreenState createState() => _BookServiceScreenState();
}

class _BookServiceScreenState extends State<BookServiceScreen> {
  DateTime _selectedDate = DateTime.now();
  String? _selectedTimeSlot;
  bool _isLoadingSlots = false;
  String _masterName = 'Мастер';
  String _clientName = 'Клиент';

  List<Map<String, dynamic>> _timeSlots = [];

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
    _selectedDate =
        DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    _loadSlotsForDate(_selectedDate);
  }

  Future<void> _loadSlotsForDate(DateTime date) async {
    setState(() => _isLoadingSlots = true);

    try {
      final serviceData = await _getServiceDetails(widget.serviceId);
      final duration = serviceData['duration_min'] ?? 60;

      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final bookings = await Supabase.instance.client
          .from('bookings')
          .select('start_time, end_time')
          .eq('master_id', widget.masterId)
          .gte('start_time', startOfDay.toIso8601String())
          .lt('start_time', endOfDay.toIso8601String())
          .neq('status', 'cancelled');

      final busyTimes = (bookings as List).map((b) {
        final start = DateTime.parse(b['start_time'] as String);
        final end = DateTime.parse(b['end_time'] as String);
        return {'start': start, 'end': end};
      }).toList();

      final slots = <Map<String, dynamic>>[];
      final startHour = 9;
      final endHour = 18;

      for (int hour = startHour; hour < endHour; hour++) {
        for (int minute in [0, 30]) {
          final timeStr =
              '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
          final slotDateTime =
              DateTime(date.year, date.month, date.day, hour, minute);
          final slotEnd = slotDateTime.add(Duration(minutes: duration));

          bool isAvailable = true;
          for (final busy in busyTimes) {
            final busyStart = busy['start'] as DateTime;
            final busyEnd = busy['end'] as DateTime;
            if (!(slotEnd.isBefore(busyStart) ||
                slotDateTime.isAfter(busyEnd))) {
              isAvailable = false;
              break;
            }
          }

          slots.add({
            'time': timeStr,
            'available': isAvailable,
            'start': slotDateTime,
            'end': slotEnd,
          });
        }
      }

      if (mounted) {
        setState(() {
          _timeSlots = slots;
          _isLoadingSlots = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingSlots = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка загрузки слотов: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA), // Чуть более мягкий фон
      appBar: AppBar(
        title: Text(
          widget.serviceName,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
        shadowColor: Colors.black.withOpacity(0.05),
      ),
      body: RefreshIndicator(
        onRefresh: () => _loadSlotsForDate(_selectedDate),
        color: Colors.blue.shade600,
        child: Column(
          children: [
            _buildCalendarSection(),
            const SizedBox(height: 8),
            Expanded(
              child: _buildTimeSlotsSection(),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildConfirmButton(), // Липкая кнопка внизу
    );
  }

  Widget _buildCalendarSection() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: _borderRadius,
        boxShadow: _cardShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min, // Берет только нужную высоту
          children: [
            const Text(
              'Выберите дату',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            TableCalendar(
              locale: 'ru_RU',
              firstDay: DateTime.now(),
              lastDay: DateTime.now().add(const Duration(days: 90)),
              focusedDay: _selectedDate,
              selectedDayPredicate: (day) => isSameDay(_selectedDate, day),
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDate = selectedDay;
                  _selectedTimeSlot = null;
                });
                _loadSlotsForDate(selectedDay);
              },
              calendarFormat: CalendarFormat.month,
              startingDayOfWeek: StartingDayOfWeek.monday,
              availableGestures: AvailableGestures
                  .horizontalSwipe, // Отключаем вертикальный свайп, чтобы не конфликтовал со скроллом
              headerStyle: HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
                titleTextStyle:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                leftChevronIcon:
                    Icon(Icons.chevron_left, color: Colors.blue.shade700),
                rightChevronIcon:
                    Icon(Icons.chevron_right, color: Colors.blue.shade700),
              ),
              calendarStyle: CalendarStyle(
                todayDecoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.blue.shade200, width: 1),
                ),
                todayTextStyle: TextStyle(
                    color: Colors.blue.shade900, fontWeight: FontWeight.w600),
                selectedDecoration: BoxDecoration(
                    color: Colors.blue.shade600,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color: Colors.blue.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4))
                    ]),
                selectedTextStyle: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
                defaultTextStyle:
                    const TextStyle(fontSize: 14, color: Colors.black87),
                weekendTextStyle: const TextStyle(color: Colors.redAccent),
                outsideTextStyle:
                    TextStyle(fontSize: 14, color: Colors.grey.shade400),
              ),
              daysOfWeekStyle: DaysOfWeekStyle(
                weekdayStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600),
                weekendStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.red.shade300),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeSlotsSection() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24), topRight: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Выберите время',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87)),
                const SizedBox(height: 4),
                Text(
                  _getFormattedDate(_selectedDate),
                  style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoadingSlots
                ? _buildSkeletonGrid()
                : _timeSlots.isEmpty
                    ? _buildNoSlotsWidget()
                    : _buildTimeSlotsGrid(),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeSlotsGrid() {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8)
          .copyWith(bottom: 24), // Отступ снизу для красоты
      physics: const BouncingScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 2.2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: _timeSlots.length,
      itemBuilder: (context, index) {
        final slot = _timeSlots[index];
        final isSelected = _selectedTimeSlot == slot['time'];

        return _buildTimeSlotChip(
          time: slot['time'],
          isSelected: isSelected,
          isAvailable: slot['available'],
        );
      },
    );
  }

  // --- СКЕЛЕТОН ДЛЯ СЛОТОВ ВРЕМЕНИ ---
  Widget _buildSkeletonGrid() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade200,
      highlightColor: Colors.grey.shade50,
      child: GridView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 2.2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: 12, // Показываем 12 пульсирующих заглушек
        itemBuilder: (context, index) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
          );
        },
      ),
    );
  }

  Widget _buildNoSlotsWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
                color: Colors.grey.shade100, shape: BoxShape.circle),
            child:
                Icon(Icons.event_busy, size: 48, color: Colors.grey.shade400),
          ),
          const SizedBox(height: 16),
          const Text(
            'Нет доступного времени',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87),
          ),
          const SizedBox(height: 8),
          Text(
            'Выберите другую дату для записи',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTimeSlotChip(
      {required String time,
      required bool isSelected,
      required bool isAvailable}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap:
            isAvailable ? () => setState(() => _selectedTimeSlot = time) : null,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: isAvailable
                ? (isSelected ? Colors.blue.shade600 : Colors.white)
                : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? Colors.blue.shade600
                  : (isAvailable ? Colors.grey.shade300 : Colors.transparent),
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                        color: Colors.blue.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4))
                  ]
                : [],
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  time,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isAvailable
                        ? (isSelected ? Colors.white : Colors.black87)
                        : Colors.grey.shade400,
                  ),
                ),
                if (!isAvailable) ...[
                  const SizedBox(height: 2),
                  Text('Занято',
                      style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.w500)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConfirmButton() {
    final isEnabled = _selectedTimeSlot != null;

    return Container(
      padding: const EdgeInsets.only(
          top: 16,
          left: 24,
          right: 24,
          bottom: 32), // Padding с учетом Safe Area iPhone/Android
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, -5))
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: isEnabled ? _confirmBooking : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
              disabledBackgroundColor: Colors.grey.shade200,
              foregroundColor: Colors.white,
              disabledForegroundColor: Colors.grey.shade500,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              elevation: isEnabled ? 4 : 0,
              shadowColor: Colors.blue.withOpacity(0.4),
            ),
            child: Text(
              isEnabled ? 'Записаться на $_selectedTimeSlot' : 'Выберите время',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmBooking() async {
    if (_selectedTimeSlot == null) return;

    try {
      final booking = await _createBooking();
      if (booking == null) return;

      final description = CalendarService.instance.buildBookingDescription(
        serviceName: widget.serviceName,
        masterName: _masterName,
        clientName: _clientName,
      );

      final added = await CalendarService.instance.addBookingToCalendar(
        title: 'Запись: ${widget.serviceName}',
        description: description,
        startDate: booking.startTime,
        endDate: booking.endTime,
        reminderDuration: const Duration(hours: 1),
      );

      if (added) {
        _showSuccessDialog(
            message: 'Запись создана и добавлена в ваш календарь!');
      } else {
        _showSuccessDialog(
          message: 'Запись успешно создана!',
          subMessage:
              'Разрешите доступ к календарю для автоматических напоминаний.',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Ошибка: ${e.toString()}'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showSuccessDialog({required String message, String? subMessage}) {
    showDialog(
      context: context,
      barrierDismissible: false, // Пользователь должен нажать кнопку
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: Colors.green.shade50, shape: BoxShape.circle),
              child: Icon(Icons.check_circle,
                  size: 48, color: Colors.green.shade600),
            ),
            const SizedBox(height: 16),
            const Text('Успешно!',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16)),
            if (subMessage != null) ...[
              const SizedBox(height: 12),
              Text(subMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 13, color: Colors.grey.shade600, height: 1.4)),
            ],
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        actions: [
          if (subMessage != null)
            TextButton(
              onPressed: () {
                openAppSettings();
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: Text('Настройки',
                  style: TextStyle(
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.w600)),
            ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              minimumSize:
                  const Size(double.infinity, 48), // Кнопка во всю ширину
              elevation: 0,
            ),
            onPressed: () {
              Navigator.pop(context); // Закрываем диалог
              Navigator.pop(context); // Возвращаемся назад
            },
            child: const Text('Отлично',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  String _getFormattedDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selected = DateTime(date.year, date.month, date.day);

    if (selected == today) {
      return 'Сегодня, ${DateFormat('d MMMM', 'ru_RU').format(date)}';
    } else if (selected == today.add(const Duration(days: 1))) {
      return 'Завтра, ${DateFormat('d MMMM', 'ru_RU').format(date)}';
    } else {
      final formatter = DateFormat('EEEE, d MMMM', 'ru_RU');
      final formatted = formatter.format(date);
      return formatted[0].toUpperCase() + formatted.substring(1);
    }
  }

  DateTime _combineDateTime(DateTime date, String time) {
    final timeParts = time.split(':');
    return DateTime(
      date.year,
      date.month,
      date.day,
      int.parse(timeParts[0]),
      int.parse(timeParts[1]),
    );
  }

  Future<BookingEntity?> _createBooking() async {
    if (_selectedTimeSlot == null) return null;

    setState(() => _isLoadingSlots = true);

    try {
      final clientId = UserUtils.getCurrentUserIdOrThrow();
      final service = await _getServiceDetails(widget.serviceId);
      final startTime = _combineDateTime(_selectedDate, _selectedTimeSlot!);
      final endTime = startTime.add(Duration(minutes: service['duration_min']));

      final clientResponse = await Supabase.instance.client
          .from('profiles')
          .select('full_name')
          .eq('id', clientId)
          .single();
      _clientName = clientResponse['full_name'] ?? 'Клиент';
      _masterName = service['master_name'] ?? 'Мастер';

      final organizationId = service['organization_id'];

      final response = await Supabase.instance.client
          .from('bookings')
          .insert({
            'client_id': clientId,
            'master_id': service['master_id'],
            'service_id': widget.serviceId,
            'organization_id': organizationId,
            'start_time': startTime.toIso8601String(),
            'end_time': endTime.toIso8601String(),
            'status': 'pending',
            'price_som': int.tryParse(service['price'].toString()) ?? 0,
          })
          .select()
          .single();

      final booking = BookingEntity(
        id: response['id'],
        masterId: response['master_id'],
        clientId: response['client_id'],
        serviceId: response['service_id'],
        startTime: DateTime.parse(response['start_time']),
        endTime: DateTime.parse(response['end_time']),
        status: BookingStatus.pending,
        clientName: _clientName,
      );

      await NotificationService().showSimpleNotification(
        title: 'Запись создана',
        body:
            'Вы записаны на ${widget.serviceName} в $_selectedTimeSlot. Ожидайте подтверждения.',
      );

      await NotificationService().scheduleReminder(
        serviceName: widget.serviceName,
        time: startTime,
        isForMaster: false,
      );

      await _sendNotificationToMaster(service['master_id'], startTime);

      setState(() => _isLoadingSlots = false);
      return booking;
    } catch (e) {
      setState(() => _isLoadingSlots = false);
      rethrow;
    }
  }

  Future<Map<String, dynamic>> _getServiceDetails(String serviceId) async {
    final supabase = Supabase.instance.client;
    final response = await supabase.from('services').select('''
          id,
          master_id,
          title,
          duration_min,
          price,
          profiles!services_master_id_fkey(full_name, organization_id)
        ''').eq('id', serviceId).single();

    return {
      'id': response['id'] as String,
      'master_id': response['master_id'] as String,
      'master_name': response['profiles']['full_name'] as String?,
      'organization_id': response['profiles']['organization_id'],
      'title': response['title'] as String,
      'duration_min': int.tryParse(response['duration_min'].toString()) ?? 60,
      'price': double.tryParse(response['price'].toString()) ?? 0.0,
    };
  }

  Future<void> _sendNotificationToMaster(
      String masterId, DateTime startTime) async {
    await NotificationService().showSimpleNotification(
      title: 'Новая заявка',
      body: 'Новая запись на ${widget.serviceName} в ${_formatTime(startTime)}',
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour}:${time.minute.toString().padLeft(2, '0')}';
  }
}
