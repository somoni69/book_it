import 'package:flutter/material.dart';

/// Represents a daily schedule with working windows
class DailySchedule {
  final int dayOfWeek; // 1-7, where 1 is Monday
  final bool isDayOff;
  final List<WorkingWindow> workingWindows;
  final bool isActive;

  const DailySchedule({
    required this.dayOfWeek,
    required this.isDayOff,
    required this.workingWindows,
    this.isActive = true,
  });

  String get dayName {
    const days = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
    return days[dayOfWeek - 1];
  }

  DailySchedule copyWith({
    int? dayOfWeek,
    bool? isDayOff,
    List<WorkingWindow>? workingWindows,
    bool? isActive,
  }) {
    return DailySchedule(
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      isDayOff: isDayOff ?? this.isDayOff,
      workingWindows: workingWindows ?? this.workingWindows,
      isActive: isActive ?? this.isActive,
    );
  }
}

/// Represents a working time window within a day
class WorkingWindow {
  final TimeOfDay startTime;
  final TimeOfDay endTime;

  const WorkingWindow({
    required this.startTime,
    required this.endTime,
  });

  String get timeRange {
    final start =
        '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}';
    final end =
        '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}';
    return '$start - $end';
  }

  WorkingWindow copyWith({
    TimeOfDay? startTime,
    TimeOfDay? endTime,
  }) {
    return WorkingWindow(
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
    );
  }
}
