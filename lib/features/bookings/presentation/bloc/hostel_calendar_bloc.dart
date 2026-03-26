import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repositories/booking_repository.dart';
import 'hostel_calendar_event.dart';
import 'hostel_calendar_state.dart';

class HostelCalendarBloc
    extends Bloc<HostelCalendarEvent, HostelCalendarState> {
  final BookingRepository repository;
  String? _currentServiceId;

  HostelCalendarBloc({
    required this.repository,
    required String initialServiceId,
  }) : super(HostelCalendarInitial()) {
    _currentServiceId = initialServiceId;

    on<LoadHostelOccupancy>(_onLoadOccupancy);
    on<ChangeMonth>(_onChangeMonth);
  }

  Future<void> _onLoadOccupancy(
    LoadHostelOccupancy event,
    Emitter<HostelCalendarState> emit,
  ) async {
    emit(HostelCalendarLoading());
    _currentServiceId = event.serviceId;

    try {
      // Получаем вместимость услуги
      final occupancyMap = await repository.getHostelOccupancy(
        serviceId: event.serviceId,
        month: event.month,
      );

      // Вычисляем totalCapacity (берём максимальное значение из карты)
      final totalCapacity = occupancyMap.values.isNotEmpty
          ? occupancyMap.values.reduce((a, b) => a > b ? a : b)
          : 1;

      emit(HostelCalendarLoaded(
        occupancyMap: occupancyMap,
        totalCapacity: totalCapacity,
        currentMonth: event.month,
        serviceId: event.serviceId,
      ));
    } catch (e) {
      emit(HostelCalendarError(e.toString()));
    }
  }

  Future<void> _onChangeMonth(
    ChangeMonth event,
    Emitter<HostelCalendarState> emit,
  ) async {
    if (_currentServiceId == null) return;

    // Сохраняем текущее состояние для плавного перехода
    final currentState = state;
    if (currentState is HostelCalendarLoaded) {
      // Не показываем лоадер при смене месяца — просто обновляем данные
      try {
        final occupancyMap = await repository.getHostelOccupancy(
          serviceId: _currentServiceId!,
          month: event.newMonth,
        );

        emit(HostelCalendarLoaded(
          occupancyMap: occupancyMap,
          totalCapacity: currentState.totalCapacity,
          currentMonth: event.newMonth,
          serviceId: _currentServiceId!,
        ));
      } catch (e) {
        emit(HostelCalendarError(e.toString()));
      }
    } else {
      // Если данных ещё не было, загружаем с нуля
      add(LoadHostelOccupancy(
        serviceId: _currentServiceId!,
        month: event.newMonth,
      ));
    }
  }
}
