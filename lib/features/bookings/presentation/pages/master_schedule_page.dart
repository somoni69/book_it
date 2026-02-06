import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/working_hour_entity.dart';
import '../../data/repositories/working_hour_repository_impl.dart';

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
  final _days = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];

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

      // Заполняем пробелы дефолтными значениями
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
            isDayOff: dayNum >= 6, // Сб-Вс выходные
          ),
        );
      });
    } catch (e) {
      // Если ошибка, создаем дефолтный график
      final userId = _supabase.auth.currentUser!.id;
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

  // Мгновенное переключение (Optimistic Update)
  void _toggleDay(int index, bool isWorking) {
    final oldDay = _schedule[index];

    setState(() {
      // 1. МГНОВЕННО обновляем UI, не ждем базу
      _schedule[index] = oldDay.copyWith(
        isDayOff: !isWorking, // Если включили (true), значит НЕ выходной
      );
    });

    // 2. Шлем запрос в фоне
    _saveToBackend();
  }

  Future<void> _saveToBackend() async {
    try {
      await _repository.updateWorkingHours(_schedule);
    } catch (e) {
      // Если ошибка - можно показать SnackBar, но UI не фризится
      debugPrint("Ошибка сохранения графика: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("График работы")),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              itemCount: 7,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final day = _schedule[index];
                final isWorking = !day.isDayOff; // Работает ли сегодня?

                return SwitchListTile(
                  title: Text(
                    _days[index],
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  subtitle: Text(
                    isWorking ? day.timeRange : "Выходной",
                    style: TextStyle(
                      color: isWorking ? Colors.black : Colors.red,
                      fontWeight: isWorking
                          ? FontWeight.normal
                          : FontWeight.bold,
                    ),
                  ),
                  value: isWorking,
                  onChanged: (val) => _toggleDay(index, val),
                );
              },
            ),
    );
  }
}
