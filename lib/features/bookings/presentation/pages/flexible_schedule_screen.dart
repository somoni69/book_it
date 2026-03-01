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
      // Показываем индикатор загрузки (можно добавить локальный стейт, но для скорости покажем SnackBar)
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Сохранение...'), duration: Duration(seconds: 1)),
      );

      await _repository.updateMasterSchedule(_schedules);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ График успешно сохранен'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
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
      final windows = List<WorkingWindow>.from(_schedules[dayIndex].workingWindows);
      windows.add(newWindow);
      _schedules[dayIndex] = _schedules[dayIndex].copyWith.call(workingWindows: windows);
    });
  }

  void _removeWorkingWindow(int dayIndex, int windowIndex) {
    setState(() {
      final windows = List<WorkingWindow>.from(_schedules[dayIndex].workingWindows);
      windows.removeAt(windowIndex);
      _schedules[dayIndex] = _schedules[dayIndex].copyWith.call(workingWindows: windows);
    });
  }

  void _updateWindowTime(int dayIndex, int windowIndex, bool isStart, TimeOfDay time) {
    setState(() {
      final windows = List<WorkingWindow>.from(_schedules[dayIndex].workingWindows);
      final window = windows[windowIndex];

      windows[windowIndex] = window.copyWith.call(
        startTime: isStart ? time : window.startTime,
        endTime: !isStart ? time : window.endTime,
      );

      _schedules[dayIndex] = _schedules[dayIndex].copyWith.call(workingWindows: windows);
    });
  }

  void _applyPreset(String presetName) {
    final presets = {
      'Стандарт (9-18)': _createStandardPreset(),
      'Вечер (14-22)': _createEveningPreset(),
      'Барбер (10-20)': _createBarberPreset(),
      'Тату (12-21)': _createTattooPreset(),
      '24/7': _create24_7Preset(),
    };

    final preset = presets[presetName];
    if (preset != null) {
      setState(() {
        _schedules = preset;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Применен шаблон: $presetName'),
          backgroundColor: Colors.blue.shade600,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
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
            : [WorkingWindow(startTime: const TimeOfDay(hour: 9, minute: 0), endTime: const TimeOfDay(hour: 18, minute: 0))],
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
            : [WorkingWindow(startTime: const TimeOfDay(hour: 14, minute: 0), endTime: const TimeOfDay(hour: 22, minute: 0))],
      );
    });
  }

  List<DailySchedule> _createTattooPreset() {
    return List.generate(7, (index) {
      final isDayOff = index == 6; // Только воскресенье выходной
      return DailySchedule(
        dayOfWeek: index + 1,
        isDayOff: isDayOff,
        workingWindows: isDayOff
            ? []
            : [WorkingWindow(startTime: const TimeOfDay(hour: 12, minute: 0), endTime: const TimeOfDay(hour: 21, minute: 0))],
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
            : [WorkingWindow(startTime: const TimeOfDay(hour: 10, minute: 0), endTime: const TimeOfDay(hour: 20, minute: 0))],
      );
    });
  }

  List<DailySchedule> _create24_7Preset() {
    return List.generate(7, (index) {
      return DailySchedule(
        dayOfWeek: index + 1,
        isDayOff: false,
        workingWindows: [WorkingWindow(startTime: const TimeOfDay(hour: 0, minute: 0), endTime: const TimeOfDay(hour: 23, minute: 59))],
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: Colors.blue)));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('График работы', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
        shadowColor: Colors.black.withOpacity(0.05),
      ),
      body: Column(
        children: [
          _buildPresetsBar(),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(top: 8, bottom: 24),
              physics: const BouncingScrollPhysics(),
              itemCount: _schedules.length,
              itemBuilder: (context, dayIndex) {
                return _buildDayCard(dayIndex);
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildStickySaveButton(),
    );
  }

  // --- Горизонтальная лента пресетов ---
  Widget _buildPresetsBar() {
    final presetsList = ['Стандарт (9-18)', 'Вечер (14-22)', 'Барбер (10-20)', 'Тату (12-21)', '24/7'];

    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(Icons.auto_awesome, size: 16, color: Colors.amber.shade700),
                const SizedBox(width: 8),
                Text('Быстрые шаблоны', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 36,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: presetsList.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final presetName = presetsList[index];
                return ActionChip(
                  label: Text(presetName, style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.w500)),
                  backgroundColor: Colors.blue.shade50,
                  side: BorderSide(color: Colors.blue.shade200),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  onPressed: () => _applyPreset(presetName),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayCard(int dayIndex) {
    final schedule = _schedules[dayIndex];
    final isWorking = !schedule.isDayOff;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: _borderRadius,
        boxShadow: _cardShadow,
        border: Border.all(color: isWorking ? Colors.blue.shade100 : Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Шапка дня
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _toggleDayOff(dayIndex),
              borderRadius: schedule.isDayOff ? _borderRadius : const BorderRadius.vertical(top: Radius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _dayNames[dayIndex],
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: isWorking ? Colors.black87 : Colors.grey.shade500,
                        ),
                      ),
                    ),
                    if (!isWorking)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                        child: Text('Выходной', style: TextStyle(color: Colors.red.shade700, fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    Switch(
                      value: isWorking,
                      onChanged: (value) => _toggleDayOff(dayIndex),
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

          // Рабочие окна
          if (isWorking) ...[
            Divider(height: 1, color: Colors.blue.shade50),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  ...schedule.workingWindows.asMap().entries.map((entry) {
                    return _buildWindowRow(dayIndex, entry.key, entry.value);
                  }),
                  
                  // Добавить окно
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _addWorkingWindow(dayIndex),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Добавить перерыв / окно', style: TextStyle(fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.blue.shade600,
                        side: BorderSide(color: Colors.blue.shade200, style: BorderStyle.solid),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWindowRow(int dayIndex, int windowIndex, WorkingWindow window) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: _buildTimePicker(
              time: window.startTime,
              onTimeChanged: (time) => _updateWindowTime(dayIndex, windowIndex, true, time),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text('-', style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: _buildTimePicker(
              time: window.endTime,
              onTimeChanged: (time) => _updateWindowTime(dayIndex, windowIndex, false, time),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(10)),
            child: IconButton(
              icon: Icon(Icons.delete_outline_rounded, color: Colors.red.shade400, size: 20),
              onPressed: () => _removeWorkingWindow(dayIndex, windowIndex),
              tooltip: 'Удалить время',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimePicker({required TimeOfDay time, required Function(TimeOfDay) onTimeChanged}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          final pickedTime = await showTimePicker(
            context: context,
            initialTime: time,
            builder: (context, child) {
              return MediaQuery(
                data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
                child: Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: ColorScheme.light(primary: Colors.blue.shade600),
                  ),
                  child: child!,
                ),
              );
            },
          );
          if (pickedTime != null) onTimeChanged(pickedTime);
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.blue.shade100),
          ),
          child: Center(
            child: Text(
              '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue.shade800),
            ),
          ),
        ),
      ),
    );
  }

  // --- ЛИПКАЯ КНОПКА СОХРАНЕНИЯ ---
  Widget _buildStickySaveButton() {
    return Container(
      padding: const EdgeInsets.only(top: 16, left: 24, right: 24, bottom: 32),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, -5))
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.save_rounded, size: 22),
            label: const Text('Сохранить график', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 4,
              shadowColor: Colors.blue.withOpacity(0.4),
            ),
            onPressed: _saveSchedules,
          ),
        ),
      ),
    );
  }
}