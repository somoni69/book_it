import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shimmer/shimmer.dart';
import '../../data/datasources/booking_remote_datasource.dart';
import '../../data/repositories/booking_repository_impl.dart';
import '../bloc/hostel_calendar_bloc.dart';
import '../bloc/hostel_calendar_event.dart';
import '../bloc/hostel_calendar_state.dart';
import '../../../../core/services/ical_sync_service.dart';

class HostelCalendarPage extends StatefulWidget {
  const HostelCalendarPage({super.key});

  @override
  State<HostelCalendarPage> createState() => _HostelCalendarPageState();
}

class _HostelCalendarPageState extends State<HostelCalendarPage> {
  DateTime _focusedDay = DateTime.now();
  String? _serviceId;
  bool _isLoadingService = true;
  String? _serviceTitle;

  @override
  void initState() {
    super.initState();
    _fetchServiceId();
  }

  /// Ищем услугу с типом 'daily' у текущего мастера
  Future<void> _fetchServiceId() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      final response = await Supabase.instance.client
          .from('services')
          .select('id, title')
          .eq('master_id', userId)
          .eq('booking_type', 'daily')
          .limit(1)
          .maybeSingle();

      if (response != null && mounted) {
        setState(() {
          _serviceId = response['id'];
          _serviceTitle = response['title'];
          _isLoadingService = false;
        });
      } else {
        if (mounted) setState(() => _isLoadingService = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingService = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Пока ищем услугу – показываем скелетон (или лоадер)
    if (_isLoadingService) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: _buildAppBar(),
        body: _buildSkeleton(),
      );
    }

