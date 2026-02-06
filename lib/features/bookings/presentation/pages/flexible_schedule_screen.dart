import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/working_hour_entity.dart';
import '../../domain/entities/daily_schedule.dart';
import '../../data/repositories/working_hour_repository_impl.dart';
import '../../../../core/utils/user_utils.dart';

class FlexibleScheduleScreen extends StatefulWidget {
  const FlexibleScheduleScreen({super.key});

  @override
  _FlexibleScheduleScreenState createState() => _FlexibleScheduleScreenState();
}

class _FlexibleScheduleScreenState extends State<FlexibleScheduleScreen> {
  late List<DailySchedule> _schedules;
  bool _isLoading = true;
  late WorkingHourRepositoryImpl _repository;

  final List<String> _dayNames = [
    'Понедельник',
    'Вторник',
    'Среда',
    'Четверг',
    'Пятница',
    'Суббота',
    'Воскресенье',
  ];

  @override
  void initState() {
    super.initState();
    _repository = WorkingHourRepositoryImpl(Supabase.instance.client);
    _loadSchedules();
  }

  Future<void> _loadSchedules() async {
    try {
      final masterId = UserUtils.getCurrentUserIdOrThrow();

      final schedules = await _repository.getMasterSchedule(masterId);

      setState(() {
        _schedules = schedules;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveSchedules() async {
    try {
      await _repository.updateMasterSchedule(_schedules);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('График сохранен'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _toggleDayOff(int dayIndex) {
    setState(() {
      _schedules[dayIndex] = _schedules[dayIndex].copyWith.call(
            isDayOff: !_schedules[dayIndex].isDayOff,
          );
    });
  }

  void _addWorkingWindow(int dayIndex) {
    final newWindow = WorkingWindow(
      startTime: const TimeOfDay(hour: 9, minute: 0),
      endTime: const TimeOfDay(hour: 18, minute: 0),
    );

    setState(() {
      final windows = List<WorkingWindow>.from(
        _schedules[dayIndex].workingWindows,
      );
      windows.add(newWindow);
      _schedules[dayIndex] = _schedules[dayIndex].copyWith.call(
            workingWindows: windows,
          );
    });
  }

  void _removeWorkingWindow(int dayIndex, int windowIndex) {
    setState(() {
      final windows = List<WorkingWindow>.from(
        _schedules[dayIndex].workingWindows,
      );
      windows.removeAt(windowIndex);
      _schedules[dayIndex] = _schedules[dayIndex].copyWith.call(
            workingWindows: windows,
          );
    });
  }

  void _updateWindowTime(
    int dayIndex,
    int windowIndex,
    bool isStart,
    TimeOfDay time,
  ) {
    setState(() {
      final windows = List<WorkingWindow>.from(
        _schedules[dayIndex].workingWindows,
      );
      final window = windows[windowIndex];

      windows[windowIndex] = window.copyWith.call(
        startTime: isStart ? time : window.startTime,
        endTime: !isStart ? time : window.endTime,
      );

      _schedules[dayIndex] = _schedules[dayIndex].copyWith.call(
            workingWindows: windows,
          );
    });
  }

  void _applyPreset(String presetName) {
    final presets = {
      'Стандартный (9:00-18:00)': _createStandardPreset(),
      'Вечерний (14:00-22:00)': _createEveningPreset(),
      'Барбер (10:00-20:00)': _createBarberPreset(),
      '24/7': _create24_7Preset(),
    };

    final preset = presets[presetName];
    if (preset != null) {
      setState(() {
        _schedules = preset;
      });
    }
  }

  List<DailySchedule> _createStandardPreset() {
    return List.generate(7, (index) {
      final isDayOff = index >= 5;

      return DailySchedule(
        dayOfWeek: index + 1,
        isDayOff: isDayOff,
        workingWindows: isDayOff
            ? []
            : [
                WorkingWindow(
                  startTime: const TimeOfDay(hour: 9, minute: 0),
                  endTime: const TimeOfDay(hour: 18, minute: 0),
                ),
              ],
      );
    });
  }

  List<DailySchedule> _createEveningPreset() {
    return List.generate(7, (index) {
      final isDayOff = index >= 5;

      return DailySchedule(
        dayOfWeek: index + 1,
        isDayOff: isDayOff,
        workingWindows: isDayOff
            ? []
            : [
                WorkingWindow(
                  startTime: const TimeOfDay(hour: 14, minute: 0),
                  endTime: const TimeOfDay(hour: 22, minute: 0),
                ),
              ],
      );
    });
  }

  List<DailySchedule> _createTattooPreset() {
    return List.generate(7, (index) {
      final isDayOff = index == 6;

      return DailySchedule(
        dayOfWeek: index + 1,
        isDayOff: isDayOff,
        workingWindows: isDayOff
            ? []
            : [
                WorkingWindow(
                  startTime: const TimeOfDay(hour: 12, minute: 0),
                  endTime: const TimeOfDay(hour: 21, minute: 0),
                ),
              ],
      );
    });
  }

  List<DailySchedule> _createBarberPreset() {
    return List.generate(7, (index) {
      final isDayOff = index == 6;

      return DailySchedule(
        dayOfWeek: index + 1,
        isDayOff: isDayOff,
        workingWindows: isDayOff
            ? []
            : [
                WorkingWindow(
                  startTime: const TimeOfDay(hour: 10, minute: 0),
                  endTime: const TimeOfDay(hour: 20, minute: 0),
                ),
              ],
      );
    });
  }

  List<DailySchedule> _create24_7Preset() {
    return List.generate(7, (index) {
      return DailySchedule(
        dayOfWeek: index + 1,
        isDayOff: false,
        workingWindows: [
          WorkingWindow(
            startTime: const TimeOfDay(hour: 0, minute: 0),
            endTime: const TimeOfDay(hour: 23, minute: 59),
          ),
        ],
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Гибкий график работы'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.auto_awesome),
            tooltip: 'Быстрые пресеты',
            onSelected: _applyPreset,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'Стандартный (9:00-18:00)',
                child: Text('Стандартный (9:00-18:00)'),
              ),
              const PopupMenuItem(
                value: 'Вечерний (14:00-22:00)',
                child: Text('Вечерний (14:00-22:00)'),
              ),
              const PopupMenuItem(
                value: 'Тату салон (12:00-21:00)',
                child: Text('Тату салон (12:00-21:00)'),
              ),
              const PopupMenuItem(
                value: 'Барбер (10:00-20:00)',
                child: Text('Барбер (10:00-20:00)'),
              ),
              const PopupMenuItem(value: '24/7', child: Text('24/7')),
            ],
          ),
          IconButton(icon: const Icon(Icons.save), onPressed: _saveSchedules),
        ],
      ),
      body: ListView.builder(
        itemCount: _schedules.length,
        itemBuilder: (context, dayIndex) {
          return _buildDayCard(dayIndex);
        },
      ),
    );
  }

  Widget _buildDayCard(int dayIndex) {
    final schedule = _schedules[dayIndex];

    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Заголовок дня
            Row(
              children: [
                Checkbox(
                  value: !schedule.isDayOff,
                  onChanged: (value) => _toggleDayOff(dayIndex),
                ),
                Expanded(
                  child: Text(
                    _dayNames[dayIndex],
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: schedule.isDayOff ? Colors.grey : Colors.black,
                    ),
                  ),
                ),
                if (schedule.isDayOff)
                  const Chip(
                    label: Text('Выходной'),
                    backgroundColor: Colors.red,
                    labelStyle: TextStyle(color: Colors.white),
                  ),
              ],
            ),

            if (!schedule.isDayOff) ...[
              const SizedBox(height: 16),

              // Рабочие окна
              ...schedule.workingWindows.asMap().entries.map((entry) {
                final windowIndex = entry.key;
                final window = entry.value;

                return _buildWindowRow(dayIndex, windowIndex, window);
              }).toList(),

              // Кнопка добавления окна
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _addWorkingWindow(dayIndex),
                  icon: const Icon(Icons.add),
                  label: const Text('Добавить время'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildWindowRow(int dayIndex, int windowIndex, WorkingWindow window) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          // Время начала
          _buildTimePicker(
            label: 'С',
            time: window.startTime,
            onTimeChanged: (time) =>
                _updateWindowTime(dayIndex, windowIndex, true, time),
          ),

          const SizedBox(width: 16),
          const Text('до'),
          const SizedBox(width: 16),

          // Время окончания
          _buildTimePicker(
            label: 'До',
            time: window.endTime,
            onTimeChanged: (time) =>
                _updateWindowTime(dayIndex, windowIndex, false, time),
          ),

          const Spacer(),

          // Кнопка удаления
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () => _removeWorkingWindow(dayIndex, windowIndex),
          ),
        ],
      ),
    );
  }

  Widget _buildTimePicker({
    required String label,
    required TimeOfDay time,
    required Function(TimeOfDay) onTimeChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        GestureDetector(
          onTap: () async {
            final pickedTime = await showTimePicker(
              context: context,
              initialTime: time,
              builder: (context, child) {
                return MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(alwaysUse24HourFormat: true),
                  child: child!,
                );
              },
            );

            if (pickedTime != null) {
              onTimeChanged(pickedTime);
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ),
      ],
    );
  }
}
