import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repositories/booking_repository.dart';
import '../../domain/usecases/generate_slots.dart';
import '../../domain/entities/booking_entity.dart';
import '../../data/models/working_hour_model.dart';
import 'booking_event.dart';
import 'booking_state.dart';

class BookingBloc extends Bloc<BookingEvent, BookingState> {
  final BookingRepository repository;
  final String masterId;
  final GenerateSlotsUseCase generateSlots = GenerateSlotsUseCase();

  int _lastServiceDuration = 60;

  BookingBloc({required this.repository, required this.masterId})
    : super(BookingInitial()) {
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

      // Запускаем два запроса параллельно: Брони и График
      final results = await Future.wait([
        repository.getBookingsForMaster(masterId, event.date),
        repository.getSchedule(masterId),
      ]);

      final List<BookingEntity> bookings = results[0] as List<BookingEntity>;
      final List<WorkingHour> schedule = results[1] as List<WorkingHour>;

      // Генерируем слоты
      final slots = generateSlots(
        bookings: bookings,
        schedule: schedule,
        date: event.date,
        serviceDurationMin: event.serviceDuration,
      );

      print(
        "📅 Для даты ${event.date} найдено ${slots.length} слотов. График: ${schedule.firstWhere((element) => element.dayOfWeek == event.date.weekday).isDayOff ? 'ВЫХОДНОЙ' : 'РАБОЧИЙ'}",
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
        orElse: () => WorkingHour(
          id: '',
          dayOfWeek: 0,
          startTime: '09:00',
          endTime: '18:00',
          isDayOff: false,
        ),
      );

      if (daySettings.isDayOff) {
        emit(
          currentState.copyWith(
            submissionStatus: BookingSubmissionStatus.failure,
          ),
        );
        print("🛑 ПОПЫТКА ЗАПИСИ В ВЫХОДНОЙ ЗАБЛОКИРОВАНА");
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
            selectedSlot: null, // Сбрасываем выбор
          ),
        );

        // Сразу перезагружаем слоты, чтобы "занять" место на экране
        add(
          LoadBookingsForDate(currentState.selectedDate, _lastServiceDuration),
        );
      } catch (e) {
        print(e);
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
        // Если ошибка - можно вернуть обратно, но для MVP забьем (или покажем тост ошибки)
        print("Ошибка отмены: $e");
        // В идеале тут нужно вернуть бронь обратно в список и показать ошибку
      }
    }
  }
}
