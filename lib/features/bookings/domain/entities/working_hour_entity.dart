import 'package:flutter/material.dart';

class WorkingHourEntity {
  final String id;
  final String masterId;
  final int dayOfWeek;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final bool isDayOff;
  final bool isActive;

  const WorkingHourEntity({
    required this.id,
    required this.masterId,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    this.isDayOff = false,
    this.isActive = true,
  });

  WorkingHourEntity copyWith({
    String? id,
    String? masterId,
    int? dayOfWeek,
    TimeOfDay? startTime,
    TimeOfDay? endTime,
    bool? isDayOff,
    bool? isActive,
  }) {
    return WorkingHourEntity(
      id: id ?? this.id,
      masterId: masterId ?? this.masterId,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      isDayOff: isDayOff ?? this.isDayOff,
      isActive: isActive ?? this.isActive,
    );
  }

  String get dayName {
    const days = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
    return days[dayOfWeek - 1];
  }

  String get timeRange {
    final start =
        '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}';
    final end =
        '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}';
    return '$start - $end';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'master_id': masterId,
      'day_of_week': dayOfWeek,
      'start_time':
          '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}',
      'end_time':
          '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}',
      'is_day_off': isDayOff,
      'is_active': isActive,
    };
  }

  factory WorkingHourEntity.fromJson(Map<String, dynamic> json) {
    final startParts = (json['start_time'] as String).split(':');
    final endParts = (json['end_time'] as String).split(':');

    return WorkingHourEntity(
      id: json['id'] as String,
      masterId: json['master_id'] as String,
      dayOfWeek: json['day_of_week'] as int,
      startTime: TimeOfDay(
        hour: int.parse(startParts[0]),
        minute: int.parse(startParts[1]),
      ),
      endTime: TimeOfDay(
        hour: int.parse(endParts[0]),
        minute: int.parse(endParts[1]),
      ),
      isDayOff: json['is_day_off'] as bool? ?? false,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WorkingHourEntity && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'WorkingHourEntity(id: $id, dayOfWeek: $dayOfWeek, timeRange: $timeRange)';
  }
}
