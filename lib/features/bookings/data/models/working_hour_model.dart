import 'package:flutter/material.dart';
import '../../domain/entities/working_hour_entity.dart';

class WorkingHourModel {
  final String id;
  final String masterId;
  final int dayOfWeek;
  final String startTime;
  final String endTime;
  final bool isDayOff;
  final bool isActive;
  final String? organizationId;
  final DateTime? createdAt;

  const WorkingHourModel({
    required this.id,
    required this.masterId,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    this.isDayOff = false,
    this.isActive = true,
    this.organizationId,
    this.createdAt,
  });

  WorkingHourModel copyWith({
    String? id,
    String? masterId,
    int? dayOfWeek,
    String? startTime,
    String? endTime,
    bool? isDayOff,
    bool? isActive,
    String? organizationId,
    DateTime? createdAt,
  }) {
    return WorkingHourModel(
      id: id ?? this.id,
      masterId: masterId ?? this.masterId,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      isDayOff: isDayOff ?? this.isDayOff,
      isActive: isActive ?? this.isActive,
      organizationId: organizationId ?? this.organizationId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'master_id': masterId,
      'day_of_week': dayOfWeek,
      'start_time': startTime,
      'end_time': endTime,
      'is_day_off': isDayOff,
      'is_active': isActive,
      'organization_id': organizationId,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  factory WorkingHourModel.fromJson(Map<String, dynamic> json) {
    return WorkingHourModel(
      id: json['id'] as String,
      masterId: json['master_id'] as String,
      dayOfWeek: json['day_of_week'] as int,
      startTime: json['start_time'] as String,
      endTime: json['end_time'] as String,
      isDayOff: json['is_day_off'] as bool? ?? false,
      isActive: json['is_active'] as bool? ?? true,
      organizationId: json['organization_id'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  WorkingHourEntity toEntity() {
    final startParts = startTime.split(':');
    final endParts = endTime.split(':');

    return WorkingHourEntity(
      id: id,
      masterId: masterId,
      dayOfWeek: dayOfWeek,
      startTime: TimeOfDay(
        hour: int.parse(startParts[0]),
        minute: int.parse(startParts[1]),
      ),
      endTime: TimeOfDay(
        hour: int.parse(endParts[0]),
        minute: int.parse(endParts[1]),
      ),
      isDayOff: isDayOff,
      isActive: isActive,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WorkingHourModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'WorkingHourModel(id: $id, dayOfWeek: $dayOfWeek, startTime: $startTime, endTime: $endTime)';
  }
}
