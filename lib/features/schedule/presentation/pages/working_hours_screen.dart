import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shimmer/shimmer.dart';
import '../../../bookings/data/repositories/working_hour_repository_impl.dart';
import '../../../bookings/domain/entities/working_hour_entity.dart';
import '../../../../core/utils/user_utils.dart';

class WorkingHoursScreen extends StatefulWidget {
  const WorkingHoursScreen({super.key});

  @override
  State<WorkingHoursScreen> createState() => _WorkingHoursScreenState();
}

class _WorkingHoursScreenState extends State<WorkingHoursScreen> {
  final List<WorkingHourEntity> _workingHours = [];
  bool _isLoading = true;
  late String _masterId;
  late WorkingHourRepositoryImpl _repository;

  // Локализация дней недели
  final Map<int, String> _dayNames = {
    1: 'Понедельник',
    2: 'Вторник',
    3: 'Среда',
    4: 'Четверг',
    5: 'Пятница',
    6: 'Суббота',
    7: 'Воскресенье',
  };

  // --- ЕДИНЫЙ СТИЛЬ ---
  final BorderRadius _borderRadius = BorderRadius.circular(16);
  final List<BoxShadow> _cardShadow = [
    BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 16, offset: const Offset(0, 4)),
  ];

  @override
  void initState() {
    super.initState();
    _masterId = UserUtils.getCurrentUserIdOrThrow();
    _repository = WorkingHourRepositoryImpl(Supabase.instance.client);
    _loadWorkingHours();
  }

  Future<void> _loadWorkingHours() async {
    try {
      final hours = await _repository.getWorkingHours(_masterId);

      if (hours.isEmpty) {
        setState(() {
          for (int i = 1; i <= 7; i++) {
            _workingHours.add(
              WorkingHourEntity(
                id: 'temp_$i',
                masterId: _masterId,
                dayOfWeek: i,
                startTime: const TimeOfDay(hour: 9, minute: 0),
                endTime: const TimeOfDay(hour: 18, minute: 0),
                isDayOff: i >= 6, // СБ и ВС - выходные по умолчанию
              ),
            );
          }
          _isLoading = false;
        });
      } else {
        // Сортируем дни по порядку (ПН-ВС)
        hours.sort((a, b) => a.dayOfWeek.compareTo(b.dayOfWeek));
        setState(() {
          _workingHours.addAll(hours);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        _showError('Ошибка загрузки: $e');
        setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red.shade600, behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _saveWorkingHours() async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Сохранение...'), duration: Duration(seconds: 1)));

      await _repository.updateWorkingHours(_workingHours);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ График работы сохранен'), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) _showError('Ошибка сохранения: $e');
    }
  }

  Future<void> _selectTime(int index, bool isStart) async {
    final wh = _workingHours[index];
    final initialTime = isStart ? wh.startTime : wh.endTime;

    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: Theme(
            data: Theme.of(context).copyWith(colorScheme: ColorScheme.light(primary: Colors.blue.shade600)),
            child: child!,
          ),
        );
      },
    );

    if (picked != null && mounted) {
      setState(() {
        if (isStart) {
          // Защита: Начало не может быть позже Конца
          final endMinutes = wh.endTime.hour * 60 + wh.endTime.minute;
          final pickedMinutes = picked.hour * 60 + picked.minute;
          
          if (pickedMinutes >= endMinutes) {
            _showError('Время открытия должно быть раньше закрытия');
            return;
          }
          _workingHours[index] = wh.copyWith(startTime: picked);
        } else {
          // Защита: Конец не может быть раньше Начала
          final startMinutes = wh.startTime.hour * 60 + wh.startTime.minute;
          final pickedMinutes = picked.hour * 60 + picked.minute;
          
          if (pickedMinutes <= startMinutes) {
            _showError('Время закрытия должно быть позже открытия');
            return;
          }
          _workingHours[index] = wh.copyWith(endTime: picked);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Настройка графика', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
        shadowColor: Colors.black.withOpacity(0.05),
      ),
      body: _isLoading ? _buildSkeleton() : _buildContent(),
      bottomNavigationBar: _isLoading ? null : _buildStickySaveButton(),
    );
  }

  Widget _buildContent() {
    return ListView.builder(
      padding: const EdgeInsets.all(16).copyWith(bottom: 24),
      physics: const BouncingScrollPhysics(),
      itemCount: _workingHours.length,
      itemBuilder: (context, index) => _buildDayCard(_workingHours[index], index),
    );
  }

  Widget _buildDayCard(WorkingHourEntity wh, int index) {
    final isWorking = !wh.isDayOff;
    final dayName = _dayNames[wh.dayOfWeek] ?? 'День';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: _borderRadius,
        boxShadow: _cardShadow,
        border: Border.all(color: isWorking ? Colors.blue.shade100 : Colors.grey.shade100),
      ),
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                setState(() => _workingHours[index] = wh.copyWith(isDayOff: isWorking));
              },
              borderRadius: isWorking ? const BorderRadius.vertical(top: Radius.circular(16)) : _borderRadius,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isWorking ? Colors.blue.shade50 : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10)
                      ),
                      child: Icon(
                        isWorking ? Icons.work_rounded : Icons.weekend_rounded,
                        size: 20,
                        color: isWorking ? Colors.blue.shade600 : Colors.grey.shade400,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(dayName,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isWorking ? Colors.black87 : Colors.grey.shade500
                            )
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isWorking ? '${_formatTime(wh.startTime)} - ${_formatTime(wh.endTime)}' : 'Выходной',
                            style: TextStyle(
                              fontSize: 13,
                              color: isWorking ? Colors.grey.shade600 : Colors.red.shade400,
                              fontWeight: isWorking ? FontWeight.normal : FontWeight.w600
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: isWorking,
                      onChanged: (value) {
                        setState(() => _workingHours[index] = wh.copyWith(isDayOff: !value));
                      },
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
          if (isWorking) ...[
            Divider(height: 1, color: Colors.blue.shade50),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(child: _buildTimeButton(context, 'Открытие', wh.startTime, () => _selectTime(index, true))),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text('-', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 18)),
                  ),
                  Expanded(child: _buildTimeButton(context, 'Закрытие', wh.endTime, () => _selectTime(index, false))),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTimeButton(BuildContext context, String label, TimeOfDay time, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue.shade100),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 11, color: Colors.blue.shade400, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatTime(time),
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue.shade900),
                  ),
                  Icon(Icons.expand_more_rounded, size: 16, color: Colors.blue.shade400),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStickySaveButton() {
    return Container(
      padding: const EdgeInsets.only(top: 16, left: 24, right: 24, bottom: 32),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, -5))],
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.save_rounded, size: 20),
            label: const Text('Сохранить график', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 4,
              shadowColor: Colors.blue.withOpacity(0.4),
            ),
            onPressed: _saveWorkingHours,
          ),
        ),
      ),
    );
  }

  Widget _buildSkeleton() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade200,
      highlightColor: Colors.grey.shade50,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: 7,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, __) => Container(height: 72, decoration: BoxDecoration(color: Colors.white, borderRadius: _borderRadius)),
      ),
    );
  }

  String _formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}