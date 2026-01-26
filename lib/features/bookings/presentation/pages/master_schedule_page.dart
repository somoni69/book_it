import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/models/working_hour_model.dart';

class MasterSchedulePage extends StatefulWidget {
  const MasterSchedulePage({super.key});

  @override
  State<MasterSchedulePage> createState() => _MasterSchedulePageState();
}

class _MasterSchedulePageState extends State<MasterSchedulePage> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<WorkingHour> _schedule = [];
  final _days = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];

  @override
  void initState() {
    super.initState();
    _loadSchedule();
  }

  Future<void> _loadSchedule() async {
    final userId = _supabase.auth.currentUser!.id;
    final response = await _supabase
        .from('working_hours')
        .select()
        .eq('master_id', userId)
        .order('day_of_week');

    final savedDays = (response as List).map((e) => WorkingHour.fromJson(e)).toList();

    // Заполняем пробелы дефолтными значениями
    _schedule = List.generate(7, (index) {
      final dayNum = index + 1;
      return savedDays.firstWhere(
        (e) => e.dayOfWeek == dayNum,
        orElse: () => WorkingHour(
            id: '', 
            dayOfWeek: dayNum, 
            startTime: '09:00', 
            endTime: '18:00', 
            isDayOff: false // По умолчанию работаем
        ),
      );
    });

    if (mounted) setState(() => _isLoading = false);
  }

  // Мгновенное переключение (Optimistic Update)
  void _toggleDay(int index, bool isWorking) {
    final oldDay = _schedule[index];
    
    setState(() {
      // 1. МГНОВЕННО обновляем UI, не ждем базу
      _schedule[index] = WorkingHour(
        id: oldDay.id,
        dayOfWeek: oldDay.dayOfWeek,
        startTime: oldDay.startTime,
        endTime: oldDay.endTime,
        isDayOff: !isWorking, // Если включили (true), значит НЕ выходной
      );
    });

    // 2. Шлем запрос в фоне
    _saveToBackend(oldDay.dayOfWeek, oldDay.startTime, oldDay.endTime, !isWorking);
  }

  Future<void> _saveToBackend(int dayNum, String start, String end, bool isOff) async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      await _supabase.from('working_hours').upsert({
        'master_id': userId,
        'day_of_week': dayNum,
        'start_time': start,
        'end_time': end,
        'is_day_off': isOff,
      }, onConflict: 'master_id, day_of_week');
    } catch (e) {
      // Если ошибка - можно показать SnackBar, но UI не фризится
      print("Ошибка сохранения графика: $e");
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
                  activeColor: Colors.green, // Зеленый когда работает
                  title: Text(_days[index], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  subtitle: Text(
                    isWorking ? "${day.startTime} - ${day.endTime}" : "Выходной",
                    style: TextStyle(
                      color: isWorking ? Colors.black : Colors.red,
                      fontWeight: isWorking ? FontWeight.normal : FontWeight.bold
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
