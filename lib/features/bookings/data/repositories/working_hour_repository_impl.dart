import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/working_hour_entity.dart';
import '../../domain/entities/daily_schedule.dart';
import '../../../../core/error/database_exception.dart';
import '../../../../core/utils/user_utils.dart';
import '../models/working_hour_model.dart';

class WorkingHourRepositoryImpl {
  final SupabaseClient _supabaseClient;

  WorkingHourRepositoryImpl(this._supabaseClient);

  Future<List<DailySchedule>> getMasterSchedule(String masterId) async {
    try {
      final response = await _supabaseClient
          .from('working_schedules')
          .select()
          .eq('master_id', masterId)
          .eq('is_active', true)
          .order('day_of_week');

      if (response.isEmpty) {
        return _createDefault24_7Schedule();
      }

      return (response as List)
          .map((json) => _dailyScheduleFromJson(json))
          .toList();
    } on PostgrestException catch (e) {
      throw DatabaseException(e.message);
    }
  }

  Future<void> updateMasterSchedule(List<DailySchedule> schedules) async {
    try {
      final masterId = UserUtils.getCurrentUserIdOrThrow();

      await _supabaseClient
          .from('working_schedules')
          .update({'is_active': false})
          .eq('master_id', masterId)
          .eq('is_active', true);

      final schedulesJson = schedules.map((schedule) {
        return {
          'master_id': masterId,
          'day_of_week': schedule.dayOfWeek,
          'is_day_off': schedule.isDayOff,
          'working_windows': schedule.workingWindows
              .map(
                (window) => {
                  'start': _timeToStr(window.startTime),
                  'end': _timeToStr(window.endTime),
                },
              )
              .toList(),
          'is_active': schedule.isActive,
        };
      }).toList();

      await _supabaseClient.from('working_schedules').insert(schedulesJson);
    } on PostgrestException catch (e) {
      throw DatabaseException(e.message);
    }
  }

  Future<List<WorkingHourEntity>> getWorkingHours(String masterId) async {
    try {
      final response = await _supabaseClient
          .from('working_hours')
          .select()
          .eq('master_id', masterId)
          .eq('is_active', true)
          .order('day_of_week');

      if (response.isEmpty) {
        return _createDefaultWorkingHours(masterId);
      }

      return (response as List)
          .map((json) => WorkingHourModel.fromJson(json).toEntity())
          .toList();
    } on PostgrestException catch (e) {
      throw DatabaseException(e.message);
    }
  }

  Future<void> updateWorkingHours(List<WorkingHourEntity> hours) async {
    try {
      if (hours.isEmpty) return;

      final masterId = hours.first.masterId;

      await _supabaseClient
          .from('working_hours')
          .delete()
          .eq('master_id', masterId);

      final hoursJson = hours.map((hour) {
        return {
          'master_id': hour.masterId,
          'day_of_week': hour.dayOfWeek,
          'start_time': _timeToStr(hour.startTime),
          'end_time': _timeToStr(hour.endTime),
          'is_day_off': hour.isDayOff,
          'is_active': hour.isActive,
        };
      }).toList();

      await _supabaseClient.from('working_hours').insert(hoursJson);
    } on PostgrestException catch (e) {
      throw DatabaseException(e.message);
    }
  }

  List<DailySchedule> _createDefault24_7Schedule() {
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

  List<WorkingHourEntity> _createDefaultWorkingHours(String masterId) {
    return List.generate(7, (index) {
      final dayNum = index + 1;
      return WorkingHourEntity(
        id: 'temp_$dayNum',
        masterId: masterId,
        dayOfWeek: dayNum,
        startTime: const TimeOfDay(hour: 9, minute: 0),
        endTime: const TimeOfDay(hour: 18, minute: 0),
        isDayOff: dayNum >= 6,
      );
    });
  }

  DailySchedule _dailyScheduleFromJson(Map<String, dynamic> json) {
    final windowsJson = json['working_windows'] as List<dynamic>? ?? [];

    final workingWindows = windowsJson
        .map(
          (window) => WorkingWindow(
            startTime: _strToTime(window['start'] as String),
            endTime: _strToTime(window['end'] as String),
          ),
        )
        .toList();

    return DailySchedule(
      dayOfWeek: json['day_of_week'] as int,
      isDayOff: json['is_day_off'] as bool? ?? false,
      workingWindows: workingWindows,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  String _timeToStr(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  TimeOfDay _strToTime(String timeStr) {
    final parts = timeStr.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }
}
