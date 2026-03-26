import 'package:equatable/equatable.dart';

abstract class HostelCalendarEvent extends Equatable {
  const HostelCalendarEvent();

  @override
  List<Object?> get props => [];
}

/// Загрузить загруженность хостела на конкретный месяц
class LoadHostelOccupancy extends HostelCalendarEvent {
  final String serviceId;
  final DateTime month;

  const LoadHostelOccupancy({
    required this.serviceId,
    required this.month,
  });

  @override
  List<Object?> get props => [serviceId, month];
}

/// Сменить месяц (при свайпе календаря)
class ChangeMonth extends HostelCalendarEvent {
  final DateTime newMonth;

  const ChangeMonth(this.newMonth);

  @override
  List<Object?> get props => [newMonth];
}
