import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:permission_handler/permission_handler.dart';

// Импорты слоёв (предполагаем, что они существуют)
import '../../domain/entities/service_entity.dart';
import '../../domain/entities/booking_entity.dart';
import '../bloc/daily_booking_bloc.dart';
import '../../data/repositories/booking_repository_impl.dart';
import '../../data/datasources/booking_remote_datasource.dart';
import '../../../../core/services/calendar_service.dart';
// import '../../../../core/services/notification_service.dart';
// import '../../../../core/utils/user_utils.dart';
import '../../../../core/widgets/responsive_layout.dart';

class DailyBookingScreenWrapper extends StatelessWidget {
  final ServiceEntity service;
  final String masterId;

  const DailyBookingScreenWrapper({
    super.key,
    required this.service,
    required this.masterId,
  });

  @override
  Widget build(BuildContext context) {
    final supabase = Supabase.instance.client;
    final dataSource = BookingRemoteDataSourceImpl(supabase);
    final repository = BookingRepositoryImpl(dataSource);

    return BlocProvider(
      create: (context) => DailyBookingBloc(
        repository: repository,
        service: service,
        masterId: masterId,
      ),
      child: DailyBookingScreen(service: service),
    );
  }
}

class DailyBookingScreen extends StatefulWidget {
  final ServiceEntity service;

  const DailyBookingScreen({super.key, required this.service});

  @override
  State<DailyBookingScreen> createState() => _DailyBookingScreenState();
}

class _DailyBookingScreenState extends State<DailyBookingScreen> {
  // --- Стили (общие для всех экранов) ---
  final BorderRadius _borderRadius = BorderRadius.circular(16);
  final List<BoxShadow> _cardShadow = [
    BoxShadow(
        color: Colors.black.withOpacity(0.04),
        blurRadius: 16,
        offset: const Offset(0, 4)),
  ];

