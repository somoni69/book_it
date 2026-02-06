import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repositories/booking_repository.dart';
import '../../domain/usecases/generate_slots.dart';
import '../../domain/entities/booking_entity.dart';
import '../../domain/entities/working_hour_entity.dart';
import '../../domain/repositories/service_repository.dart';
import 'booking_event.dart';
import 'booking_state.dart';

class BookingBloc extends Bloc<BookingEvent, BookingState> {
  final BookingRepository repository;
  final ServiceRepository serviceRepository;
  final String masterId;
  late final GenerateSlotsUseCase generateSlots;

  int _lastServiceDuration = 60;

  BookingBloc({
    required this.repository,
    required this.serviceRepository,
    required this.masterId,
  }) : super(BookingInitial()) {
    generateSlots = GenerateSlotsUseCase(
      bookingRepo: repository,
      serviceRepo: serviceRepository,
    );
    on<LoadBookingsForDate>(_onLoadBookings);
    on<SelectTimeSlot>(_onSelectSlot);
    on<ConfirmBooking>(_onConfirmBooking);
    on<CancelBookingEvent>(_onCancelBooking);
  }

  Future<void> _onLoadBookings(
    LoadBookingsForDate event,
    Emitter<BookingState> emit,
  ) async {
    emit(BookingLoading());
    try {
      _lastServiceDuration = event.serviceDuration;

      final bookings = await repository.getBookingsForMaster(
        masterId,
        event.date,
      );

      final slots = await generateSlots(
        GenerateSlotsParams(
          masterId: masterId,
          serviceId: event.serviceId,
          selectedDate: event.date,
        ),
      );

      emit(
        BookingLoaded(
          bookings: bookings,
          slots: slots,
          selectedDate: event.date,
          selectedSlot: null,
        ),
      );
    } catch (e) {
      emit(BookingError("Ошибка: $e"));
    }
  }

  void _onSelectSlot(SelectTimeSlot event, Emitter<BookingState> emit) {
    if (state is BookingLoaded) {
      final currentState = state as BookingLoaded;
      emit(currentState.copyWith(selectedSlot: event.slot));
    }
  }

  Future<void> _onConfirmBooking(
    ConfirmBooking event,
    Emitter<BookingState> emit,
  ) async {
    if (state is BookingLoaded) {
      final currentState = state as BookingLoaded;
      final slot = currentState.selectedSlot;

      if (slot == null) return; // Если ничего не выбрано, игнор

      // 1. ПРОВЕРКА ПЕРЕД ЗАПИСЬЮ: А не выходной ли это?
      // Мы можем загрузить график еще раз для страховки
      final schedule = await repository.getSchedule(masterId);
      final daySettings = schedule.firstWhere(
        (h) => h.dayOfWeek == slot.startTime.weekday,
        orElse: () => const WorkingHourEntity(
          id: '',
          masterId: '',
          dayOfWeek: 0,
          startTime: TimeOfDay(hour: 9, minute: 0),
          endTime: TimeOfDay(hour: 18, minute: 0),
          isDayOff: false,
        ),
      );

      if (daySettings.isDayOff) {
        emit(
          currentState.copyWith(
            submissionStatus: BookingSubmissionStatus.failure,
          ),
        );
        return;
      }

      // 2. Если не выходной - создаем запись
      emit(
        currentState.copyWith(
          submissionStatus: BookingSubmissionStatus.submitting,
        ),
      );

      try {
        await repository.createBooking(
          masterId: masterId,
          serviceId: event.serviceId,
          startTime: slot.startTime,
        );

        emit(
          currentState.copyWith(
            submissionStatus: BookingSubmissionStatus.success,
            selectedSlot: null,
          ),
        );

        add(
          LoadBookingsForDate(
            currentState.selectedDate,
            _lastServiceDuration,
            event.serviceId,
          ),
        );
      } catch (e) {
        emit(
          currentState.copyWith(
            submissionStatus: BookingSubmissionStatus.failure,
          ),
        );
      }
    }
  }

  Future<void> _onCancelBooking(
    CancelBookingEvent event,
    Emitter<BookingState> emit,
  ) async {
    if (state is BookingLoaded) {
      // Оптимистичное обновление: Сразу убираем из списка на экране, не ждем базы
      final currentState = state as BookingLoaded;

      // Создаем новый список без удаленного элемента
      final updatedList = currentState.bookings
          .where((b) => b.id != event.bookingId)
          .toList();

      // Эмитим новое состояние с обновленным списком
      emit(currentState.copyWith(bookings: updatedList));

      try {
        await repository.updateBookingStatus(
          event.bookingId,
          BookingStatus.cancelled,
        );
      } catch (e) {
        // Rollback on error
      }
    }
  }
}
