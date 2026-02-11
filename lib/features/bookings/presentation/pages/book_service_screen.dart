import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
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

  // Моковые данные - потом заменим на реальные
  List<Map<String, dynamic>> _timeSlots = [
    {'time': '09:00', 'available': true},
    {'time': '09:30', 'available': true},
    {'time': '10:00', 'available': true},
    {'time': '10:30', 'available': true},
    {'time': '11:00', 'available': true},
    {'time': '11:30', 'available': true},
    {'time': '12:00', 'available': true},
    {'time': '12:30', 'available': true},
    {'time': '13:00', 'available': true},
    {'time': '13:30', 'available': true},
    {'time': '14:00', 'available': true},
    {'time': '14:30', 'available': true},
    {'time': '15:00', 'available': true},
    {'time': '15:30', 'available': true},
    {'time': '16:00', 'available': true},
    {'time': '16:30', 'available': true},
    {'time': '17:00', 'available': true},
    {'time': '17:30', 'available': false}, // Занято
  ];

  @override
  void initState() {
    super.initState();
    // Устанавливаем дату без времени (только день)
    _selectedDate = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
    // Загружаем начальные слоты
    _loadInitialSlots();
  }

  // Загрузка начальных слотов для сегодня
  Future<void> _loadInitialSlots() async {
    await _loadSlotsForDate(_selectedDate);
  }

  // Быстрая загрузка слотов для выбранной даты
  Future<void> _loadSlotsForDate(DateTime date) async {
    setState(() => _isLoadingSlots = true);

    try {
      // Генерируем временные слоты каждые 30 минут с 9:00 до 18:00
      final slots = <Map<String, dynamic>>[];
      final startHour = 9;
      final endHour = 18;

      for (int hour = startHour; hour < endHour; hour++) {
        for (int minute in [0, 30]) {
          final time =
              '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
          // TODO: Проверить занятость через Supabase
          slots.add({'time': time, 'available': true});
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
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(
          'Запись: ${widget.serviceName}',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // 1. Календарь (фиксированная высота ~60%)
              Expanded(
                flex: 6, // 60% высоты
                child: SingleChildScrollView(child: _buildCalendarSection()),
              ),

              // Разделитель
              Container(
                height: 1,
                color: Colors.grey[200],
                margin: const EdgeInsets.symmetric(horizontal: 16),
              ),

              // 2. Время (фиксированная высота ~40%)
              Expanded(
                flex: 4, // 40% высоты
                child: _buildTimeSlotsSection(),
              ),
            ],
          ),
          if (_isLoadingSlots)
            Container(
              color: Colors.black.withValues(alpha: 0.3),
              child: const Center(
                child: CircularProgressIndicator(color: Color(0xFF4A6EF6)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCalendarSection() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Выберите дату',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 12),

            // КАЛЕНДАРЬ
            SizedBox(
              height: 400, // Увеличили высоту для исключения overflow
              child: TableCalendar(
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
                },
                calendarFormat: CalendarFormat.month,
                startingDayOfWeek: StartingDayOfWeek.monday,
                headerStyle: const HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: true,
                  titleTextStyle: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A1A),
                  ),
                  leftChevronIcon: Icon(
                    Icons.chevron_left,
                    color: Color(0xFF4A6EF6),
                  ),
                  rightChevronIcon: Icon(
                    Icons.chevron_right,
                    color: Color(0xFF4A6EF6),
                  ),
                  headerPadding: EdgeInsets.only(bottom: 12),
                  headerMargin: EdgeInsets.only(bottom: 8),
                ),
                calendarStyle: CalendarStyle(
                  // ← ИСПРАВЛЯЕМ ЦВЕТ ТЕКУЩЕГО ДНЯ
                  todayDecoration: BoxDecoration(
                    color: const Color(
                      0xFF4A6EF6,
                    ).withValues(alpha: 0.15), // ← БОЛЕЕ ПРОЗРАЧНЫЙ
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(
                        0xFF4A6EF6,
                      ).withValues(alpha: 0.5), // ← ТОНИРОВАННАЯ ГРАНИЦА
                      width: 1,
                    ),
                  ),
                  todayTextStyle: const TextStyle(
                    color: Color(0xFF1A1A1A), // ← ТЕМНЫЙ ТЕКСТ ДЛЯ ТЕКУЩЕГО ДНЯ
                    fontWeight: FontWeight.w500,
                  ),

                  // ← СТИЛЬ ВЫБРАННОГО ДНЯ (оставляем ярким)
                  selectedDecoration: const BoxDecoration(
                    color: Color(0xFF4A6EF6),
                    shape: BoxShape.circle,
                  ),
                  selectedTextStyle: const TextStyle(color: Colors.white),

                  // ← БАЗОВЫЕ СТИЛИ
                  defaultTextStyle: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF1A1A1A),
                  ),
                  weekendTextStyle: const TextStyle(color: Color(0xFFF24E1E)),
                  outsideTextStyle: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[400],
                  ),

                  // ← ОПТИМИЗАЦИЯ РАЗМЕРОВ
                  cellPadding: const EdgeInsets.all(6),
                  cellMargin: EdgeInsets.zero,
                ),
                daysOfWeekStyle: const DaysOfWeekStyle(
                  weekdayStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF666666),
                  ),
                  weekendStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFFF24E1E),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeSlotsSection() {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          // Заголовок времени
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 12, 32, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Выберите время',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _getFormattedDate(_selectedDate),
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF666666),
                  ),
                ),
              ],
            ),
          ),

          // Сетка времени с прокруткой
          Expanded(
            child: _timeSlots.isEmpty
                ? _buildNoSlotsWidget()
                : _buildTimeSlotsGrid(),
          ),

          // Кнопка подтверждения
          _buildConfirmButton(),
        ],
      ),
    );
  }

  Widget _buildTimeSlotsGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: GridView.builder(
        shrinkWrap: true,
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
      ),
    );
  }

  Widget _buildNoSlotsWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.access_time_filled, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text(
            'Нет доступного времени',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Выберите другую дату',
            style: TextStyle(fontSize: 14, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTimeSlotChip({
    required String time,
    required bool isSelected,
    required bool isAvailable,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isAvailable
            ? () {
                setState(() {
                  _selectedTimeSlot = time;
                });
              }
            : null,
        borderRadius: BorderRadius.circular(12),
        splashColor: const Color(0xFF4A6EF6).withValues(alpha: 0.1),
        child: Container(
          decoration: BoxDecoration(
            color: isAvailable
                ? (isSelected
                    ? const Color(0xFF4A6EF6)
                    : const Color(0xFFF8F9FF)) // ← СВЕТЛЫЙ ФОН ДЛЯ ДОСТУПНЫХ
                : const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF4A6EF6)
                  : (isAvailable
                      ? const Color(
                          0xFFE8EBFF,
                        ) // ← СВЕТЛАЯ ГРАНИЦА ДЛЯ ДОСТУПНЫХ
                      : Colors.transparent),
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFF4A6EF6).withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
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
                    fontWeight: FontWeight.w600,
                    color: isAvailable
                        ? (isSelected ? Colors.white : const Color(0xFF4A6EF6))
                        : const Color(0xFFCCCCCC),
                  ),
                ),
                if (!isAvailable) ...[
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Занято',
                      style: TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[200]!, width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: isEnabled ? _confirmBooking : null,
          style: ElevatedButton.styleFrom(
            backgroundColor:
                isEnabled ? const Color(0xFF4A6EF6) : const Color(0xFFE8EBFF),
            foregroundColor: isEnabled ? Colors.white : const Color(0xFFA0A9FF),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: isEnabled ? 3 : 0,
            shadowColor: isEnabled
                ? const Color(0xFF4A6EF6).withValues(alpha: 0.3)
                : Colors.transparent,
          ),
          child: Text(
            isEnabled ? 'Записаться на $_selectedTimeSlot' : 'Выберите время',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isEnabled ? Colors.white : const Color(0xFFA0A9FF),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmBooking() async {
    if (_selectedTimeSlot == null) return;

    try {
      // Создаем бронирование
      final booking = await _createBooking();

      if (booking == null) return;

      // Добавляем в календарь
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
          message: 'Запись создана и добавлена в ваш календарь!',
        );
      } else {
        _showSuccessDialog(
          message: 'Запись создана!',
          subMessage: 'Разрешите доступ к календарю для напоминаний.',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showSuccessDialog({required String message, String? subMessage}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('✅ Успешно!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message),
            if (subMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                subMessage,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Go back
            },
            child: const Text('ОК'),
          ),
          ElevatedButton(
            onPressed: () {
              // Открыть настройки календаря
              openAppSettings();
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Настройки календаря'),
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
      return 'Сегодня';
    } else if (selected == today.add(const Duration(days: 1))) {
      return 'Завтра';
    } else {
      final formatter = DateFormat('EEEE, d MMMM', 'ru_RU');
      final formatted = formatter.format(date);
      // Делаем первую букву заглавной
      return formatted[0].toUpperCase() + formatted.substring(1);
    }
  }

  // Комбинируем дату и время
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
      final endTime = startTime.add(
        Duration(minutes: service['duration_minutes']),
      );

      // Получаем имя клиента
      final clientResponse = await Supabase.instance.client
          .from('profiles')
          .select('full_name')
          .eq('id', clientId)
          .single();
      _clientName = clientResponse['full_name'] ?? 'Клиент';
      _masterName = service['master_name'] ?? 'Мастер';

      final response = await Supabase.instance.client
          .from('bookings')
          .insert({
            'client_id': clientId,
            'master_id': service['master_id'],
            'service_id': widget.serviceId,
            'organization_id': service['organization_id'],
            'start_time': startTime.toIso8601String(),
            'end_time': endTime.toIso8601String(),
            'status': 'pending',
            'price': service['price'],
            'currency': 'TJS',
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
            'Вы записаны на ${widget.serviceName} в $_selectedTimeSlot. Ожидайте подтверждения мастера.',
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
          name,
          duration_minutes,
          price,
          profiles!services_master_id_fkey(organization_id, full_name)
        ''').eq('id', serviceId).single();

    return {
      'id': response['id'] as String,
      'master_id': response['master_id'] as String,
      'organization_id': response['profiles']['organization_id'] as String?,
      'master_name': response['profiles']['full_name'] as String?,
      'name': response['name'] as String,
      'duration_minutes': response['duration_minutes'] as int? ?? 60,
      'price': (response['price'] as num?)?.toDouble() ?? 0.0,
    };
  }

  Future<void> _sendNotificationToMaster(
    String masterId,
    DateTime startTime,
  ) async {
    await NotificationService().showSimpleNotification(
      title: 'New booking request',
      body:
          'New booking for ${widget.serviceName} at ${_formatTime(startTime)}',
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour}:${time.minute.toString().padLeft(2, '0')}';
  }
}
