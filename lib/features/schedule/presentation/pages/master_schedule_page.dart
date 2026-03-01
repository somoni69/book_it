import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shimmer/shimmer.dart';
import '../../../bookings/domain/entities/working_hour_entity.dart';
import '../../../bookings/data/repositories/working_hour_repository_impl.dart';

class MasterSchedulePage extends StatefulWidget {
  const MasterSchedulePage({super.key});

  @override
  State<MasterSchedulePage> createState() => _MasterSchedulePageState();
}

class _MasterSchedulePageState extends State<MasterSchedulePage> {
  final _supabase = Supabase.instance.client;
  late final WorkingHourRepositoryImpl _repository;
  bool _isLoading = true;
  List<WorkingHourEntity> _schedule = [];

  final List<Map<String, dynamic>> _daysInfo = [
    {'short': 'Пн', 'full': 'Понедельник'},
    {'short': 'Вт', 'full': 'Вторник'},
    {'short': 'Ср', 'full': 'Среда'},
    {'short': 'Чт', 'full': 'Четверг'},
    {'short': 'Пт', 'full': 'Пятница'},
    {'short': 'Сб', 'full': 'Суббота'},
    {'short': 'Вс', 'full': 'Воскресенье'},
  ];

  // --- Единый стиль ---
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
    _repository = WorkingHourRepositoryImpl(_supabase);
    _loadSchedule();
  }

  Future<void> _loadSchedule() async {
    final userId = _supabase.auth.currentUser!.id;

    try {
      final savedDays = await _repository.getWorkingHours(userId);

      _schedule = List.generate(7, (index) {
        final dayNum = index + 1;
        return savedDays.firstWhere(
          (e) => e.dayOfWeek == dayNum,
          orElse: () => WorkingHourEntity(
            id: 'temp_$dayNum',
            masterId: userId,
            dayOfWeek: dayNum,
            startTime: const TimeOfDay(hour: 9, minute: 0),
            endTime: const TimeOfDay(hour: 18, minute: 0),
            isDayOff: dayNum >= 6,
          ),
        );
      });
    } catch (e) {
      _schedule = List.generate(7, (index) {
        final dayNum = index + 1;
        return WorkingHourEntity(
          id: 'temp_$dayNum',
          masterId: userId,
          dayOfWeek: dayNum,
          startTime: const TimeOfDay(hour: 9, minute: 0),
          endTime: const TimeOfDay(hour: 18, minute: 0),
          isDayOff: dayNum >= 6,
        );
      });
    }

    if (mounted) setState(() => _isLoading = false);
  }

  void _toggleDay(int index, bool isWorking) {
    final oldDay = _schedule[index];
    setState(() {
      _schedule[index] = oldDay.copyWith(isDayOff: !isWorking);
    });
    _saveToBackend();
  }

  Future<void> _saveToBackend() async {
    try {
      await _repository.updateWorkingHours(_schedule);
    } catch (e) {
      debugPrint("Ошибка сохранения графика: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text("График работы",
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
        shadowColor: Colors.black.withOpacity(0.05),
      ),
      body: _isLoading ? _buildSkeleton() : _buildContent(),
    );
  }

  Widget _buildContent() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      physics: const BouncingScrollPhysics(),
      itemCount: 7,
      itemBuilder: (context, index) {
        final day = _schedule[index];
        final isWorking = !day.isDayOff;
        final isWeekend = index >= 5; // Сб и Вс

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: _borderRadius,
            boxShadow: _cardShadow,
            border: Border.all(
                color: isWorking ? Colors.blue.shade100 : Colors.grey.shade100),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _toggleDay(index, !isWorking),
              borderRadius: _borderRadius,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    // Круглая аватарка дня недели
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isWorking
                            ? Colors.blue.shade50
                            : (isWeekend
                                ? Colors.red.shade50
                                : Colors.grey.shade100),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          _daysInfo[index]['short'],
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: isWorking
                                ? Colors.blue.shade700
                                : (isWeekend
                                    ? Colors.red.shade400
                                    : Colors.grey.shade500),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Информация
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _daysInfo[index]['full'],
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: isWorking
                                  ? Colors.black87
                                  : Colors.grey.shade500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isWorking
                                ? "С ${day.timeRange.replaceAll(' - ', ' до ')}"
                                : "Выходной",
                            style: TextStyle(
                              fontSize: 13,
                              color: isWorking
                                  ? Colors.grey.shade700
                                  : Colors.red.shade400,
                              fontWeight: isWorking
                                  ? FontWeight.normal
                                  : FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Свитч
                    Switch(
                      value: isWorking,
                      onChanged: (val) => _toggleDay(index, val),
                      activeColor: Colors.blue.shade600,
                      activeTrackColor: Colors.blue.shade100,
                      inactiveThumbColor: Colors.grey.shade400,
                      inactiveTrackColor: Colors.grey.shade200,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSkeleton() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade200,
      highlightColor: Colors.grey.shade50,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 7,
        itemBuilder: (context, index) => Container(
          height: 76,
          margin: const EdgeInsets.only(bottom: 12),
          decoration:
              BoxDecoration(color: Colors.white, borderRadius: _borderRadius),
        ),
      ),
    );
  }
}
