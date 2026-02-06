import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/repositories/working_hour_repository_impl.dart';
import '../../domain/entities/working_hour_entity.dart';
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
        // Создаем дефолтный график (Пн-Пт 9:00-18:00, Сб-Вс выходные)
        setState(() {
          for (int i = 1; i <= 7; i++) {
            _workingHours.add(
              WorkingHourEntity(
                id: 'temp_$i',
                masterId: _masterId,
                dayOfWeek: i,
                startTime: const TimeOfDay(hour: 9, minute: 0),
                endTime: const TimeOfDay(hour: 18, minute: 0),
                isDayOff: i >= 6, // Суббота и воскресенье - выходные
              ),
            );
          }
          _isLoading = false;
        });
      } else {
        setState(() {
          _workingHours.addAll(hours);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Ошибка загрузки: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveWorkingHours() async {
    try {
      await _repository.updateWorkingHours(_workingHours);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('График работы успешно сохранен'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка сохранения: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      setState(() {
        if (isStart) {
          _workingHours[index] = wh.copyWith(startTime: picked);
        } else {
          _workingHours[index] = wh.copyWith(endTime: picked);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('График работы'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.save, color: Colors.blue),
            onPressed: _saveWorkingHours,
            tooltip: 'Сохранить',
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _workingHours.length,
        itemBuilder: (context, index) {
          final wh = _workingHours[index];
          return _buildDayCard(wh, index);
        },
      ),
    );
  }

  Widget _buildDayCard(WorkingHourEntity wh, int index) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          SwitchListTile(
            title: Text(
              wh.dayName,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            subtitle: wh.isDayOff ? const Text('Выходной') : Text(wh.timeRange),
            value: !wh.isDayOff,
            onChanged: (value) {
              setState(() {
                _workingHours[index] = wh.copyWith(isDayOff: !value);
              });
            },
            secondary: Icon(
              wh.isDayOff ? Icons.beach_access : Icons.work,
              color: wh.isDayOff ? Colors.orange : Colors.blue,
            ),
          ),
          if (!wh.isDayOff)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: _buildTimeButton(
                      context,
                      'Начало',
                      wh.startTime,
                      () => _selectTime(index, true),
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Icon(Icons.arrow_forward, color: Colors.grey),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildTimeButton(
                      context,
                      'Конец',
                      wh.endTime,
                      () => _selectTime(index, false),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTimeButton(
    BuildContext context,
    String label,
    TimeOfDay time,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blue.shade200),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 4),
            Text(
              time.format(context),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
