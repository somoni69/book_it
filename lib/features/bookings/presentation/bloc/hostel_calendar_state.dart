import 'package:equatable/equatable.dart';

abstract class HostelCalendarState extends Equatable {
  const HostelCalendarState();

  @override
  List<Object?> get props => [];
}

/// Начальное состояние (пусто)
class HostelCalendarInitial extends HostelCalendarState {}

/// Загрузка данных
class HostelCalendarLoading extends HostelCalendarState {}

/// Данные загружены
class HostelCalendarLoaded extends HostelCalendarState {
  final Map<int, int> occupancyMap; // {день: свободные места}
  final int totalCapacity;
  final DateTime currentMonth;
  final String serviceId;

  const HostelCalendarLoaded({
    required this.occupancyMap,
    required this.totalCapacity,
    required this.currentMonth,
    required this.serviceId,
  });

  @override
  List<Object?> get props =>
      [occupancyMap, totalCapacity, currentMonth, serviceId];
}

/// Ошибка загрузки
class HostelCalendarError extends HostelCalendarState {
  final String message;

  const HostelCalendarError(this.message);

  @override
  List<Object?> get props => [message];
}