    // Если услуга не найдена (мастер без посуточного жилья)
    if (_serviceId == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: _buildAppBar(),
        body: _buildNoServicePlaceholder(),
      );
    }

    // Услуга найдена – создаём репозиторий и BLoC локально
    final supabase = Supabase.instance.client;
    final dataSource = BookingRemoteDataSourceImpl(supabase);
    final repository = BookingRepositoryImpl(dataSource);

    return BlocProvider(
      create: (context) => HostelCalendarBloc(
        repository: repository,
        initialServiceId: _serviceId!,
      )..add(LoadHostelOccupancy(
          serviceId: _serviceId!,
          month: DateTime(_focusedDay.year, _focusedDay.month, 1),
        )),
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: _buildAppBar(title: _serviceTitle),
        body: BlocBuilder<HostelCalendarBloc, HostelCalendarState>(
          builder: (context, state) {
            if (state is HostelCalendarLoading) {
              return _buildSkeleton();
            }

            if (state is HostelCalendarError) {
              return _buildError(state.message);
            }

            if (state is HostelCalendarLoaded) {
              return _buildCalendarContent(context, state);
            }

            // Начальное состояние – тоже скелетон
            return _buildSkeleton();
          },
        ),
      ),
    );
  }

  AppBar _buildAppBar({String? title}) {
    return AppBar(
      title: Text(
        title ?? 'Шахматка',
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
      ),
      centerTitle: true,
      backgroundColor: Colors.white,
      foregroundColor: Colors.black87,
      elevation: 1,
      actions: [
        if (_serviceId != null)
          IconButton(
            icon: const Icon(Icons.sync_rounded, color: Colors.blue),
            tooltip: 'Синхронизация iCal',
            onPressed: _showSyncDialog,
          ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildCalendarContent(
      BuildContext context, HostelCalendarLoaded state) {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: TableCalendar(
            locale: 'ru_RU',
            firstDay: DateTime.utc(2024, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            // ИСПРАВЛЕНИЕ 1: Используем локальную переменную вместо стейта BLoC
            focusedDay: _focusedDay,
            startingDayOfWeek: StartingDayOfWeek.monday,
            headerStyle: const HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
              titleTextStyle:
                  TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            daysOfWeekStyle: const DaysOfWeekStyle(
              weekdayStyle:
                  TextStyle(fontWeight: FontWeight.bold, color: Colors.black54),
              weekendStyle: TextStyle(
                  fontWeight: FontWeight.bold, color: Colors.redAccent),
            ),
            calendarBuilders: CalendarBuilders(
              defaultBuilder: (context, day, focusedDay) =>
                  _buildCalendarCell(day, state),
              todayBuilder: (context, day, focusedDay) =>
                  _buildCalendarCell(day, state, isToday: true),
              outsideBuilder: (context, day, focusedDay) =>
                  const SizedBox.shrink(),
            ),
            onPageChanged: (focusedDay) {
              setState(() => _focusedDay = focusedDay);
              context.read<HostelCalendarBloc>().add(
                    ChangeMonth(DateTime(focusedDay.year, focusedDay.month, 1)),
                  );
            },
          ),
        ),

        // Легенда
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildLegendItem(Colors.green.shade500, 'Свободно'),
              _buildLegendItem(Colors.amber.shade500, 'Мало мест'),
              _buildLegendItem(Colors.red.shade400, 'Мест нет'),
            ],
          ),
        ),

        // Информация о вместимости (опционально)
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.bed_rounded, color: Colors.blue.shade600),
                const SizedBox(width: 8),
                Text(
                  'Вместимость: ${state.totalCapacity} мест',
                  style: TextStyle(
                    color: Colors.blue.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCalendarCell(DateTime day, HostelCalendarLoaded state,
      {bool isToday = false}) {
    // ИСПРАВЛЕНИЕ 2: Если месяц ячейки не совпадает с месяцем загруженных данных (идет загрузка)
    if (day.month != state.currentMonth.month ||
        day.year != state.currentMonth.year) {
      return Container(
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.grey.shade200, // Серый цвет пока грузятся данные
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            '${day.day}',
            style: const TextStyle(
                color: Colors.black38,
                fontSize: 16,
                fontWeight: FontWeight.bold),
          ),
        ),
      );
    }

    // --- Оригинальная логика раскраски ---
    final available = state.occupancyMap[day.day] ?? 0;
    final total = state.totalCapacity;

    Color bgColor;
    if (available == 0) {
      bgColor = Colors.red.shade400;
    } else if (available <= (total * 0.3).ceil()) {
      bgColor = Colors.amber.shade500;
    } else {
      bgColor = Colors.green.shade500;
    }

    return Container(
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: isToday ? Border.all(color: Colors.black, width: 2) : null,
      ),
      child: Center(
        // ИСПРАВЛЕНИЕ: Обернули в FittedBox, чтобы текст всегда влезал в ячейку
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${day.day}',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 2),
              Text(
                available == 0 ? '0' : '$available',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
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
            // Заглушка календаря
            Container(
              height: 350,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            const SizedBox(height: 16),
            // Заглушка легенды
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(
                  3,
                  (_) => Container(
                        width: 80,
                        height: 20,
                        color: Colors.white,
                      )),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoServicePlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.hotel_rounded, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text(
            'Нет услуг посуточной аренды',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Добавьте услугу с типом "Посуточно", чтобы управлять загрузкой хостела.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade500, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline_rounded,
              size: 64, color: Colors.red.shade300),
          const SizedBox(height: 16),
          const Text(
            'Ошибка загрузки',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              context.read<HostelCalendarBloc>().add(LoadHostelOccupancy(
                    serviceId: _serviceId!,
                    month: DateTime(_focusedDay.year, _focusedDay.month, 1),
                  ));
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Повторить'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // КИЛЛЕР-ФИЧА: Синхронизация с Airbnb/Booking
  // ==========================================
  void _showSyncDialog() {
    final TextEditingController urlController = TextEditingController();
    bool isSyncing = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (dialogContext) =>
          StatefulBuilder(builder: (context, setModalState) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            top: 24,
            left: 24,
            right: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: Colors.blue.shade50, shape: BoxShape.circle),
                child: Icon(Icons.cloud_sync_rounded,
                    size: 40, color: Colors.blue.shade600),
              ),
              const SizedBox(height: 16),
              const Text('Синхронизация календаря',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(
                'Вставьте ссылку iCal (.ics) от Airbnb, Booking или другого сервиса, чтобы автоматически заблокировать занятые даты.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
              ),
              const SizedBox(height: 24),

              // Поле для ссылки
              TextField(
                controller: urlController,
                decoration: InputDecoration(
                  hintText: 'https://www.airbnb.ru/calendar/ical/...',
                  hintStyle:
                      TextStyle(color: Colors.grey.shade400, fontSize: 13),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  prefixIcon:
                      const Icon(Icons.link_rounded, color: Colors.grey),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: Colors.grey.shade200)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: Colors.grey.shade200)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: Colors.blue.shade400)),
                ),
              ),
              const SizedBox(height: 24),

              // Кнопка запуска
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: isSyncing
                      ? null
                      : () async {
                          final url = urlController.text.trim();
                          if (url.isEmpty || !url.startsWith('http')) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Введите корректную ссылку!'),
                                    backgroundColor: Colors.orange));
                            return;
                          }

                          setModalState(() => isSyncing = true);
                          try {
                            // 1. Запускаем наш сервис
                            final syncService = ICalSyncService();
                            await syncService.syncWithAirbnb(url, _serviceId!);

                            // 2. Закрываем диалог
                            if (mounted) Navigator.pop(dialogContext);

                            // 3. Показываем успех
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: const Text(
                                          'Синхронизация прошла успешно!'),
                                      backgroundColor: Colors.green.shade600));
                            }

                            // 4. ГЛАВНАЯ МАГИЯ: Заставляем BLoC перезагрузить текущий месяц,
                            // чтобы новые брони с Airbnb сразу закрасили ячейки красным!
                            if (mounted) {
                              context
                                  .read<HostelCalendarBloc>()
                                  .add(LoadHostelOccupancy(
                                    serviceId: _serviceId!,
                                    month: DateTime(
                                        _focusedDay.year, _focusedDay.month, 1),
                                  ));
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text(e.toString()),
                                      backgroundColor: Colors.red));
                            }
                          } finally {
                            if (mounted) setModalState(() => isSyncing = false);
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: isSyncing
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Text('Начать синхронизацию',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              )
            ],
          ),
        );
      }),
    );
  }
}