  @override
  Widget build(BuildContext context) {
    return BlocListener<DailyBookingBloc, DailyBookingState>(
      listener: (context, state) async {
        if (state is DailyBookingSuccess) {
          // После успешной записи пытаемся добавить в календарь устройства
          if (state.booking != null) {
            await _handleCalendarIntegration(state.booking!);
          }
          _showSuccessDialog();
        } else if (state is DailyBookingError && state.isCritical) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ ${state.message}'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(
          title: const Text('Бронирование жилья',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),
          centerTitle: true,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 1,
        ),
        body: ResponsiveLayout(
          mobile: _buildMobileLayout(),
          tablet: _buildTabletLayout(),
          desktop: _buildDesktopLayout(),
        ),
      ),
    );
  }

  // --- Мобильная версия (вертикальная форма) ---
  Widget _buildMobileLayout() {
    return _buildFormContainer(maxWidth: double.infinity);
  }

  // --- Планшетная версия (с ограничением ширины) ---
  Widget _buildTabletLayout() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: _buildFormContent(),
      ),
    );
  }

  // --- Десктопная версия (две колонки) ---
  Widget _buildDesktopLayout() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Левая колонка: информация о номере
            Expanded(
              flex: 1,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _buildServiceInfoCard(isDesktop: true),
              ),
            ),
            // Правая колонка: форма бронирования
            Expanded(
              flex: 1,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: _borderRadius),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: _buildFormContent(isDesktop: true),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Обёртка для мобильной/планшетной версии
  Widget _buildFormContainer({required double maxWidth}) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              _buildServiceInfoCard(),
              const SizedBox(height: 24),
              _buildFormContent(),
            ],
          ),
        ),
      ),
    );
  }

  // Карточка с информацией об услуге (номере)
  Widget _buildServiceInfoCard({bool isDesktop = false}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: _borderRadius,
        boxShadow: _cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.service.title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            '${widget.service.price} с. / ночь',
            style: TextStyle(
                fontSize: 18,
                color: Colors.blue.shade700,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.bed_rounded, size: 18, color: Colors.grey.shade500),
              const SizedBox(width: 8),
              Text(
                'Вместимость: ${widget.service.capacity} мест',
                style: TextStyle(
                    color: Colors.grey.shade600, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Основное содержимое формы (выбор дат, гостей, кнопка)
  Widget _buildFormContent({bool isDesktop = false}) {
    return BlocBuilder<DailyBookingBloc, DailyBookingState>(
      builder: (context, state) {
        // Получаем текущие значения из состояния
        final selectedDates = state.selectedDates;
        final guests = state.guests;
        final isLoading = state.isLoading;
        final error = state.error;
        final isAvailable = state.isAvailable;

        // Подсчёт ночей и цены (ИСПРАВЛЕНО: минимум 1 ночь)
        int nights = selectedDates != null
            ? selectedDates.end.difference(selectedDates.start).inDays
            : 0;

        // Защита от нулевой цены: если даты выбраны, минимум 1 ночь
        if (selectedDates != null && nights == 0) {
          nights = 1;
        }

        final totalPrice = nights * widget.service.price * guests;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Заголовок формы
            const Text(
              'Даты проживания',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            // Выбор дат
            InkWell(
              onTap: () => _pickDateRange(context),
              borderRadius: _borderRadius,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.blue.shade200),
                  borderRadius: _borderRadius,
                  color: Colors.blue.shade50.withOpacity(0.5),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_month_rounded,
                        color: Colors.blue.shade600),
                    const SizedBox(width: 16),
                    Expanded(
                      child: selectedDates == null
                          ? Text(
                              'Выберите даты заезда и выезда',
                              style: TextStyle(
                                  color: Colors.blue.shade700,
                                  fontWeight: FontWeight.w500),
                            )
                          : Text(
                              '${DateFormat('d MMM', 'ru_RU').format(selectedDates.start)} — ${DateFormat('d MMM', 'ru_RU').format(selectedDates.end)} ($nights ночей)',
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87),
                            ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Количество гостей
            const Text(
              'Количество мест (гостей)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: _borderRadius,
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$guests',
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline_rounded),
                        color: guests > 1
                            ? Colors.blue.shade600
                            : Colors.grey.shade300,
                        onPressed: guests > 1
                            ? () => context
                                .read<DailyBookingBloc>()
                                .add(UpdateGuests(guests - 1))
                            : null,
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline_rounded),
                        color: guests < widget.service.capacity
                            ? Colors.blue.shade600
                            : Colors.grey.shade300,
                        onPressed: guests < widget.service.capacity
                            ? () => context
                                .read<DailyBookingBloc>()
                                .add(UpdateGuests(guests + 1))
                            : null,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Статус доступности (если даты выбраны)
            if (selectedDates != null && nights > 0) ...[
              if (isLoading)
                const Center(child: CircularProgressIndicator())
              else if (error != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: _borderRadius,
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          error,
                          style: TextStyle(color: Colors.red.shade700),
                        ),
                      ),
                    ],
                  ),
                )
              else if (isAvailable == false)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: _borderRadius,
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded,
                          color: Colors.orange.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'На выбранные даты нет свободных мест. Попробуйте изменить даты или количество гостей.',
                          style: TextStyle(color: Colors.orange.shade700),
                        ),
                      ),
                    ],
                  ),
                ),
            ],

            const SizedBox(height: 24),

            // Итого к оплате
            if (selectedDates != null && nights > 0 && isAvailable == true) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Итого к оплате:',
                    style: TextStyle(
                        fontSize: 16,
                        color: Colors.black54,
                        fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '$totalPrice с.',
                    style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],

            // Кнопка бронирования
            SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed:
                    _canBook(state) ? () => _confirmBooking(context) : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade600,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: _borderRadius),
                  elevation: 4,
                ),
                child: isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Забронировать',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        );
      },
    );
  }

  // Проверка, можно ли забронировать
  bool _canBook(DailyBookingState state) {
    return !state.isLoading &&
        state.selectedDates != null &&
        state.guests > 0 &&
        state.isAvailable == true &&
        state.error == null;
  }

  // Выбор дат через DateRangePicker
  Future<void> _pickDateRange(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      initialDateRange: context.read<DailyBookingBloc>().state.selectedDates,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.indigo.shade600, // Красим под стиль хостелов
              onPrimary: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      context.read<DailyBookingBloc>().add(UpdateDateRange(picked));
    }
  }

  // Диалог подтверждения перед созданием брони
  void _confirmBooking(BuildContext context) {
    final state = context.read<DailyBookingBloc>().state;
    int nights =
        state.selectedDates!.end.difference(state.selectedDates!.start).inDays;
    // Минимум 1 ночь
    if (nights == 0) nights = 1;
    final total = nights * widget.service.price * state.guests;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: _borderRadius),
        title: const Text('Подтверждение бронирования'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${widget.service.title}'),
            const SizedBox(height: 8),
            Text(
                'Даты: ${DateFormat('d MMM', 'ru_RU').format(state.selectedDates!.start)} — ${DateFormat('d MMM', 'ru_RU').format(state.selectedDates!.end)}'),
            Text('Гостей: ${state.guests}'),
            const Divider(),
            Text('Итого: $total с.',
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              context.read<DailyBookingBloc>().add(CreateDailyBooking());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
              foregroundColor: Colors.white,
            ),
            child: const Text('Подтвердить'),
          ),
        ],
      ),
    );
  }

  // Интеграция с календарём устройства
  Future<void> _handleCalendarIntegration(BookingEntity booking) async {
    final permission = await Permission.calendar.request();
    if (permission.isGranted) {
      await CalendarService.instance.addBookingToCalendar(
        title: 'Заезд: ${widget.service.title}',
        description: CalendarService.instance.buildBookingDescription(
          serviceName: widget.service.title,
          masterName: 'Хостел', // Можно передать имя мастера, если есть
          clientName: 'Клиент',
        ),
        startDate: booking.startTime,
        endDate: booking.endTime,
        reminderDuration: const Duration(hours: 24), // Напоминание за день
      );
    }
  }

  // Диалог успешного бронирования
  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: _borderRadius),
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
              const Text(
                'Бронирование подтверждено!',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'Мы отправили уведомление. Ждём вас!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: Colors.grey),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () =>
                      Navigator.of(context).popUntil((route) => route.isFirst),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: _borderRadius),
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
}
